import Foundation
import os

public actor SanitizationPipeline {
	private var openRouterClient: OpenRouterClient?
	private let keyManager = AIKeyManager()

	private static let logger = Logger(subsystem: "com.ebb.app", category: "ai")

	public init() {
		// Client initialized lazily in checkAvailability()
	}

	/// Check if AI is available and configure the client with current settings
	public func checkAvailability() async {
		let apiKey = keyManager.loadOrNil()
		let (model, provider) = await MainActor.run {
			let model = UserDefaults.standard.string(forKey: "aiModel") ?? AIModel.gpt5Nano.rawValue
			let provider =
				UserDefaults.standard.string(forKey: "aiProvider") ?? AIProvider.openRouter.rawValue
			return (model, provider)
		}

		Self.logger.debug(
			"checkAvailability: key=\(apiKey != nil), provider=\(provider), model=\(model)")

		if provider == AIProvider.openRouter.rawValue, let apiKey, !apiKey.isEmpty {
			self.openRouterClient = OpenRouterClient(apiKey: apiKey, model: model)
			Self.logger.debug("OpenRouter client configured")
		} else {
			self.openRouterClient = nil
			Self.logger.debug("No OpenRouter client (AI formatting disabled)")
		}
	}

	/// Returns whether AI sanitization is currently available
	public func isAIAvailable() -> Bool {
		openRouterClient != nil
	}

	/// Format pre-cleaned plain text using AI
	/// If AI is unavailable, returns the input as-is (PlainTextSanitizer already ran at fetch time)
	/// This method never throws - it always returns something useful
	public func sanitize(_ content: String) async -> String {
		// Skip empty or very short content
		guard !content.isEmpty, content.count > 10 else {
			Self.logger.debug("Skipping: content too short (\(content.count) chars)")
			return content
		}

		// Light preprocessing: normalize whitespace
		let preprocessed = preprocess(content)

		// Try AI formatting if available
		if let client = openRouterClient {
			Self.logger.debug("Calling OpenRouter API...")
			do {
				let result = try await client.sanitize(preprocessed)
				Self.logger.debug("OpenRouter success (\(result.count) chars)")
				return result
			} catch {
				Self.logger.error("OpenRouter FAILED: \(error)")
			}
		} else {
			Self.logger.debug("No OpenRouter client, returning input as-is")
		}

		// Return input as-is if AI unavailable or failed
		// PlainTextSanitizer already ran at fetch time, so this is still clean text
		return content
	}

	/// Light preprocessing before sending to AI
	private func preprocess(_ content: String) -> String {
		var result = content

		// Collapse 3+ consecutive newlines to 2 (paragraph break)
		while result.contains("\n\n\n") {
			result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
		}

		// Collapse multiple spaces to single space
		while result.contains("  ") {
			result = result.replacingOccurrences(of: "  ", with: " ")
		}

		// Trim leading/trailing whitespace
		result = result.trimmingCharacters(in: .whitespacesAndNewlines)

		return result
	}

	/// Sanitize multiple messages in parallel with controlled concurrency
	public func sanitizeMessages(_ contents: [(id: String, content: String)]) async -> [String:
		String]
	{
		await withTaskGroup(of: (String, String).self) { group in
			for (id, content) in contents {
				group.addTask {
					let sanitized = await self.sanitize(content)
					return (id, sanitized)
				}
			}

			var results: [String: String] = [:]
			for await (id, sanitized) in group {
				results[id] = sanitized
			}
			return results
		}
	}
}

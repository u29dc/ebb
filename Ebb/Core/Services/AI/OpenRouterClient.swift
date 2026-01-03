import Foundation
import os

nonisolated public struct OpenRouterClient: ContentSanitizer, Sendable {
	private let apiKey: String
	private let model: String
	private let timeout: TimeInterval
	private let baseURL = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
	private let session: URLSession

	private static let logger = Logger(subsystem: "com.ebb.app", category: "ai")

	/// System prompt loaded from bundled resource file
	private static let systemPrompt: String = {
		guard let url = Bundle.main.url(forResource: "SanitizationPrompt", withExtension: "md"),
			let content = try? String(contentsOf: url, encoding: .utf8)
		else {
			Self.logger.warning("Failed to load SanitizationPrompt.md from bundle")
			return
				"Format this email content as clean markdown. Output only the content, no commentary."
		}
		return content
	}()

	nonisolated public init(
		apiKey: String,
		model: String = "meta-llama/llama-3.1-8b-instruct",
		timeout: TimeInterval = 30
	) {
		self.apiKey = apiKey
		self.model = model
		self.timeout = timeout

		let config = URLSessionConfiguration.default
		config.timeoutIntervalForRequest = timeout
		config.timeoutIntervalForResource = timeout * 2
		self.session = URLSession(configuration: config)
	}

	nonisolated public func sanitize(_ content: String) async throws -> String {
		var request = URLRequest(url: baseURL)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
		request.setValue("Ebb", forHTTPHeaderField: "X-Title")
		request.timeoutInterval = timeout

		// Build full prompt: system instructions + input wrapper
		let fullPrompt = Self.systemPrompt + "\n\n<input>\n" + content + "\n</input>\n\nOUTPUT:"

		let body = OpenRouterRequest(
			model: model,
			messages: [
				Message(role: "user", content: fullPrompt)
			]
		)

		request.httpBody = try JSONEncoder().encode(body)

		let (data, response) = try await session.data(for: request)

		guard let httpResponse = response as? HTTPURLResponse else {
			throw SanitizationError.invalidResponse
		}

		switch httpResponse.statusCode {
		case 200...299:
			break
		case 401:
			throw SanitizationError.processingFailed("Invalid API key")
		case 429:
			throw SanitizationError.processingFailed("Rate limited")
		case 500...599:
			throw SanitizationError.serviceUnavailable
		default:
			// Log the actual error response for debugging
			let errorBody = String(data: data, encoding: .utf8) ?? "No body"
			Self.logger.error("OpenRouter HTTP \(httpResponse.statusCode): \(errorBody)")
			throw SanitizationError.processingFailed("HTTP \(httpResponse.statusCode)")
		}

		let result = try JSONDecoder().decode(OpenRouterResponse.self, from: data)

		guard let choice = result.choices.first else {
			throw SanitizationError.invalidResponse
		}

		let responseContent = choice.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
		return postProcess(responseContent)
	}

	/// Strip common LLM preamble/suffix patterns that models add despite instructions
	private nonisolated func postProcess(_ content: String) -> String {
		var result = content

		// Common preamble patterns to strip (case-insensitive)
		let preamblePatterns = [
			"(?i)^here('s| is) the (extracted|cleaned|sanitized|formatted|markdown|content|email).*?:\\s*\n*",
			"(?i)^the (extracted|cleaned|sanitized|formatted) (content|email|markdown).*?:\\s*\n*",
			"(?i)^(extracted|formatted) (content|email|markdown).*?:\\s*\n*",
			"(?i)^below is the.*?:\\s*\n*",
			"(?i)^i('ve| have) (extracted|formatted).*?:\\s*\n*",
		]

		for pattern in preamblePatterns {
			result = result.replacingOccurrences(
				of: pattern,
				with: "",
				options: .regularExpression
			)
		}

		// Strip markdown image syntax ![alt](url)
		result = result.replacingOccurrences(
			of: "!\\[[^\\]]*\\]\\([^)]*\\)",
			with: "",
			options: .regularExpression
		)

		// Strip any remaining raw HTML tags
		result = result.replacingOccurrences(
			of: "<[^>]+>",
			with: "",
			options: .regularExpression
		)

		// Clean up multiple blank lines
		while result.contains("\n\n\n") {
			result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
		}

		return result.trimmingCharacters(in: .whitespacesAndNewlines)
	}

	nonisolated public func isAvailable() async -> Bool {
		!apiKey.isEmpty
	}
}

// MARK: - Request/Response Models

nonisolated private struct OpenRouterRequest: Encodable, Sendable {
	let model: String
	let messages: [Message]
}

nonisolated private struct Message: Codable, Sendable {
	let role: String
	let content: String
}

nonisolated private struct OpenRouterResponse: Decodable, Sendable {
	let choices: [Choice]
}

nonisolated private struct Choice: Decodable, Sendable {
	let message: Message
}

// MARK: - Provider & Model Presets

nonisolated public enum AIProvider: String, CaseIterable, Sendable {
	case openRouter
	case none
}

nonisolated public enum AIModel: String, CaseIterable, Sendable {
	case gpt5Nano = "openai/gpt-5-nano"
	case llama4Scout = "meta-llama/llama-4-scout-17b-16e-instruct"
	case gemini25Flash = "google/gemini-2.5-flash"
	case gemini3Flash = "google/gemini-3-flash-preview"
	case claudeHaiku35 = "anthropic/claude-3.5-haiku"

	public var displayName: String {
		switch self {
		case .gpt5Nano: return "GPT-5 Nano"
		case .llama4Scout: return "Llama 4 Scout"
		case .gemini25Flash: return "Gemini 2.5 Flash"
		case .gemini3Flash: return "Gemini 3 Flash"
		case .claudeHaiku35: return "Claude Haiku 3.5"
		}
	}

	public var description: String {
		switch self {
		case .gpt5Nano: return "Cheapest, good instruction-following"
		case .llama4Scout: return "Fast via Groq"
		case .gemini25Flash: return "Good value"
		case .gemini3Flash: return "Better reasoning"
		case .claudeHaiku35: return "Best quality"
		}
	}
}

import Foundation

public protocol ContentSanitizer: Sendable {
	nonisolated func sanitize(_ content: String) async throws -> String
	nonisolated func isAvailable() async -> Bool
}

public enum SanitizationError: Error, LocalizedError, Sendable {
	case serviceUnavailable
	case processingFailed(String)
	case timeout
	case invalidResponse

	public var errorDescription: String? {
		switch self {
		case .serviceUnavailable:
			return "AI service is not available"
		case .processingFailed(let reason):
			return "Content processing failed: \(reason)"
		case .timeout:
			return "Request timed out"
		case .invalidResponse:
			return "Invalid response from AI service"
		}
	}
}

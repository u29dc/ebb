import Foundation

/// Defines retry behavior for network requests
public struct RetryPolicy: Sendable {
	/// Maximum number of retry attempts
	public let maxRetries: Int

	/// Base delay between retries (doubles with each attempt)
	public let baseDelay: TimeInterval

	/// Maximum delay between retries
	public let maxDelay: TimeInterval

	/// Jitter factor (0.0 to 1.0) to randomize delays
	public let jitterFactor: Double

	/// Default retry policy
	public static let `default` = RetryPolicy(
		maxRetries: 3,
		baseDelay: 1.0,
		maxDelay: 30.0,
		jitterFactor: 0.2
	)

	/// No retries
	public static let none = RetryPolicy(
		maxRetries: 0,
		baseDelay: 0,
		maxDelay: 0,
		jitterFactor: 0
	)

	public init(
		maxRetries: Int,
		baseDelay: TimeInterval,
		maxDelay: TimeInterval,
		jitterFactor: Double
	) {
		self.maxRetries = maxRetries
		self.baseDelay = baseDelay
		self.maxDelay = maxDelay
		self.jitterFactor = jitterFactor
	}

	/// Calculates the delay for a given attempt number
	public func delay(for attempt: Int) -> TimeInterval {
		guard attempt > 0 else { return 0 }

		// Exponential backoff: baseDelay * 2^attempt
		let exponentialDelay = baseDelay * pow(2.0, Double(attempt - 1))
		let cappedDelay = min(exponentialDelay, maxDelay)

		// Add jitter
		let jitter = cappedDelay * jitterFactor * Double.random(in: -1...1)
		return max(0, cappedDelay + jitter)
	}

	/// Determines if an error is retryable
	public static func isRetryable(_ error: Error) -> Bool {
		// Check for GmailAPIError
		if let apiError = error as? GmailAPIError {
			switch apiError {
			case .httpError(let status, _):
				// Retry on rate limit, server errors, and service unavailable
				return status == 429 || status == 503 || (500...599).contains(status)
			case .invalidURL, .invalidResponse:
				return false
			}
		}

		// Check for URLError (network issues)
		if let urlError = error as? URLError {
			switch urlError.code {
			case .timedOut, .networkConnectionLost, .notConnectedToInternet:
				return true
			default:
				return false
			}
		}

		return false
	}
}

/// Executes an async operation with retry logic
public func withRetry<T: Sendable>(
	policy: RetryPolicy = .default,
	operation: @Sendable () async throws -> T
) async throws -> T {
	var lastError: Error?

	for attempt in 0...policy.maxRetries {
		do {
			return try await operation()
		} catch {
			lastError = error

			// Check if we should retry
			guard attempt < policy.maxRetries && RetryPolicy.isRetryable(error) else {
				throw error
			}

			// Wait before retrying
			let delay = policy.delay(for: attempt + 1)
			try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
		}
	}

	throw lastError ?? GmailAPIError.invalidResponse
}

import Foundation

public struct GmailAPIClient: Sendable {
	public struct Configuration: Sendable {
		public let baseURL: URL
		public let userId: String

		public init(
			baseURL: URL = URL(string: "https://gmail.googleapis.com/gmail/v1")!,
			userId: String = "me"
		) {
			self.baseURL = baseURL
			self.userId = userId
		}
	}

	public let configuration: Configuration
	public let session: URLSession
	public let tokenProvider: @Sendable () async throws -> String

	public init(
		configuration: Configuration = Configuration(),
		session: URLSession = .shared,
		tokenProvider: @escaping @Sendable () async throws -> String
	) {
		self.configuration = configuration
		self.session = session
		self.tokenProvider = tokenProvider
	}

	/// List threads with optional filtering
	public func listThreads(
		labelIds: [String] = [],
		query: String? = nil,
		pageToken: String? = nil,
		maxResults: Int = 50
	) async throws -> GmailThreadListResponse {
		var queryItems: [URLQueryItem] = [
			URLQueryItem(name: "maxResults", value: String(maxResults))
		]
		if !labelIds.isEmpty {
			queryItems.append(
				URLQueryItem(name: "labelIds", value: labelIds.joined(separator: ",")))
		}
		if let query {
			queryItems.append(URLQueryItem(name: "q", value: query))
		}
		if let pageToken {
			queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
		}

		return try await request(
			path: "users/\(configuration.userId)/threads",
			queryItems: queryItems
		)
	}

	/// Get full thread details including messages
	public func getThread(id: String, format: String = "full") async throws -> GmailThread {
		return try await request(
			path: "users/\(configuration.userId)/threads/\(id)",
			queryItems: [URLQueryItem(name: "format", value: format)]
		)
	}

	/// List all labels
	public func listLabels() async throws -> GmailLabelsResponse {
		return try await request(path: "users/\(configuration.userId)/labels")
	}

	/// Get user profile
	public func getProfile() async throws -> GmailProfile {
		return try await request(path: "users/\(configuration.userId)/profile")
	}

	/// List history for incremental sync
	public func listHistory(startHistoryId: String) async throws -> GmailHistoryListResponse {
		return try await request(
			path: "users/\(configuration.userId)/history",
			queryItems: [URLQueryItem(name: "startHistoryId", value: startHistoryId)]
		)
	}

	/// Send an email message
	/// - Parameters:
	///   - raw: Base64url-encoded RFC 2822 message
	///   - threadId: Optional thread ID for replies (ensures message is grouped with thread)
	/// - Returns: The created message metadata
	public func sendMessage(
		raw: String,
		threadId: String? = nil
	) async throws -> GmailSendResponse {
		var body: [String: String] = ["raw": raw]
		if let threadId {
			body["threadId"] = threadId
		}

		return try await postRequest(
			path: "users/\(configuration.userId)/messages/send",
			body: body
		)
	}

	/// Result of an incremental fetch operation
	public struct IncrementalFetchResult: Sendable {
		public let threads: [GmailThread]
		public let hasMore: Bool
	}

	/// Fetches threads that are new or have been updated since last sync
	/// - Parameters:
	///   - knownThreads: Map of known thread IDs to their historyIds
	///   - targetCount: Maximum number of changed threads to fetch
	/// - Returns: New/updated threads and whether more are available
	public func fetchRecentThreads(
		knownThreads: [String: String?],
		targetCount: Int
	) async throws -> IncrementalFetchResult {
		var changedThreads: [GmailThread] = []
		var pageToken: String? = nil

		while changedThreads.count < targetCount {
			// Fetch page of thread summaries (request more than needed for efficiency)
			let response = try await listThreads(pageToken: pageToken, maxResults: 20)
			let summaries = response.threads ?? []

			// Fetch full details for new or changed threads
			for summary in summaries {
				guard changedThreads.count < targetCount else { break }

				// Check if thread needs fetching
				let needsFetch: Bool
				if let knownHistoryId = knownThreads[summary.id] {
					// Known thread - fetch only if historyId changed
					needsFetch = (knownHistoryId != summary.historyId)
				} else {
					// New thread - always fetch
					needsFetch = true
				}

				if needsFetch {
					let thread = try await getThread(id: summary.id)
					changedThreads.append(thread)
				}
			}

			// Check if more pages available
			guard let next = response.nextPageToken else {
				// Pagination exhausted
				return IncrementalFetchResult(threads: changedThreads, hasMore: false)
			}
			pageToken = next
		}

		return IncrementalFetchResult(threads: changedThreads, hasMore: true)
	}

	// MARK: - Private

	private func postRequest<Response: Decodable>(
		path: String,
		body: [String: String],
		retryPolicy: RetryPolicy = .default
	) async throws -> Response {
		var lastError: Error?

		for attempt in 0...retryPolicy.maxRetries {
			do {
				return try await executePostRequest(path: path, body: body)
			} catch {
				lastError = error

				guard attempt < retryPolicy.maxRetries && RetryPolicy.isRetryable(error) else {
					throw error
				}

				let delay = retryPolicy.delay(for: attempt + 1)
				try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
			}
		}

		throw lastError ?? GmailAPIError.invalidResponse
	}

	private func executePostRequest<Response: Decodable>(
		path: String,
		body: [String: String]
	) async throws -> Response {
		guard
			var components = URLComponents(
				url: configuration.baseURL, resolvingAgainstBaseURL: false)
		else {
			throw GmailAPIError.invalidURL
		}
		components.path = components.path.appending("/") + path
		guard let url = components.url else { throw GmailAPIError.invalidURL }

		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.setValue("application/json", forHTTPHeaderField: "Accept")
		request.httpBody = try JSONEncoder().encode(body)

		let token = try await tokenProvider()
		request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

		let (data, response) = try await session.data(for: request)
		guard let http = response as? HTTPURLResponse else {
			throw GmailAPIError.invalidResponse
		}
		guard (200...299).contains(http.statusCode) else {
			throw GmailAPIError.httpError(
				status: http.statusCode, body: String(data: data, encoding: .utf8))
		}

		return try JSONDecoder().decode(Response.self, from: data)
	}

	private func request<Response: Decodable>(
		path: String,
		method: String = "GET",
		queryItems: [URLQueryItem] = [],
		retryPolicy: RetryPolicy = .default
	) async throws -> Response {
		var lastError: Error?

		for attempt in 0...retryPolicy.maxRetries {
			do {
				return try await executeRequest(
					path: path,
					method: method,
					queryItems: queryItems
				)
			} catch {
				lastError = error

				guard attempt < retryPolicy.maxRetries && RetryPolicy.isRetryable(error) else {
					throw error
				}

				let delay = retryPolicy.delay(for: attempt + 1)
				try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
			}
		}

		throw lastError ?? GmailAPIError.invalidResponse
	}

	private func executeRequest<Response: Decodable>(
		path: String,
		method: String,
		queryItems: [URLQueryItem]
	) async throws -> Response {
		guard
			var components = URLComponents(
				url: configuration.baseURL, resolvingAgainstBaseURL: false)
		else {
			throw GmailAPIError.invalidURL
		}
		components.path = components.path.appending("/") + path
		if !queryItems.isEmpty {
			components.queryItems = queryItems
		}
		guard let url = components.url else { throw GmailAPIError.invalidURL }

		var request = URLRequest(url: url)
		request.httpMethod = method
		request.setValue("application/json", forHTTPHeaderField: "Accept")

		let token = try await tokenProvider()
		request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

		let (data, response) = try await session.data(for: request)
		guard let http = response as? HTTPURLResponse else {
			throw GmailAPIError.invalidResponse
		}
		guard (200...299).contains(http.statusCode) else {
			throw GmailAPIError.httpError(
				status: http.statusCode, body: String(data: data, encoding: .utf8))
		}

		return try JSONDecoder().decode(Response.self, from: data)
	}
}

public enum GmailAPIError: Error, Sendable, LocalizedError {
	case invalidURL
	case invalidResponse
	case httpError(status: Int, body: String?)

	public var errorDescription: String? {
		switch self {
		case .invalidURL:
			return "Invalid request URL"
		case .invalidResponse:
			return "Invalid response from server"
		case .httpError(let status, _):
			return userFriendlyMessage(for: status)
		}
	}

	private func userFriendlyMessage(for status: Int) -> String {
		switch status {
		case 401:
			return "Your session has expired. Please sign in again."
		case 403:
			return "Access denied. Check your Gmail permissions."
		case 404:
			return "The requested resource was not found."
		case 429:
			return "Too many requests. Please wait a moment and try again."
		case 500...599:
			return "Gmail servers are temporarily unavailable. Please try again later."
		default:
			return "Request failed (error \(status)). Please try again."
		}
	}
}

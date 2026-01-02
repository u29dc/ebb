import Combine
import Foundation
import SwiftData

@MainActor
final class AppState: ObservableObject {
	enum AuthState: Equatable {
		case signedOut
		case authenticating
		case signedIn
	}

	@Published var isFullscreen: Bool = false
	@Published var authState: AuthState = .signedOut
	@Published var ownerEmailAddress: String = ""
	@Published var errorMessage: String?
	@Published var threads: [MailThread] = []
	@Published var isRefreshing: Bool = false

	private let oauthManager = OAuthManager()
	private(set) lazy var gmailClient: GmailAPIClient = {
		GmailAPIClient(tokenProvider: { [weak self] in
			guard let self else { throw GmailAPIError.invalidResponse }
			return try await self.oauthManager.validAccessToken()
		})
	}()

	var modelContext: ModelContext?

	init() {}

	func setModelContext(_ context: ModelContext) {
		self.modelContext = context
	}

	/// Called on app launch to restore session from keychain
	func bootstrap() {
		if oauthManager.isAuthenticated {
			authState = .signedIn
			ownerEmailAddress = oauthManager.userEmail ?? ""
		} else {
			authState = .signedOut
		}
		loadThreadsFromCache()
	}

	// MARK: - Persistence

	private func loadThreadsFromCache() {
		guard let context = modelContext else { return }
		let descriptor = FetchDescriptor<PersistedThread>(
			sortBy: [SortDescriptor(\.lastMessageDate, order: .reverse)]
		)
		if let persisted = try? context.fetch(descriptor) {
			threads = persisted.map { $0.toMailThread() }
		}
	}

	private func saveThreadsToCache(_ newThreads: [MailThread]) {
		guard let context = modelContext else { return }

		for thread in newThreads {
			let threadId = thread.id
			let predicate = #Predicate<PersistedThread> { $0.id == threadId }
			let descriptor = FetchDescriptor(predicate: predicate)

			if let existing = try? context.fetch(descriptor).first {
				existing.update(from: thread, preservingSanitized: existing.messages)
			} else {
				context.insert(PersistedThread.from(thread))
			}
		}

		try? context.save()
	}

	func startLogin() {
		guard authState != .authenticating else { return }

		authState = .authenticating
		errorMessage = nil

		Task {
			do {
				try await oauthManager.startAuthentication()
				authState = .signedIn
				ownerEmailAddress = oauthManager.userEmail ?? ""
			} catch {
				authState = .signedOut
				errorMessage = error.localizedDescription
			}
		}
	}

	func signOut() {
		oauthManager.signOut()
		authState = .signedOut
		ownerEmailAddress = ""
		errorMessage = nil
		threads = []
	}

	/// Fetch recent threads from Gmail
	func fetchRecentThreads(count: Int = 10) {
		guard authState == .signedIn else { return }
		guard !isRefreshing else { return }

		isRefreshing = true
		errorMessage = nil

		Task {
			do {
				// Get thread list (IDs only)
				let response = try await gmailClient.listThreads(maxResults: count)
				let threadSummaries = response.threads ?? []

				// Fetch full thread details for each
				var fetchedThreads: [MailThread] = []
				for summary in threadSummaries {
					let gmailThread = try await gmailClient.getThread(id: summary.id)
					let mailThread = gmailThread.toMailThread()
					fetchedThreads.append(mailThread)
				}

				// Sort by last message date (newest first)
				let sortedThreads = fetchedThreads.sorted { $0.lastMessageDate > $1.lastMessageDate }

				// Save to cache and update UI
				saveThreadsToCache(sortedThreads)
				threads = sortedThreads
				isRefreshing = false
			} catch {
				errorMessage = error.localizedDescription
				isRefreshing = false
			}
		}
	}
}

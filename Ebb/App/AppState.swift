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
	@Published var selectedThreadId: String?

	/// Currently selected thread for display in conversation view
	var selectedThread: MailThread? {
		threads.first { $0.id == selectedThreadId }
	}

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
		print("[Persistence] ModelContext set")
	}

	/// Called on app launch to restore session from keychain
	func bootstrap() {
		if oauthManager.isAuthenticated {
			authState = .signedIn
			ownerEmailAddress = oauthManager.userEmail ?? ""
			// Fetch reliable email from Gmail API as fallback
			Task {
				await fetchOwnerEmail()
			}
		} else {
			authState = .signedOut
		}
		loadThreadsFromCache()
	}

	// MARK: - Persistence

	private func loadThreadsFromCache() {
		guard let context = modelContext else {
			print("[Persistence] loadThreadsFromCache: modelContext is nil")
			return
		}
		let descriptor = FetchDescriptor<PersistedThread>(
			sortBy: [SortDescriptor(\.lastMessageDate, order: .reverse)]
		)
		do {
			let persisted = try context.fetch(descriptor)
			threads = persisted.map { $0.toMailThread() }
			print("[Persistence] Loaded \(threads.count) threads from cache")
		} catch {
			print("[Persistence] Failed to load cache: \(error)")
		}
	}

	private func saveThreadsToCache(_ newThreads: [MailThread]) {
		guard let context = modelContext else {
			print("[Persistence] saveThreadsToCache: modelContext is nil")
			return
		}

		for thread in newThreads {
			let threadId = thread.id
			let predicate = #Predicate<PersistedThread> { $0.id == threadId }
			let descriptor = FetchDescriptor(predicate: predicate)

			do {
				if let existing = try context.fetch(descriptor).first {
					existing.update(from: thread, preservingSanitized: existing.messages)
				} else {
					context.insert(PersistedThread.from(thread))
				}
			} catch {
				print("[Persistence] Failed to fetch for upsert: \(error)")
			}
		}

		do {
			try context.save()
			print("[Persistence] Saved \(newThreads.count) threads to cache")
		} catch {
			print("[Persistence] Failed to save cache: \(error)")
		}
	}

	/// Clear all cached threads and messages, preserving authentication
	func clearCache() {
		guard let context = modelContext else { return }

		// Fetch and delete all threads (cascade deletes messages)
		let descriptor = FetchDescriptor<PersistedThread>()
		if let allThreads = try? context.fetch(descriptor) {
			for thread in allThreads {
				context.delete(thread)
			}
		}

		// Commit deletions
		try? context.save()

		// Clear in-memory state
		threads = []
		selectedThreadId = nil
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
				// Fetch reliable email from Gmail API
				await fetchOwnerEmail()
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
					let mailThread = gmailThread.toMailThread(ownerEmail: ownerEmailAddress)
					// Apply plain text sanitization to messages
					let sanitizedThread = sanitizePlainText(mailThread)
					fetchedThreads.append(sanitizedThread)
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

	// MARK: - Owner Email

	/// Fetch owner email from Gmail API (more reliable than OAuth userinfo)
	private func fetchOwnerEmail() async {
		do {
			let profile = try await gmailClient.getProfile()
			ownerEmailAddress = profile.emailAddress
		} catch {
			// Non-fatal: continue without owner email
		}
	}

	// MARK: - Plain Text Sanitization

	/// Apply plain text extraction to messages that don't have sanitizedBody yet
	private func sanitizePlainText(_ thread: MailThread) -> MailThread {
		let sanitizedMessages = thread.messages.map { message -> MailMessage in
			// Skip if already sanitized
			if message.sanitizedBody != nil {
				return message
			}

			// Try to sanitize HTML body, fall back to plain body
			let sanitized: String?
			if let html = message.bodyHtml {
				sanitized = PlainTextSanitizer.sanitize(html)
			} else if let plain = message.bodyPlain {
				// Already plain text, just normalize whitespace
				sanitized = PlainTextSanitizer.sanitize(plain)
			} else {
				sanitized = nil
			}

			// Create new message with sanitized body
			return MailMessage(
				id: message.id,
				threadId: message.threadId,
				from: message.from,
				to: message.to,
				cc: message.cc,
				subject: message.subject,
				date: message.date,
				snippet: message.snippet,
				bodyPlain: message.bodyPlain,
				bodyHtml: message.bodyHtml,
				labelIds: message.labelIds,
				isUnread: message.isUnread,
				references: message.references,
				sanitizedBody: sanitized,
				ownerEmail: message.ownerEmail
			)
		}
		return thread.withMessages(sanitizedMessages)
	}
}

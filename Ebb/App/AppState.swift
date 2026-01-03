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

	// MARK: - Compose State

	@Published var composeMode: ComposeMode = .none
	@Published var composeDraft: ComposeDraft = ComposeDraft()
	@Published var isSending: Bool = false
	@Published var sendError: String?

	// MARK: - AI Sanitization State

	@Published var sanitizingThreadIds: Set<String> = []

	/// True if AI sanitization is in progress
	var isSanitizing: Bool {
		!sanitizingThreadIds.isEmpty
	}

	/// True if in any compose mode
	var isComposing: Bool {
		composeMode != .none
	}

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

	private let sanitizationPipeline = SanitizationPipeline()

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

	/// Fetch threads we don't already have, accumulating results
	/// - Parameter count: Number of NEW threads to fetch (default 10)
	func fetchRecentThreads(count: Int = 10) {
		guard authState == .signedIn else { return }
		guard !isRefreshing else { return }

		isRefreshing = true
		errorMessage = nil

		Task {
			do {
				// Build map of known threads with their historyIds
				let knownThreads = Dictionary(
					uniqueKeysWithValues: threads.map { ($0.id, $0.historyId) }
				)

				// Fetch new or updated threads
				let result = try await gmailClient.fetchRecentThreads(
					knownThreads: knownThreads,
					targetCount: count
				)

				if result.threads.isEmpty {
					print("[Sync] No new or updated threads")
					isRefreshing = false
					return
				}

				// Convert and sanitize fetched threads
				let fetchedThreads = result.threads.map { gmailThread in
					let mailThread = gmailThread.toMailThread(ownerEmail: ownerEmailAddress)
					return sanitizePlainText(mailThread)
				}

				// Merge with existing threads (new threads added, updated threads replaced)
				let merged = mergeThreads(existing: threads, new: fetchedThreads)

				// Save fetched threads to cache
				saveThreadsToCache(fetchedThreads)
				threads = merged
				isRefreshing = false

				print("[Sync] Fetched \(fetchedThreads.count) threads, total now \(threads.count)")
				if !result.hasMore {
					print("[Sync] Reached end of available threads")
				}
			} catch {
				errorMessage = error.localizedDescription
				isRefreshing = false
			}
		}
	}

	/// Merge new threads into existing collection, sorted by date descending
	private func mergeThreads(existing: [MailThread], new: [MailThread]) -> [MailThread] {
		var threadMap = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
		for thread in new {
			threadMap[thread.id] = thread
		}
		return threadMap.values.sorted { $0.lastMessageDate > $1.lastMessageDate }
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

	// MARK: - AI Sanitization

	/// Sanitize all unsanitized messages using AI formatting
	func sanitizeAll() {
		guard authState == .signedIn else { return }
		guard !isSanitizing else { return }

		// Find threads with unsanitized messages
		let threadsNeedingSanitization = threads.filter { thread in
			thread.messages.contains { $0.sanitizedBody == nil && $0.displayBody.count > 10 }
		}

		guard !threadsNeedingSanitization.isEmpty else {
			print("[AI] No threads need sanitization")
			return
		}

		sanitizingThreadIds = Set(threadsNeedingSanitization.map(\.id))
		print("[AI] Starting sanitization for \(threadsNeedingSanitization.count) threads")

		Task {
			// Check AI availability
			await sanitizationPipeline.checkAvailability()

			for thread in threadsNeedingSanitization {
				// Process each message in the thread
				var updatedMessages: [MailMessage] = []

				for message in thread.messages {
					if message.sanitizedBody != nil {
						// Already sanitized
						updatedMessages.append(message)
						continue
					}

					// Get content to sanitize (already plain text from PlainTextSanitizer)
					let content = message.displayBody
					guard content.count > 10 else {
						updatedMessages.append(message)
						continue
					}

					// Run through AI pipeline
					let formatted = await sanitizationPipeline.sanitize(content)

					// Create updated message with sanitized body
					let updatedMessage = MailMessage(
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
						messageId: message.messageId,
						references: message.references,
						sanitizedBody: formatted,
						ownerEmail: message.ownerEmail
					)
					updatedMessages.append(updatedMessage)
				}

				// Update thread with sanitized messages
				let updatedThread = thread.withMessages(updatedMessages)

				// Update in-memory state
				if let index = threads.firstIndex(where: { $0.id == thread.id }) {
					threads[index] = updatedThread
				}

				// Update selected thread if it's the one we just processed
				if selectedThreadId == thread.id {
					// Force UI refresh by toggling selection
					let currentId = selectedThreadId
					selectedThreadId = nil
					selectedThreadId = currentId
				}

				// Save to cache
				saveThreadsToCache([updatedThread])

				// Remove from sanitizing set
				sanitizingThreadIds.remove(thread.id)

				print("[AI] Completed sanitization for thread \(thread.id)")
			}

			print("[AI] All sanitization complete")
		}
	}

	/// Clear sanitized data from all messages (for re-sanitization)
	func resetSanitizedData() {
		guard let context = modelContext else { return }

		// Update persisted messages
		let descriptor = FetchDescriptor<PersistedMessage>()
		if let messages = try? context.fetch(descriptor) {
			for message in messages {
				message.sanitizedBody = nil
				message.sanitizedAt = nil
			}
		}
		try? context.save()

		// Update in-memory threads
		threads = threads.map { thread in
			let clearedMessages = thread.messages.map { message in
				MailMessage(
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
					messageId: message.messageId,
					references: message.references,
					sanitizedBody: nil,
					ownerEmail: message.ownerEmail
				)
			}
			return thread.withMessages(clearedMessages)
		}

		print("[AI] Reset all sanitized data")
	}

	// MARK: - Plain Text Sanitization

	/// Apply plain text extraction to messages, updating bodyPlain with cleaned content
	/// Note: sanitizedBody is reserved for AI-formatted content
	private func sanitizePlainText(_ thread: MailThread) -> MailThread {
		let sanitizedMessages = thread.messages.map { message -> MailMessage in
			// Try to extract clean plain text from HTML body, fall back to plain body
			let cleanedPlain: String?
			if let html = message.bodyHtml {
				cleanedPlain = PlainTextSanitizer.sanitize(html)
			} else if let plain = message.bodyPlain {
				// Already plain text, just normalize whitespace
				cleanedPlain = PlainTextSanitizer.sanitize(plain)
			} else {
				cleanedPlain = nil
			}

			// Create new message with cleaned bodyPlain, preserve sanitizedBody for AI
			return MailMessage(
				id: message.id,
				threadId: message.threadId,
				from: message.from,
				to: message.to,
				cc: message.cc,
				subject: message.subject,
				date: message.date,
				snippet: message.snippet,
				bodyPlain: cleanedPlain ?? message.bodyPlain,
				bodyHtml: message.bodyHtml,
				labelIds: message.labelIds,
				isUnread: message.isUnread,
				messageId: message.messageId,
				references: message.references,
				sanitizedBody: message.sanitizedBody,
				ownerEmail: message.ownerEmail
			)
		}
		return thread.withMessages(sanitizedMessages)
	}

	// MARK: - Compose Actions

	/// Start composing a new message
	func startNewMessage() {
		selectedThreadId = nil
		composeDraft.clear()
		composeMode = .newMessage
		sendError = nil
	}

	/// Start replying to the currently selected thread
	func startReply() {
		guard let thread = selectedThread else { return }
		composeMode = .reply(threadId: thread.id)
		// Pre-fill draft with reply context
		composeDraft.subject = thread.subject
		composeDraft.recipients = collectReplyRecipients(for: thread)
		composeDraft.ccRecipients = collectCCRecipients(for: thread)
		sendError = nil
	}

	/// Cancel compose mode and clear draft
	func cancelCompose() {
		composeMode = .none
		composeDraft.clear()
		sendError = nil
	}

	/// Send the current draft
	func sendDraft() {
		guard !isSending else { return }
		guard composeDraft.canSend else { return }

		isSending = true
		sendError = nil

		Task {
			do {
				let result = try await performSend()

				// Clear draft and exit compose mode
				let wasReply = composeMode
				composeDraft.clear()
				composeMode = .none

				// Refresh the thread to show new message
				if case .reply(let threadId) = wasReply {
					await refreshThread(threadId)
				} else {
					// For new message, select the new thread
					selectedThreadId = result.threadId
					await refreshThread(result.threadId)
				}

				isSending = false
			} catch {
				sendError = error.localizedDescription
				isSending = false
			}
		}
	}

	/// Send reply from conversation view (inline reply)
	func sendReply(body: String) {
		guard let thread = selectedThread else { return }
		guard !isSending else { return }
		guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

		// Set up draft for reply
		composeDraft.body = body
		composeDraft.subject = thread.subject
		composeDraft.recipients = collectReplyRecipients(for: thread)
		composeDraft.ccRecipients = collectCCRecipients(for: thread)
		composeMode = .reply(threadId: thread.id)

		// Send it
		sendDraft()
	}

	private func performSend() async throws -> GmailSendResponse {
		let ownerAddress = EmailAddress(name: nil, email: ownerEmailAddress)

		let rawMessage: String
		switch composeMode {
		case .none:
			throw NSError(
				domain: "Ebb", code: 1,
				userInfo: [NSLocalizedDescriptionKey: "Not in compose mode"])

		case .newMessage:
			rawMessage = RFC2822Builder.buildNewMessage(
				from: ownerAddress,
				to: composeDraft.recipients,
				cc: composeDraft.ccRecipients,
				subject: composeDraft.subject,
				body: composeDraft.body
			)
			let encoded = Base64URL.encode(Data(rawMessage.utf8))
			return try await gmailClient.sendMessage(raw: encoded)

		case .reply(let threadId):
			guard let thread = threads.first(where: { $0.id == threadId }),
				let lastMessage = thread.messages.last
			else {
				throw NSError(
					domain: "Ebb", code: 2,
					userInfo: [NSLocalizedDescriptionKey: "Thread not found"])
			}

			// Get Message-ID header from last message for threading
			let inReplyTo = lastMessage.messageId ?? "<\(lastMessage.id)@gmail.com>"
			let references = lastMessage.references

			rawMessage = RFC2822Builder.buildReply(
				from: ownerAddress,
				to: composeDraft.recipients,
				cc: composeDraft.ccRecipients,
				subject: composeDraft.subject,
				body: composeDraft.body,
				inReplyTo: inReplyTo,
				references: references
			)
			let encoded = Base64URL.encode(Data(rawMessage.utf8))
			return try await gmailClient.sendMessage(raw: encoded, threadId: threadId)
		}
	}

	/// Collect TO recipients for reply-all (excluding owner)
	private func collectReplyRecipients(for thread: MailThread) -> [EmailAddress] {
		var recipients = Set<String>()
		var addressMap: [String: EmailAddress] = [:]
		let ownerLower = ownerEmailAddress.lowercased()

		for message in thread.messages {
			// Add sender if not owner
			let fromLower = message.from.email.lowercased()
			if fromLower != ownerLower {
				recipients.insert(fromLower)
				addressMap[fromLower] = message.from
			}
			// Add all TO recipients except owner
			for addr in message.to {
				let addrLower = addr.email.lowercased()
				if addrLower != ownerLower {
					recipients.insert(addrLower)
					addressMap[addrLower] = addr
				}
			}
		}

		return recipients.compactMap { addressMap[$0] }
	}

	/// Collect CC recipients for reply-all (excluding owner)
	private func collectCCRecipients(for thread: MailThread) -> [EmailAddress] {
		var ccRecipients = Set<String>()
		var addressMap: [String: EmailAddress] = [:]
		let ownerLower = ownerEmailAddress.lowercased()
		let toRecipients = Set(collectReplyRecipients(for: thread).map { $0.email.lowercased() })

		for message in thread.messages {
			for addr in message.cc {
				let addrLower = addr.email.lowercased()
				// Exclude owner and anyone already in TO
				if addrLower != ownerLower && !toRecipients.contains(addrLower) {
					ccRecipients.insert(addrLower)
					addressMap[addrLower] = addr
				}
			}
		}

		return ccRecipients.compactMap { addressMap[$0] }
	}

	/// Refresh a single thread from API
	private func refreshThread(_ threadId: String) async {
		do {
			let gmailThread = try await gmailClient.getThread(id: threadId)
			let mailThread = gmailThread.toMailThread(ownerEmail: ownerEmailAddress)
			let sanitized = sanitizePlainText(mailThread)

			// Update in threads array
			if let index = threads.firstIndex(where: { $0.id == threadId }) {
				threads[index] = sanitized
			} else {
				threads.insert(sanitized, at: 0)
			}

			// Update cache
			saveThreadsToCache([sanitized])
		} catch {
			// Non-fatal: thread will be updated on next full refresh
			print("[Sync] Failed to refresh thread \(threadId): \(error)")
		}
	}
}

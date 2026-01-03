import Foundation

public struct MailThread: Identifiable, Hashable, Sendable {
	public let id: String
	public let snippet: String
	public let historyId: String?
	public let messages: [MailMessage]
	public let lastMessageDate: Date
	public let unreadCount: Int

	public nonisolated init(
		id: String,
		snippet: String,
		historyId: String?,
		messages: [MailMessage],
		lastMessageDate: Date,
		unreadCount: Int
	) {
		self.id = id
		self.snippet = snippet
		self.historyId = historyId
		self.messages = messages
		self.lastMessageDate = lastMessageDate
		self.unreadCount = unreadCount
	}

	/// Returns a copy with updated messages
	public func withMessages(_ newMessages: [MailMessage]) -> MailThread {
		MailThread(
			id: id,
			snippet: snippet,
			historyId: historyId,
			messages: newMessages,
			lastMessageDate: lastMessageDate,
			unreadCount: unreadCount
		)
	}

	/// Primary sender for display (first message's from address)
	public var primarySender: EmailAddress? {
		messages.first?.from
	}

	/// Subject line from first message
	public var subject: String {
		messages.first?.subject ?? ""
	}
}

public struct MailMessage: Identifiable, Hashable, Sendable {
	public let id: String
	public let threadId: String
	public let from: EmailAddress
	public let to: [EmailAddress]
	public let cc: [EmailAddress]
	public let subject: String
	public let date: Date
	public let snippet: String
	public let bodyPlain: String?
	public let bodyHtml: String?
	public let labelIds: [String]
	public let isUnread: Bool
	public let messageId: String?  // Message-ID header for threading replies
	public let references: String?
	public let sanitizedBody: String?  // AI-cleaned markdown (write-once)
	public let ownerEmail: String  // Authenticated user's email for sent/received detection

	/// Returns true if this message was sent by the authenticated user
	public var isFromOwner: Bool {
		from.isSameAs(ownerEmail)
	}

	public nonisolated init(
		id: String,
		threadId: String,
		from: EmailAddress,
		to: [EmailAddress],
		cc: [EmailAddress],
		subject: String,
		date: Date,
		snippet: String,
		bodyPlain: String?,
		bodyHtml: String?,
		labelIds: [String],
		isUnread: Bool,
		messageId: String? = nil,
		references: String? = nil,
		sanitizedBody: String? = nil,
		ownerEmail: String = ""
	) {
		self.id = id
		self.threadId = threadId
		self.from = from
		self.to = to
		self.cc = cc
		self.subject = subject
		self.date = date
		self.snippet = snippet
		self.bodyPlain = bodyPlain
		self.bodyHtml = bodyHtml
		self.labelIds = labelIds
		self.isUnread = isUnread
		self.messageId = messageId
		self.references = references
		self.sanitizedBody = sanitizedBody
		self.ownerEmail = ownerEmail
	}

	/// Display body: prefers sanitized, falls back to plain, then snippet
	public var displayBody: String {
		sanitizedBody ?? bodyPlain ?? snippet
	}
}

public struct EmailAddress: Hashable, Sendable, Codable {
	public let name: String?
	public let email: String

	public nonisolated init(name: String?, email: String) {
		self.name = name
		self.email = email
	}

	/// Display name (prefers name, falls back to email)
	public var displayName: String {
		if let name = name, !name.isEmpty {
			return name
		}
		return email
	}

	/// Compare email addresses case-insensitively
	public func isSameAs(_ other: EmailAddress) -> Bool {
		email.lowercased() == other.email.lowercased()
	}

	/// Compare this email address to a raw email string
	public func isSameAs(_ otherEmail: String) -> Bool {
		email.lowercased() == otherEmail.lowercased()
	}
}

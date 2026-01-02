import Foundation
import SwiftData

@Model
final class PersistedThread {
	@Attribute(.unique) var id: String
	var snippet: String
	var historyId: String?
	var lastMessageDate: Date
	var unreadCount: Int
	var fetchedAt: Date

	@Relationship(deleteRule: .cascade, inverse: \PersistedMessage.thread)
	var messages: [PersistedMessage] = []

	init(
		id: String,
		snippet: String,
		historyId: String?,
		lastMessageDate: Date,
		unreadCount: Int,
		fetchedAt: Date = Date()
	) {
		self.id = id
		self.snippet = snippet
		self.historyId = historyId
		self.lastMessageDate = lastMessageDate
		self.unreadCount = unreadCount
		self.fetchedAt = fetchedAt
	}
}

@Model
final class PersistedMessage {
	@Attribute(.unique) var id: String
	var threadId: String
	var fromName: String?
	var fromEmail: String
	var toAddressesJSON: String
	var ccAddressesJSON: String
	var subject: String
	var date: Date
	var snippet: String
	var bodyPlain: String?
	var bodyHtml: String?
	var labelIdsJSON: String
	var isUnread: Bool
	var sanitizedBody: String?
	var sanitizedAt: Date?
	var references: String?
	var ownerEmail: String

	var thread: PersistedThread?

	init(
		id: String,
		threadId: String,
		fromName: String?,
		fromEmail: String,
		toAddressesJSON: String,
		ccAddressesJSON: String,
		subject: String,
		date: Date,
		snippet: String,
		bodyPlain: String?,
		bodyHtml: String?,
		labelIdsJSON: String,
		isUnread: Bool,
		sanitizedBody: String? = nil,
		sanitizedAt: Date? = nil,
		references: String? = nil,
		ownerEmail: String = ""
	) {
		self.id = id
		self.threadId = threadId
		self.fromName = fromName
		self.fromEmail = fromEmail
		self.toAddressesJSON = toAddressesJSON
		self.ccAddressesJSON = ccAddressesJSON
		self.subject = subject
		self.date = date
		self.snippet = snippet
		self.bodyPlain = bodyPlain
		self.bodyHtml = bodyHtml
		self.labelIdsJSON = labelIdsJSON
		self.isUnread = isUnread
		self.sanitizedBody = sanitizedBody
		self.sanitizedAt = sanitizedAt
		self.references = references
		self.ownerEmail = ownerEmail
	}
}

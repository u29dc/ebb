import Foundation

// MARK: - API Response Types

public struct GmailProfile: Codable, Sendable {
	public let emailAddress: String
	public let messagesTotal: Int?
	public let threadsTotal: Int?
	public let historyId: String?
}

public struct GmailThreadListResponse: Codable, Sendable {
	public let threads: [GmailThreadSummary]?
	public let nextPageToken: String?
	public let resultSizeEstimate: Int?
}

public struct GmailThreadSummary: Codable, Sendable {
	public let id: String
	public let snippet: String?
	public let historyId: String?
}

public struct GmailThread: Codable, Sendable {
	public let id: String
	public let historyId: String?
	public let messages: [GmailMessage]?
}

public struct GmailMessage: Codable, Sendable {
	public let id: String
	public let threadId: String
	public let labelIds: [String]?
	public let snippet: String?
	public let historyId: String?
	public let internalDate: String?
	public let payload: MessagePayload?
	public let sizeEstimate: Int?
}

public struct MessagePayload: Codable, Sendable {
	public let partId: String?
	public let mimeType: String
	public let filename: String?
	public let headers: [MessageHeader]?
	public let body: MessageBody?
	public let parts: [MessagePayload]?
}

public struct MessageHeader: Codable, Sendable {
	public let name: String
	public let value: String
}

public struct MessageBody: Codable, Sendable {
	public let attachmentId: String?
	public let size: Int?
	public let data: String?
}

public struct GmailLabelsResponse: Codable, Sendable {
	public let labels: [GmailLabel]?
}

public struct GmailLabel: Codable, Sendable {
	public let id: String
	public let name: String
	public let type: String
	public let messageListVisibility: String?
	public let labelListVisibility: String?
}

public struct GmailHistoryListResponse: Codable, Sendable {
	public let history: [GmailHistoryEntry]?
	public let historyId: String?
	public let nextPageToken: String?
}

public struct GmailHistoryEntry: Codable, Sendable {
	public let id: String
	public let messages: [GmailMessage]?
	public let messagesAdded: [GmailHistoryMessage]?
	public let messagesDeleted: [GmailHistoryMessage]?
}

public struct GmailHistoryMessage: Codable, Sendable {
	public let message: GmailMessage
}

// MARK: - Transformers to Domain Models

extension GmailThread {
	/// Convert Gmail API thread to domain MailThread
	public func toMailThread(ownerEmail: String) -> MailThread {
		let mappedMessages = (messages ?? []).compactMap { $0.toMailMessage(ownerEmail: ownerEmail) }
		let lastDate = mappedMessages.map { $0.date }.max() ?? Date.distantPast
		let unreadCount = mappedMessages.filter { $0.isUnread }.count
		return MailThread(
			id: id,
			snippet: mappedMessages.last?.snippet ?? "",
			historyId: historyId,
			messages: mappedMessages,
			lastMessageDate: lastDate,
			unreadCount: unreadCount
		)
	}
}

extension GmailMessage {
	/// Convert Gmail API message to domain MailMessage
	public func toMailMessage(ownerEmail: String) -> MailMessage? {
		let headers = payload?.headers ?? []
		let subject = headers.firstValue(for: "Subject") ?? ""
		let from = EmailAddress.parse(from: headers.firstValue(for: "From"))
		let to = EmailAddress.parseList(from: headers.firstValue(for: "To"))
		let cc = EmailAddress.parseList(from: headers.firstValue(for: "Cc"))
		let date = headers.firstValue(for: "Date").flatMap(DateParser.parseRFC822) ?? Date()
		let references = headers.firstValue(for: "References")
		let body = payload?.bestBody()
		let labelIds = self.labelIds ?? []
		let isUnread = labelIds.contains("UNREAD")

		return MailMessage(
			id: id,
			threadId: threadId,
			from: from ?? EmailAddress(name: nil, email: ""),
			to: to,
			cc: cc,
			subject: subject,
			date: date,
			snippet: snippet ?? "",
			bodyPlain: body?.plain,
			bodyHtml: body?.html,
			labelIds: labelIds,
			isUnread: isUnread,
			references: references,
			ownerEmail: ownerEmail
		)
	}
}

extension [MessageHeader] {
	fileprivate func firstValue(for name: String) -> String? {
		first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })?.value
	}
}

extension MessagePayload {
	fileprivate struct BodyParts: Sendable {
		let plain: String?
		let html: String?
	}

	fileprivate func bestBody() -> BodyParts? {
		var plain: String?
		var html: String?

		if mimeType == "text/plain", let data = body?.data {
			plain = Base64URL.decodeToString(data)
		}
		if mimeType == "text/html", let data = body?.data {
			html = Base64URL.decodeToString(data)
		}

		for part in parts ?? [] {
			let child = part.bestBody()
			if plain == nil { plain = child?.plain }
			if html == nil { html = child?.html }
		}

		if plain == nil, html == nil { return nil }
		return BodyParts(plain: plain, html: html)
	}
}

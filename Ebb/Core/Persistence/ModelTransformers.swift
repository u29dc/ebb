import Foundation

// MARK: - PersistedThread

extension PersistedThread {
	nonisolated func toMailThread() -> MailThread {
		let mailMessages = messages.map { $0.toMailMessage() }.sorted { $0.date < $1.date }
		return MailThread(
			id: id,
			snippet: snippet,
			historyId: historyId,
			messages: mailMessages,
			lastMessageDate: lastMessageDate,
			unreadCount: unreadCount
		)
	}

	nonisolated static func from(_ thread: MailThread) -> PersistedThread {
		let persisted = PersistedThread(
			id: thread.id,
			snippet: thread.snippet,
			historyId: thread.historyId,
			lastMessageDate: thread.lastMessageDate,
			unreadCount: thread.unreadCount
		)
		persisted.messages = thread.messages.map { PersistedMessage.from($0, thread: persisted) }
		return persisted
	}

	/// Update in-place, preserving sanitizedBody on existing messages
	nonisolated func update(from thread: MailThread, preservingSanitized existingMessages: [PersistedMessage]) {
		snippet = thread.snippet
		historyId = thread.historyId
		lastMessageDate = thread.lastMessageDate
		unreadCount = thread.unreadCount
		fetchedAt = Date()

		// Build lookup of existing persisted messages by ID
		let existingLookup = Dictionary(uniqueKeysWithValues: existingMessages.map { ($0.id, $0) })

		// Update or create messages
		var updatedMessages: [PersistedMessage] = []
		for mailMsg in thread.messages {
			if let existing = existingLookup[mailMsg.id] {
				// Update existing message in place (preserves PersistentIdentifier)
				existing.updateFrom(mailMsg)
				updatedMessages.append(existing)
			} else {
				// Create new message only if it doesn't exist
				let newMessage = PersistedMessage.from(mailMsg, thread: self)
				updatedMessages.append(newMessage)
			}
		}

		messages = updatedMessages
	}
}

// MARK: - PersistedMessage

extension PersistedMessage {
	nonisolated func toMailMessage() -> MailMessage {
		MailMessage(
			id: id,
			threadId: threadId,
			from: EmailAddress(name: fromName, email: fromEmail),
			to: Self.decodeAddresses(toAddressesJSON),
			cc: Self.decodeAddresses(ccAddressesJSON),
			subject: subject,
			date: date,
			snippet: snippet,
			bodyPlain: bodyPlain,
			bodyHtml: bodyHtml,
			labelIds: Self.decodeLabelIds(labelIdsJSON),
			isUnread: isUnread,
			references: references,
			sanitizedBody: sanitizedBody,
			ownerEmail: ownerEmail
		)
	}

	nonisolated static func from(_ message: MailMessage, thread: PersistedThread) -> PersistedMessage {
		let persisted = PersistedMessage(
			id: message.id,
			threadId: message.threadId,
			fromName: message.from.name,
			fromEmail: message.from.email,
			toAddressesJSON: encodeAddresses(message.to),
			ccAddressesJSON: encodeAddresses(message.cc),
			subject: message.subject,
			date: message.date,
			snippet: message.snippet,
			bodyPlain: message.bodyPlain,
			bodyHtml: message.bodyHtml,
			labelIdsJSON: encodeLabelIds(message.labelIds),
			isUnread: message.isUnread,
			sanitizedBody: message.sanitizedBody,
			sanitizedAt: message.sanitizedBody != nil ? Date() : nil,
			references: message.references,
			ownerEmail: message.ownerEmail
		)
		persisted.thread = thread
		return persisted
	}

	/// Update message properties in place (preserves PersistentIdentifier)
	nonisolated func updateFrom(_ message: MailMessage) {
		fromName = message.from.name
		fromEmail = message.from.email
		toAddressesJSON = Self.encodeAddresses(message.to)
		ccAddressesJSON = Self.encodeAddresses(message.cc)
		subject = message.subject
		date = message.date
		snippet = message.snippet
		bodyPlain = message.bodyPlain
		bodyHtml = message.bodyHtml
		labelIdsJSON = Self.encodeLabelIds(message.labelIds)
		isUnread = message.isUnread
		references = message.references
		ownerEmail = message.ownerEmail

		// Update sanitized content if present in the domain model
		if let body = message.sanitizedBody {
			sanitizedBody = body
			sanitizedAt = Date()
		}
		// Note: Don't clear sanitizedBody if nil - preserve existing
	}

	// MARK: - JSON Helpers

	nonisolated static func encodeAddresses(_ addresses: [EmailAddress]) -> String {
		guard let data = try? JSONEncoder().encode(addresses),
			let json = String(data: data, encoding: .utf8)
		else { return "[]" }
		return json
	}

	nonisolated private static func decodeAddresses(_ json: String) -> [EmailAddress] {
		guard let data = json.data(using: .utf8),
			let addresses = try? JSONDecoder().decode([EmailAddress].self, from: data)
		else { return [] }
		return addresses
	}

	nonisolated static func encodeLabelIds(_ labelIds: [String]) -> String {
		guard let data = try? JSONEncoder().encode(labelIds),
			let json = String(data: data, encoding: .utf8)
		else { return "[]" }
		return json
	}

	nonisolated private static func decodeLabelIds(_ json: String) -> [String] {
		guard let data = json.data(using: .utf8),
			let labels = try? JSONDecoder().decode([String].self, from: data)
		else { return [] }
		return labels
	}
}

import Foundation

/// Represents the compose mode for the right pane
public enum ComposeMode: Equatable, Sendable {
	/// Normal viewing mode (no compose active)
	case none
	/// Creating a new thread
	case newMessage
	/// Replying to an existing thread
	case reply(threadId: String)
}

/// Draft data for composing messages
public struct ComposeDraft: Equatable, Sendable {
	public var recipients: [EmailAddress] = []
	public var ccRecipients: [EmailAddress] = []
	public var subject: String = ""
	public var body: String = ""

	public init() {}

	public init(
		recipients: [EmailAddress],
		ccRecipients: [EmailAddress] = [],
		subject: String,
		body: String = ""
	) {
		self.recipients = recipients
		self.ccRecipients = ccRecipients
		self.subject = subject
		self.body = body
	}

	/// True if draft has any content worth preserving
	public var hasContent: Bool {
		!body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
			|| !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
			|| !recipients.isEmpty
	}

	/// True if draft has minimum required fields to send
	public var canSend: Bool {
		!recipients.isEmpty
			&& !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}

	/// Reset to empty state
	public mutating func clear() {
		recipients = []
		ccRecipients = []
		subject = ""
		body = ""
	}
}

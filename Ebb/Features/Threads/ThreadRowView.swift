import SwiftUI

struct ThreadRowView: View {
	let thread: MailThread
	@EnvironmentObject var appState: AppState

	private var isSelected: Bool {
		appState.selectedThreadId == thread.id
	}

	var body: some View {
		VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
			// Subject and date row
			HStack {
				Text(thread.subject)
					.font(.headline)
					.fontWeight(thread.unreadCount > 0 ? .semibold : .regular)
					.lineLimit(1)

				Spacer()

				Text(formattedDate)
					.font(.caption)
					.foregroundColor(.secondary)
			}

			// Participants (excluding owner)
			Text(participantEmails)
				.font(.subheadline)
				.foregroundColor(.secondary)
				.lineLimit(1)
		}
		.padding(.vertical, DesignTokens.Spacing.xs)
		.padding(.horizontal, DesignTokens.Spacing.xs)
		.background(
			RoundedRectangle(cornerRadius: DesignTokens.Corner.sm)
				.fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
		)
		.contentShape(Rectangle())
		.onTapGesture {
			appState.cancelCompose()
			appState.selectedThreadId = thread.id
		}
	}

	private var participantEmails: String {
		let ownerEmail = appState.ownerEmailAddress.lowercased()
		var emails = Set<String>()

		for message in thread.messages {
			// Add sender if not owner
			if message.from.email.lowercased() != ownerEmail {
				emails.insert(message.from.email.lowercased())
			}
			// Add recipients if not owner
			for recipient in message.to + message.cc {
				if recipient.email.lowercased() != ownerEmail {
					emails.insert(recipient.email.lowercased())
				}
			}
		}

		return emails.sorted().joined(separator: ", ")
	}

	private var formattedDate: String {
		let date = thread.lastMessageDate
		let calendar = Calendar.current

		if calendar.isDateInToday(date) {
			return date.formatted(date: .omitted, time: .shortened)
		} else if calendar.isDateInYesterday(date) {
			return "Yesterday"
		} else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
			return date.formatted(.dateTime.weekday(.abbreviated))
		} else if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
			return date.formatted(.dateTime.month(.abbreviated).day())
		} else {
			return date.formatted(.dateTime.month(.abbreviated).day().year())
		}
	}
}

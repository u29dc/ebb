import SwiftUI

struct ThreadRowView: View {
	let thread: MailThread

	var body: some View {
		VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
			// Sender and date row
			HStack {
				Text(senderDisplayName)
					.font(.headline)
					.fontWeight(thread.unreadCount > 0 ? .semibold : .regular)
					.lineLimit(1)

				Spacer()

				Text(formattedDate)
					.font(.caption)
					.foregroundColor(.secondary)
			}

			// Subject line
			Text(thread.subject)
				.font(.subheadline)
				.fontWeight(thread.unreadCount > 0 ? .medium : .regular)
				.foregroundColor(.primary)
				.lineLimit(1)
		}
		.padding(.vertical, DesignTokens.Spacing.xs)
		.contentShape(Rectangle())
	}

	private var senderDisplayName: String {
		thread.primarySender?.displayName ?? "Unknown"
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

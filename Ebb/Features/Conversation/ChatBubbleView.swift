import SwiftUI

struct ChatBubbleView: View {
	let message: MailMessage
	let isFromMe: Bool

	var body: some View {
		HStack(alignment: .bottom, spacing: DesignTokens.Spacing.xs) {
			if isFromMe {
				Spacer(minLength: DesignTokens.Spacing.xl)
			}

			VStack(alignment: isFromMe ? .trailing : .leading, spacing: DesignTokens.Spacing.xxs) {
				// Sender email (only for received messages)
				if !isFromMe {
					Text(message.from.email.lowercased())
						.font(.caption)
						.fontWeight(.medium)
						.foregroundColor(.secondary)
				}

				// Message bubble
				Text(message.displayBody)
					.font(.body)
					.foregroundColor(isFromMe ? DesignTokens.Colors.bubbleSentText : DesignTokens.Colors.bubbleReceivedText)
					.padding(.horizontal, DesignTokens.Spacing.sm)
					.padding(.vertical, DesignTokens.Spacing.xs)
					.background(isFromMe ? DesignTokens.Colors.bubbleSent : DesignTokens.Colors.bubbleReceived)
					.clipShape(RoundedRectangle(cornerRadius: DesignTokens.Corner.md))

				// Timestamp
				Text(formattedTime)
					.font(.caption2)
					.foregroundColor(.secondary)
			}
			.frame(maxWidth: DesignTokens.Layout.bubbleMaxWidth, alignment: isFromMe ? .trailing : .leading)

			if !isFromMe {
				Spacer(minLength: DesignTokens.Spacing.xl)
			}
		}
	}

	private var formattedTime: String {
		message.date.formatted(date: .omitted, time: .shortened)
	}
}

import SwiftUI

struct ConversationView: View {
	let thread: MailThread
	let ownerEmail: String
	@EnvironmentObject var appState: AppState

	// Reply input state (local to this view)
	@State private var replyText: String = ""

	var body: some View {
		VStack(spacing: 0) {
			// Header with participants and subject
			ConversationHeaderView(
				participants: collectParticipants(),
				subject: thread.subject,
				ownerEmail: ownerEmail
			)

			Divider()

			// Messages
			ScrollViewReader { proxy in
				ScrollView {
					LazyVStack(spacing: DesignTokens.Spacing.sm) {
						ForEach(thread.messages) { message in
							ChatBubbleView(
								message: message,
								isFromMe: message.from.isSameAs(ownerEmail)
							)
							.id(message.id)
						}
					}
					.padding(.horizontal, DesignTokens.Spacing.md)
					.padding(.vertical, DesignTokens.Spacing.sm)
				}
				.onAppear {
					scrollToBottom(proxy: proxy, animated: false)
				}
				.onChange(of: thread.id) { _, _ in
					// Reset reply text when switching threads
					replyText = ""
					// Delay to allow ScrollView to re-render with new content
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
						scrollToBottom(proxy: proxy, animated: false)
					}
				}
				.onChange(of: thread.messages.count) { _, _ in
					scrollToBottom(proxy: proxy, animated: true)
				}
			}

			Divider()

			// Reply input
			MessageInputView(
				text: $replyText,
				placeholder: "Reply...",
				isEnabled: !appState.isSending,
				onSend: {
					appState.sendReply(body: replyText)
					replyText = ""
				}
			)
		}
	}

	/// Collect all unique participants from the thread
	private func collectParticipants() -> [EmailAddress] {
		var participants: [EmailAddress] = []
		var seen = Set<String>()

		for message in thread.messages {
			// Add sender
			let fromEmail = message.from.email.lowercased()
			if !seen.contains(fromEmail) {
				participants.append(message.from)
				seen.insert(fromEmail)
			}

			// Add TO recipients
			for addr in message.to {
				let email = addr.email.lowercased()
				if !seen.contains(email) {
					participants.append(addr)
					seen.insert(email)
				}
			}

			// Add CC recipients
			for addr in message.cc {
				let email = addr.email.lowercased()
				if !seen.contains(email) {
					participants.append(addr)
					seen.insert(email)
				}
			}
		}

		return participants
	}

	private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
		if let lastMessage = thread.messages.last {
			if animated {
				withAnimation(.easeOut(duration: 0.15)) {
					proxy.scrollTo(lastMessage.id, anchor: .bottom)
				}
			} else {
				proxy.scrollTo(lastMessage.id, anchor: .bottom)
			}
		}
	}
}

import SwiftUI

struct ConversationView: View {
	let thread: MailThread
	let ownerEmail: String

	var body: some View {
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
				// Delay to allow ScrollView to re-render with new content
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
					scrollToBottom(proxy: proxy, animated: false)
				}
			}
		}
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

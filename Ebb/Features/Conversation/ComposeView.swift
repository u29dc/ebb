import SwiftUI

/// Full compose view for new messages
struct ComposeView: View {
	@EnvironmentObject var appState: AppState

	@State private var recipientInput: String = ""

	var body: some View {
		VStack(spacing: 0) {
			// Header with To/Subject fields
			ComposeHeaderView(
				recipientInput: $recipientInput,
				subjectInput: $appState.composeDraft.subject,
				recipients: appState.composeDraft.recipients,
				onAddRecipient: addRecipient,
				onRemoveRecipient: removeRecipient
			)

			Divider()

			// Empty message area
			Spacer()

			// Error display
			if let error = appState.sendError {
				errorBanner(error)
			}

			Divider()

			// Message input
			MessageInputView(
				text: $appState.composeDraft.body,
				placeholder: "Message",
				isEnabled: canSend,
				onSend: appState.sendDraft
			)
		}
	}

	private var canSend: Bool {
		!appState.isSending
			&& !appState.composeDraft.recipients.isEmpty
			&& !appState.composeDraft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}

	@ViewBuilder
	private func errorBanner(_ error: String) -> some View {
		HStack(spacing: DesignTokens.Spacing.xs) {
			Image(systemName: "exclamationmark.triangle.fill")
				.foregroundColor(.red)

			Text(error)
				.foregroundColor(.red)
				.font(.caption)
				.lineLimit(2)

			Spacer()

			Button("Dismiss") {
				appState.sendError = nil
			}
			.buttonStyle(.plain)
			.font(.caption)
			.foregroundColor(.secondary)
		}
		.padding(.horizontal, DesignTokens.Spacing.md)
		.padding(.vertical, DesignTokens.Spacing.xs)
		.background(Color.red.opacity(0.1))
	}

	private func addRecipient(_ email: String) {
		let trimmed = email.trimmingCharacters(in: .whitespaces).lowercased()
		guard !trimmed.isEmpty else { return }
		guard trimmed.contains("@") else { return }  // Basic validation

		let address = EmailAddress(name: nil, email: trimmed)
		if !appState.composeDraft.recipients.contains(where: { $0.isSameAs(address) }) {
			appState.composeDraft.recipients.append(address)
		}
	}

	private func removeRecipient(_ recipient: EmailAddress) {
		appState.composeDraft.recipients.removeAll { $0.isSameAs(recipient) }
	}
}

#Preview {
	struct PreviewWrapper: View {
		@StateObject private var appState = AppState()

		var body: some View {
			ComposeView()
				.environmentObject(appState)
				.frame(width: 500, height: 400)
				.background(DesignTokens.Colors.cardBackground)
				.onAppear {
					appState.ownerEmailAddress = "me@example.com"
					appState.startNewMessage()
				}
		}
	}

	return PreviewWrapper()
}

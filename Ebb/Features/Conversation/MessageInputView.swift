import SwiftUI

/// Multi-line text input with Cmd+Enter to send
struct MessageInputView: View {
	@Binding var text: String
	let placeholder: String
	let isEnabled: Bool
	let onSend: () -> Void

	@FocusState private var isFocused: Bool

	init(
		text: Binding<String>,
		placeholder: String = "Message",
		isEnabled: Bool = true,
		onSend: @escaping () -> Void
	) {
		self._text = text
		self.placeholder = placeholder
		self.isEnabled = isEnabled
		self.onSend = onSend
	}

	var body: some View {
		HStack(alignment: .bottom, spacing: DesignTokens.Spacing.xs) {
			// Text editor with dynamic height
			ZStack(alignment: .topLeading) {
				// Placeholder
				if text.isEmpty {
					Text(placeholder)
						.foregroundColor(.secondary)
						.padding(.horizontal, DesignTokens.Spacing.xs)
						.padding(.vertical, DesignTokens.Spacing.xs)
						.allowsHitTesting(false)
				}

				// Text editor - Enter creates newlines naturally
				TextEditor(text: $text)
					.font(.body)
					.scrollContentBackground(.hidden)
					.padding(.horizontal, DesignTokens.Spacing.xxs)
					.frame(minHeight: DesignTokens.Layout.inputMinHeight)
					.frame(maxHeight: DesignTokens.Layout.inputMaxHeight)
					.fixedSize(horizontal: false, vertical: true)
					.focused($isFocused)
					.onKeyPress(.return, phases: .down) { keyPress in
						if keyPress.modifiers.contains(.command) {
							handleSend()
							return .handled
						}
						return .ignored
					}
			}
			.background(DesignTokens.Colors.inputBackground)
			.clipShape(RoundedRectangle(cornerRadius: DesignTokens.Corner.md))
			.overlay(
				RoundedRectangle(cornerRadius: DesignTokens.Corner.md)
					.stroke(DesignTokens.Colors.inputBorder, lineWidth: 1)
			)

			// Send button - Cmd+Enter triggers this
			Button(action: handleSend) {
				Image(systemName: "arrow.up.circle.fill")
					.font(.system(size: 28))
					.foregroundColor(canSend ? .accentColor : .secondary.opacity(0.5))
			}
			.buttonStyle(.plain)
			.disabled(!canSend)
			.keyboardShortcut(.return, modifiers: .command)
			.help("Send (Cmd+Return)")
		}
		.padding(.horizontal, DesignTokens.Spacing.md)
		.padding(.vertical, DesignTokens.Spacing.sm)
	}

	private var canSend: Bool {
		isEnabled && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}

	private func handleSend() {
		guard canSend else { return }
		onSend()
	}
}

#Preview {
	struct PreviewWrapper: View {
		@State private var text = ""

		var body: some View {
			VStack {
				Spacer()
				MessageInputView(text: $text, placeholder: "Reply...") {
					print("Send: \(text)")
					text = ""
				}
			}
			.frame(width: 400, height: 200)
			.background(DesignTokens.Colors.cardBackground)
		}
	}

	return PreviewWrapper()
}

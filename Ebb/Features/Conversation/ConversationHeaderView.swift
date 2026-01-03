import SwiftUI

/// Header showing participants and subject for a conversation
struct ConversationHeaderView: View {
	let participants: [EmailAddress]
	let subject: String
	let ownerEmail: String

	var body: some View {
		HStack(spacing: DesignTokens.Spacing.sm) {
			// Participant avatars (overlapping)
			participantAvatars

			VStack(alignment: .leading, spacing: 2) {
				// Participant names/emails
				Text(participantNames)
					.font(.headline)
					.lineLimit(1)

				// Subject line
				if !subject.isEmpty {
					Text(subject)
						.font(.subheadline)
						.foregroundColor(.secondary)
						.lineLimit(1)
				}
			}

			Spacer()
		}
		.padding(.horizontal, DesignTokens.Spacing.md)
		.padding(.vertical, DesignTokens.Spacing.sm)
		.frame(height: DesignTokens.Layout.headerHeight)
	}

	// MARK: - Avatar Stack

	@ViewBuilder
	private var participantAvatars: some View {
		let displayParticipants = Array(otherParticipants.prefix(4))
		let overlap: CGFloat = 8

		if displayParticipants.isEmpty {
			// No other participants - show empty avatar
			AvatarView(email: ownerEmail, name: nil)
		} else {
			HStack(spacing: -overlap) {
				ForEach(Array(displayParticipants.enumerated()), id: \.element.email) { index, participant in
					AvatarView(
						email: participant.email,
						name: participant.name
					)
					.zIndex(Double(displayParticipants.count - index))
				}
			}
		}
	}

	private var otherParticipants: [EmailAddress] {
		// Filter out owner and dedupe by email
		var seen = Set<String>()
		return participants.filter { participant in
			let email = participant.email.lowercased()
			guard email != ownerEmail.lowercased() else { return false }
			guard !seen.contains(email) else { return false }
			seen.insert(email)
			return true
		}
	}

	private var participantNames: String {
		let names = otherParticipants.map { $0.displayName }
		if names.isEmpty {
			return "New Message"
		}
		return names.joined(separator: ", ")
	}
}

// MARK: - Avatar View

struct AvatarView: View {
	let email: String
	let name: String?

	var body: some View {
		ZStack {
			Circle()
				.fill(avatarColor)

			Text(initials)
				.font(.system(size: 14, weight: .medium))
				.foregroundColor(.white)
		}
		.frame(width: DesignTokens.Layout.avatarSize, height: DesignTokens.Layout.avatarSize)
		.overlay(
			Circle()
				.stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 2)
		)
	}

	private var initials: String {
		if let name = name, !name.isEmpty {
			let parts = name.split(separator: " ")
			if parts.count >= 2 {
				return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
			}
			return String(name.prefix(2)).uppercased()
		}
		// Fall back to first two chars of email local part
		let local = email.split(separator: "@").first ?? ""
		return String(local.prefix(2)).uppercased()
	}

	private var avatarColor: Color {
		// Deterministic color based on email hash
		let hash = abs(email.lowercased().hashValue)
		let colors = DesignTokens.Colors.avatarColors
		let index = hash % colors.count
		return colors[index]
	}
}

// MARK: - Compose Header View

/// Header for compose mode with recipient and subject input
struct ComposeHeaderView: View {
	@Binding var recipientInput: String
	@Binding var subjectInput: String
	let recipients: [EmailAddress]
	let onAddRecipient: (String) -> Void
	let onRemoveRecipient: (EmailAddress) -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
			// To field with pills for added recipients
			HStack(alignment: .top, spacing: DesignTokens.Spacing.xs) {
				Text("To:")
					.foregroundColor(.secondary)
					.frame(width: 60, alignment: .leading)

				// Recipient pills + input
				FlowLayout(spacing: DesignTokens.Spacing.xxs) {
					ForEach(recipients, id: \.email) { recipient in
						RecipientPill(recipient: recipient) {
							onRemoveRecipient(recipient)
						}
					}

					TextField("Email address", text: $recipientInput)
						.textFieldStyle(.plain)
						.frame(minWidth: 150)
						.onSubmit {
							if !recipientInput.isEmpty {
								onAddRecipient(recipientInput)
								recipientInput = ""
							}
						}
				}
			}

			// Subject field
			HStack(spacing: DesignTokens.Spacing.xs) {
				Text("Subject:")
					.foregroundColor(.secondary)
					.frame(width: 60, alignment: .leading)

				TextField("Subject", text: $subjectInput)
					.textFieldStyle(.plain)
			}
		}
		.padding(.horizontal, DesignTokens.Spacing.md)
		.padding(.vertical, DesignTokens.Spacing.sm)
	}
}

// MARK: - Recipient Pill

struct RecipientPill: View {
	let recipient: EmailAddress
	let onRemove: () -> Void

	var body: some View {
		HStack(spacing: DesignTokens.Spacing.xxs) {
			Text(recipient.displayName)
				.font(.caption)
				.lineLimit(1)

			Button(action: onRemove) {
				Image(systemName: "xmark.circle.fill")
					.font(.caption)
					.foregroundColor(.secondary)
			}
			.buttonStyle(.plain)
		}
		.padding(.horizontal, DesignTokens.Spacing.xs)
		.padding(.vertical, DesignTokens.Spacing.xxs)
		.background(DesignTokens.Colors.inputBackground)
		.clipShape(Capsule())
	}
}

// MARK: - Flow Layout

/// Simple horizontal flow layout that wraps items
struct FlowLayout: Layout {
	var spacing: CGFloat = 4

	func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
		let result = layout(proposal: proposal, subviews: subviews)
		return result.size
	}

	func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
		let result = layout(proposal: proposal, subviews: subviews)
		for (index, position) in result.positions.enumerated() {
			subviews[index].place(
				at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
				proposal: ProposedViewSize(result.sizes[index])
			)
		}
	}

	private func layout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
		var positions: [CGPoint] = []
		var sizes: [CGSize] = []
		var currentX: CGFloat = 0
		var currentY: CGFloat = 0
		var lineHeight: CGFloat = 0
		let maxWidth = proposal.width ?? .infinity

		for subview in subviews {
			let size = subview.sizeThatFits(.unspecified)
			sizes.append(size)

			if currentX + size.width > maxWidth && currentX > 0 {
				currentX = 0
				currentY += lineHeight + spacing
				lineHeight = 0
			}

			positions.append(CGPoint(x: currentX, y: currentY))
			currentX += size.width + spacing
			lineHeight = max(lineHeight, size.height)
		}

		return LayoutResult(
			size: CGSize(width: maxWidth, height: currentY + lineHeight),
			positions: positions,
			sizes: sizes
		)
	}

	struct LayoutResult {
		let size: CGSize
		let positions: [CGPoint]
		let sizes: [CGSize]
	}
}

// MARK: - Previews

#Preview("View Mode") {
	ConversationHeaderView(
		participants: [
			EmailAddress(name: "John Doe", email: "john@example.com"),
			EmailAddress(name: "Jane Smith", email: "jane@example.com"),
			EmailAddress(name: nil, email: "me@example.com"),
		],
		subject: "Project Update - Q4 Planning",
		ownerEmail: "me@example.com"
	)
	.frame(width: 400)
	.background(DesignTokens.Colors.cardBackground)
}

#Preview("Compose Mode") {
	struct PreviewWrapper: View {
		@State private var recipient = ""
		@State private var subject = ""
		@State private var recipients: [EmailAddress] = [
			EmailAddress(name: "John Doe", email: "john@example.com")
		]

		var body: some View {
			ComposeHeaderView(
				recipientInput: $recipient,
				subjectInput: $subject,
				recipients: recipients,
				onAddRecipient: { email in
					recipients.append(EmailAddress(name: nil, email: email))
				},
				onRemoveRecipient: { recipient in
					recipients.removeAll { $0.email == recipient.email }
				}
			)
			.frame(width: 400)
			.background(DesignTokens.Colors.cardBackground)
		}
	}

	return PreviewWrapper()
}

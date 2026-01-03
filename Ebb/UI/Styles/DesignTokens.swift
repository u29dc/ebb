import AppKit
import SwiftUI

enum DesignTokens {
	// MARK: - Spacing

	enum Spacing {
		static let xxs: CGFloat = 4
		static let xs: CGFloat = 8
		static let sm: CGFloat = 12
		static let md: CGFloat = 16
		static let lg: CGFloat = 24
		static let xl: CGFloat = 32
		static let xxl: CGFloat = 48
	}

	// MARK: - Corner Radius

	enum Corner {
		static let sm: CGFloat = 8
		static let md: CGFloat = 12
		static let lg: CGFloat = 16
		static let pane: CGFloat = 20
	}

	// MARK: - Colors

	enum Colors {
		// Backgrounds
		static let background = Color(
			light: Color(white: 0.94),
			dark: Color(white: 0.11)
		)
		static let cardBackground = Color(
			light: Color.white,
			dark: Color(white: 0.18)
		)

		// Floating panel styling
		static let subtleBackground = Color(
			light: Color.white.opacity(0.7),
			dark: Color(white: 0.15).opacity(0.7)
		)
		static let panelBorder = Color(
			light: Color.black.opacity(0.1),
			dark: Color.white.opacity(0.1)
		)

		// Text
		static let primaryText = Color.primary
		static let secondaryText = Color.secondary

		// Chat bubbles - iMessage style
		static let bubbleSent = Color(red: 0.0, green: 0.48, blue: 1.0)
		static let bubbleReceived = Color(
			light: Color(white: 0.92),
			dark: Color(white: 0.25)
		)
		static let bubbleSentText = Color.white
		static let bubbleReceivedText = Color.primary

		// Sanitization indicators
		static let inProgress: Double = 0.5

		// Avatar colors (deterministic based on email hash)
		static let avatarColors: [Color] = [
			Color(red: 0.95, green: 0.26, blue: 0.21),  // Red
			Color(red: 0.91, green: 0.12, blue: 0.39),  // Pink
			Color(red: 0.61, green: 0.15, blue: 0.69),  // Purple
			Color(red: 0.40, green: 0.23, blue: 0.72),  // Deep Purple
			Color(red: 0.25, green: 0.32, blue: 0.71),  // Indigo
			Color(red: 0.13, green: 0.59, blue: 0.95),  // Blue
			Color(red: 0.01, green: 0.66, blue: 0.96),  // Light Blue
			Color(red: 0.00, green: 0.74, blue: 0.83),  // Cyan
			Color(red: 0.00, green: 0.59, blue: 0.53),  // Teal
			Color(red: 0.30, green: 0.69, blue: 0.31),  // Green
		]

		// Input field styling
		static let inputBackground = Color(
			light: Color(white: 0.96),
			dark: Color(white: 0.14)
		)
		static let inputBorder = Color(
			light: Color.black.opacity(0.1),
			dark: Color.white.opacity(0.15)
		)
	}

	// MARK: - Layout

	enum Layout {
		static let sidebarMinFraction: CGFloat = 0.16
		static let sidebarMaxFraction: CGFloat = 0.30
		static let floatingPadding: CGFloat = 6
		static let floatingCornerRadius: CGFloat = 16
		static let bubbleMaxWidth: CGFloat = 400

		// Conversation header
		static let avatarSize: CGFloat = 32
		static let headerHeight: CGFloat = 56

		// Message input
		static let inputMinHeight: CGFloat = 36
		static let inputMaxHeight: CGFloat = 120
	}

	// MARK: - Animation

	enum Animation {
		static let sidebarDuration: Double = 0.2
		static let sidebarDamping: Double = 1.0
	}

	// MARK: - Window Dimensions

	enum Window {
		static let mainMinWidth: CGFloat = 800
		static let mainMinHeight: CGFloat = 600
		static let mainDefaultWidth: CGFloat = 1200
		static let mainDefaultHeight: CGFloat = 800
	}
}

// MARK: - Adaptive Color Extension

extension Color {
	init(light: Color, dark: Color) {
		self.init(
			nsColor: NSColor(name: nil) { appearance in
				let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
				return isDark ? NSColor(dark) : NSColor(light)
			})
	}
}

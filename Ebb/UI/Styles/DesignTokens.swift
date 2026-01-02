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

		// Sanitization indicators
		static let inProgress: Double = 0.5
	}

	// MARK: - Layout

	enum Layout {
		static let sidebarMinFraction: CGFloat = 0.16
		static let sidebarMaxFraction: CGFloat = 0.30
		static let floatingPadding: CGFloat = 6
		static let floatingCornerRadius: CGFloat = 16
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

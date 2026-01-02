import AppKit
import SwiftUI

enum WindowControlType {
	case close, minimize, zoom
}

struct WindowControls: View {
	@State private var isHovered = false
	let isFullscreen: Bool

	var body: some View {
		if !isFullscreen {
			HStack(spacing: 8) {
				WindowControlButton(type: .close, isHovered: $isHovered)
				WindowControlButton(type: .minimize, isHovered: $isHovered)
				WindowControlButton(type: .zoom, isHovered: $isHovered)
			}
			.padding(.leading, 8)
			.onHover { hovering in
				withAnimation(.easeInOut(duration: 0.1)) {
					isHovered = hovering
				}
			}
		} else {
			EmptyView()
		}
	}
}

struct WindowControlButton: View {
	let type: WindowControlType
	@Binding var isHovered: Bool

	private let buttonSize: CGFloat = 12

	private var baseColor: Color {
		switch type {
		case .close: return Color(red: 1.0, green: 0.373, blue: 0.341)  // #FF5F57
		case .minimize: return Color(red: 0.996, green: 0.737, blue: 0.180)  // #FEBC2E
		case .zoom: return Color(red: 0.157, green: 0.784, blue: 0.251)  // #28C840
		}
	}

	private var iconColor: Color {
		switch type {
		case .close: return Color(red: 0.302, green: 0.0, blue: 0.0)
		case .minimize: return Color(red: 0.604, green: 0.388, blue: 0.0)
		case .zoom: return Color(red: 0.0, green: 0.302, blue: 0.051)
		}
	}

	var body: some View {
		ZStack {
			Circle()
				.fill(isHovered ? baseColor : Color(white: 0.5, opacity: 0.3))
				.frame(width: buttonSize, height: buttonSize)

			if isHovered {
				iconView
			}
		}
		.contentShape(Circle())
		.onTapGesture {
			performAction()
		}
	}

	@ViewBuilder
	private var iconView: some View {
		switch type {
		case .close:
			Image(systemName: "xmark")
				.font(.system(size: 7, weight: .bold))
				.foregroundColor(iconColor)
		case .minimize:
			Rectangle()
				.fill(iconColor)
				.frame(width: 8, height: 1.5)
		case .zoom:
			Image(systemName: "plus")
				.font(.system(size: 7, weight: .bold))
				.foregroundColor(iconColor)
		}
	}

	private func performAction() {
		guard let window = NSApp.keyWindow else { return }
		switch type {
		case .close:
			window.performClose(nil)
		case .minimize:
			window.performMiniaturize(nil)
		case .zoom:
			window.toggleFullScreen(nil)
		}
	}
}

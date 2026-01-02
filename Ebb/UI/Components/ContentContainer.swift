import SwiftUI

struct ContentContainer<Content: View>: View {
	@Environment(SidebarManager.self) var sidebarManager
	@Binding var isFullscreen: Bool

	let content: () -> Content

	private var isCompleteFullscreen: Bool {
		isFullscreen && sidebarManager.isSidebarHidden
	}

	private var cornerRadius: CGFloat {
		if #available(macOS 26, *) {
			return 13
		} else {
			return DesignTokens.Layout.floatingCornerRadius
		}
	}

	init(isFullscreen: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) {
		self._isFullscreen = isFullscreen
		self.content = content
	}

	var body: some View {
		content()
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.clipShape(
				RoundedRectangle(
					cornerRadius: isCompleteFullscreen ? 0 : cornerRadius,
					style: .continuous
				)
			)
			.padding(
				isCompleteFullscreen
					? EdgeInsets()
					: EdgeInsets(
						top: DesignTokens.Layout.floatingPadding,
						leading: sidebarManager.isSidebarHidden
							? DesignTokens.Layout.floatingPadding : 0,
						bottom: DesignTokens.Layout.floatingPadding,
						trailing: DesignTokens.Layout.floatingPadding
					)
			)
			.animation(.easeInOut(duration: 0.3), value: isFullscreen)
			.shadow(
				color: .black.opacity(0.15),
				radius: isCompleteFullscreen ? 0 : cornerRadius,
				x: 0,
				y: 2
			)
	}
}

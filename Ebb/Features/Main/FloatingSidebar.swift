import SwiftUI

struct FloatingSidebar: View {
	@EnvironmentObject var appState: AppState

	private let sidebarCornerRadius: CGFloat = {
		if #available(macOS 26, *) {
			return 13
		} else {
			return 10
		}
	}()

	var body: some View {
		let clipShape = ConditionallyConcentricRectangle(cornerRadius: sidebarCornerRadius)

		ZStack(alignment: .topLeading) {
			// Sidebar content
			VStack(alignment: .leading, spacing: 0) {
				// Traffic lights
				WindowControls(isFullscreen: appState.isFullscreen)
					.padding(.top, 12)

				// Placeholder content
				Text("Sidebar")
					.font(.headline)
					.foregroundColor(.secondary)
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			}
			.background(BlurEffectView(material: .popover, blendingMode: .withinWindow))
			.clipShape(clipShape)
			.overlay(
				clipShape
					.stroke(DesignTokens.Colors.panelBorder, lineWidth: 1)
			)
		}
		.padding(6)
	}
}

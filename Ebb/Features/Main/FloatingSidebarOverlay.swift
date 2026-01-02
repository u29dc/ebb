import SwiftUI

struct FloatingSidebarOverlay: View {
	@Environment(SidebarManager.self) private var sidebarManager

	@Binding var showFloatingSidebar: Bool
	@Binding var isMouseOverSidebar: Bool

	var sidebarFraction: FractionHolder

	@State private var dragFraction: CGFloat?

	var body: some View {
		GeometryReader { geo in
			let totalWidth = geo.size.width
			let minFraction: CGFloat = DesignTokens.Layout.sidebarMinFraction
			let maxFraction: CGFloat = DesignTokens.Layout.sidebarMaxFraction
			let currentFraction = dragFraction ?? sidebarFraction.value
			let clampedFraction = min(max(currentFraction, minFraction), maxFraction)
			let floatingWidth = max(0, min(totalWidth * clampedFraction, totalWidth))

			ZStack(alignment: .leading) {
				if showFloatingSidebar {
					FloatingSidebar()
						.frame(width: floatingWidth)
						.transition(.move(edge: .leading))
						.overlay(alignment: .trailing) {
							ResizeHandle(
								dragFraction: $dragFraction,
								sidebarFraction: sidebarFraction,
								floatingWidth: floatingWidth,
								totalWidth: totalWidth,
								minFraction: minFraction,
								maxFraction: maxFraction
							)
						}
						.zIndex(3)
				}

				HStack(spacing: 0) {
					hoverStrip(width: showFloatingSidebar ? floatingWidth : 10)
					Spacer()
				}
				.zIndex(2)
			}
		}
	}

	@ViewBuilder
	private func hoverStrip(width: CGFloat) -> some View {
		Color.clear
			.frame(width: width)
			.overlay(
				GlobalMouseTrackingArea(
					mouseEntered: Binding(
						get: { showFloatingSidebar },
						set: { newValue in
							isMouseOverSidebar = newValue
							showFloatingSidebar = newValue
						}
					),
					edge: .left,
					padding: 40,
					slack: 8
				)
			)
	}
}

private struct ResizeHandle: View {
	@Binding var dragFraction: CGFloat?
	var sidebarFraction: FractionHolder
	let floatingWidth: CGFloat
	let totalWidth: CGFloat
	let minFraction: CGFloat
	let maxFraction: CGFloat

	var body: some View {
		Rectangle()
			.fill(Color.clear)
			.frame(width: 14)
			.contentShape(Rectangle())
			.onHover { hovering in
				if hovering {
					NSCursor.resizeLeftRight.push()
				} else {
					NSCursor.pop()
				}
			}
			.gesture(
				DragGesture()
					.onChanged { value in
						let proposedWidth = max(
							0, min(floatingWidth + value.translation.width, totalWidth))
						let newFraction = proposedWidth / max(totalWidth, 1)
						dragFraction = min(max(newFraction, minFraction), maxFraction)
					}
					.onEnded { _ in
						if let fraction = dragFraction {
							sidebarFraction.value = fraction
						}
						dragFraction = nil
					}
			)
	}
}

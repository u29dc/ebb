import SwiftUI

struct RootView: View {
	@ObservedObject var appState: AppState
	@Environment(SidebarManager.self) var sidebarManager

	@State private var showFloatingSidebar = false
	@State private var isMouseOverSidebar = false

	var body: some View {
		Group {
			switch appState.authState {
			case .signedOut, .authenticating:
				loginContent
			case .signedIn:
				mainContent
			}
		}
	}

	@ViewBuilder
	private var loginContent: some View {
		ZStack {
			BlurEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
				.ignoresSafeArea(.all)

			LoginView()
				.environmentObject(appState)

			// Fullscreen state tracker (allowsHitTesting false to not block button clicks)
			FullscreenAccessor(isFullscreen: $appState.isFullscreen)
				.allowsHitTesting(false)
		}
		.ignoresSafeArea(.all)
	}

	@ViewBuilder
	private var mainContent: some View {
		ZStack(alignment: .topLeading) {
			// Main content area
			VStack(spacing: 0) {
				HStack(spacing: 0) {
					if !sidebarManager.isSidebarHidden {
						// Static sidebar with traffic lights
						VStack(alignment: .leading, spacing: 0) {
							WindowControls(isFullscreen: appState.isFullscreen)
								.padding(.top, 12)
								.padding(.leading, 8)

							Text("Sidebar")
								.font(.headline)
								.foregroundColor(.secondary)
								.frame(maxWidth: .infinity, maxHeight: .infinity)
						}
						.frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
					}

					ContentContainer(isFullscreen: $appState.isFullscreen) {
						// Main content placeholder
						VStack {
							Text("Main Content")
								.font(.headline)
								.foregroundColor(.secondary)
						}
						.frame(maxWidth: .infinity, maxHeight: .infinity)
						.background(DesignTokens.Colors.cardBackground)
					}
				}
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.background(
				BlurEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
					.ignoresSafeArea(.all)
			)

			// Floating sidebar overlay (when sidebar is hidden)
			if sidebarManager.isSidebarHidden {
				FloatingSidebarOverlay(
					showFloatingSidebar: $showFloatingSidebar,
					isMouseOverSidebar: $isMouseOverSidebar,
					sidebarFraction: sidebarManager.fraction
				)
			}

			// Fullscreen state tracker
			FullscreenAccessor(isFullscreen: $appState.isFullscreen)
		}
		.ignoresSafeArea(.all)
		.animation(.easeInOut(duration: 0.2), value: sidebarManager.isSidebarHidden)
		.animation(.easeOut(duration: 0.1), value: showFloatingSidebar)
	}
}

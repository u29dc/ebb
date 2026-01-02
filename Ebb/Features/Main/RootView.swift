import SwiftData
import SwiftUI

struct RootView: View {
	@ObservedObject var appState: AppState
	@Environment(SidebarManager.self) var sidebarManager
	@Environment(\.modelContext) private var modelContext

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
		.onAppear {
			appState.setModelContext(modelContext)
			appState.bootstrap()
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
						// Sidebar with traffic lights and thread list
						VStack(alignment: .leading, spacing: 0) {
							WindowControls(isFullscreen: appState.isFullscreen)
								.padding(.top, 12)
								.padding(.leading, DesignTokens.Spacing.md)

							ThreadListView()
								.environmentObject(appState)
						}
						.frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
					}

					ContentContainer(isFullscreen: $appState.isFullscreen) {
						if let thread = appState.selectedThread {
							ConversationView(thread: thread, ownerEmail: appState.ownerEmailAddress)
								.frame(maxWidth: .infinity, maxHeight: .infinity)
								.background(DesignTokens.Colors.cardBackground)
						} else {
							// Empty state
							VStack(spacing: DesignTokens.Spacing.md) {
								Image(systemName: "bubble.left.and.bubble.right")
									.font(.system(size: 48))
									.foregroundColor(.secondary.opacity(0.5))
								Text("Select a conversation")
									.font(.headline)
									.foregroundColor(.secondary)
							}
							.frame(maxWidth: .infinity, maxHeight: .infinity)
							.background(DesignTokens.Colors.cardBackground)
						}
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

			// Fullscreen state tracker (allowsHitTesting false to not block clicks)
			FullscreenAccessor(isFullscreen: $appState.isFullscreen)
				.allowsHitTesting(false)
		}
		.ignoresSafeArea(.all)
		.animation(.easeInOut(duration: 0.2), value: sidebarManager.isSidebarHidden)
		.animation(.easeOut(duration: 0.1), value: showFloatingSidebar)
	}
}

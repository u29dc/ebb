import SwiftData
import SwiftUI

@main
struct EbbApp: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
	@StateObject private var appState = AppState()
	@State private var sidebarManager = SidebarManager()

	var body: some Scene {
		WindowGroup {
			RootView(appState: appState)
				.environmentObject(appState)
				.environment(sidebarManager)
				.background(
					WindowAccessor { window in
						appDelegate.configureMainWindow(window)
					}
				)
		}
		.modelContainer(for: [PersistedThread.self, PersistedMessage.self])
		.windowStyle(.hiddenTitleBar)
		.windowResizability(.contentMinSize)
		.commands {
			CommandGroup(after: .sidebar) {
				Button(sidebarManager.isSidebarHidden ? "Show Sidebar" : "Hide Sidebar") {
					sidebarManager.toggleSidebar()
				}
				.keyboardShortcut("s", modifiers: [.command])

				Divider()

				Button("Fetch 10 Emails") {
					appState.fetchRecentThreads(count: 10)
				}
				.keyboardShortcut("f", modifiers: [.command, .shift])
				.disabled(appState.authState != .signedIn || appState.isRefreshing)

				Button("Clear Cache") {
					appState.clearCache()
				}
				.keyboardShortcut("k", modifiers: [.command, .shift])
				.disabled(appState.authState != .signedIn)

				Divider()

				Button("Sanitize Emails") {
					appState.sanitizeAll()
				}
				.keyboardShortcut("u", modifiers: [.command, .shift])
				.disabled(
					appState.authState != .signedIn || appState.isSanitizing
						|| appState.threads.isEmpty)

				Button("Reset Sanitization") {
					appState.resetSanitizedData()
				}
				.disabled(appState.authState != .signedIn || appState.isSanitizing)
			}

			CommandGroup(replacing: .appInfo) {
				Button("About Ebb") {
					NSApplication.shared.orderFrontStandardAboutPanel()
				}

				Divider()

				if appState.authState == .signedIn {
					Button("Sign Out") {
						appState.signOut()
					}
				}
			}
		}

		Settings {
			SettingsView()
		}
	}
}

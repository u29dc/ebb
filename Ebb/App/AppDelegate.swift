import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
	private var mainWindow: NSWindow?

	func applicationDidFinishLaunching(_: Notification) {
		// Disable automatic window tabbing for all NSWindow instances
		NSWindow.allowsAutomaticWindowTabbing = false
	}

	func applicationWillTerminate(_: Notification) {
		// Frame is auto-saved by setFrameAutosaveName
	}

	func configureMainWindow(_ window: NSWindow?) {
		guard let window = window else { return }
		guard mainWindow !== window else { return }  // Skip if same window

		mainWindow = window

		// Set minimum size
		window.minSize = NSSize(
			width: DesignTokens.Window.mainMinWidth,
			height: DesignTokens.Window.mainMinHeight
		)

		// Use macOS native window frame persistence
		window.setFrameAutosaveName("EbbMainWindow")

		// If no saved frame exists (first launch), set reasonable default
		if window.frame.size.width < DesignTokens.Window.mainMinWidth
			|| window.frame.size.height < DesignTokens.Window.mainMinHeight
		{
			window.setContentSize(
				NSSize(
					width: DesignTokens.Window.mainDefaultWidth,
					height: DesignTokens.Window.mainDefaultHeight
				))
			window.center()
		}
	}
}

extension NSScreen {
	var displayID: CGDirectDisplayID {
		let key = NSDeviceDescriptionKey("NSScreenNumber")
		return deviceDescription[key] as? CGDirectDisplayID ?? CGMainDisplayID()
	}
}

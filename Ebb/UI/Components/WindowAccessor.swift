import AppKit
import SwiftUI

/// Simple window accessor that captures the window via callback
struct WindowAccessor: NSViewRepresentable {
	let callback: (NSWindow?) -> Void

	func makeNSView(context _: Context) -> NSView {
		let view = NSView()
		DispatchQueue.main.async {
			self.callback(view.window)
		}
		return view
	}

	func updateNSView(_ nsView: NSView, context _: Context) {
		if nsView.window != nil {
			DispatchQueue.main.async {
				self.callback(nsView.window)
			}
		}
	}
}

/// Window reader that extracts the window reference into a binding
struct WindowReader: NSViewRepresentable {
	@Binding var window: NSWindow?

	func makeNSView(context _: Context) -> NSView {
		let view = NSView()
		DispatchQueue.main.async { [weak view] in
			if let win = view?.window {
				self.window = win
			}
		}
		return view
	}

	func updateNSView(_ nsView: NSView, context _: Context) {
		DispatchQueue.main.async { [weak nsView] in
			if let win = nsView?.window {
				self.window = win
			}
		}
	}
}

/// Tracks fullscreen state and manages traffic light visibility
struct FullscreenAccessor: NSViewRepresentable {
	@Binding var isFullscreen: Bool

	func makeCoordinator() -> Coordinator {
		Coordinator(isFullscreen: $isFullscreen)
	}

	func makeNSView(context: Context) -> NSView {
		let view = NSView()

		DispatchQueue.main.async {
			guard let window = view.window else { return }

			// Set initial fullscreen state
			context.coordinator.isFullscreen.wrappedValue = window.styleMask.contains(.fullScreen)

			// Register for fullscreen notifications
			let enterObserver = NotificationCenter.default.addObserver(
				forName: NSWindow.willEnterFullScreenNotification,
				object: window,
				queue: .main
			) { _ in
				MainActor.assumeIsolated {
					context.coordinator.isFullscreen.wrappedValue = true
					context.coordinator.updateTrafficLights(for: window, isFullscreen: true)
				}
			}

			let exitObserver = NotificationCenter.default.addObserver(
				forName: NSWindow.willExitFullScreenNotification,
				object: window,
				queue: .main
			) { _ in
				MainActor.assumeIsolated {
					context.coordinator.isFullscreen.wrappedValue = false
					context.coordinator.updateTrafficLights(for: window, isFullscreen: false)
				}
			}

			context.coordinator.observers = [enterObserver, exitObserver]
			context.coordinator.updateTrafficLights(
				for: window, isFullscreen: window.styleMask.contains(.fullScreen))
		}

		return view
	}

	func updateNSView(_: NSView, context _: Context) {}

	class Coordinator {
		var isFullscreen: Binding<Bool>
		nonisolated(unsafe) var observers: [Any] = []

		init(isFullscreen: Binding<Bool>) {
			self.isFullscreen = isFullscreen
		}

		deinit {
			let observersToRemove = observers
			observersToRemove.forEach { NotificationCenter.default.removeObserver($0) }
		}

		func updateTrafficLights(for window: NSWindow, isFullscreen: Bool) {
			// When using hidden titlebar with custom traffic lights:
			// - Hide native buttons always (we use custom ones)
			// - Show native buttons only in fullscreen (no custom ones there)
			for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
				guard let button = window.standardWindowButton(type) else { continue }
				button.animator().isHidden = !isFullscreen
			}
		}
	}
}

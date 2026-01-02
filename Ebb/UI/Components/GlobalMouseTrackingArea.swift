import AppKit
import SwiftUI

enum TrackingEdge {
	case left
	case right
	case top
	case bottom
}

struct GlobalMouseTrackingArea: NSViewRepresentable {
	@Binding var mouseEntered: Bool
	let edge: TrackingEdge
	let padding: CGFloat
	let slack: CGFloat

	init(
		mouseEntered: Binding<Bool>,
		edge: TrackingEdge,
		padding: CGFloat = 40,
		slack: CGFloat = 8
	) {
		_mouseEntered = mouseEntered
		self.edge = edge
		self.padding = padding
		self.slack = slack
	}

	func makeNSView(context _: Context) -> NSView {
		let view = GlobalTrackingStrip(edge: edge, padding: padding, slack: slack)
		view.onHoverChange = { hovering in
			self.mouseEntered = hovering
		}
		return view
	}

	func updateNSView(_ nsView: NSView, context _: Context) {
		if let strip = nsView as? GlobalTrackingStrip {
			strip.edge = edge
			strip.padding = padding
			strip.slack = slack
		}
	}
}

private final class GlobalTrackingStrip: NSView {
	var edge: TrackingEdge
	var padding: CGFloat
	var slack: CGFloat
	var onHoverChange: ((Bool) -> Void)?

	nonisolated(unsafe) private var hoverTracker: GlobalHoverTracker?

	init(edge: TrackingEdge, padding: CGFloat = 40, slack: CGFloat = 8) {
		self.edge = edge
		self.padding = padding
		self.slack = slack
		super.init(frame: .zero)
		hoverTracker = GlobalHoverTracker(view: self)
	}

	@available(*, unavailable)
	required init?(coder _: NSCoder) { fatalError() }

	override func viewWillMove(toWindow newWindow: NSWindow?) {
		if newWindow == nil { hoverTracker?.stop() }
		super.viewWillMove(toWindow: newWindow)
	}

	deinit {
		hoverTracker?.stop()
	}

	override func viewDidMoveToWindow() {
		if window == nil {
			hoverTracker?.stop()
		} else {
			hoverTracker?.startTracking { [weak self] inside in
				MainActor.assumeIsolated {
					guard let self else { return }
					self.onHoverChange?(inside)
				}
			}
		}
		super.viewDidMoveToWindow()
	}
}

private final class GlobalHoverTracker: @unchecked Sendable {
	typealias LocalMonitorToken = Any

	nonisolated(unsafe) private var localMonitor: LocalMonitorToken?
	nonisolated(unsafe) private var armed = false
	nonisolated(unsafe) private var isInside = false
	nonisolated(unsafe) weak var view: GlobalTrackingStrip?

	init(view: GlobalTrackingStrip? = nil) {
		self.view = view
	}

	func startTracking(completion: @escaping @Sendable (Bool) -> Void) {
		guard localMonitor == nil else { return }

		localMonitor = NSEvent.addLocalMonitorForEvents(
			matching: [.mouseMoved]
		) { [weak self] event in
			guard let self else { return event }
			guard let view = self.view else { return event }
			guard let window = view.window else { return event }

			let mouse = NSEvent.mouseLocation
			let screenRect = window.convertToScreen(
				view.convert(view.bounds, to: nil)
			)

			let basePadding: CGFloat = self.armed ? view.padding : 0
			let offset: CGFloat = -1

			// Create extended band based on edge
			let band: NSRect
			switch view.edge {
			case .left:
				band = NSRect(
					x: screenRect.minX - offset - basePadding,
					y: screenRect.minY - view.slack,
					width: basePadding,
					height: screenRect.height + 2 * view.slack
				)
			case .right:
				band = NSRect(
					x: screenRect.maxX + offset,
					y: screenRect.minY - view.slack,
					width: basePadding,
					height: screenRect.height + 2 * view.slack
				)
			case .top:
				band = NSRect(
					x: screenRect.minX - view.slack,
					y: screenRect.maxY + offset,
					width: screenRect.width + 2 * view.slack,
					height: basePadding
				)
			case .bottom:
				band = NSRect(
					x: screenRect.minX - view.slack,
					y: screenRect.minY - offset - basePadding,
					width: screenRect.width + 2 * view.slack,
					height: basePadding
				)
			}

			let insideBase = screenRect.contains(mouse)
			let inBand = band.contains(mouse)
			let effective = insideBase || inBand

			if effective != self.isInside {
				self.isInside = effective
				self.armed = effective
				if Thread.isMainThread {
					completion(effective)
				} else {
					DispatchQueue.main.async { completion(effective) }
				}
			}
			return event
		}
	}

	nonisolated func stop() {
		if let local = localMonitor { NSEvent.removeMonitor(local) }
		localMonitor = nil
		isInside = false
	}
}

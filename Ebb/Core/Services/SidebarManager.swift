import SwiftUI

@MainActor
@Observable
final class SidebarManager {
	var isSidebarHidden: Bool {
		get {
			access(keyPath: \.isSidebarHidden)
			return UserDefaults.standard.bool(forKey: "ui.sidebar.hidden")
		}
		set {
			withMutation(keyPath: \.isSidebarHidden) {
				UserDefaults.standard.set(newValue, forKey: "ui.sidebar.hidden")
			}
		}
	}

	var sidebarPosition: SidebarPosition = .primary

	var fraction = FractionHolder.usingUserDefaults(0.25, key: "ui.sidebar.fraction")
	var hiddenSidebar = SideHolder.usingUserDefaults(key: "ui.sidebar.visibility")

	var currentFraction: FractionHolder {
		fraction
	}

	func updateSidebarHidden() {
		isSidebarHidden = hiddenSidebar.side == .primary || hiddenSidebar.side == .secondary
	}

	func toggleSidebar() {
		let targetSide: SplitSide = sidebarPosition == .primary ? .primary : .secondary
		withAnimation(.spring(response: 0.2, dampingFraction: 1.0)) {
			hiddenSidebar.side = (hiddenSidebar.side == targetSide) ? nil : targetSide
			updateSidebarHidden()
		}
	}

	func showSidebar() {
		withAnimation(.spring(response: 0.2, dampingFraction: 1.0)) {
			hiddenSidebar.side = nil
			updateSidebarHidden()
		}
	}

	func hideSidebar() {
		let targetSide: SplitSide = sidebarPosition == .primary ? .primary : .secondary
		withAnimation(.spring(response: 0.2, dampingFraction: 1.0)) {
			hiddenSidebar.side = targetSide
			updateSidebarHidden()
		}
	}
}

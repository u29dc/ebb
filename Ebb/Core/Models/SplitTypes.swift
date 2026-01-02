import Foundation

/// The two sides of a SplitView
public enum SplitSide: String {
	case primary
	case secondary
	case left
	case right
	case top
	case bottom

	public var isPrimary: Bool {
		self == .primary || self == .left || self == .top
	}

	public var isSecondary: Bool {
		self == .secondary || self == .right || self == .bottom
	}
}

extension Optional where Wrapped == SplitSide {
	public var isPrimary: Bool {
		self == nil ? false : self!.isPrimary
	}

	public var isSecondary: Bool {
		self == nil ? false : self!.isSecondary
	}
}

/// Position of the sidebar
public enum SidebarPosition: String, Hashable {
	case primary
	case secondary
}

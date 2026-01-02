import Combine
import Foundation

/// An ObservableObject that stores the split position as a fraction (0.0-1.0).
/// Use the static `usingUserDefaults` method to save state automatically.
public class FractionHolder: ObservableObject {
	@Published public var value: CGFloat {
		didSet {
			setter?(value)
		}
	}

	public var getter: (() -> CGFloat)?
	public var setter: ((CGFloat) -> Void)?

	public init(
		_ fraction: CGFloat? = nil,
		getter: (() -> CGFloat)? = nil,
		setter: ((CGFloat) -> Void)? = nil
	) {
		value = getter?() ?? fraction ?? 0.5
		self.getter = getter
		self.setter = setter
	}

	public static func usingUserDefaults(_ fraction: CGFloat? = nil, key: String) -> FractionHolder
	{
		FractionHolder(
			fraction,
			getter: { UserDefaults.standard.value(forKey: key) as? CGFloat ?? fraction ?? 0.5 },
			setter: { fraction in UserDefaults.standard.set(fraction, forKey: key) }
		)
	}

	public func inverted() -> FractionHolder {
		FractionHolder(
			1.0 - value,
			getter: { [weak self] in
				guard let self else { return 0.5 }
				return 1.0 - self.value
			},
			setter: { [weak self] newValue in
				guard let self else { return }
				self.value = 1.0 - newValue
			}
		)
	}
}

/// An ObservableObject that tracks which side is hidden.
/// Use the static `usingUserDefaults` method to save state automatically.
public class SideHolder: ObservableObject {
	@Published private var value: SplitSide? {
		didSet {
			setter?(value)
		}
	}

	public var getter: (() -> SplitSide?)?
	public var setter: ((SplitSide?) -> Void)?

	public var side: SplitSide? {
		get { value }
		set { setValue(newValue) }
	}

	public var oldSide: SplitSide? { oldValue }
	private var oldValue: SplitSide?

	public init(
		_ hide: SplitSide? = nil,
		getter: (() -> SplitSide?)? = nil,
		setter: ((SplitSide?) -> Void)? = nil
	) {
		let value = getter?() ?? hide
		self.value = value
		self.getter = getter
		self.setter = setter
		oldValue = value == nil ? .secondary : nil
	}

	/// Hide the specified side
	public func hide(_ side: SplitSide) {
		setValue(side)
	}

	/// Toggle whether the side is hidden
	public func toggle(_ side: SplitSide? = nil) {
		guard let side else {
			setValue(oldValue)
			return
		}
		if (side.isPrimary && value.isPrimary) || (side.isSecondary && value.isSecondary) {
			setValue(oldValue)
		} else {
			setValue(side)
		}
	}

	private func setValue(_ side: SplitSide?) {
		guard value != side else { return }
		let oldSide = value
		value = side
		oldValue = oldSide
	}

	public static func usingUserDefaults(_ hide: SplitSide? = nil, key: String) -> SideHolder {
		SideHolder(
			hide,
			getter: {
				guard
					let value = UserDefaults.standard.value(forKey: key) as? String,
					let side = SplitSide(rawValue: value)
				else {
					return nil
				}
				return side
			},
			setter: { side in
				UserDefaults.standard.set(side?.rawValue, forKey: key)
			}
		)
	}
}

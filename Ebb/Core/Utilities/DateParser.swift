import Foundation

public enum DateParser: Sendable {
	private static let rfc822Formatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.timeZone = TimeZone(secondsFromGMT: 0)
		formatter.dateFormat = "EEE, d MMM yyyy HH:mm:ss Z"
		return formatter
	}()

	/// Parse RFC 822 date format used in email headers
	public static func parseRFC822(_ value: String) -> Date? {
		rfc822Formatter.date(from: value)
	}
}

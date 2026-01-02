import Foundation

extension EmailAddress {
	/// Parse an email address from a string like "Name <email@domain.com>" or "email@domain.com"
	public static func parse(from value: String?) -> EmailAddress? {
		guard let value else { return nil }
		let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
		if let match = trimmed.firstMatch(of: /(.+)\s<(.+)>/) {
			let name = String(match.1).trimmingCharacters(in: .whitespacesAndNewlines)
			let email = String(match.2).trimmingCharacters(in: .whitespacesAndNewlines)
			return EmailAddress(name: name, email: email)
		}
		return EmailAddress(name: nil, email: trimmed)
	}

	/// Parse a comma-separated list of email addresses
	public static func parseList(from value: String?) -> [EmailAddress] {
		guard let value else { return [] }
		return
			value
			.split(separator: ",")
			.compactMap { parse(from: String($0)) }
	}
}

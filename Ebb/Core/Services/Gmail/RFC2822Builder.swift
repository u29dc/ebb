import Foundation

/// Builds RFC 2822 compliant email messages for Gmail API
public enum RFC2822Builder: Sendable {

	/// Build a new message (no threading)
	/// - Parameters:
	///   - from: Sender address
	///   - to: Primary recipients
	///   - cc: Carbon copy recipients
	///   - subject: Email subject
	///   - body: Plain text body
	///   - messageId: Optional custom Message-ID (auto-generated if nil)
	/// - Returns: RFC 2822 formatted message string
	public static func buildNewMessage(
		from: EmailAddress,
		to: [EmailAddress],
		cc: [EmailAddress] = [],
		subject: String,
		body: String,
		messageId: String? = nil
	) -> String {
		var lines: [String] = []
		let msgId = messageId ?? generateMessageId()

		// Required headers
		lines.append("From: \(formatAddress(from))")
		lines.append("To: \(to.map(formatAddress).joined(separator: ", "))")
		if !cc.isEmpty {
			lines.append("Cc: \(cc.map(formatAddress).joined(separator: ", "))")
		}
		lines.append("Subject: \(encodeHeader(subject))")
		lines.append("Message-ID: \(msgId)")
		lines.append("Date: \(formatDate(Date()))")
		lines.append("MIME-Version: 1.0")
		lines.append("Content-Type: text/plain; charset=utf-8")
		lines.append("Content-Transfer-Encoding: quoted-printable")

		// Blank line separating headers from body
		lines.append("")

		// Body (quoted-printable encoded)
		lines.append(encodeQuotedPrintable(body))

		return lines.joined(separator: "\r\n")
	}

	/// Build a reply message (with threading headers)
	/// - Parameters:
	///   - from: Sender address
	///   - to: Primary recipients
	///   - cc: Carbon copy recipients
	///   - subject: Email subject (Re: prefix added if not present)
	///   - body: Plain text body
	///   - inReplyTo: Message-ID of the message being replied to
	///   - references: Existing References header chain
	///   - messageId: Optional custom Message-ID (auto-generated if nil)
	/// - Returns: RFC 2822 formatted message string
	public static func buildReply(
		from: EmailAddress,
		to: [EmailAddress],
		cc: [EmailAddress] = [],
		subject: String,
		body: String,
		inReplyTo: String,
		references: String?,
		messageId: String? = nil
	) -> String {
		var lines: [String] = []
		let msgId = messageId ?? generateMessageId()

		// Required headers
		lines.append("From: \(formatAddress(from))")
		lines.append("To: \(to.map(formatAddress).joined(separator: ", "))")
		if !cc.isEmpty {
			lines.append("Cc: \(cc.map(formatAddress).joined(separator: ", "))")
		}

		// Add Re: prefix if not already present
		let replySubject = subject.hasPrefix("Re:") ? subject : "Re: \(subject)"
		lines.append("Subject: \(encodeHeader(replySubject))")

		lines.append("Message-ID: \(msgId)")
		lines.append("Date: \(formatDate(Date()))")

		// Threading headers
		lines.append("In-Reply-To: \(inReplyTo)")
		if let refs = references, !refs.isEmpty {
			lines.append("References: \(refs) \(inReplyTo)")
		} else {
			lines.append("References: \(inReplyTo)")
		}

		lines.append("MIME-Version: 1.0")
		lines.append("Content-Type: text/plain; charset=utf-8")
		lines.append("Content-Transfer-Encoding: quoted-printable")

		// Blank line separating headers from body
		lines.append("")

		// Body (quoted-printable encoded)
		lines.append(encodeQuotedPrintable(body))

		return lines.joined(separator: "\r\n")
	}

	/// Generate a unique Message-ID
	public static func generateMessageId() -> String {
		let uuid = UUID().uuidString.lowercased()
		let timestamp = Int(Date().timeIntervalSince1970)
		return "<\(uuid).\(timestamp)@ebb.local>"
	}

	// MARK: - Private Helpers

	/// Format email address for headers
	private static func formatAddress(_ address: EmailAddress) -> String {
		if let name = address.name, !name.isEmpty {
			// RFC 2047 encode name if needed
			if name.needsHeaderEncoding {
				return "=?UTF-8?B?\(Data(name.utf8).base64EncodedString())?= <\(address.email)>"
			}
			// Quote the name if it contains special characters
			if name.containsSpecialHeaderChars {
				return "\"\(name.replacingOccurrences(of: "\"", with: "\\\""))\" <\(address.email)>"
			}
			return "\(name) <\(address.email)>"
		}
		return address.email
	}

	/// Encode header value (RFC 2047 if needed)
	private static func encodeHeader(_ value: String) -> String {
		if value.needsHeaderEncoding {
			return "=?UTF-8?B?\(Data(value.utf8).base64EncodedString())?="
		}
		return value
	}

	/// Format date for Date header (RFC 2822)
	private static func formatDate(_ date: Date) -> String {
		let formatter = DateFormatter()
		formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.timeZone = TimeZone.current
		return formatter.string(from: date)
	}

	/// Encode body as quoted-printable (RFC 2045)
	private static func encodeQuotedPrintable(_ string: String) -> String {
		var result = ""
		var lineLength = 0
		let maxLineLength = 76

		for scalar in string.unicodeScalars {
			let value = scalar.value

			// Handle line breaks - preserve them
			if value == 0x0D {
				// Carriage return - skip, we'll handle with LF
				continue
			} else if value == 0x0A {
				// Line feed - output CRLF and reset line length
				result.append("\r\n")
				lineLength = 0
				continue
			}

			// Determine encoding for this character
			let encoded: String
			if value >= 33 && value <= 126 && value != 61 {
				// Printable ASCII (except '=' which must be encoded)
				encoded = String(Character(scalar))
			} else if value == 32 {
				// Space - encode only if it would be at end of line
				encoded = " "
			} else if value == 9 {
				// Tab - encode only if it would be at end of line
				encoded = "\t"
			} else {
				// Encode as =XX for each byte
				var bytes = ""
				for byte in String(scalar).utf8 {
					bytes.append(String(format: "=%02X", byte))
				}
				encoded = bytes
			}

			// Check if we need to wrap the line (soft line break)
			if lineLength + encoded.count > maxLineLength - 1 {
				result.append("=\r\n")
				lineLength = 0
			}

			result.append(encoded)
			lineLength += encoded.count
		}

		return result
	}
}

// MARK: - String Extensions

private extension String {
	/// Check if string contains non-ASCII or control chars requiring RFC 2047 encoding
	var needsHeaderEncoding: Bool {
		self.unicodeScalars.contains { $0.value > 127 || $0.value < 32 }
	}

	/// Check if string contains special characters that need quoting in headers
	var containsSpecialHeaderChars: Bool {
		let special = CharacterSet(charactersIn: "()<>@,;:\\\".[]")
		return self.unicodeScalars.contains { special.contains($0) }
	}
}

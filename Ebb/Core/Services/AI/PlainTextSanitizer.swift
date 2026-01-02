import Foundation
import SwiftSoup

/// Simple HTML to plain text extraction using SwiftSoup
/// This is a basic sanitizer that strips all HTML and returns clean text.
/// AI-based sanitization can be layered on top of this later.
struct PlainTextSanitizer: Sendable {
	/// Extract clean plain text from HTML
	/// - Parameter html: Raw HTML string from email body
	/// - Returns: Clean plain text with normalized whitespace
	nonisolated static func sanitize(_ html: String) -> String {
		// Step 1: Use SwiftSoup whitelist to strip scripts, styles, forms, etc.
		// basic() keeps: a, b, blockquote, br, cite, code, dd, dl, dt, em, i,
		//                li, ol, p, pre, q, small, span, strike, strong, sub, sup, u, ul
		guard let cleaned = try? SwiftSoup.clean(html, Whitelist.basic()) else {
			return stripHTMLFallback(html)
		}

		// Step 2: Parse cleaned HTML and extract text content
		guard let doc = try? SwiftSoup.parse(cleaned),
			let text = try? doc.text()
		else {
			return stripHTMLFallback(cleaned)
		}

		// Step 3: Normalize whitespace
		return normalizeWhitespace(text)
	}

	/// Fallback HTML stripping using regex when SwiftSoup fails
	private nonisolated static func stripHTMLFallback(_ html: String) -> String {
		// Remove HTML tags
		var result = html.replacingOccurrences(
			of: "<[^>]+>",
			with: " ",
			options: .regularExpression
		)

		// Decode common HTML entities
		let entities: [(String, String)] = [
			("&nbsp;", " "),
			("&amp;", "&"),
			("&lt;", "<"),
			("&gt;", ">"),
			("&quot;", "\""),
			("&#39;", "'"),
			("&apos;", "'"),
		]
		for (entity, replacement) in entities {
			result = result.replacingOccurrences(of: entity, with: replacement)
		}

		return normalizeWhitespace(result)
	}

	/// Normalize whitespace: collapse multiple spaces/newlines, trim
	private nonisolated static func normalizeWhitespace(_ text: String) -> String {
		// Replace multiple whitespace characters with single space
		var result = text.replacingOccurrences(
			of: "\\s+",
			with: " ",
			options: .regularExpression
		)

		// Trim leading/trailing whitespace
		result = result.trimmingCharacters(in: .whitespacesAndNewlines)

		return result
	}
}

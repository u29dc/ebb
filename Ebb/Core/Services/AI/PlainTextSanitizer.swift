import Foundation
import SwiftSoup

/// Simple HTML to plain text extraction using SwiftSoup
/// This is a basic sanitizer that strips all HTML and returns clean text.
/// AI-based sanitization can be layered on top of this later.
struct PlainTextSanitizer: Sendable {
	/// Extract clean plain text from HTML, removing quoted content
	/// - Parameter html: Raw HTML string from email body
	/// - Returns: Clean plain text with normalized whitespace, quotes removed
	nonisolated static func sanitize(_ html: String) -> String {
		// Step 1: Parse HTML
		guard let doc = try? SwiftSoup.parse(html) else {
			return stripHTMLFallback(html)
		}

		// Step 2: Remove quoted content (blockquotes, gmail_quote divs, etc.)
		removeQuotedContent(doc)

		// Step 3: Extract text content
		guard let text = try? doc.text() else {
			return stripHTMLFallback(html)
		}

		// Step 4: Remove quote headers and markers from plain text
		let withoutQuoteHeaders = removeQuoteHeaders(text)

		// Step 5: Normalize whitespace
		return normalizeWhitespace(withoutQuoteHeaders)
	}

	/// Remove quoted content from HTML document before text extraction
	private nonisolated static func removeQuotedContent(_ doc: Document) {
		// Remove blockquotes (standard HTML quoting)
		try? doc.select("blockquote").remove()

		// Remove Gmail quote containers
		try? doc.select("div.gmail_quote").remove()
		try? doc.select("div.gmail_extra").remove()

		// Remove Outlook quote containers
		try? doc.select("div#appendonsend").remove()
		try? doc.select("div.OutlookMessageHeader").remove()
		try? doc.select("div#divRplyFwdMsg").remove()

		// Remove Yahoo quote containers
		try? doc.select("div.yahoo_quoted").remove()

		// Remove Apple Mail quotes
		try? doc.select("div[type=cite]").remove()
		try? doc.select("blockquote[type=cite]").remove()

		// Remove generic reply/forward markers
		try? doc.select("div.moz-cite-prefix").remove()  // Thunderbird
		try? doc.select("div.WordSection1").remove()  // Word/Outlook

		// Remove hr elements often used as separators before quotes
		try? doc.select("hr").remove()
	}

	/// Remove quote headers and markers from plain text
	private nonisolated static func removeQuoteHeaders(_ text: String) -> String {
		var result = text

		// Remove "On [date], [person] wrote:" lines (common in Gmail, Apple Mail)
		// This pattern matches variations like:
		// - "On Mon, Jan 1, 2024 at 10:00 AM, John Doe wrote:"
		// - "On 1 Jan 2024, at 10:00, john@example.com wrote:"
		result = result.replacingOccurrences(
			of: "On [^:]+wrote:",
			with: "",
			options: .regularExpression
		)

		// Remove "From: ... Sent: ... To: ... Subject: ..." blocks (Outlook style)
		result = result.replacingOccurrences(
			of: "From:[^S]*Sent:[^T]*To:[^S]*Subject:[^\n]*",
			with: "",
			options: .regularExpression
		)

		// Remove separator lines (often before quoted content)
		result = result.replacingOccurrences(
			of: "-{3,}",
			with: "",
			options: .regularExpression
		)
		result = result.replacingOccurrences(
			of: "_{3,}",
			with: "",
			options: .regularExpression
		)

		// Remove lines that start with > (plain text quoting)
		// Split into lines, filter, rejoin
		let lines = result.components(separatedBy: .newlines)
		let filteredLines = lines.filter { line in
			let trimmed = line.trimmingCharacters(in: .whitespaces)
			return !trimmed.hasPrefix(">")
		}
		result = filteredLines.joined(separator: " ")

		return result
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

		// Also apply quote header removal to fallback
		result = removeQuoteHeaders(result)

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

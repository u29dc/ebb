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
		_ = try? doc.select("blockquote").remove()

		// Remove Gmail quote containers
		_ = try? doc.select("div.gmail_quote").remove()
		_ = try? doc.select("div.gmail_extra").remove()
		_ = try? doc.select("div.gmail_attr").remove()
		_ = try? doc.select("div.gmail_signature").remove()

		// Remove Outlook quote containers
		_ = try? doc.select("div#appendonsend").remove()
		_ = try? doc.select("div.OutlookMessageHeader").remove()
		_ = try? doc.select("div#divRplyFwdMsg").remove()

		// Remove Yahoo quote containers
		_ = try? doc.select("div.yahoo_quoted").remove()

		// Remove Apple Mail quotes
		_ = try? doc.select("div[type=cite]").remove()
		_ = try? doc.select("blockquote[type=cite]").remove()

		// Remove generic reply/forward markers
		_ = try? doc.select("div.moz-cite-prefix").remove()  // Thunderbird
		_ = try? doc.select("div.WordSection1").remove()  // Word/Outlook

		// Remove hr elements often used as separators before quotes
		_ = try? doc.select("hr").remove()
	}

	/// Remove quote headers and markers from plain text
	private nonisolated static func removeQuoteHeaders(_ text: String) -> String {
		var result = text

		// Normalize newlines to spaces to handle Gmail's 80-char line wrapping
		// This allows patterns to match across wrapped lines
		let normalizedForHeaders =
			result
			.replacingOccurrences(of: "\r\n", with: " ")
			.replacingOccurrences(of: "\n", with: " ")
			.replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)

		// International "wrote:" variants with 200-char limit to prevent backtracking
		// Covers: English, German, French, Spanish, Italian, Portuguese, Dutch
		let wrotePatterns = [
			"On [^:]{1,200}wrote:",  // English (Gmail, Apple Mail)
			"Am [^:]{1,200}schrieb:",  // German
			"Le [^:]{1,200}a écrit:",  // French
			"El [^:]{1,200}escribió:",  // Spanish
			"Il [^:]{1,200}(ha )?scritto:",  // Italian
			"Em [^:]{1,200}escreveu:",  // Portuguese
			"Op [^:]{1,200}schreef:",  // Dutch
		]

		result = normalizedForHeaders
		for pattern in wrotePatterns {
			result = result.replacingOccurrences(
				of: pattern,
				with: "",
				options: .regularExpression
			)
		}

		// Remove common mobile email signatures
		result = result.replacingOccurrences(
			of: "Sent from my (iPhone|iPad|Android|Galaxy|Pixel|device|mobile).*",
			with: "",
			options: .regularExpression
		)
		result = result.replacingOccurrences(
			of: "Get Outlook for (iOS|Android).*",
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
		// Normalize Unicode whitespace variants that \s may not catch consistently
		var result =
			text
			.replacingOccurrences(of: "\u{00A0}", with: " ")  // Non-breaking space
			.replacingOccurrences(of: "\u{200B}", with: "")  // Zero-width space
			.replacingOccurrences(of: "\u{200C}", with: "")  // Zero-width non-joiner
			.replacingOccurrences(of: "\u{200D}", with: "")  // Zero-width joiner
			.replacingOccurrences(of: "\u{2060}", with: "")  // Word joiner
			.replacingOccurrences(of: "\u{FEFF}", with: "")  // BOM
			.replacingOccurrences(of: "\u{3000}", with: " ")  // Ideographic space

		// Replace multiple whitespace characters with single space
		result = result.replacingOccurrences(
			of: "\\s+",
			with: " ",
			options: .regularExpression
		)

		// Trim leading/trailing whitespace
		result = result.trimmingCharacters(in: .whitespacesAndNewlines)

		return result
	}
}

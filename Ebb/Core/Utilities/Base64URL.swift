import Foundation

enum Base64URL: Sendable {
	nonisolated static func decode(_ value: String) -> Data? {
		var base64 =
			value
			.replacingOccurrences(of: "-", with: "+")
			.replacingOccurrences(of: "_", with: "/")
		let padding = 4 - (base64.count % 4)
		if padding < 4 {
			base64.append(String(repeating: "=", count: padding))
		}
		return Data(base64Encoded: base64)
	}

	nonisolated static func decodeToString(_ value: String) -> String? {
		guard let data = decode(value) else { return nil }
		return String(data: data, encoding: .utf8)
	}

	nonisolated static func encode(_ data: Data) -> String {
		data.base64EncodedString()
			.replacingOccurrences(of: "+", with: "-")
			.replacingOccurrences(of: "/", with: "_")
			.replacingOccurrences(of: "=", with: "")
	}
}

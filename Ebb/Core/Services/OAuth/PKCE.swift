import CryptoKit
import Foundation

struct PKCE: Sendable {
	let verifier: String
	let challenge: String

	static func generate() -> PKCE {
		// Generate 32 random bytes for verifier
		var bytes = [UInt8](repeating: 0, count: 32)
		_ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)

		// Base64URL encode (no padding)
		let verifier = Data(bytes)
			.base64EncodedString()
			.replacingOccurrences(of: "+", with: "-")
			.replacingOccurrences(of: "/", with: "_")
			.replacingOccurrences(of: "=", with: "")

		// SHA256 hash of verifier, then Base64URL encode
		let hash = SHA256.hash(data: Data(verifier.utf8))
		let challenge = Data(hash)
			.base64EncodedString()
			.replacingOccurrences(of: "+", with: "-")
			.replacingOccurrences(of: "/", with: "_")
			.replacingOccurrences(of: "=", with: "")

		return PKCE(verifier: verifier, challenge: challenge)
	}
}

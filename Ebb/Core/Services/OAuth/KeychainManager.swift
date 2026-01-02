import Foundation
import Security

final class KeychainManager: Sendable {
	enum KeychainError: Error, LocalizedError {
		case encodingFailed
		case decodingFailed
		case saveFailed(OSStatus)
		case deleteFailed(OSStatus)
		case notFound
		case unexpectedError(OSStatus)

		var errorDescription: String? {
			switch self {
			case .encodingFailed:
				return "Failed to encode tokens for keychain"
			case .decodingFailed:
				return "Failed to decode tokens from keychain"
			case .saveFailed(let status):
				return "Failed to save to keychain: \(status)"
			case .deleteFailed(let status):
				return "Failed to delete from keychain: \(status)"
			case .notFound:
				return "No tokens found in keychain"
			case .unexpectedError(let status):
				return "Unexpected keychain error: \(status)"
			}
		}
	}

	private let service = "u29dc.Ebb"
	private let account = "oauth_tokens"

	func save(_ tokens: OAuthTokens) throws {
		let data: Data
		do {
			data = try JSONEncoder().encode(tokens)
		} catch {
			throw KeychainError.encodingFailed
		}

		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: account,
		]

		// Delete existing item first
		SecItemDelete(query as CFDictionary)

		var addQuery = query
		addQuery[kSecValueData as String] = data
		addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

		let status = SecItemAdd(addQuery as CFDictionary, nil)
		guard status == errSecSuccess else {
			throw KeychainError.saveFailed(status)
		}
	}

	func load() throws -> OAuthTokens {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: account,
			kSecReturnData as String: true,
			kSecMatchLimit as String: kSecMatchLimitOne,
		]

		var result: AnyObject?
		let status = SecItemCopyMatching(query as CFDictionary, &result)

		guard status == errSecSuccess else {
			if status == errSecItemNotFound {
				throw KeychainError.notFound
			}
			throw KeychainError.unexpectedError(status)
		}

		guard let data = result as? Data else {
			throw KeychainError.decodingFailed
		}

		do {
			return try JSONDecoder().decode(OAuthTokens.self, from: data)
		} catch {
			throw KeychainError.decodingFailed
		}
	}

	func delete() throws {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: account,
		]

		let status = SecItemDelete(query as CFDictionary)
		guard status == errSecSuccess || status == errSecItemNotFound else {
			throw KeychainError.deleteFailed(status)
		}
	}
}

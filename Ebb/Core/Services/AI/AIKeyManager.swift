import Foundation
import Security

nonisolated final class AIKeyManager: Sendable {
	enum KeychainError: Error {
		case encodingFailed
		case saveFailed(OSStatus)
		case deleteFailed(OSStatus)
		case notFound
		case unexpectedError(OSStatus)
	}

	private let service = "u29dc.Ebb"
	private let account = "openrouter_api_key"

	private var baseQuery: [String: Any] {
		[
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: account,
		]
	}

	nonisolated func save(_ apiKey: String) throws {
		guard let data = apiKey.data(using: .utf8) else {
			throw KeychainError.encodingFailed
		}

		// Delete existing item first
		SecItemDelete(baseQuery as CFDictionary)

		var addQuery = baseQuery
		addQuery[kSecValueData as String] = data
		addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

		let status = SecItemAdd(addQuery as CFDictionary, nil)
		guard status == errSecSuccess else {
			throw KeychainError.saveFailed(status)
		}
	}

	nonisolated func load() throws -> String {
		var query = baseQuery
		query[kSecReturnData as String] = true
		query[kSecMatchLimit as String] = kSecMatchLimitOne

		var result: AnyObject?
		let status = SecItemCopyMatching(query as CFDictionary, &result)

		guard status == errSecSuccess else {
			if status == errSecItemNotFound {
				throw KeychainError.notFound
			}
			throw KeychainError.unexpectedError(status)
		}

		guard let data = result as? Data,
			let apiKey = String(data: data, encoding: .utf8)
		else {
			throw KeychainError.unexpectedError(errSecDecode)
		}

		return apiKey
	}

	nonisolated func delete() throws {
		let status = SecItemDelete(baseQuery as CFDictionary)
		guard status == errSecSuccess || status == errSecItemNotFound else {
			throw KeychainError.deleteFailed(status)
		}
	}

	nonisolated func loadOrNil() -> String? {
		try? load()
	}
}

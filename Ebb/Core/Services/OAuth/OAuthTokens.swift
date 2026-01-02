import Foundation

struct OAuthTokens: Codable, Sendable {
	let accessToken: String
	let refreshToken: String?
	let expiresAt: Date
	let tokenType: String
	let userEmail: String?

	var isExpired: Bool {
		Date() >= expiresAt
	}

	var isExpiringSoon: Bool {
		Date().addingTimeInterval(300) >= expiresAt  // 5 minute buffer
	}

	func withUserEmail(_ email: String) -> OAuthTokens {
		OAuthTokens(
			accessToken: accessToken,
			refreshToken: refreshToken,
			expiresAt: expiresAt,
			tokenType: tokenType,
			userEmail: email
		)
	}
}

struct TokenResponse: Decodable, Sendable {
	let access_token: String
	let refresh_token: String?
	let expires_in: Int
	let token_type: String

	func toTokens(
		preservingRefreshToken existingRefreshToken: String? = nil,
		preservingUserEmail existingUserEmail: String? = nil
	) -> OAuthTokens {
		OAuthTokens(
			accessToken: access_token,
			refreshToken: refresh_token ?? existingRefreshToken,
			expiresAt: Date().addingTimeInterval(TimeInterval(expires_in)),
			tokenType: token_type,
			userEmail: existingUserEmail
		)
	}
}

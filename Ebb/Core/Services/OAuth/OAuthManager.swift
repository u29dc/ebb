import AppKit
import Combine
import Foundation

@MainActor
final class OAuthManager: ObservableObject {
	enum OAuthError: Error, LocalizedError {
		case configurationMissing
		case authorizationFailed(String)
		case tokenExchangeFailed(String)
		case refreshFailed(String)
		case cancelled
		case noRefreshToken
		case browserOpenFailed

		var errorDescription: String? {
			switch self {
			case .configurationMissing:
				return "OAuth client ID not configured"
			case .authorizationFailed(let reason):
				return "Authorization failed: \(reason)"
			case .tokenExchangeFailed(let reason):
				return "Token exchange failed: \(reason)"
			case .refreshFailed(let reason):
				return "Token refresh failed: \(reason)"
			case .cancelled:
				return "Authentication was cancelled"
			case .noRefreshToken:
				return "No refresh token available. Please sign in again."
			case .browserOpenFailed:
				return "Failed to open browser for authentication"
			}
		}
	}

	private let keychain = KeychainManager()
	private let loopbackServer = LoopbackServer()
	private var currentPKCE: PKCE?

	@Published private(set) var tokens: OAuthTokens?
	@Published private(set) var userEmail: String?

	init() {
		loadStoredTokens()
	}

	/// Perform network request off main actor to avoid Sendable warnings
	private nonisolated func fetchData(for request: URLRequest) async throws -> (Data, URLResponse)
	{
		try await URLSession.shared.data(for: request)
	}

	private func loadStoredTokens() {
		do {
			tokens = try keychain.load()
			userEmail = tokens?.userEmail
		} catch {
			tokens = nil
		}
	}

	var isAuthenticated: Bool {
		tokens != nil
	}

	func startAuthentication() async throws {
		guard !OAuthConfiguration.clientId.isEmpty else {
			throw OAuthError.configurationMissing
		}

		// Start loopback server to receive callback
		_ = try await loopbackServer.start()
		let redirectURI = await loopbackServer.redirectURI

		// Generate PKCE
		let pkce = PKCE.generate()
		currentPKCE = pkce

		// Build authorization URL
		var components = URLComponents(
			url: OAuthConfiguration.authorizationEndpoint, resolvingAgainstBaseURL: false)!
		components.queryItems = [
			URLQueryItem(name: "client_id", value: OAuthConfiguration.clientId),
			URLQueryItem(name: "redirect_uri", value: redirectURI),
			URLQueryItem(name: "response_type", value: "code"),
			URLQueryItem(name: "scope", value: OAuthConfiguration.scopeString),
			URLQueryItem(name: "code_challenge", value: pkce.challenge),
			URLQueryItem(name: "code_challenge_method", value: "S256"),
			URLQueryItem(name: "access_type", value: "offline"),
			URLQueryItem(name: "prompt", value: "consent"),
		]

		guard let authURL = components.url else {
			await loopbackServer.stop()
			throw OAuthError.authorizationFailed("Invalid authorization URL")
		}

		// Open browser for authentication
		let opened = NSWorkspace.shared.open(authURL)
		guard opened else {
			await loopbackServer.stop()
			throw OAuthError.browserOpenFailed
		}

		// Wait for callback with authorization code
		let code: String
		do {
			code = try await loopbackServer.waitForCallback()
		} catch {
			await loopbackServer.stop()
			throw error
		}

		// Exchange code for tokens
		try await exchangeCodeForTokens(code: code, redirectURI: redirectURI)

		// Fetch user info
		try await fetchUserInfo()
	}

	private func exchangeCodeForTokens(code: String, redirectURI: String) async throws {
		guard let pkce = currentPKCE else {
			throw OAuthError.tokenExchangeFailed("PKCE verifier missing")
		}

		var request = URLRequest(url: OAuthConfiguration.tokenEndpoint)
		request.httpMethod = "POST"
		request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

		let params = [
			"client_id": OAuthConfiguration.clientId,
			"client_secret": OAuthConfiguration.clientSecret,
			"code": code,
			"code_verifier": pkce.verifier,
			"grant_type": "authorization_code",
			"redirect_uri": redirectURI,
		]

		request.httpBody =
			params
			.map { key, value in
				let encodedValue =
					value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
				return "\(key)=\(encodedValue)"
			}
			.joined(separator: "&")
			.data(using: .utf8)

		let (data, response) = try await fetchData(for: request)

		guard let httpResponse = response as? HTTPURLResponse else {
			throw OAuthError.tokenExchangeFailed("Invalid response")
		}

		guard (200...299).contains(httpResponse.statusCode) else {
			let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
			throw OAuthError.tokenExchangeFailed("HTTP \(httpResponse.statusCode): \(errorBody)")
		}

		let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
		let newTokens = tokenResponse.toTokens()

		try keychain.save(newTokens)
		self.tokens = newTokens
		currentPKCE = nil
	}

	func refreshAccessToken() async throws {
		guard let currentTokens = tokens, let refreshToken = currentTokens.refreshToken else {
			throw OAuthError.noRefreshToken
		}

		var request = URLRequest(url: OAuthConfiguration.tokenEndpoint)
		request.httpMethod = "POST"
		request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

		let params = [
			"client_id": OAuthConfiguration.clientId,
			"client_secret": OAuthConfiguration.clientSecret,
			"refresh_token": refreshToken,
			"grant_type": "refresh_token",
		]

		request.httpBody =
			params
			.map { key, value in
				let encodedValue =
					value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
				return "\(key)=\(encodedValue)"
			}
			.joined(separator: "&")
			.data(using: .utf8)

		let (data, response) = try await fetchData(for: request)

		guard let httpResponse = response as? HTTPURLResponse else {
			throw OAuthError.refreshFailed("Invalid response")
		}

		guard (200...299).contains(httpResponse.statusCode) else {
			let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
			// If refresh fails with 400/401, the refresh token is likely invalid
			if httpResponse.statusCode == 400 || httpResponse.statusCode == 401 {
				throw OAuthError.noRefreshToken
			}
			throw OAuthError.refreshFailed("HTTP \(httpResponse.statusCode): \(errorBody)")
		}

		let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
		let newTokens = tokenResponse.toTokens(
			preservingRefreshToken: refreshToken,
			preservingUserEmail: currentTokens.userEmail
		)

		try keychain.save(newTokens)
		self.tokens = newTokens
	}

	func validAccessToken() async throws -> String {
		guard let currentTokens = tokens else {
			throw OAuthError.configurationMissing
		}

		// Proactively refresh if expiring soon
		if currentTokens.isExpiringSoon {
			try await refreshAccessToken()
		}

		guard let refreshedTokens = tokens else {
			throw OAuthError.refreshFailed("No tokens after refresh")
		}

		return refreshedTokens.accessToken
	}

	private func fetchUserInfo() async throws {
		guard let token = tokens?.accessToken else { return }

		var request = URLRequest(url: OAuthConfiguration.userInfoEndpoint)
		request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

		let (data, response) = try await fetchData(for: request)

		guard let httpResponse = response as? HTTPURLResponse,
			(200...299).contains(httpResponse.statusCode)
		else {
			// Non-fatal: we can proceed without email
			return
		}

		struct UserInfo: Decodable {
			let email: String
		}

		if let userInfo = try? JSONDecoder().decode(UserInfo.self, from: data) {
			self.userEmail = userInfo.email
			// Persist email with tokens for app restart
			if let currentTokens = self.tokens {
				let updatedTokens = currentTokens.withUserEmail(userInfo.email)
				try? keychain.save(updatedTokens)
				self.tokens = updatedTokens
			}
		}
	}

	func signOut() {
		do {
			try keychain.delete()
		} catch {
			// Log but don't block sign out
		}
		tokens = nil
		userEmail = nil
	}
}

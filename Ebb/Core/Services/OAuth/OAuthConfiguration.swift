import Foundation

enum OAuthConfiguration {
	static let clientId = OAuthSecrets.clientId
	static let clientSecret = OAuthSecrets.clientSecret

	static let authorizationEndpoint = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
	static let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!
	static let userInfoEndpoint = URL(string: "https://www.googleapis.com/oauth2/v2/userinfo")!

	static let scopes = [
		"https://www.googleapis.com/auth/gmail.readonly",
		"https://www.googleapis.com/auth/gmail.send",
		"https://www.googleapis.com/auth/gmail.modify",
	]

	static var scopeString: String {
		scopes.joined(separator: " ")
	}
}

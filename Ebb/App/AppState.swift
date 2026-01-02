import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
	enum AuthState: Equatable {
		case signedOut
		case authenticating
		case signedIn
	}

	@Published var isFullscreen: Bool = false
	@Published var authState: AuthState = .signedOut
	@Published var ownerEmailAddress: String = ""
	@Published var errorMessage: String?

	private let oauthManager = OAuthManager()

	init() {}

	/// Called on app launch to restore session from keychain
	func bootstrap() {
		if oauthManager.isAuthenticated {
			authState = .signedIn
			ownerEmailAddress = oauthManager.userEmail ?? ""
		} else {
			authState = .signedOut
		}
	}

	func startLogin() {
		guard authState != .authenticating else { return }

		authState = .authenticating
		errorMessage = nil

		Task {
			do {
				try await oauthManager.startAuthentication()
				authState = .signedIn
				ownerEmailAddress = oauthManager.userEmail ?? ""
			} catch {
				authState = .signedOut
				errorMessage = error.localizedDescription
			}
		}
	}

	func signOut() {
		oauthManager.signOut()
		authState = .signedOut
		ownerEmailAddress = ""
		errorMessage = nil
	}
}

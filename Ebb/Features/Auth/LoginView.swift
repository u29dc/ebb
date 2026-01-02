import SwiftUI

struct LoginView: View {
	@EnvironmentObject var appState: AppState

	var body: some View {
		VStack(spacing: DesignTokens.Spacing.lg) {
			Spacer()

			if appState.authState == .authenticating {
				ProgressView()
					.scaleEffect(0.8)
				Text("Signing in...")
					.font(.subheadline)
					.foregroundColor(.secondary)
			} else {
				Button("Sign in with Gmail") {
					appState.startLogin()
				}
				.buttonStyle(.borderedProminent)
				.controlSize(.large)
			}

			if let error = appState.errorMessage {
				Text(error)
					.font(.caption)
					.foregroundColor(.red)
					.multilineTextAlignment(.center)
					.padding(.horizontal, DesignTokens.Spacing.lg)
			}

			Spacer()
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}
}

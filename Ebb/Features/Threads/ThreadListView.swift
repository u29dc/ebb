import SwiftUI

struct ThreadListView: View {
	@EnvironmentObject var appState: AppState

	var body: some View {
		Group {
			if appState.isRefreshing && appState.threads.isEmpty {
				loadingView
			} else if appState.threads.isEmpty {
				emptyView
			} else {
				threadList
			}
		}
	}

	private var loadingView: some View {
		VStack(spacing: DesignTokens.Spacing.sm) {
			ProgressView()
				.scaleEffect(0.8)
			Text("Loading...")
				.font(.caption)
				.foregroundColor(.secondary)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}

	private var emptyView: some View {
		VStack(spacing: DesignTokens.Spacing.md) {
			Text("No emails yet")
				.font(.headline)
				.foregroundColor(.secondary)
			Text("Use Cmd+Shift+F to fetch emails")
				.font(.caption)
				.foregroundColor(.secondary)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}

	private var threadList: some View {
		ScrollView {
			LazyVStack(spacing: 0) {
				ForEach(appState.threads) { thread in
					ThreadRowView(thread: thread)
						.padding(.horizontal, 8)

					if thread.id != appState.threads.last?.id {
						Divider()
							.padding(.leading, 8)
					}
				}
			}
			.padding(.vertical, DesignTokens.Spacing.xs)
		}
		.overlay(alignment: .top) {
			if appState.isRefreshing {
				HStack(spacing: DesignTokens.Spacing.xs) {
					ProgressView()
						.scaleEffect(0.7)
					Text("Refreshing...")
						.font(.caption)
						.foregroundColor(.secondary)
				}
				.padding(.vertical, DesignTokens.Spacing.xs)
				.padding(.horizontal, DesignTokens.Spacing.sm)
				.background(.regularMaterial, in: Capsule())
				.padding(.top, DesignTokens.Spacing.xs)
			}
		}
	}
}

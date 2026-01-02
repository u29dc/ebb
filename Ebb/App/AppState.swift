import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
	@Published var isFullscreen: Bool = false
}

import SwiftUI

struct SettingsView: View {
	@AppStorage("aiProvider") private var aiProvider: String = AIProvider.openRouter.rawValue
	@AppStorage("aiModel") private var aiModel: String = AIModel.gpt5Nano.rawValue
	@State private var apiKey: String = ""
	@State private var showingKey: Bool = false
	@State private var saveTask: Task<Void, Never>?

	private let keyManager = AIKeyManager()
	private let debounceInterval: UInt64 = 500_000_000  // 500ms in nanoseconds

	var body: some View {
		Form {
			Section("AI Content Formatting") {
				Picker("Provider", selection: $aiProvider) {
					Text("OpenRouter").tag(AIProvider.openRouter.rawValue)
					Text("None (Plain Text Only)").tag(AIProvider.none.rawValue)
				}
				.pickerStyle(.radioGroup)

				if aiProvider == AIProvider.openRouter.rawValue {
					HStack {
						if showingKey {
							TextField("API Key", text: $apiKey)
								.textFieldStyle(.roundedBorder)
						} else {
							SecureField("API Key", text: $apiKey)
								.textFieldStyle(.roundedBorder)
						}
						Button(action: { showingKey.toggle() }) {
							Image(systemName: showingKey ? "eye.slash" : "eye")
						}
						.buttonStyle(.borderless)
					}
					.onChange(of: apiKey) { _, newValue in
						debounceSaveApiKey(newValue)
					}
					.onSubmit {
						saveApiKeyImmediately(apiKey)
					}

					Picker("Model", selection: $aiModel) {
						ForEach(AIModel.allCases, id: \.rawValue) { model in
							VStack(alignment: .leading) {
								Text(model.displayName)
								Text(model.description)
									.font(.caption)
									.foregroundStyle(.secondary)
							}
							.tag(model.rawValue)
						}
					}

					Link(
						"Get API key at openrouter.ai",
						destination: URL(string: "https://openrouter.ai/keys")!
					)
					.font(.caption)
				}
			}
		}
		.formStyle(.grouped)
		.frame(width: 450, height: 300)
		.padding()
		.onAppear {
			loadApiKey()
		}
		.onDisappear {
			saveTask?.cancel()
			saveApiKeyImmediately(apiKey)
		}
	}

	private func loadApiKey() {
		apiKey = keyManager.loadOrNil() ?? ""
	}

	private func debounceSaveApiKey(_ key: String) {
		saveTask?.cancel()
		saveTask = Task {
			try? await Task.sleep(nanoseconds: debounceInterval)
			guard !Task.isCancelled else { return }
			saveApiKeyImmediately(key)
		}
	}

	private func saveApiKeyImmediately(_ key: String) {
		saveTask?.cancel()
		if key.isEmpty {
			try? keyManager.delete()
		} else {
			try? keyManager.save(key)
		}
	}
}

#Preview {
	SettingsView()
}

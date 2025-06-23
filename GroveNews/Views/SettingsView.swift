import SwiftUI

struct SettingsView: View {
    @AppStorage("anthropicAPIKey") private var anthropicAPIKey = ""
    @AppStorage("speechifyAPIKey") private var speechifyAPIKey = ""
    @FocusState private var isAnthropicAPIKeyFocused: Bool
    @FocusState private var isSpeechifyAPIKeyFocused: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("API Keys")) {
                    SecureField("Anthropic API Key", text: $anthropicAPIKey)
                        .textContentType(.password)
                        .focused($isAnthropicAPIKeyFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            isAnthropicAPIKeyFocused = false
                        }
                    
                    SecureField("Speechify API Key", text: $speechifyAPIKey)
                        .textContentType(.password)
                        .focused($isSpeechifyAPIKeyFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            isSpeechifyAPIKeyFocused = false
                        }
                }
                
                Section(footer: Text("API keys are stored securely on your device and used only for podcast generation.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Settings")
        }
    }
}
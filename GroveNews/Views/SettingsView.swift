import SwiftUI

struct SettingsView: View {
    @AppStorage("anthropicAPIKey") private var anthropicAPIKey = ""
    @AppStorage("speechifyAPIKey") private var speechifyAPIKey = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("API Keys")) {
                    SecureField("Anthropic API Key", text: $anthropicAPIKey)
                        .textContentType(.password)
                    
                    SecureField("Speechify API Key", text: $speechifyAPIKey)
                        .textContentType(.password)
                }
                
                Section(footer: Text("API keys are stored securely on your device and used only for podcast generation.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Settings")
        }
    }
}
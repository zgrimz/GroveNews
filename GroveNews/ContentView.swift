import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            ArticleQueueView()
                .tabItem {
                    Image(systemName: "doc.text")
                    Text("Articles")
                }
            
            PodcastsView()
                .tabItem {
                    Image(systemName: "play.circle")
                    Text("Podcasts")
                }
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
        }
    }
}
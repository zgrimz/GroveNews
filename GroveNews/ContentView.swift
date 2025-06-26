import SwiftUI

struct ContentView: View {
    @StateObject private var articleManager = ArticleManager()
    
    var body: some View {
        TabView {
            ArticleQueueView()
                .environmentObject(articleManager)
                .tabItem {
                    Image(systemName: "doc.text")
                    Text("Articles")
                }
            
            PodcastsView()
                .environmentObject(articleManager)
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
import Foundation
import SwiftUI

class ArticleManager: ObservableObject {
    @Published var articles: [Article] = []
    @Published var podcasts: [PodcastEpisode] = []
    
    private let articlesKey = "SavedArticles"
    private let podcastsKey = "SavedPodcasts"
    
    init() {
        loadArticles()
        loadPodcasts()
    }
    
    func addArticle(_ article: Article) {
        guard articles.count < 5 else { return }
        articles.append(article)
        saveArticles()
    }
    
    func removeArticle(_ article: Article) {
        articles.removeAll { $0.id == article.id }
        saveArticles()
    }
    
    func updateArticle(_ article: Article) {
        if let index = articles.firstIndex(where: { $0.id == article.id }) {
            articles[index] = article
            saveArticles()
        }
    }
    
    func clearQueue() {
        articles.removeAll()
        saveArticles()
    }
    
    func addPodcast(_ episode: PodcastEpisode) {
        podcasts.insert(episode, at: 0)
        savePodcasts()
    }
    
    func removePodcast(_ episode: PodcastEpisode) {
        podcasts.removeAll { $0.id == episode.id }
        savePodcasts()
    }
    
    private func saveArticles() {
        if let data = try? JSONEncoder().encode(articles) {
            UserDefaults.standard.set(data, forKey: articlesKey)
        }
    }
    
    private func loadArticles() {
        if let data = UserDefaults.standard.data(forKey: articlesKey),
           let articles = try? JSONDecoder().decode([Article].self, from: data) {
            self.articles = articles
        }
    }
    
    private func savePodcasts() {
        if let data = try? JSONEncoder().encode(podcasts) {
            UserDefaults.standard.set(data, forKey: podcastsKey)
        }
    }
    
    private func loadPodcasts() {
        if let data = UserDefaults.standard.data(forKey: podcastsKey),
           let podcasts = try? JSONDecoder().decode([PodcastEpisode].self, from: data) {
            self.podcasts = podcasts
        }
    }
}
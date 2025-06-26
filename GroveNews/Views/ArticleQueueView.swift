import SwiftUI

struct ArticleQueueView: View {
    @EnvironmentObject private var articleManager: ArticleManager
    @State private var showingAddArticle = false
    @State private var isGenerating = false
    @State private var showingGenerateConfirmation = false
    @State private var generationStatus = ""
    @State private var editingArticle: Article?
    
    var body: some View {
        NavigationView {
            VStack {
                if articleManager.articles.isEmpty {
                    ContentUnavailableView(
                        "No Articles",
                        systemImage: "doc.text",
                        description: Text("Add articles to start creating podcasts")
                    )
                } else {
                    List {
                        ForEach(articleManager.articles) { article in
                            ArticleRowView(article: article, onEdit: {
                                editingArticle = article
                            }, onDelete: {
                                articleManager.removeArticle(article)
                            })
                        }
                        .onDelete(perform: deleteArticles)
                    }
                    
                    Button(action: { showingGenerateConfirmation = true }) {
                        HStack {
                            if isGenerating {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isGenerating ? generationStatus : "Generate Podcast")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(articleManager.articles.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(articleManager.articles.isEmpty || isGenerating)
                    .padding()
                }
            }
            .navigationTitle("Articles")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddArticle = true }) {
                        Image(systemName: "plus")
                    }
                    .disabled(articleManager.articles.count >= 5)
                }
            }
            .sheet(isPresented: $showingAddArticle) {
                AddArticleView { article in
                    articleManager.addArticle(article)
                }
            }
            .sheet(item: $editingArticle) { article in
                EditArticleView(article: article) { updatedArticle in
                    articleManager.updateArticle(updatedArticle)
                }
            }
            .alert(alertTitle, isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .confirmationDialog("Generate Podcast", isPresented: $showingGenerateConfirmation) {
                Button("Generate") {
                    generatePodcast()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will generate a podcast from \(articleManager.articles.count) article\(articleManager.articles.count == 1 ? "" : "s"). This may take a few minutes.")
            }
        }
    }
    
    private func deleteArticles(offsets: IndexSet) {
        for index in offsets {
            articleManager.removeArticle(articleManager.articles[index])
        }
    }
    
    private func generatePodcast() {
        isGenerating = true
        
        Task {
            do {
                let generator = PodcastGenerator()
                
                let episode = try await generator.generatePodcast(from: articleManager.articles) { status in
                    await MainActor.run {
                        generationStatus = status
                    }
                }
                
                await MainActor.run {
                    articleManager.addPodcast(episode)
                    articleManager.clearQueue()
                    isGenerating = false
                    generationStatus = ""
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    generationStatus = ""
                    showAlert(title: "Generation Failed", message: error.localizedDescription)
                }
            }
        }
    }
    
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
}

struct ArticleRowView: View {
    let article: Article
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(article.title)
                .font(.headline)
                .lineLimit(1)
            
            Text(article.preview)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            Text(article.dateAdded, style: .date)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .swipeActions {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Edit") {
                onEdit()
            }
            .tint(.blue)
        }
    }
}
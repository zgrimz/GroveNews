import SwiftUI

struct AddArticleView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var content = ""
    
    let onSave: (Article) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Article Details")) {
                    TextField("Title (optional)", text: $title)
                    
                    TextEditor(text: $content)
                        .frame(minHeight: 200)
                }
                
                Section(footer: Text("Paste your article content here. You can add up to 5 articles to the queue.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Add Article")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add to Queue") {
                        let article = Article(title: title, content: content)
                        onSave(article)
                        dismiss()
                    }
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct EditArticleView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var content: String
    
    let article: Article
    let onSave: (Article) -> Void
    
    init(article: Article, onSave: @escaping (Article) -> Void) {
        self.article = article
        self.onSave = onSave
        self._title = State(initialValue: article.title)
        self._content = State(initialValue: article.content)
        print("EditArticleView init - title: \(article.title), content length: \(article.content.count)")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Article Details")) {
                    TextField("Title", text: $title)
                    
                    TextEditor(text: $content)
                        .frame(minHeight: 200)
                }
            }
            .navigationTitle("Edit Article")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updatedArticle = article
                        updatedArticle.title = title
                        updatedArticle.content = content
                        onSave(updatedArticle)
                        dismiss()
                    }
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            print("EditArticleView appeared - title: \(title), content length: \(content.count)")
        }
    }
}
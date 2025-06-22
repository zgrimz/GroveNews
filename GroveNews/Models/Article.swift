import Foundation

struct Article: Identifiable, Codable {
    let id: UUID
    var title: String
    var content: String
    var dateAdded: Date
    
    init(title: String = "", content: String) {
        self.id = UUID()
        self.title = title.isEmpty ? "Article \(Date().formatted(date: .abbreviated, time: .shortened))" : title
        self.content = content
        self.dateAdded = Date()
    }
    
    var preview: String {
        String(content.prefix(100)) + (content.count > 100 ? "..." : "")
    }
}

struct PodcastEpisode: Identifiable, Codable {
    let id: UUID
    let title: String
    let filename: String
    let dateCreated: Date
    let duration: TimeInterval?
    
    init(title: String, filename: String, duration: TimeInterval? = nil) {
        self.id = UUID()
        self.title = title
        self.filename = filename
        self.dateCreated = Date()
        self.duration = duration
    }
}
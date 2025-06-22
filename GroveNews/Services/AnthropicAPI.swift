import Foundation


struct PodcastScript: Codable {
    let episodeTitle: String
    let intro: String
    let stories: [String: String]
    let outro: String
    
    enum CodingKeys: String, CodingKey {
        case episodeTitle = "episode_title"
        case intro, outro
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        episodeTitle = try container.decode(String.self, forKey: .episodeTitle)
        intro = try container.decode(String.self, forKey: .intro)
        outro = try container.decode(String.self, forKey: .outro)
        
        // Use AnyCodingKey container for dynamic story keys
        let dynamicContainer = try decoder.container(keyedBy: AnyCodingKey.self)
        let allKeys = Set(dynamicContainer.allKeys.map { $0.stringValue })
        let storyKeys = allKeys.filter { $0.hasPrefix("story_") }
        
        var stories: [String: String] = [:]
        for key in storyKeys {
            if let dynamicKey = AnyCodingKey(stringValue: key) {
                stories[key] = try dynamicContainer.decode(String.self, forKey: dynamicKey)
            }
        }
        self.stories = stories
    }
}

private struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

class AnthropicAPI {
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let promptURL = "https://grovehouse.xyz/grovenews/scriptprompt.txt"
    private var cachedPrompt: String?
    private var promptLastFetched: Date?
    private let promptCacheTimeout: TimeInterval = 300 // 5 minutes
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func generatePodcastScript(from articles: [Article]) async throws -> PodcastScript {
        let articlesText = articles.map { $0.content }.joined(separator: "\n\n---\n\n")
        let prompt = try await createPrompt(with: articlesText)
        
        let request = AnthropicRequest(
            model: "claude-3-5-sonnet-20241022",
            maxTokens: 8192,
            temperature: 0.7,
            messages: [
                AnthropicMessage(role: "user", content: prompt)
            ]
        )
        
        let response = try await performRequest(request)
        
        guard let content = response.content.first?.text else {
            throw AnthropicError.invalidResponse
        }
        
        let cleanedContent = cleanJSONResponse(content)
        
        guard let data = cleanedContent.data(using: .utf8) else {
            throw AnthropicError.invalidResponse
        }
        
        do {
            return try JSONDecoder().decode(PodcastScript.self, from: data)
        } catch {
            throw AnthropicError.decodingFailed(error)
        }
    }
    
    private func createPrompt(with articlesText: String) async throws -> String {
        let baseTemplate = try await fetchPromptTemplate()
        return baseTemplate.replacingOccurrences(of: "{{ARTICLES}}", with: articlesText)
    }
    
    private func fetchPromptTemplate() async throws -> String {
        // Check if we have a valid cached prompt
        if let cached = cachedPrompt,
           let lastFetched = promptLastFetched,
           Date().timeIntervalSince(lastFetched) < promptCacheTimeout {
            return cached
        }
        
        // Fetch new prompt from URL
        guard let url = URL(string: promptURL) else {
            throw AnthropicError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw AnthropicError.promptFetchFailed
            }
            
            guard let promptText = String(data: data, encoding: .utf8) else {
                throw AnthropicError.invalidPromptData
            }
            
            // Cache the prompt
            self.cachedPrompt = promptText
            self.promptLastFetched = Date()
            
            return promptText
        } catch {
            throw AnthropicError.promptFetchError(error)
        }
    }
    
    
    private func cleanJSONResponse(_ response: String) -> String {
        var cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        }
        
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func performRequest(_ request: AnthropicRequest) async throws -> AnthropicResponse {
        guard let url = URL(string: baseURL) else {
            throw AnthropicError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            throw AnthropicError.encodingFailed(error)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AnthropicError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                // Log the error response for debugging
                if let errorString = String(data: data, encoding: .utf8) {
                    print("API Error Response: \(errorString)")
                }
                throw AnthropicError.httpError(httpResponse.statusCode)
            }
            
            return try JSONDecoder().decode(AnthropicResponse.self, from: data)
        } catch let error as AnthropicError {
            throw error
        } catch {
            throw AnthropicError.networkError(error)
        }
    }
}

private struct AnthropicRequest: Codable {
    let model: String
    let maxTokens: Int
    let temperature: Double
    let messages: [AnthropicMessage]
    
    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case temperature
        case messages
    }
}

private struct AnthropicMessage: Codable {
    let role: String
    let content: String
}

private struct AnthropicResponse: Codable {
    let id: String
    let type: String
    let role: String
    let content: [AnthropicContent]
    let model: String
    let stopReason: String?
    let stopSequence: String?
    let usage: AnthropicUsage
    
    enum CodingKeys: String, CodingKey {
        case id, type, role, content, model
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
        case usage
    }
}

private struct AnthropicContent: Codable {
    let type: String
    let text: String
}

private struct AnthropicUsage: Codable {
    let inputTokens: Int
    let outputTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

enum AnthropicError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case networkError(Error)
    case encodingFailed(Error)
    case decodingFailed(Error)
    case promptFetchFailed
    case invalidPromptData
    case promptFetchError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from API"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .encodingFailed(let error):
            return "Encoding failed: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Decoding failed: \(error.localizedDescription)"
        case .promptFetchFailed:
            return "Failed to fetch prompt from server"
        case .invalidPromptData:
            return "Invalid prompt data received"
        case .promptFetchError(let error):
            return "Prompt fetch error: \(error.localizedDescription)"
        }
    }
}
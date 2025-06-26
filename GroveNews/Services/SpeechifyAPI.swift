import Foundation
import AVFoundation

class SpeechifyAPI {
    private let apiKey: String
    private let baseURL = "https://api.sws.speechify.com/v1/audio/speech"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func generateAudio(for sections: [(String, String)]) async throws -> [URL] {
        var audioFiles: [URL] = []
        
        for (index, section) in sections.enumerated() {
            let (sectionName, text) = section
            
            let chunks = splitTextIntoChunks(text, maxChars: 2000)
            var sectionAudioFiles: [URL] = []
            
            for (chunkIndex, chunk) in chunks.enumerated() {
                let audioURL = try await generateAudioChunk(
                    text: chunk,
                    filename: "\(sectionName)_\(index)_\(chunkIndex)"
                )
                sectionAudioFiles.append(audioURL)
                
                try await Task.sleep(nanoseconds: 1_500_000_000)
            }
            
            if sectionAudioFiles.count > 1 {
                let combinedURL = try await combineAudioFiles(sectionAudioFiles, outputName: "\(sectionName)_\(index)_combined")
                audioFiles.append(combinedURL)
                
                for url in sectionAudioFiles {
                    try? FileManager.default.removeItem(at: url)
                }
            } else if let singleFile = sectionAudioFiles.first {
                audioFiles.append(singleFile)
            }
        }
        
        return audioFiles
    }
    
    private func generateAudioChunk(text: String, filename: String) async throws -> URL {
        let request = SpeechifyRequest(
            input: text,
            voiceId: "kristy",
            model: "simba-english",
            emotion: "assertive",
            pitch: 0,
            speed: 1.0,
            textNormalization: true,
            audioFormat: "mp3"
        )
        
        guard let url = URL(string: baseURL) else {
            throw SpeechifyError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            throw SpeechifyError.encodingFailed(error)
        }
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpeechifyError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw SpeechifyError.httpError(httpResponse.statusCode)
        }
        
        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""
        
        let audioData: Data
        if contentType.contains("application/json") {
            let speechifyResponse = try JSONDecoder().decode(SpeechifyResponse.self, from: data)
            guard let audioBase64 = speechifyResponse.audioData,
                  let decodedData = Data(base64Encoded: audioBase64) else {
                throw SpeechifyError.invalidAudioData
            }
            audioData = decodedData
        } else if contentType.contains("audio/") {
            audioData = data
        } else {
            throw SpeechifyError.invalidResponse
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let audioURL = tempDir.appendingPathComponent("\(filename).mp3")
        
        try audioData.write(to: audioURL)
        return audioURL
    }
    
    private func splitTextIntoChunks(_ text: String, maxChars: Int) -> [String] {
        if text.count <= maxChars {
            return [text]
        }
        
        var chunks: [String] = []
        var start = 0
        
        while start < text.count {
            var end = min(start + maxChars, text.count)
            
            if end < text.count {
                let substring = String(text[text.index(text.startIndex, offsetBy: start)..<text.index(text.startIndex, offsetBy: end)])
                if let periodIndex = substring.lastIndex(of: ".") {
                    end = start + text.distance(from: text.startIndex, to: periodIndex) + 1
                }
            }
            
            let chunk = String(text[text.index(text.startIndex, offsetBy: start)..<text.index(text.startIndex, offsetBy: end)])
            chunks.append(chunk)
            start = end
        }
        
        return chunks
    }
    
    private func combineAudioFiles(_ audioFiles: [URL], outputName: String) async throws -> URL {
        let composition = AVMutableComposition()
        
        guard let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: CMPersistentTrackID(kCMPersistentTrackID_Invalid)
        ) else {
            throw SpeechifyError.audioProcessingFailed
        }
        
        var currentTime = CMTime.zero
        
        for audioURL in audioFiles {
            let asset = AVURLAsset(url: audioURL)
            
            do {
                let duration = try await asset.load(.duration)
                let audioAssetTrack = try await asset.loadTracks(withMediaType: .audio).first
                
                guard let track = audioAssetTrack else { continue }
                
                let timeRange = CMTimeRange(start: .zero, duration: duration)
                try audioTrack.insertTimeRange(timeRange, of: track, at: currentTime)
                currentTime = CMTimeAdd(currentTime, duration)
            } catch {
                continue
            }
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent("\(outputName).mp3")
        
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw SpeechifyError.audioProcessingFailed
        }
        
        exportSession.outputURL = outputURL.appendingPathExtension("m4a")
        exportSession.outputFileType = .m4a
        
        let finalOutputURL = outputURL.appendingPathExtension("m4a")
        do {
            try await exportSession.export(to: finalOutputURL, as: .m4a)
            return finalOutputURL
        } catch {
            throw SpeechifyError.audioProcessingFailed
        }
    }
}

private struct SpeechifyRequest: Codable {
    let input: String
    let voiceId: String
    let model: String
    let emotion: String
    let pitch: Int
    let speed: Double
    let textNormalization: Bool
    let audioFormat: String
    
    enum CodingKeys: String, CodingKey {
        case input
        case voiceId = "voice_id"
        case model
        case emotion
        case pitch
        case speed
        case textNormalization = "text_normalization"
        case audioFormat = "audio_format"
    }
}

private struct SpeechifyResponse: Codable {
    let audioData: String?
    
    enum CodingKeys: String, CodingKey {
        case audioData = "audio_data"
    }
}

enum SpeechifyError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidAudioData
    case httpError(Int)
    case networkError(Error)
    case encodingFailed(Error)
    case audioProcessingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from API"
        case .invalidAudioData:
            return "Invalid audio data received"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .encodingFailed(let error):
            return "Encoding failed: \(error.localizedDescription)"
        case .audioProcessingFailed:
            return "Audio processing failed"
        }
    }
}
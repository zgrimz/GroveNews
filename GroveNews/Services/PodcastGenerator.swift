import Foundation
import AVFoundation
import SwiftUI

class PodcastGenerator {
    @AppStorage("anthropicAPIKey") private var anthropicAPIKey = ""
    @AppStorage("speechifyAPIKey") private var speechifyAPIKey = ""
    
    func generatePodcast(from articles: [Article], statusUpdate: @escaping (String) async -> Void = { _ in }) async throws -> PodcastEpisode {
        guard !anthropicAPIKey.isEmpty else {
            throw PodcastGenerationError.missingAnthropicKey
        }
        
        guard !speechifyAPIKey.isEmpty else {
            throw PodcastGenerationError.missingSpeechifyKey
        }
        
        let anthropicAPI = AnthropicAPI(apiKey: anthropicAPIKey)
        let speechifyAPI = SpeechifyAPI(apiKey: speechifyAPIKey)
        
        await statusUpdate("Generating Script")
        let script = try await anthropicAPI.generatePodcastScript(from: articles)
        
        await statusUpdate("Generating Podcast")
        let sections = buildSections(from: script)
        
        let audioFiles = try await speechifyAPI.generateAudio(for: sections)
        
        let finalAudioURL = try await combineAudioFiles(audioFiles)
        
        for audioFile in audioFiles {
            try? FileManager.default.removeItem(at: audioFile)
        }
        
        let finalURL = try await moveToDocuments(from: finalAudioURL, title: script.episodeTitle)
        
        let duration = try await getAudioDuration(url: finalURL)
        
        return PodcastEpisode(
            title: script.episodeTitle,
            filename: finalURL.lastPathComponent,
            duration: duration
        )
    }
    
    private func buildSections(from script: PodcastScript) -> [(String, String)] {
        var sections: [(String, String)] = []
        
        sections.append(("intro", script.intro))
        
        let sortedStories = script.stories.sorted { $0.key < $1.key }
        for (key, content) in sortedStories {
            sections.append((key, content))
        }
        
        sections.append(("outro", script.outro))
        
        return sections
    }
    
    private func combineAudioFiles(_ audioFiles: [URL]) async throws -> URL {
        let composition = AVMutableComposition()
        
        guard let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: CMPersistentTrackID(kCMPersistentTrackID_Invalid)
        ) else {
            throw PodcastGenerationError.audioProcessingFailed
        }
        
        var currentTime = CMTime.zero
        
        for audioURL in audioFiles {
            let asset = AVURLAsset(url: audioURL)
            
            do {
                let duration = try await asset.load(.duration)
                let audioAssetTracks = try await asset.loadTracks(withMediaType: .audio)
                
                guard let track = audioAssetTracks.first else { continue }
                
                let timeRange = CMTimeRange(start: .zero, duration: duration)
                try audioTrack.insertTimeRange(timeRange, of: track, at: currentTime)
                currentTime = CMTimeAdd(currentTime, duration)
            } catch {
                continue
            }
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent("combined_podcast.m4a")
        
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw PodcastGenerationError.audioProcessingFailed
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        
        do {
            try await exportSession.export(to: outputURL, as: .m4a)
            return outputURL
        } catch {
            throw PodcastGenerationError.audioProcessingFailed
        }
    }
    
    private func moveToDocuments(from tempURL: URL, title: String) async throws -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let podcastsURL = documentsURL.appendingPathComponent("Podcasts")
        
        try FileManager.default.createDirectory(at: podcastsURL, withIntermediateDirectories: true)
        
        let sanitizedTitle = title.replacingOccurrences(of: "[^a-zA-Z0-9\\s_-]", with: "", options: .regularExpression)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        
        let filename = "\(dateString) \(sanitizedTitle).m4a"
        let finalURL = podcastsURL.appendingPathComponent(filename)
        
        if FileManager.default.fileExists(atPath: finalURL.path) {
            try FileManager.default.removeItem(at: finalURL)
        }
        
        try FileManager.default.moveItem(at: tempURL, to: finalURL)
        
        return finalURL
    }
    
    private func getAudioDuration(url: URL) async throws -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    }
}

enum PodcastGenerationError: Error, LocalizedError {
    case missingAnthropicKey
    case missingSpeechifyKey
    case audioProcessingFailed
    
    var errorDescription: String? {
        switch self {
        case .missingAnthropicKey:
            return "Anthropic API key is missing. Please add it in Settings."
        case .missingSpeechifyKey:
            return "Speechify API key is missing. Please add it in Settings."
        case .audioProcessingFailed:
            return "Failed to process audio files."
        }
    }
}
import SwiftUI

struct PodcastsView: View {
    @StateObject private var articleManager = ArticleManager()
    @StateObject private var audioPlayer = AudioPlayerManager()
    @State private var showingShareSheet = false
    @State private var shareURL: URL?
    
    var body: some View {
        NavigationView {
            VStack {
                if articleManager.podcasts.isEmpty {
                    ContentUnavailableView(
                        "No Podcasts",
                        systemImage: "play.circle",
                        description: Text("Generate your first podcast from articles")
                    )
                } else {
                    List {
                        ForEach(articleManager.podcasts) { episode in
                            PodcastRowView(
                                episode: episode,
                                isCurrentlyPlaying: audioPlayer.currentEpisode?.id == episode.id,
                                isPlaying: audioPlayer.isPlaying,
                                onPlay: { audioPlayer.play(episode: episode) },
                                onPause: { audioPlayer.pause() },
                                onDelete: { articleManager.removePodcast(episode) },
                                onShare: { shareEpisode(episode) }
                            )
                        }
                    }
                    
                    if audioPlayer.currentEpisode != nil {
                        AudioPlayerControlsView(audioPlayer: audioPlayer)
                            .padding()
                            .background(.background)
                            .shadow(radius: 5)
                    }
                }
            }
            .navigationTitle("Podcasts")
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = shareURL {
                ShareSheet(activityItems: [url])
            }
        }
    }
    
    private func shareEpisode(_ episode: PodcastEpisode) {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let podcastsURL = documentsURL.appendingPathComponent("Podcasts")
        let audioURL = podcastsURL.appendingPathComponent(episode.filename)
        
        shareURL = audioURL
        showingShareSheet = true
    }
}

struct PodcastRowView: View {
    let episode: PodcastEpisode
    let isCurrentlyPlaying: Bool
    let isPlaying: Bool
    let onPlay: () -> Void
    let onPause: () -> Void
    let onDelete: () -> Void
    let onShare: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(episode.title)
                .font(.headline)
                .lineLimit(2)
            
            HStack {
                Text(episode.dateCreated, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let duration = episode.duration {
                    Text("• \(formatDuration(duration))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if isCurrentlyPlaying && isPlaying {
                    Text("• Playing")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isCurrentlyPlaying && isPlaying {
                onPause()
            } else {
                onPlay()
            }
        }
        .swipeActions {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Share") {
                onShare()
            }
            .tint(.blue)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct AudioPlayerControlsView: View {
    @ObservedObject var audioPlayer: AudioPlayerManager
    @State private var showingSpeedPicker = false
    
    var body: some View {
        VStack(spacing: 12) {
            if let episode = audioPlayer.currentEpisode {
                Text(episode.title)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            
            HStack {
                Text(audioPlayer.formattedCurrentTime)
                    .font(.caption)
                    .monospacedDigit()
                
                Slider(
                    value: Binding(
                        get: { audioPlayer.currentTime },
                        set: { audioPlayer.seek(to: $0) }
                    ),
                    in: 0...audioPlayer.duration
                )
                
                Text(audioPlayer.formattedDuration)
                    .font(.caption)
                    .monospacedDigit()
            }
            
            HStack(spacing: 20) {
                Button(action: {
                    audioPlayer.skipBackward()
                }) {
                    Image(systemName: "gobackward.15")
                        .font(.title2)
                }
                
                Button(action: {
                    if audioPlayer.isPlaying {
                        audioPlayer.pause()
                    } else {
                        audioPlayer.resume()
                    }
                }) {
                    Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.largeTitle)
                }
                
                Button(action: {
                    audioPlayer.skipForward()
                }) {
                    Image(systemName: "goforward.15")
                        .font(.title2)
                }
            }
            .foregroundColor(.blue)
            
            HStack {
                Spacer()
                
                Button(action: {
                    showingSpeedPicker.toggle()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                        Text("\(String(format: "%.1f", audioPlayer.playbackRate))x")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .popover(isPresented: $showingSpeedPicker, arrowEdge: .bottom) {
                    PlaybackSpeedPicker(audioPlayer: audioPlayer)
                        .presentationCompactAdaptation(.popover)
                }
            }
        }
    }
}

struct PlaybackSpeedPicker: View {
    @ObservedObject var audioPlayer: AudioPlayerManager
    
    private let speeds: [Float] = Array(stride(from: 0.5, through: 3.0, by: 0.1)).map { Float($0) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Playback Speed")
                .font(.headline)
                .padding()
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(speeds, id: \.self) { speed in
                        Button(action: {
                            audioPlayer.setPlaybackRate(speed)
                        }) {
                            HStack {
                                Text("\(String(format: "%.1f", speed))x")
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if abs(audioPlayer.playbackRate - speed) < 0.01 {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if speed != speeds.last {
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(width: 200, height: 300)
    }
}

#if os(iOS)
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        return UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#else
struct ShareSheet: View {
    let activityItems: [Any]
    
    var body: some View {
        VStack {
            Text("Sharing not available on macOS")
                .padding()
        }
    }
}
#endif
import SwiftUI

struct MiniAudioPlayerView: View {
    @ObservedObject var player: AudiobookPlayer = .shared
    @State private var showFullPlayer = false

    var body: some View {
        if player.state.isActive, let audiobook = player.currentAudiobook {
            VStack(spacing: 0) {
                // Progress bar at top
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * (player.duration > 0 ? player.currentPosition / player.duration : 0), height: 2)
                }
                .frame(height: 2)

                HStack(spacing: 12) {
                    // Cover image
                    AsyncImage(url: URL(string: audiobook.coverUrl ?? "")) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.2))
                                .overlay {
                                    Image(systemName: "headphones")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                        }
                    }
                    .frame(width: 44, height: 44)
                    .cornerRadius(4)

                    // Title and chapter
                    VStack(alignment: .leading, spacing: 2) {
                        Text(audiobook.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)

                        if let chapter = player.currentChapter {
                            Text(chapter.title)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    // Controls
                    HStack(spacing: 16) {
                        // Skip backward
                        Button {
                            player.seek(by: -15)
                        } label: {
                            Image(systemName: "gobackward.15")
                                .font(.title3)
                                .foregroundColor(.primary)
                        }

                        // Play/Pause
                        Button {
                            player.togglePlayPause()
                        } label: {
                            if player.isBuffering {
                                ProgressView()
                                    .frame(width: 32, height: 32)
                            } else {
                                Image(systemName: player.state.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.title2)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 32, height: 32)
                            }
                        }

                        // Skip forward
                        Button {
                            player.seek(by: 30)
                        } label: {
                            Image(systemName: "goforward.30")
                                .font(.title3)
                                .foregroundColor(.primary)
                        }

                        // Close
                        Button {
                            player.stop()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(
                Material.regular
            )
            .onTapGesture {
                showFullPlayer = true
            }
            .fullScreenCover(isPresented: $showFullPlayer) {
                AudiobookPlayerView(player: player)
            }
        }
    }
}

// MARK: - Compact Mini Player (for Reader)

struct CompactMiniPlayerView: View {
    @ObservedObject var player: AudiobookPlayer = .shared
    @State private var showFullPlayer = false

    var body: some View {
        if player.state.isActive {
            HStack(spacing: 12) {
                // Waveform indicator
                if player.state.isPlaying {
                    Image(systemName: "waveform")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                        .symbolEffect(.variableColor.iterative.reversing)
                } else {
                    Image(systemName: "headphones")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Chapter info
                if let chapter = player.currentChapter {
                    Text(chapter.title)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }

                Spacer()

                // Compact controls
                HStack(spacing: 12) {
                    Button {
                        player.togglePlayPause()
                    } label: {
                        Image(systemName: player.state.isPlaying ? "pause.fill" : "play.fill")
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                    }

                    Button {
                        showFullPlayer = true
                    } label: {
                        Image(systemName: "chevron.up.circle")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(8)
            .fullScreenCover(isPresented: $showFullPlayer) {
                AudiobookPlayerView(player: player)
            }
        }
    }
}

// MARK: - Floating Mini Player

struct FloatingMiniPlayerView: View {
    @ObservedObject var player: AudiobookPlayer = .shared
    @State private var showFullPlayer = false
    @State private var offset: CGSize = .zero
    @State private var isDragging = false

    var body: some View {
        if player.state.isActive, let audiobook = player.currentAudiobook {
            HStack(spacing: 10) {
                // Cover
                AsyncImage(url: URL(string: audiobook.coverUrl ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        Circle()
                            .fill(Color.accentColor.opacity(0.2))
                            .overlay {
                                Image(systemName: "headphones")
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                            }
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                .overlay {
                    // Progress ring
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 3)

                    Circle()
                        .trim(from: 0, to: player.duration > 0 ? player.currentPosition / player.duration : 0)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }

                // Play/Pause button overlay
                Button {
                    player.togglePlayPause()
                } label: {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 50, height: 50)
                        .overlay {
                            if player.isBuffering {
                                ProgressView()
                            } else {
                                Image(systemName: player.state.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.title3)
                                    .foregroundColor(.accentColor)
                            }
                        }
                }
            }
            .padding(4)
            .background(.ultraThinMaterial)
            .cornerRadius(30)
            .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
            .offset(offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        offset = value.translation
                    }
                    .onEnded { value in
                        isDragging = false
                        // Snap to edge
                        withAnimation(.spring()) {
                            offset = .zero
                        }
                    }
            )
            .onTapGesture {
                if !isDragging {
                    showFullPlayer = true
                }
            }
            .fullScreenCover(isPresented: $showFullPlayer) {
                AudiobookPlayerView(player: player)
            }
        }
    }
}

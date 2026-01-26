import SwiftUI

/// Full-screen image viewer with zoom and pan support
struct ImageViewer: View {
    let images: [BookImage]
    @Binding var currentIndex: Int
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @GestureState private var magnifyBy = 1.0

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            // Image content
            TabView(selection: $currentIndex) {
                ForEach(Array(images.enumerated()), id: \.element.id) { index, image in
                    ZoomableImageView(
                        image: image,
                        scale: index == currentIndex ? $scale : .constant(1.0),
                        offset: index == currentIndex ? $offset : .constant(.zero)
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: currentIndex) { _, _ in
                resetZoom()
            }

            // Controls overlay
            VStack {
                // Top bar
                topBar

                Spacer()

                // Bottom bar with page indicator and caption
                bottomBar
            }
        }
        .statusBarHidden(true)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial.opacity(0.5))
                    .clipShape(Circle())
            }

            Spacer()

            HStack(spacing: 16) {
                Button {
                    saveImage()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial.opacity(0.5))
                        .clipShape(Circle())
                }

                Button {
                    shareImage()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial.opacity(0.5))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 12) {
            // Page indicator
            if images.count > 1 {
                HStack(spacing: 16) {
                    Button {
                        if currentIndex > 0 {
                            withAnimation {
                                currentIndex -= 1
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(currentIndex > 0 ? .white : .gray)
                    }
                    .disabled(currentIndex == 0)

                    Text("\(currentIndex + 1) / \(images.count)")
                        .font(.subheadline)
                        .foregroundColor(.white)

                    Button {
                        if currentIndex < images.count - 1 {
                            withAnimation {
                                currentIndex += 1
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.title2)
                            .foregroundColor(currentIndex < images.count - 1 ? .white : .gray)
                    }
                    .disabled(currentIndex == images.count - 1)
                }
            }

            // Caption
            if let caption = images[safe: currentIndex]?.caption, !caption.isEmpty {
                Text(caption)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Actions

    private func resetZoom() {
        withAnimation(.spring()) {
            scale = 1.0
            offset = .zero
        }
    }

    private func saveImage() {
        guard let image = images[safe: currentIndex],
              let url = URL(string: image.src) else { return }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let uiImage = UIImage(data: data) {
                    UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
                }
            } catch {
                print("Failed to save image: \(error)")
            }
        }
    }

    private func shareImage() {
        guard let image = images[safe: currentIndex],
              let url = URL(string: image.src) else { return }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        let activityVC = UIActivityViewController(
                            activityItems: [uiImage],
                            applicationActivities: nil
                        )
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootVC = windowScene.windows.first?.rootViewController {
                            rootVC.present(activityVC, animated: true)
                        }
                    }
                }
            } catch {
                print("Failed to share image: \(error)")
            }
        }
    }
}

// MARK: - Zoomable Image View

private struct ZoomableImageView: View {
    let image: BookImage
    @Binding var scale: CGFloat
    @Binding var offset: CGSize

    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            AsyncImage(url: URL(string: image.src)) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .success(let loadedImage):
                    loadedImage
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(zoomGesture)
                        .gesture(dragGesture(geometry: geometry))
                        .onTapGesture(count: 2) {
                            withAnimation(.spring()) {
                                if scale > 1.0 {
                                    scale = 1.0
                                    offset = .zero
                                } else {
                                    scale = 2.5
                                }
                            }
                        }

                case .failure:
                    VStack(spacing: 12) {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("Failed to load image")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / lastScale
                lastScale = value
                scale = min(max(scale * delta, 1.0), 5.0)
            }
            .onEnded { _ in
                lastScale = 1.0
                if scale < 1.0 {
                    withAnimation(.spring()) {
                        scale = 1.0
                        offset = .zero
                    }
                }
            }
    }

    private func dragGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1.0 else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
                constrainOffset(geometry: geometry)
            }
    }

    private func constrainOffset(geometry: GeometryProxy) {
        let maxX = (geometry.size.width * (scale - 1)) / 2
        let maxY = (geometry.size.height * (scale - 1)) / 2

        withAnimation(.spring()) {
            offset.width = min(max(offset.width, -maxX), maxX)
            offset.height = min(max(offset.height, -maxY), maxY)
        }
        lastOffset = offset
    }
}

// MARK: - Book Image Model

struct BookImage: Identifiable {
    let id: String
    let src: String
    let alt: String?
    let caption: String?
    let chapterId: String
    let orderInChapter: Int
}

// MARK: - Array Safe Subscript

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

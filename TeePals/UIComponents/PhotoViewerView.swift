import SwiftUI

/// Fullscreen photo viewer with swipeable paging through multiple photos.
struct PhotoViewerView: View {
    let photoUrls: [String]
    let initialIndex: Int
    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex: Int

    init(photoUrls: [String], initialIndex: Int = 0) {
        self.photoUrls = photoUrls
        self.initialIndex = min(initialIndex, photoUrls.count - 1)
        _currentIndex = State(initialValue: min(initialIndex, photoUrls.count - 1))
    }

    var body: some View {
        ZStack {
            // Black background
            Color.black.ignoresSafeArea()

            // Photo pager
            TabView(selection: $currentIndex) {
                ForEach(photoUrls.indices, id: \.self) { index in
                    PhotoPage(url: photoUrls[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Overlay controls
            VStack {
                // Top bar with close button and counter
                HStack {
                    Spacer()

                    // Photo counter
                    if photoUrls.count > 1 {
                        Text("\(currentIndex + 1) / \(photoUrls.count)")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(20)
                    }

                    // Close button
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                    }
                    .padding()
                }

                Spacer()

                // Page indicator dots (if multiple photos)
                if photoUrls.count > 1 {
                    HStack(spacing: 8) {
                        ForEach(photoUrls.indices, id: \.self) { index in
                            Circle()
                                .fill(currentIndex == index ? Color.white : Color.white.opacity(0.5))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
        }
    }
}

// MARK: - Photo Page

private struct PhotoPage: View {
    let url: String
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geometry in
            CachedAsyncImage(url: URL(string: url)) { image in
                image
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value
                            }
                            .onEnded { value in
                                lastScale = scale
                                // Reset if zoomed out too far
                                if scale < 1.0 {
                                    withAnimation {
                                        scale = 1.0
                                        lastScale = 1.0
                                    }
                                }
                                // Limit max zoom
                                if scale > 3.0 {
                                    withAnimation {
                                        scale = 3.0
                                        lastScale = 3.0
                                    }
                                }
                            }
                    )
                    .onTapGesture(count: 2) {
                        // Double tap to toggle zoom
                        withAnimation {
                            if scale > 1.0 {
                                scale = 1.0
                                lastScale = 1.0
                            } else {
                                scale = 2.0
                                lastScale = 2.0
                            }
                        }
                    }
            } placeholder: {
                ProgressView()
                    .tint(.white)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    PhotoViewerView(
        photoUrls: [
            "https://picsum.photos/400/600",
            "https://picsum.photos/400/601",
            "https://picsum.photos/400/602"
        ],
        initialIndex: 0
    )
}
#endif

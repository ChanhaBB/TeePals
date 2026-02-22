import SwiftUI
import NukeUI

/// Fullscreen photo viewer with swipeable paging through multiple photos.
/// Supports swipe-down to dismiss gesture.
struct PhotoViewerView: View {
    let photoUrls: [String]
    let initialIndex: Int
    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex: Int
    @State private var dragOffset: CGFloat = 0
    @State private var backgroundOpacity: Double = 1.0

    init(photoUrls: [String], initialIndex: Int = 0) {
        self.photoUrls = photoUrls
        self.initialIndex = min(initialIndex, photoUrls.count - 1)
        _currentIndex = State(initialValue: min(initialIndex, photoUrls.count - 1))
    }

    var body: some View {
        ZStack {
            // Black background with dynamic opacity
            Color.black
                .opacity(backgroundOpacity)
                .ignoresSafeArea()

            // Photo pager
            TabView(selection: $currentIndex) {
                ForEach(photoUrls.indices, id: \.self) { index in
                    PhotoPage(
                        url: photoUrls[index],
                        dragOffset: dragOffset,
                        onDismiss: { dismiss() }
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Only allow downward drag
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                            // Fade background as user drags down
                            let progress = min(value.translation.height / 300, 1.0)
                            backgroundOpacity = 1.0 - progress
                        }
                    }
                    .onEnded { value in
                        // Dismiss if dragged down enough (150pt threshold)
                        if value.translation.height > 150 {
                            dismiss()
                        } else {
                            // Bounce back
                            withAnimation(.spring()) {
                                dragOffset = 0
                                backgroundOpacity = 1.0
                            }
                        }
                    }
            )

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
            .offset(y: dragOffset) // Move overlay with photo
        }
    }
}

// MARK: - Photo Page

private struct PhotoPage: View {
    let url: String
    let dragOffset: CGFloat
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geometry in
            LazyImage(url: URL(string: url)) { state in
                if let image = state.image {
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
                                    if scale < 1.0 {
                                        withAnimation {
                                            scale = 1.0
                                            lastScale = 1.0
                                        }
                                    }
                                    if scale > 3.0 {
                                        withAnimation {
                                            scale = 3.0
                                            lastScale = 3.0
                                        }
                                    }
                                }
                        )
                        .onTapGesture(count: 2) {
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
                } else {
                    ProgressView()
                        .tint(.white)
                }
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

import SwiftUI

/// Animated skeleton shimmer effect.
struct SkeletonModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.white.opacity(0.4),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (phase * geometry.size.width * 2))
                }
            )
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    /// Apply skeleton shimmer animation
    func skeleton() -> some View {
        modifier(SkeletonModifier())
    }
}

// MARK: - Skeleton Shape

/// Base skeleton shape with customizable size and corner radius.
struct SkeletonShape: View {
    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat
    
    init(
        width: CGFloat? = nil,
        height: CGFloat = 16,
        cornerRadius: CGFloat = AppSpacing.radiusSmall
    ) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(AppColors.surfaceSecondary)
            .frame(width: width, height: height)
            .skeleton()
    }
}

// MARK: - Skeleton Row

/// Skeleton placeholder for list rows.
struct SkeletonRow: View {
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Avatar placeholder
            SkeletonShape(width: 44, height: 44, cornerRadius: 22)
            
            // Text placeholders
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                SkeletonShape(width: 140, height: 14)
                SkeletonShape(width: 200, height: 12)
            }
            
            Spacer()
        }
        .padding(AppSpacing.md)
    }
}

// MARK: - Skeleton Card

/// Skeleton placeholder for cards.
struct SkeletonCard: View {
    let style: Style
    
    enum Style {
        case standard
        case roundCard
        case profileCard
    }
    
    init(style: Style = .standard) {
        self.style = style
    }
    
    var body: some View {
        Group {
            switch style {
            case .standard:
                standardSkeleton
            case .roundCard:
                roundCardSkeleton
            case .profileCard:
                profileCardSkeleton
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColors.surface)
        .cornerRadius(AppSpacing.radiusLarge)
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }
    
    // MARK: - Standard Skeleton
    
    private var standardSkeleton: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SkeletonShape(height: 18)
            SkeletonShape(width: 200, height: 14)
            SkeletonShape(width: 150, height: 14)
        }
    }
    
    // MARK: - Round Card Skeleton
    
    private var roundCardSkeleton: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Header with host avatar
            HStack(spacing: AppSpacing.sm) {
                SkeletonShape(width: 36, height: 36, cornerRadius: 18)
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    SkeletonShape(width: 80, height: 12)
                    SkeletonShape(width: 60, height: 10)
                }
            }
            
            // Course and time
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                SkeletonShape(width: 180, height: 16)
                SkeletonShape(width: 140, height: 14)
            }
            
            // Bottom row
            HStack {
                SkeletonShape(width: 60, height: 24, cornerRadius: AppSpacing.radiusFull)
                Spacer()
                SkeletonShape(width: 80, height: 24, cornerRadius: AppSpacing.radiusFull)
            }
        }
    }
    
    // MARK: - Profile Card Skeleton
    
    private var profileCardSkeleton: some View {
        VStack(spacing: AppSpacing.lg) {
            // Avatar
            SkeletonShape(width: 80, height: 80, cornerRadius: 40)
            
            // Name and location
            VStack(spacing: AppSpacing.sm) {
                SkeletonShape(width: 120, height: 18)
                SkeletonShape(width: 160, height: 14)
            }
            
            // Stats row
            HStack(spacing: AppSpacing.xl) {
                statSkeleton
                statSkeleton
                statSkeleton
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var statSkeleton: some View {
        VStack(spacing: AppSpacing.xs) {
            SkeletonShape(width: 40, height: 20)
            SkeletonShape(width: 60, height: 12)
        }
    }
}

// MARK: - Skeleton List

/// Multiple skeleton rows for list loading state.
struct SkeletonList: View {
    let count: Int
    
    init(count: Int = 5) {
        self.count = count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { _ in
                SkeletonRow()
                Divider()
                    .padding(.leading, 72)
            }
        }
        .background(AppColors.surface)
        .cornerRadius(AppSpacing.radiusLarge)
    }
}

// MARK: - Preview

#if DEBUG
struct SkeletonViews_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                Text("Skeleton Row").font(AppTypography.labelMedium)
                SkeletonRow()
                    .background(AppColors.surface)
                    .cornerRadius(AppSpacing.radiusMedium)
                
                Text("Skeleton Card - Standard").font(AppTypography.labelMedium)
                SkeletonCard(style: .standard)
                
                Text("Skeleton Card - Round").font(AppTypography.labelMedium)
                SkeletonCard(style: .roundCard)
                
                Text("Skeleton Card - Profile").font(AppTypography.labelMedium)
                SkeletonCard(style: .profileCard)
                
                Text("Skeleton List").font(AppTypography.labelMedium)
                SkeletonList(count: 3)
            }
            .padding()
        }
        .background(AppColors.backgroundGrouped)
    }
}
#endif


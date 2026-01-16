import SwiftUI

// MARK: - Price Tier Inference Helper

/// Infer price tier from dollar amount
func inferPriceTierFromAmount(_ amount: String) -> PriceTier {
    guard let value = Int(amount), value > 0 else {
        return .free
    }
    
    switch value {
    case 1...50:
        return .budget
    case 51...100:
        return .moderate
    case 101...200:
        return .premium
    default:
        return .luxury
    }
}

/// Get display label for price tier
func priceTierDisplayLabel(amount: String, tier: PriceTier) -> String {
    if amount.isEmpty || Int(amount) == nil || Int(amount) == 0 {
        return "Free round"
    }
    
    switch tier {
    case .free:
        return "Free"
    case .budget:
        return "Budget ($1-50)"
    case .moderate:
        return "Moderate ($51-100)"
    case .premium:
        return "Premium ($101-200)"
    case .luxury:
        return "Luxury ($200+)"
    }
}

// MARK: - Age Range Section

struct AgeRangeSection: View {
    @Binding var minAge: Int
    @Binding var maxAge: Int
    
    @State private var minAgeDouble: Double = 18
    @State private var maxAgeDouble: Double = 65
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Value label - right aligned, prominent
            HStack {
                Text("Age Range")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(rangeDisplayText)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
            
            // Slider
            RangeSliderView(minValue: $minAgeDouble, maxValue: $maxAgeDouble, bounds: 18...65)
                .onAppear {
                    minAgeDouble = Double(minAge)
                    maxAgeDouble = Double(maxAge)
                }
                .onChange(of: minAgeDouble) { _, newValue in
                    minAge = Int(newValue)
                }
                .onChange(of: maxAgeDouble) { _, newValue in
                    maxAge = Int(newValue)
                }
            
            // Min/Max labels
            HStack {
                Text("18")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("65+")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
    
    private var rangeDisplayText: String {
        let maxText = maxAge >= 65 ? "65+" : "\(maxAge)"
        return "\(minAge) - \(maxText) years"
    }
}

// MARK: - Range Slider

/// A dual-thumb range slider for selecting min/max values.
struct RangeSliderView: View {
    @Binding var minValue: Double
    @Binding var maxValue: Double
    let bounds: ClosedRange<Double>
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                Rectangle()
                    .fill(AppColors.backgroundSecondary)
                    .frame(height: 4)
                
                // Selected range
                Rectangle()
                    .fill(AppColors.primary)
                    .frame(width: selectedWidth(geometry), height: 4)
                    .offset(x: minOffset(geometry))
                
                // Min thumb
                Circle()
                    .fill(AppColors.primary)
                    .frame(width: 24, height: 24)
                    .offset(x: minOffset(geometry) - 12)
                    .gesture(minDragGesture(geometry))
                
                // Max thumb
                Circle()
                    .fill(AppColors.primary)
                    .frame(width: 24, height: 24)
                    .offset(x: maxOffset(geometry) - 12)
                    .gesture(maxDragGesture(geometry))
            }
        }
        .frame(height: 24)
    }
    
    private func selectedWidth(_ geo: GeometryProxy) -> CGFloat {
        guard geo.size.width > 0, bounds.upperBound > bounds.lowerBound else { return 0 }
        return CGFloat((maxValue - minValue) / (bounds.upperBound - bounds.lowerBound)) * geo.size.width
    }

    private func minOffset(_ geo: GeometryProxy) -> CGFloat {
        guard geo.size.width > 0, bounds.upperBound > bounds.lowerBound else { return 0 }
        return CGFloat((minValue - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound)) * geo.size.width
    }

    private func maxOffset(_ geo: GeometryProxy) -> CGFloat {
        guard geo.size.width > 0, bounds.upperBound > bounds.lowerBound else { return 0 }
        return CGFloat((maxValue - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound)) * geo.size.width
    }
    
    private func minDragGesture(_ geo: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard geo.size.width > 0, bounds.upperBound > bounds.lowerBound else { return }
                let newValue = bounds.lowerBound + Double(value.location.x / geo.size.width) * (bounds.upperBound - bounds.lowerBound)
                minValue = min(max(bounds.lowerBound, newValue), maxValue - 1)
            }
    }

    private func maxDragGesture(_ geo: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard geo.size.width > 0, bounds.upperBound > bounds.lowerBound else { return }
                let newValue = bounds.lowerBound + Double(value.location.x / geo.size.width) * (bounds.upperBound - bounds.lowerBound)
                maxValue = max(min(bounds.upperBound, newValue), minValue + 1)
            }
    }
}


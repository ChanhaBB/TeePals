import SwiftUI

/// Compact filter summary displayed below navigation title.
/// Tapping opens the filter sheet.
struct FilterSummaryView: View {
    let filters: RoundsListFilters
    let userProfile: PublicProfile?
    
    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: locationIcon)
                .font(.caption)
                .foregroundColor(AppColors.iconAccent)
            
            Text(summaryText)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(AppColors.textSecondary.opacity(0.6))
        }
        .padding(.horizontal, AppSpacing.contentPadding)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.backgroundPrimary)
    }
    
    private var locationIcon: String {
        filters.distance == .anywhere ? "globe" : "location.fill"
    }
    
    private var summaryText: String {
        var parts: [String] = []
        
        // Location/Distance part
        switch filters.distance {
        case .anywhere:
            parts.append("Anywhere")
        case .miles(let value):
            if let city = filters.cityLabel ?? userProfile?.primaryCityLabel {
                parts.append("\(city) • \(value) mi")
            } else {
                parts.append("\(value) mi")
            }
        }
        
        // Date range part
        parts.append(filters.dateRange.displayText)
        
        return parts.joined(separator: " • ")
    }
}

// MARK: - Preview

#if DEBUG
struct FilterSummaryView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 0) {
            // Geo mode
            FilterSummaryView(
                filters: RoundsListFilters(
                    centerLat: 37.3382,
                    centerLng: -121.8863,
                    cityLabel: "San Jose, CA",
                    distance: .miles(25),
                    dateRange: .next30,
                    sortBy: .date
                ),
                userProfile: nil
            )
            
            Divider()
            
            // Anywhere mode
            FilterSummaryView(
                filters: RoundsListFilters(
                    distance: .anywhere,
                    dateRange: .next7,
                    sortBy: .date
                ),
                userProfile: nil
            )
        }
        .background(AppColors.backgroundGrouped)
    }
}
#endif


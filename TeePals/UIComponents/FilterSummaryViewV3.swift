import SwiftUI

/// V3 Filter summary displayed below segmented control
/// Format: "Within **10 miles** • **This Weekend**" with green highlights
/// Tune button on the right side
struct FilterSummaryViewV3: View {
    let filters: RoundsListFilters
    let userProfile: PublicProfile?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Filter summary text with green highlights
                filterText
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                Spacer()

                // Tune icon
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 20))
                    .foregroundColor(AppColorsV3.forestGreen)
            }
            .padding(.horizontal, AppSpacingV3.contentPadding)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColorsV3.bgNeutral)
            .overlay(
                Rectangle()
                    .fill(AppColorsV3.borderLight)
                    .frame(height: 1),
                alignment: .bottom
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var filterText: some View {
        // Build attributed text with green highlights
        HStack(spacing: 0) {
            Text("Within ")
                .foregroundColor(AppColorsV3.textSecondary)
            +
            Text(distanceText)
                .foregroundColor(AppColorsV3.forestGreen)
                .fontWeight(.semibold)
            +
            Text(" • ")
                .foregroundColor(AppColorsV3.textSecondary)
            +
            Text(dateRangeText)
                .foregroundColor(AppColorsV3.forestGreen)
                .fontWeight(.semibold)
        }
    }

    private var distanceText: String {
        switch filters.distance {
        case .anywhere:
            return "Anywhere"
        case .miles(let value):
            return "\(value) miles"
        }
    }

    private var dateRangeText: String {
        filters.dateRange.displayText
    }
}

// MARK: - Preview

#if DEBUG
struct FilterSummaryViewV3_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 0) {
            // Example 1: 10 miles, Next 7 days
            FilterSummaryViewV3(
                filters: RoundsListFilters(
                    centerLat: 37.3382,
                    centerLng: -121.8863,
                    cityLabel: "San Jose, CA",
                    distance: .miles(10),
                    dateRange: .next7,
                    sortBy: .date
                ),
                userProfile: nil,
                onTap: {}
            )

            // Example 2: 25 miles, This Weekend
            FilterSummaryViewV3(
                filters: RoundsListFilters(
                    centerLat: 37.3382,
                    centerLng: -121.8863,
                    cityLabel: "San Diego, CA",
                    distance: .miles(25),
                    dateRange: .thisWeekend,
                    sortBy: .date
                ),
                userProfile: nil,
                onTap: {}
            )

            // Example 3: Anywhere
            FilterSummaryViewV3(
                filters: RoundsListFilters(
                    distance: .anywhere,
                    dateRange: .next30,
                    sortBy: .date
                ),
                userProfile: nil,
                onTap: {}
            )
        }
        .background(AppColorsV3.bgNeutral)
    }
}
#endif

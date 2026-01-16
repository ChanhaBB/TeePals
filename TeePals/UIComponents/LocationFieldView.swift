import SwiftUI

/// Location picker field with GPS and search options.
/// Used in profile setup forms.
struct LocationFieldView: View {
    let cityLabel: String
    @Binding var isLocating: Bool
    let onUseGPS: () -> Void
    let onSearch: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Current location display
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.secondary)
                    .frame(width: 24)
                
                if cityLabel.isEmpty {
                    Text("Set your home location")
                        .foregroundColor(.secondary)
                } else {
                    Text(cityLabel)
                }
                
                Spacer()
            }
            
            // Action buttons
            HStack(spacing: 12) {
                gpsButton
                searchButton
            }
        }
    }
    
    private var gpsButton: some View {
        Button(action: onUseGPS) {
            HStack {
                if isLocating {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Image(systemName: "location.circle")
                }
                Text("Use GPS")
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(isLocating)
    }
    
    private var searchButton: some View {
        Button(action: onSearch) {
            HStack {
                Image(systemName: "magnifyingglass")
                Text("Search")
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview("Empty") {
    Form {
        LocationFieldView(
            cityLabel: "",
            isLocating: .constant(false),
            onUseGPS: {},
            onSearch: {}
        )
    }
}

#Preview("With Location") {
    Form {
        LocationFieldView(
            cityLabel: "San Jose, CA",
            isLocating: .constant(false),
            onUseGPS: {},
            onSearch: {}
        )
    }
}
#endif


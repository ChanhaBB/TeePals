import SwiftUI

/// Sheet for manually entering course details when search doesn't find the course.
struct ManualCourseEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationService = LocationService()
    
    @State private var courseName = ""
    @State private var cityLabel = ""
    @State private var isLocating = false
    @State private var location: GeoLocation?
    
    var onAdd: (CourseCandidate) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Course Name", text: $courseName)
                    TextField("City, State", text: $cityLabel)
                } header: {
                    Text("Course Info")
                }
                
                Section {
                    if let loc = location {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Location set")
                            Spacer()
                            Text(String(format: "%.4f, %.4f", loc.latitude, loc.longitude))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Button {
                        getCurrentLocation()
                    } label: {
                        HStack {
                            if isLocating {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "location.fill")
                            }
                            Text("Use Current Location")
                        }
                    }
                    .disabled(isLocating)
                } header: {
                    Text("Location")
                } footer: {
                    Text("Location helps players find rounds near them.")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Add Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addCourse()
                    }
                    .disabled(!canAdd)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private var canAdd: Bool {
        !courseName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !cityLabel.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private func getCurrentLocation() {
        isLocating = true
        Task {
            let result = await locationService.requestCurrentLocation()
            isLocating = false
            if let loc = result.location {
                location = GeoLocation(
                    latitude: loc.coordinate.latitude,
                    longitude: loc.coordinate.longitude
                )
                if let city = result.cityLabel, cityLabel.isEmpty {
                    cityLabel = city
                }
            }
        }
    }
    
    private func addCourse() {
        let course = CourseCandidate(
            name: courseName.trimmingCharacters(in: .whitespaces),
            cityLabel: cityLabel.trimmingCharacters(in: .whitespaces),
            location: location ?? GeoLocation(latitude: 0, longitude: 0)
        )
        onAdd(course)
        dismiss()
    }
}


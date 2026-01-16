import SwiftUI

/// Step 4: Review all round details before posting
struct CreateRoundReviewStep: View {
    @ObservedObject var viewModel: CreateRoundViewModel
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text("Review Your Round")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                Text("Make sure everything looks good before posting")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)
            
            // Course
            if let course = viewModel.selectedCourse {
                courseCard(course)
            }
            
            // Date & Time
            dateTimeCard
            
            // Settings
            settingsCard
            
            // Preferred TeePals (if any restrictions)
            if hasPreferredTeePals {
                preferredTeePalsCard
            }
            
            // Host Message (if any)
            if !viewModel.hostMessage.isEmpty {
                messageCard
            }
            
            Spacer(minLength: 16)
        }
    }
    
    // MARK: - Course Card
    
    private func courseCard(_ course: CourseCandidate) -> some View {
        SectionCard {
            HStack(spacing: 12) {
                Image(systemName: "flag.fill")
                    .font(.title2)
                    .foregroundStyle(AppColors.primary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(course.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(course.cityLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Date & Time Card
    
    private var dateTimeCard: some View {
        SectionCard {
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.title2)
                    .foregroundStyle(AppColors.primary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Preferred Time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(dateFormatter.string(from: viewModel.combinedDateTime))
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Settings Card
    
    private var settingsCard: some View {
        SectionCard(title: "Settings") {
            VStack(spacing: 12) {
                settingRow(
                    icon: viewModel.visibility.systemImage,
                    label: "Visibility",
                    value: viewModel.visibility.displayText
                )
                
                Divider()
                
                settingRow(
                    icon: viewModel.joinPolicy == .instant ? "bolt.fill" : "hand.raised.fill",
                    label: "Join Policy",
                    value: viewModel.joinPolicy.displayText
                )
                
                Divider()
                settingRow(
                    icon: "dollarsign.circle",
                    label: "Price",
                    value: priceDisplayText
                )
            }
        }
    }
    
    private var priceDisplayText: String {
        if let amount = Int(viewModel.priceAmount), amount > 0 {
            return "$\(amount)"
        }
        return "Price TBD"
    }
    
    private func settingRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(AppColors.primary)
                .frame(width: 24)
            
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
    }
    
    // MARK: - Preferred TeePals Card
    
    private var hasPreferredTeePals: Bool {
        viewModel.minAge > 18 ||
        viewModel.maxAge < 65 ||
        viewModel.skillLevels.count < SkillLevel.allCases.count
    }
    
    private var preferredTeePalsCard: some View {
        SectionCard(title: "Preferred TeePals") {
            VStack(alignment: .leading, spacing: 8) {
                if viewModel.minAge > 18 || viewModel.maxAge < 65 {
                    let maxAgeText = viewModel.maxAge >= 65 ? "65+" : "\(viewModel.maxAge)"
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Age: \(viewModel.minAge) - \(maxAgeText)")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                }
                
                if viewModel.skillLevels.count < SkillLevel.allCases.count {
                    let skills = viewModel.skillLevels.map { $0.displayText }.joined(separator: ", ")
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Skill: \(skills)")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
    }
    
    // MARK: - Message Card
    
    private var messageCard: some View {
        SectionCard(title: "Message from Host") {
            Text(viewModel.hostMessage)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
}

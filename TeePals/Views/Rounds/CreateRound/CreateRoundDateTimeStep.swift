import SwiftUI

/// Step 2: Preferred date and time selection
struct CreateRoundDateTimeStep: View {
    @ObservedObject var viewModel: CreateRoundViewModel
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }()
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text("When do you want to play?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                Text("Select your preferred date and time")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)
            
            // Date Section
            SectionCard(title: "Preferred Date") {
                DatePicker(
                    "",
                    selection: $viewModel.preferredDate,
                    in: Date()...,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(AppColors.primary)
            }
            
            // Time Section
            SectionCard(title: "Preferred Time") {
                DatePicker(
                    "",
                    selection: $viewModel.preferredTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(height: 120)
                .tint(AppColors.primary)
            }
            
            // Summary
            summaryCard
            
            Spacer(minLength: 16)
        }
    }
    
    // MARK: - Summary Card
    
    private var summaryCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.badge.checkmark")
                .font(.title2)
                .foregroundStyle(AppColors.primary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(dateFormatter.string(from: viewModel.preferredDate))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                
                Text("at \(timeFormatter.string(from: viewModel.preferredTime))")
                    .font(.headline)
                    .foregroundStyle(AppColors.primary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.primary.opacity(0.1))
        )
    }
}

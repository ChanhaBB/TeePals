import SwiftUI

/// Step 2: Preferred date and time selection
struct CreateRoundDateTimeStep: View {
    @ObservedObject var viewModel: CreateRoundViewModel
    
    private let summaryDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f
    }()
    
    private let summaryTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacingV3.lg) {
            stepTitle
            dateSection
            timeSection
            summaryCard
            Spacer(minLength: AppSpacingV3.md)
        }
        .padding(.top, AppSpacingV3.md)
    }
    
    // MARK: - Step Title
    
    private var stepTitle: some View {
        Text("When is the preferred tee time?")
            .font(Font.custom("PlayfairDisplay-Regular", size: 30, relativeTo: .largeTitle).weight(.bold))
            .foregroundColor(AppColorsV3.textPrimary)
            .tracking(-0.3)
    }
    
    // MARK: - Date Section
    
    private var dateSection: some View {
        VStack(alignment: .leading, spacing: AppSpacingV3.sm) {
            sectionLabel("Date")
            
            DatePicker(
                "",
                selection: $viewModel.preferredDate,
                in: Date()...,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(AppColorsV3.forestGreen)
        }
        .padding(AppSpacingV3.md)
        .background(AppColorsV3.surfaceWhite)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacingV3.radiusSmall))
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Time Section
    
    private var timeSection: some View {
        VStack(alignment: .leading, spacing: AppSpacingV3.sm) {
            sectionLabel("Time")
            
            DatePicker(
                "",
                selection: $viewModel.preferredTime,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .tint(AppColorsV3.forestGreen)
        }
        .padding(AppSpacingV3.md)
        .background(AppColorsV3.surfaceWhite)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacingV3.radiusSmall))
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Summary Card
    
    private var summaryCard: some View {
        HStack(spacing: AppSpacingV3.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(AppColorsV3.forestGreen)
            
            Text("\(summaryDateFormatter.string(from: viewModel.preferredDate)) at \(summaryTimeFormatter.string(from: viewModel.preferredTime))")
                .font(AppTypographyV3.bodySemibold)
                .foregroundColor(AppColorsV3.textPrimary)
            
            Spacer()
        }
        .padding(AppSpacingV3.md)
        .background(AppColorsV3.forestGreen.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacingV3.radiusSmall))
    }
    
    // MARK: - Helpers
    
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .textCase(.uppercase)
            .tracking(0.15 * 11)
            .foregroundColor(AppColorsV3.textSecondary)
    }
}

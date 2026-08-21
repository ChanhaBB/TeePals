import SwiftUI

/// Step 1: Golf course search and selection
struct CreateRoundCourseStep: View {
    @ObservedObject var viewModel: CreateRoundViewModel
    @ObservedObject var searchService: GolfCourseSearchService
    
    @State private var showingManualEntry = false
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacingV3.lg) {
            stepTitle
            
            if let course = viewModel.selectedCourse {
                selectedCourseCard(course)
            } else {
                searchField
                searchResults
            }
            
            Spacer(minLength: AppSpacingV3.md)
            
            manualEntryLink
        }
        .padding(.top, AppSpacingV3.md)
        .sheet(isPresented: $showingManualEntry) {
            ManualCourseEntrySheet { course in
                viewModel.selectCourse(course)
            }
        }
    }
    
    // MARK: - Step Title
    
    private var stepTitle: some View {
        Text("Where are you playing?")
            .font(Font.custom("PlayfairDisplay-Regular", size: 30, relativeTo: .largeTitle).weight(.bold))
            .foregroundColor(AppColorsV3.textPrimary)
            .tracking(-0.3)
    }
    
    // MARK: - Search Field (underline style)
    
    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20))
                .foregroundColor(AppColorsV3.textSecondary)
            
            TextField("Search golf courses", text: $viewModel.courseSearchText)
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(AppColorsV3.textPrimary)
                .focused($isSearchFocused)
                .autocorrectionDisabled()
                .onChange(of: viewModel.courseSearchText) { _, newValue in
                    searchService.search(query: newValue)
                }
            
            if !viewModel.courseSearchText.isEmpty {
                Button {
                    viewModel.courseSearchText = ""
                    searchService.clearResults()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(AppColorsV3.textSecondary.opacity(0.5))
                }
            }
        }
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(isSearchFocused ? AppColorsV3.forestGreen : AppColorsV3.borderLight)
                .frame(height: 1)
                .animation(.easeInOut(duration: 0.2), value: isSearchFocused)
        }
    }
    
    // MARK: - Search Results
    
    @ViewBuilder
    private var searchResults: some View {
        if searchService.isSearching {
            HStack {
                Spacer()
                ProgressView()
                    .tint(AppColorsV3.forestGreen)
                Spacer()
            }
            .padding(.vertical, AppSpacingV3.lg)
        } else if !searchService.searchResults.isEmpty {
            VStack(spacing: 0) {
                ForEach(searchService.searchResults) { course in
                    courseRow(course)
                    
                    if course.id != searchService.searchResults.last?.id {
                        Divider()
                            .background(AppColorsV3.borderLight)
                    }
                }
            }
        } else if !viewModel.courseSearchText.isEmpty && !searchService.isSearching {
            VStack(spacing: AppSpacingV3.sm) {
                Text("No courses found")
                    .font(AppTypographyV3.bodyMedium)
                    .foregroundColor(AppColorsV3.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacingV3.lg)
        }
    }
    
    private func courseRow(_ course: CourseCandidate) -> some View {
        Button {
            viewModel.selectCourse(course)
            viewModel.courseSearchText = ""
            searchService.clearResults()
            isSearchFocused = false
        } label: {
            HStack(spacing: AppSpacingV3.md) {
                ZStack {
                    Circle()
                        .fill(AppColorsV3.forestGreen.opacity(0.08))
                        .frame(width: 40, height: 40)
                    Image(systemName: "flag.fill")
                        .font(.system(size: 16))
                        .foregroundColor(AppColorsV3.forestGreen)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(course.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColorsV3.textPrimary)
                        .lineLimit(1)
                    Text(course.cityLabel)
                        .font(AppTypographyV3.bodyRegular)
                        .foregroundColor(AppColorsV3.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(.vertical, AppSpacingV3.md)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Selected Course Card
    
    private func selectedCourseCard(_ course: CourseCandidate) -> some View {
        VStack(spacing: AppSpacingV3.md) {
            HStack(spacing: AppSpacingV3.md) {
                ZStack {
                    Circle()
                        .fill(AppColorsV3.forestGreen.opacity(0.08))
                        .frame(width: 44, height: 44)
                    Image(systemName: "flag.fill")
                        .font(.system(size: 18))
                        .foregroundColor(AppColorsV3.forestGreen)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(course.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(AppColorsV3.textPrimary)
                    Text(course.cityLabel)
                        .font(AppTypographyV3.bodyRegular)
                        .foregroundColor(AppColorsV3.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(AppColorsV3.forestGreen)
            }
            
            Button {
                viewModel.clearCourse()
            } label: {
                Text("Change course")
                    .font(AppTypographyV3.bodyMedium)
                    .foregroundColor(AppColorsV3.forestGreen)
            }
        }
        .padding(AppSpacingV3.md)
        .background(AppColorsV3.surfaceWhite)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacingV3.radiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacingV3.radiusSmall)
                .stroke(AppColorsV3.forestGreen.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Manual Entry Link
    
    private var manualEntryLink: some View {
        HStack {
            Spacer()
            Button {
                showingManualEntry = true
            } label: {
                Text("Enter course manually")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColorsV3.forestGreen)
            }
            Spacer()
        }
    }
}

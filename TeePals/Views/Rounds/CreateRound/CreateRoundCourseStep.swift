import SwiftUI

/// Step 1: Golf course search and selection
struct CreateRoundCourseStep: View {
    @ObservedObject var viewModel: CreateRoundViewModel
    @ObservedObject var searchService: GolfCourseSearchService
    
    @State private var showingManualEntry = false
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text("Where will you play?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                Text("Search for a golf course or enter manually")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)
            
            // Content
            if let course = viewModel.selectedCourse {
                selectedCourseCard(course)
            } else {
                searchSection
            }
            
            Spacer(minLength: 16)
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualCourseEntrySheet { course in
                viewModel.selectCourse(course)
            }
        }
    }
    
    // MARK: - Search Section
    
    private var searchSection: some View {
        SectionCard {
            VStack(spacing: 12) {
                // Search field
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    
                    TextField("Search golf courses...", text: $viewModel.courseSearchText)
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
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                // Results
                if searchService.isSearching {
                    ProgressView()
                        .padding()
                } else if !searchService.searchResults.isEmpty {
                    searchResultsList
                } else if !viewModel.courseSearchText.isEmpty {
                    noResultsView
                }
            }
        }
    }
    
    // MARK: - Search Results
    
    private var searchResultsList: some View {
        VStack(spacing: 8) {
            ForEach(searchService.searchResults) { course in
                Button {
                    viewModel.selectCourse(course)
                    viewModel.courseSearchText = ""
                    searchService.clearResults()
                    isSearchFocused = false
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "flag.fill")
                            .font(.body)
                            .foregroundStyle(AppColors.primary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(course.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            Text(course.cityLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - No Results
    
    private var noResultsView: some View {
        VStack(spacing: 12) {
            Text("No courses found")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button {
                showingManualEntry = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                    Text("Enter course manually")
                }
                .font(.subheadline)
                .fontWeight(.medium)
            }
        }
        .padding()
    }
    
    // MARK: - Selected Course Card
    
    private func selectedCourseCard(_ course: CourseCandidate) -> some View {
        SectionCard {
            VStack(spacing: 16) {
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
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
                
                Button {
                    viewModel.clearCourse()
                } label: {
                    Text("Change course")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

import SwiftUI

/// Step 3: Round settings with improved visual hierarchy and readability.
struct CreateRoundDetailsStep: View {
    @ObservedObject var viewModel: CreateRoundViewModel
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case price, message
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Screen header
            VStack(alignment: .leading, spacing: 6) {
                Text("Round Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                Text("Customize preferences for your round")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)
            
            // Sections
            visibilitySection
            priceSection
            preferredTeePalsSection
            messageSection
            
            Spacer(minLength: 16)
        }
    }
    
    // MARK: - Visibility Section
    
    private var visibilitySection: some View {
        SectionCard(title: "Visibility") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ForEach(RoundVisibility.allCases, id: \.self) { visibility in
                        VisibilityChip(
                            title: visibility.displayText,
                            icon: visibility.systemImage,
                            isSelected: viewModel.visibility == visibility
                        ) {
                            viewModel.visibility = visibility
                        }
                    }
                }
                
                AssistiveText(
                    viewModel.visibility == .public
                        ? "Players will request to join"
                        : "Friends can join instantly",
                    icon: viewModel.visibility == .public ? "hand.raised.fill" : "bolt.fill"
                )
            }
        }
    }
    
    // MARK: - Price Section
    
    private var priceSection: some View {
        SectionCard(title: "Estimated Price", subtitle: "Optional") {
            HStack(spacing: 8) {
                Text("$")
                    .font(.body)
                    .foregroundStyle(.secondary)
                
                TextField("Enter estimated amount", text: $viewModel.priceAmount)
                    .font(.body)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .price)
                
                if focusedField == .price {
                    Button {
                        focusedField = nil
                    } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .font(.system(size: 18))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .animation(.easeInOut(duration: 0.15), value: focusedField)
        }
    }
    
    // MARK: - Preferred TeePals Section
    
    private var preferredTeePalsSection: some View {
        SectionCard(title: "Preferred TeePals", subtitle: "Optional") {
            VStack(alignment: .leading, spacing: 20) {
                // Age Range
                AgeRangeSection(minAge: $viewModel.minAge, maxAge: $viewModel.maxAge)
                
                Divider()
                
                // Skill Level
                VStack(alignment: .leading, spacing: 10) {
                    Text("Skill Level")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    MultiSelectChipGroup(
                        options: SkillLevel.allCases,
                        selection: viewModel.skillLevels,
                        labelProvider: { $0.displayText },
                        onToggle: { skill in
                            if viewModel.skillLevels.contains(skill) {
                                viewModel.skillLevels.remove(skill)
                            } else {
                                viewModel.skillLevels.insert(skill)
                            }
                        },
                        allSelectedText: "All skill levels welcome",
                        noneSelectedText: "Select at least one"
                    )
                }
            }
        }
    }
    
    // MARK: - Message Section
    
    private var messageSection: some View {
        SectionCard(title: "Message from Host", subtitle: "Optional") {
            VStack(alignment: .trailing, spacing: 8) {
                TextField("Add a message for potential players...", text: $viewModel.hostMessage, axis: .vertical)
                    .lineLimit(3...6)
                    .font(.body)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .focused($focusedField, equals: .message)
                
                if focusedField == .message {
                    Button {
                        focusedField = nil
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "keyboard.chevron.compact.down")
                                .font(.system(size: 16))
                            Text("Done")
                                .font(.subheadline)
                        }
                        .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.15), value: focusedField)
        }
    }
}

// MARK: - Visibility Chip

private struct VisibilityChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.subheadline)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? AppColors.primary : Color(.systemGray6))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}


import SwiftUI

/// Styled text field with label, hint, and error states.
struct AppTextField: View {
    
    let label: String
    let placeholder: String
    let hint: String?
    let error: String?
    let icon: String?
    
    @Binding var text: String
    @FocusState private var isFocused: Bool
    
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?
    var autocapitalization: TextInputAutocapitalization = .sentences
    var autocorrectionDisabled: Bool = false
    
    init(
        label: String,
        placeholder: String = "",
        hint: String? = nil,
        error: String? = nil,
        icon: String? = nil,
        text: Binding<String>
    ) {
        self.label = label
        self.placeholder = placeholder
        self.hint = hint
        self.error = error
        self.icon = icon
        self._text = text
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            // Label
            Text(label)
                .font(AppTypography.labelMedium)
                .foregroundColor(labelColor)
            
            // Input field
            HStack(spacing: AppSpacing.iconSpacing) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(iconColor)
                        .frame(width: 20)
                }
                
                TextField(placeholder, text: $text)
                    .font(AppTypography.bodyLarge)
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled(autocorrectionDisabled)
                    .focused($isFocused)
                
                // Clear button
                if !text.isEmpty && isFocused {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                
                // Error icon
                if hasError {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(AppColors.error)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .frame(height: AppSpacing.inputHeight)
            .background(AppColors.surfaceSecondary)
            .cornerRadius(AppSpacing.radiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            
            // Hint or Error message
            if let error = error, !error.isEmpty {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 12))
                    Text(error)
                }
                .font(AppTypography.caption)
                .foregroundColor(AppColors.error)
            } else if let hint = hint {
                Text(hint)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var hasError: Bool {
        error != nil && !error!.isEmpty
    }
    
    private var labelColor: Color {
        if hasError {
            return AppColors.error
        }
        return isFocused ? AppColors.primary : AppColors.textSecondary
    }
    
    private var iconColor: Color {
        if hasError {
            return AppColors.error
        }
        return isFocused ? AppColors.primary : AppColors.textTertiary
    }
    
    private var borderColor: Color {
        if hasError {
            return AppColors.error
        }
        return isFocused ? AppColors.primary : .clear
    }
    
    private var borderWidth: CGFloat {
        (isFocused || hasError) ? 2 : 0
    }
}

// MARK: - Secure Field Variant

struct AppSecureField: View {
    
    let label: String
    let placeholder: String
    let hint: String?
    let error: String?
    
    @Binding var text: String
    @State private var isSecure = true
    @FocusState private var isFocused: Bool
    
    init(
        label: String,
        placeholder: String = "",
        hint: String? = nil,
        error: String? = nil,
        text: Binding<String>
    ) {
        self.label = label
        self.placeholder = placeholder
        self.hint = hint
        self.error = error
        self._text = text
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            // Label
            Text(label)
                .font(AppTypography.labelMedium)
                .foregroundColor(labelColor)
            
            // Input field
            HStack(spacing: AppSpacing.iconSpacing) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
                    .frame(width: 20)
                
                Group {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .font(AppTypography.bodyLarge)
                .focused($isFocused)
                
                // Toggle visibility
                Button {
                    isSecure.toggle()
                } label: {
                    Image(systemName: isSecure ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .frame(height: AppSpacing.inputHeight)
            .background(AppColors.surfaceSecondary)
            .cornerRadius(AppSpacing.radiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.radiusMedium)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            
            // Hint or Error message
            if let error = error, !error.isEmpty {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 12))
                    Text(error)
                }
                .font(AppTypography.caption)
                .foregroundColor(AppColors.error)
            } else if let hint = hint {
                Text(hint)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var hasError: Bool {
        error != nil && !error!.isEmpty
    }
    
    private var labelColor: Color {
        if hasError { return AppColors.error }
        return isFocused ? AppColors.primary : AppColors.textSecondary
    }
    
    private var iconColor: Color {
        if hasError { return AppColors.error }
        return isFocused ? AppColors.primary : AppColors.textTertiary
    }
    
    private var borderColor: Color {
        if hasError { return AppColors.error }
        return isFocused ? AppColors.primary : .clear
    }
    
    private var borderWidth: CGFloat {
        (isFocused || hasError) ? 2 : 0
    }
}

// MARK: - Preview

#if DEBUG
struct AppTextField_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var text1 = ""
        @State private var text2 = "John"
        @State private var text3 = "bad@"
        @State private var password = ""
        
        var body: some View {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    AppTextField(
                        label: "Nickname",
                        placeholder: "Enter your nickname",
                        hint: "2-20 characters",
                        icon: "person",
                        text: $text1
                    )
                    
                    AppTextField(
                        label: "Nickname",
                        placeholder: "Enter your nickname",
                        hint: "Looks good!",
                        icon: "person",
                        text: $text2
                    )
                    
                    AppTextField(
                        label: "Email",
                        placeholder: "Enter your email",
                        error: "Please enter a valid email",
                        icon: "envelope",
                        text: $text3
                    )
                    
                    AppSecureField(
                        label: "Password",
                        placeholder: "Enter password",
                        hint: "At least 8 characters",
                        text: $password
                    )
                }
                .padding()
            }
        }
    }
    
    static var previews: some View {
        PreviewWrapper()
    }
}
#endif


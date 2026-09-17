import SwiftUI

struct OTPInputView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Binding var code: String
    let characterCount: Int
    let digitsOnly: Bool
    let isError: Bool
    let automaticallyFocus: Bool
    let accessibilityLabel: String?
    let onSubmit: (() -> Void)?
    @FocusState private var isFocused: Bool

    init(
        code: Binding<String>,
        characterCount: Int = 6,
        digitsOnly: Bool = false,
        isError: Bool = false,
        automaticallyFocus: Bool = false,
        accessibilityLabel: String? = nil,
        onSubmit: (() -> Void)? = nil
    ) {
        _code = code
        self.characterCount = max(1, characterCount)
        self.digitsOnly = digitsOnly
        self.isError = isError
        self.automaticallyFocus = automaticallyFocus
        self.accessibilityLabel = accessibilityLabel
        self.onSubmit = onSubmit
    }

    var body: some View {
        HStack(spacing: boxSpacing) {
            ForEach(0..<characterCount, id: \.self) { index in
                digitBox(at: index)
            }
        }
        .frame(maxWidth: 326)
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
        .background(
            TextField("", text: $code)
                .keyboardType(digitsOnly ? .numberPad : .asciiCapable)
                .textContentType(.oneTimeCode)
                .textInputAutocapitalization(digitsOnly ? .never : .characters)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .focused($isFocused)
                .opacity(0.001)
                .onChange(of: code) { _, newValue in
                    let allowed = newValue.filter { character in
                        digitsOnly ? character.isNumber : (character.isLetter || character.isNumber)
                    }
                    let filtered = String(allowed.prefix(characterCount))
                    let normalized = digitsOnly ? filtered : filtered.uppercased()
                    if normalized != newValue {
                        code = normalized
                    }
                }
                .onSubmit {
                    guard code.count == characterCount else { return }
                    onSubmit?()
                }
        )
        .task {
            guard automaticallyFocus else { return }
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            isFocused = true
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            accessibilityLabel
                ?? appViewModel.localized(
                    "email_verification_code_accessibility_label",
                    fallback: "Verification code"
                )
        )
        .accessibilityValue(code)
    }

    private func digitBox(at index: Int) -> some View {
        let characters = Array(code)
        let character = index < characters.count ? String(characters[index]) : ""
        let activeIndex = min(code.count, characterCount - 1)
        let isActive = index == activeIndex && isFocused

        return ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isError ? AppDesign.Colors.error :
                                isActive ? AppDesign.Colors.primary :
                                !character.isEmpty ? AppDesign.Colors.primary.opacity(0.45) :
                                Color(.systemGray4),
                            lineWidth: isError || isActive ? 2 : 1
                        )
                )
                .frame(maxWidth: .infinity)
                .frame(height: boxHeight)

            Text(character)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(AppDesign.Colors.text)
        }
        .animation(AppDesign.Animation.quick, value: code)
        .animation(AppDesign.Animation.quick, value: isFocused)
        .animation(AppDesign.Animation.quick, value: isError)
    }

    private var boxSpacing: CGFloat {
        characterCount > 6 ? AppDesign.Spacing.xs : 10
    }

    private var boxHeight: CGFloat {
        characterCount > 6 ? 50 : 58
    }
}

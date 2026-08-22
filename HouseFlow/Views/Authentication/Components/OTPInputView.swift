import SwiftUI

struct OTPInputView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Binding var code: String
    let digitsOnly: Bool
    @FocusState private var isFocused: Bool

    init(code: Binding<String>, digitsOnly: Bool = false) {
        _code = code
        self.digitsOnly = digitsOnly
    }

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<6, id: \.self) { index in
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
                .focused($isFocused)
                .opacity(0.001)
                .onChange(of: code) { _, newValue in
                    let allowed = newValue.filter { character in
                        digitsOnly ? character.isNumber : (character.isLetter || character.isNumber)
                    }
                    let filtered = String(allowed.prefix(6))
                    let normalized = digitsOnly ? filtered : filtered.uppercased()
                    if normalized != newValue {
                        code = normalized
                    }
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(appViewModel.localized(
            "email_verification_code_accessibility_label",
            fallback: "Verification code"
        ))
        .accessibilityValue(code)
    }

    private func digitBox(at index: Int) -> some View {
        let characters = Array(code)
        let character = index < characters.count ? String(characters[index]) : ""
        let activeIndex = min(code.count, 5)
        let isActive = index == activeIndex && isFocused

        return ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isActive ? AppDesign.Colors.primary :
                                !character.isEmpty ? AppDesign.Colors.primary.opacity(0.45) :
                                Color(.systemGray4),
                            lineWidth: isActive ? 2 : 1
                        )
                )
                .frame(maxWidth: .infinity)
                .frame(height: 58)

            Text(character)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(AppDesign.Colors.text)
        }
        .animation(AppDesign.Animation.quick, value: code)
        .animation(AppDesign.Animation.quick, value: isFocused)
    }
}

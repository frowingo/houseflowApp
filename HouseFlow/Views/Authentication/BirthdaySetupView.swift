import SwiftUI
import HouseFlowCore

struct BirthdaySetupView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    @State private var selectedDate = Calendar.current.startOfDay(
        for: Calendar.current.date(
            byAdding: .year,
            value: -25,
            to: Date()
        ) ?? Date()
    )
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let accentOrange = FausBrand.orange
    private let accentInk = HouseJourneyTheme.accentOrangeInk
    private let earliestDate = Calendar.current.startOfDay(
        for: Calendar.current.date(
            byAdding: .year,
            value: -120,
            to: Date()
        ) ?? Date.distantPast
    )
    private let latestDate = Calendar.current.startOfDay(for: Date())

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                    contentCard
                        .padding(.horizontal, AppDesign.Spacing.xl)
                        .offset(y: -28)
                        .padding(.bottom, -28)
                }
            }
        }
        .task {
            populateExistingBirthday()
        }
    }

    private var heroSection: some View {
        ZStack {
            FausHeroBackground()
                .ignoresSafeArea(edges: .top)

            decorativeConfetti

            VStack(spacing: AppDesign.Spacing.lg) {
                FausBadge(size: 80) {
                    Image(systemName: "birthday.cake.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .fausGradientForeground()
                }

                VStack(spacing: AppDesign.Spacing.sm) {
                    Text(appViewModel.localized(
                        "birthday_setup_title",
                        fallback: "When is your birthday?"
                    ))
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(appViewModel.localized(
                        "birthday_setup_subtitle",
                        fallback: "Add your date of birth to complete your profile."
                    ))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.82))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppDesign.Spacing.xxxl)
                }
            }
            .padding(.top, AppDesign.Spacing.xl)
            .padding(.bottom, 58)
        }
        .frame(minHeight: 280)
    }

    private var decorativeConfetti: some View {
        GeometryReader { proxy in
            Group {
                confettiCircle(size: 12, opacity: 0.32)
                    .position(x: proxy.size.width * 0.13, y: 58)
                confettiCircle(size: 7, opacity: 0.7, color: Color(red: 1.0, green: 0.83, blue: 0.66))
                    .position(x: proxy.size.width * 0.82, y: 50)
                confettiCircle(size: 16, opacity: 0.18)
                    .position(x: proxy.size.width * 0.91, y: 154)
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white.opacity(0.34))
                    .position(x: proxy.size.width * 0.18, y: 178)
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 1.0, green: 0.83, blue: 0.66).opacity(0.55))
                    .position(x: proxy.size.width * 0.78, y: 210)
            }
        }
        .allowsHitTesting(false)
    }

    private func confettiCircle(size: CGFloat, opacity: Double, color: Color = .white) -> some View {
        Circle()
            .fill(color.opacity(opacity))
            .frame(width: size, height: size)
    }

    private var contentCard: some View {
        VStack(spacing: AppDesign.Spacing.xl) {
            VStack(spacing: AppDesign.Spacing.xs) {
                Label {
                    Text(appViewModel.localized(
                        "birthday_setup_date_label",
                        fallback: "Date of birth"
                    ))
                } icon: {
                    Image(systemName: "calendar")
                        .fausGradientForeground()
                }
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(AppDesign.Colors.textPrimary)

                Text(selectedDate.formatted(date: .long, time: .omitted))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accentInk)
                    .contentTransition(.numericText())
            }

            DatePicker(
                appViewModel.localized(
                    "birthday_setup_date_label",
                    fallback: "Date of birth"
                ),
                selection: normalizedDateSelection,
                in: earliestDate...latestDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .tint(accentOrange)

            HStack(alignment: .top, spacing: AppDesign.Spacing.sm) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(accentInk)
                Text(appViewModel.localized(
                    "birthday_setup_privacy_note",
                    fallback: "Your birthday is saved securely as part of your profile."
                ))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppDesign.Colors.textSecondary)
                Spacer(minLength: 0)
            }
            .padding(AppDesign.Spacing.md)
            .background(accentOrange.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))

            if let errorMessage {
                HStack(alignment: .top, spacing: AppDesign.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .medium))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(AppDesign.Colors.error)
                .padding(AppDesign.Spacing.md)
                .background(AppDesign.Colors.error.opacity(0.09))
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            saveButton
        }
        .padding(AppDesign.Spacing.xl)
        .background(AppDesign.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xxl))
        .shadow(color: FausBrand.deepBerry.opacity(0.12), radius: 22, x: 0, y: 10)
        .animation(AppDesign.Animation.standard, value: errorMessage)
    }

    private var saveButton: some View {
        Button(action: saveBirthday) {
            ZStack {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    HStack(spacing: AppDesign.Spacing.sm) {
                        Text(appViewModel.localized(
                            "birthday_setup_continue_button",
                            fallback: "Save and continue"
                        ))
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background {
                if isSaving {
                    Color(.systemGray4)
                } else {
                    FausBrand.buttonGradient
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl))
            .shadow(
                color: isSaving ? .clear : FausBrand.deepBerry.opacity(0.28),
                radius: 12,
                x: 0,
                y: 6
            )
        }
        .disabled(isSaving)
        .accessibilityHint(appViewModel.localized(
            "birthday_setup_continue_hint",
            fallback: "Saves your birthday and continues to the app."
        ))
    }

    private var normalizedDateSelection: Binding<Date> {
        Binding(
            get: { selectedDate },
            set: { selectedDate = Calendar.current.startOfDay(for: $0) }
        )
    }

    private func populateExistingBirthday() {
        guard
            let value = appViewModel.currentUserProfile?.birthDate,
            let parsedDate = HouseFlowDateFormatter.parseAPIDate(value)
        else { return }

        let date = Calendar.current.startOfDay(for: parsedDate)
        guard earliestDate...latestDate ~= date else { return }
        selectedDate = date
    }

    private func saveBirthday() {
        guard !isSaving else { return }
        let birthDate = selectedDate
        isSaving = true
        errorMessage = nil

        Task { @MainActor in
            do {
                try await appViewModel.completeBirthdaySetup(with: birthDate)
                // Root navigation removes this screen after a successful update.
                // Avoid touching its state once that transition starts.
                return
            } catch {
                isSaving = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    BirthdaySetupView()
        .environmentObject(AppViewModel())
}

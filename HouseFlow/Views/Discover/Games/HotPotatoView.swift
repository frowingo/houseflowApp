import SwiftUI

// MARK: - Phase
private enum HotPotatoPhase: Equatable {
    case setup
    case playing
    case exploded
}

// MARK: - Hot Potato View
struct HotPotatoView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var members: [String] = ["Ali", "Ayşe", "Mehmet", "Fatma"]
    @State private var newMemberName = ""
    @State private var showAddField = false
    @State private var phase: HotPotatoPhase = .setup
    @State private var currentIndex = 0
    @State private var passCount = 0
    @State private var bombPulse = false
    @State private var bombTask: Task<Void, Never>?
    @State private var resultAppeared = false

    private var currentHolder: String {
        guard !members.isEmpty else { return "" }
        return members[currentIndex % members.count]
    }

    var body: some View {
        ZStack {
            AppDesign.Colors.background.ignoresSafeArea()
            switch phase {
            case .setup:    setupView.transition(.opacity)
            case .playing:  playingView.transition(.opacity)
            case .exploded: explodedView.transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity), removal: .opacity))
            }
        }
        .navigationBarBackButtonHidden(phase != .setup)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { bombTask?.cancel() }
    }

    // MARK: - Setup (broken into sub-views to avoid Swift 6 type-checker crash)
    private var setupView: some View {
        VStack(spacing: 0) {
            potatoSetupHeader
            HotPotatoMemberList(members: $members, newMemberName: $newMemberName,
                                showAddField: $showAddField, onAddMember: addMember)
            Spacer(minLength: AppDesign.Spacing.lg)
            startGameButton
        }
    }

    private var potatoSetupHeader: some View {
        VStack(spacing: AppDesign.Spacing.sm) {
            ZStack {
                Circle().fill(Color.red.opacity(0.1)).frame(width: 80, height: 80)
                Text("💣").font(.system(size: 42))
            }
            Text("Hot Potato")
                .font(AppDesign.Typography.title2).foregroundStyle(AppDesign.Colors.textPrimary)
            Text("Pass it on! Whoever holds it when it explodes loses.")
                .font(AppDesign.Typography.subheadline).foregroundStyle(AppDesign.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, AppDesign.Spacing.xxl)
        .padding(.horizontal, AppDesign.Spacing.xl)
        .padding(.bottom, AppDesign.Spacing.xl)
    }

    private var startGameButton: some View {
        Button { startGame() } label: {
            Label("Start Game", systemImage: "flame.fill")
                .font(AppDesign.Typography.headline).foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: AppDesign.Size.buttonHeightLarge)
                .background(members.count >= 2 ? Color.red : Color.gray.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg))
        }
        .disabled(members.count < 2).buttonStyle(ScaleButtonStyle())
        .padding(.horizontal, AppDesign.Spacing.lg).padding(.bottom, AppDesign.Spacing.xxxl)
    }

    // MARK: - Playing
    private var playingView: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.12)).frame(width: 170, height: 170)
                    .scaleEffect(bombPulse ? 1.1 : 0.92)
                    .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: bombPulse)
                Text("💣").font(.system(size: 84))
            }
            .padding(.bottom, AppDesign.Spacing.xxl)
            VStack(spacing: AppDesign.Spacing.sm) {
                Text("Current holder:").font(AppDesign.Typography.subheadline).foregroundStyle(AppDesign.Colors.textSecondary)
                Text(currentHolder)
                    .font(.system(size: 34, weight: .black)).foregroundStyle(AppDesign.Colors.textPrimary)
                    .id(currentHolder)
                    .transition(.asymmetric(insertion: .scale(scale: 1.2).combined(with: .opacity), removal: .scale(scale: 0.8).combined(with: .opacity)))
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: currentHolder)
                Text("\(passCount) passes")
                    .font(AppDesign.Typography.caption).foregroundStyle(AppDesign.Colors.textTertiary)
                    .padding(.horizontal, AppDesign.Spacing.md).padding(.vertical, AppDesign.Spacing.xs)
                    .background(AppDesign.Colors.secondaryBackground).clipShape(Capsule())
            }
            Spacer()
            Button { pass() } label: {
                Text("🤲  PASS!")
                    .font(.system(size: 22, weight: .black)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: AppDesign.Size.buttonHeightLarge + 8)
                    .background(LinearGradient(colors: [Color.red, Color.orange], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl))
                    .shadow(color: Color.red.opacity(0.35), radius: 14, x: 0, y: 6)
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, AppDesign.Spacing.xl).padding(.bottom, AppDesign.Spacing.xxxl)
        }
        .onAppear { bombPulse = true }
        .onDisappear { bombPulse = false }
    }

    // MARK: - Exploded
    private var explodedView: some View {
        HotPotatoResultContent(
            holder: currentHolder, passCount: passCount, resultAppeared: $resultAppeared,
            onRetry: {
                resultAppeared = false; passCount = 0; currentIndex = 0
                withAnimation(.easeInOut(duration: 0.25)) { phase = .setup }
            },
            onDismiss: { dismiss() }
        )
        .onAppear { resultAppeared = true }
    }

    // MARK: - Logic
    private func addMember() {
        let trimmed = newMemberName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            members.append(trimmed); newMemberName = ""; showAddField = false
        }
    }

    private func startGame() {
        guard members.count >= 2 else { return }
        currentIndex = 0; passCount = 0
        withAnimation(.easeInOut(duration: 0.25)) { phase = .playing }
        let bombDelay = Double.random(in: 12 ... 28)
        bombTask?.cancel()
        bombTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(bombDelay * 1_000_000_000))
            if Task.isCancelled { return }
            await MainActor.run {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { phase = .exploded }
            }
        }
    }

    private func pass() {
        guard !members.isEmpty else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            passCount += 1
            currentIndex = (currentIndex + 1) % members.count
        }
    }
}

// MARK: - Hot Potato Member List
private struct HotPotatoMemberList: View {
    @Binding var members: [String]
    @Binding var newMemberName: String
    @Binding var showAddField: Bool
    let onAddMember: () -> Void

    var body: some View {
        VStack(spacing: AppDesign.Spacing.sm) {
            ForEach(members.indices, id: \.self) { index in
                MemberListRow(name: members[index], color: .red, canDelete: members.count > 2) {
                    deleteMember(at: index)
                }
            }
            addMemberControl
        }
        .padding(.horizontal, AppDesign.Spacing.lg)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showAddField)
    }

    private func deleteMember(at index: Int) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            members.remove(at: index)
        }
    }

    @ViewBuilder
    private var addMemberControl: some View {
        if showAddField {
            HStack(spacing: AppDesign.Spacing.md) {
                TextField("Enter name...", text: $newMemberName)
                    .font(AppDesign.Typography.body)
                    .padding(AppDesign.Spacing.md)
                    .background(AppDesign.Colors.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
                    .onSubmit { onAddMember() }
                Button { onAddMember() } label: {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 30)).foregroundStyle(Color.red)
                }
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        } else {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showAddField = true }
            } label: {
                Label("Add Member", systemImage: "plus.circle")
                    .font(AppDesign.Typography.bodyBold).foregroundStyle(Color.red)
                    .frame(maxWidth: .infinity).padding(AppDesign.Spacing.md)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
            }
            .transition(.opacity)
        }
    }
}

// MARK: - Hot Potato Result Content
private struct HotPotatoResultContent: View {
    let holder: String
    let passCount: Int
    @Binding var resultAppeared: Bool
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: AppDesign.Spacing.xxxl) {
            Spacer()
            Text("💥").font(.system(size: 100))
                .scaleEffect(resultAppeared ? 1 : 0.2)
                .animation(.spring(response: 0.5, dampingFraction: 0.4), value: resultAppeared)
            VStack(spacing: AppDesign.Spacing.sm) {
                Text("BOOM!").font(.system(size: 36, weight: .black)).foregroundStyle(Color.red)
                Text("\(holder) must do the chore!")
                    .font(AppDesign.Typography.headline).foregroundStyle(AppDesign.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                Text("passed \(passCount) times 🥵")
                    .font(AppDesign.Typography.subheadline).foregroundStyle(AppDesign.Colors.textSecondary)
            }
            .opacity(resultAppeared ? 1 : 0).offset(y: resultAppeared ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: resultAppeared)
            Spacer()
            VStack(spacing: AppDesign.Spacing.md) {
                Button { onRetry() } label: {
                    Label("Play Again", systemImage: "arrow.clockwise")
                        .font(AppDesign.Typography.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: AppDesign.Size.buttonHeightLarge)
                        .background(Color.red).clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg))
                }.buttonStyle(ScaleButtonStyle())
                Button { onDismiss() } label: {
                    Text("Main Menu").font(AppDesign.Typography.bodyBold).foregroundStyle(AppDesign.Colors.textSecondary)
                        .frame(maxWidth: .infinity).frame(height: AppDesign.Size.buttonHeight)
                }
            }
            .opacity(resultAppeared ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.38), value: resultAppeared)
        }
        .padding(.horizontal, AppDesign.Spacing.xl).padding(.bottom, AppDesign.Spacing.xxxl)
    }
}

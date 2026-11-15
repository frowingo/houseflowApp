import SwiftUI
import FausCrewCore

extension HouseTanksSetupStep {
    var titleKey: String {
        switch self {
        case .map: "house_tanks_map_pick"
        case .color: "house_tanks_step_color"
        case .difficulty: "house_tanks_step_difficulty"
        }
    }
}

/// Demo flow of the lobby: the numbered picks (map, tank color, difficulty) against the bots.
struct HouseTanksDemoSetupView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @ObservedObject var model: HouseTanksViewModel
    let isWaitingForLandscape: Bool
    /// The step the start button just sent the player to.
    let highlightedStep: HouseTanksSetupStep?

    private var copy: HouseTanksCopy { HouseTanksCopy(appViewModel) }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            setupStep(.map) {
                // An eager two-column grid: a lazy grid under-measures its last row while
                // scrolling, letting an odd last tile slide under the next section. Crowded-match
                // maps are online only.
                let maps = HouseTanksMapCatalog.demoMapIDs
                VStack(spacing: AppDesign.Spacing.md) {
                    ForEach(Array(stride(from: 0, to: maps.count, by: 2)), id: \.self) { start in
                        let row = Array(maps[start..<min(start + 2, maps.count)])
                        HStack(alignment: .top, spacing: AppDesign.Spacing.md) {
                            ForEach(row) { mapID in mapTile(mapID) }
                            if row.count == 1 { Color.clear.frame(maxWidth: .infinity) }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            setupStep(.color) {
                VStack(alignment: .leading, spacing: AppDesign.Spacing.lg) {
                    colorPicker
                    HouseTanksFieldTheme.hairline.frame(height: 1)
                    roster
                }
                .houseTanksFieldCard()
            }

            setupStep(.difficulty) {
                difficultyPicker
                    .houseTanksFieldCard()
            }
        }
        .disabled(isWaitingForLandscape)
    }

    /// One numbered pick with its status; the next missing pick gets a dashed frame.
    private func setupStep<Content: View>(_ step: HouseTanksSetupStep,
                                          @ViewBuilder content: () -> Content) -> some View {
        let isNext = model.pendingSetupStep == step
        let isHighlighted = highlightedStep == step
        return VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                HouseTanksSectionHeader(code: String(format: "%02d", (model.setupSteps.firstIndex(of: step) ?? 0) + 1),
                              key: step.titleKey)
                Spacer(minLength: AppDesign.Spacing.sm)
                stepBadge(step)
            }
            content()
        }
        .padding(isNext ? AppDesign.Spacing.sm : 0)
        .background {
            if isNext {
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md, style: .continuous)
                    .fill(HouseTanksMapPalette.khaki.opacity(isHighlighted ? 0.26 : 0.08))
            }
        }
        .overlay {
            if isNext {
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md, style: .continuous)
                    .stroke(HouseTanksMapPalette.umber.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            }
        }
        .padding(isNext ? -AppDesign.Spacing.sm : 0)
        .animation(.easeInOut(duration: 0.25), value: isNext)
        .animation(.easeInOut(duration: 0.25), value: isHighlighted)
        .id(step)
    }

    private func stepBadge(_ step: HouseTanksSetupStep) -> some View {
        let done = model.isComplete(step)
        let isNext = model.pendingSetupStep == step
        let key = done ? "house_tanks_step_done" : isNext ? "house_tanks_step_next" : "house_tanks_step_waiting"
        let tint = done ? HouseTanksMapPalette.steel : isNext ? HouseTanksMapPalette.umber : HouseTanksFieldTheme.muted
        return Label(copy(key), systemImage: done ? "checkmark.circle.fill" : isNext ? "hand.point.down.fill" : "circle.dashed")
            .font(HouseTanksFieldTheme.stencil)
            .tracking(1)
            .foregroundStyle(tint)
            .padding(.horizontal, AppDesign.Spacing.sm)
            .padding(.vertical, 3)
            .background(tint.opacity(0.12), in: Capsule())
    }

    private func mapTile(_ mapID: HouseTanksMapID) -> some View {
        let selected = model.mapID == mapID
        return Button { model.mapID = mapID } label: {
            VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
                HouseTanksMapPreview(mapID: mapID, isSelected: selected)
                    .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xs, style: .continuous))
                HStack(spacing: AppDesign.Spacing.xs) {
                    Text(copy(mapID.titleKey))
                        .font(.headline)
                        .foregroundStyle(HouseTanksFieldTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(HouseTanksFieldTheme.accent)
                    }
                }
                Text(copy(mapID.detailKey))
                    .font(.caption)
                    .foregroundStyle(HouseTanksFieldTheme.muted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(AppDesign.Spacing.sm)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(selected ? HouseTanksMapPalette.paper : HouseTanksFieldTheme.surface.opacity(0.7),
                        in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous)
                    .stroke(selected ? HouseTanksFieldTheme.accent : HouseTanksFieldTheme.hairline,
                            lineWidth: selected ? 2 : 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
            fieldLabel("house_tanks_color")
            LazyVGrid(columns: HouseTanksColorSwatch.gridColumns, spacing: AppDesign.Spacing.sm) {
                ForEach(HouseTanksColor.allCases) { color in
                    HouseTanksColorSwatch(color: color, isSelected: model.humanColor == color) {
                        model.humanColor = color
                    }
                }
            }
        }
    }

    private var difficultyPicker: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
            fieldLabel("house_tanks_difficulty")
            Picker(copy("house_tanks_difficulty"), selection: $model.difficulty) {
                ForEach(HouseTanksDifficulty.allCases) { difficulty in
                    Text(copy(difficulty.titleKey)).tag(Optional(difficulty))
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 300)
            if model.difficulty == .hard {
                Label(copy("house_tanks_difficulty_hard_note"), systemImage: "scope")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HouseTanksFieldTheme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var roster: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
            fieldLabel("house_tanks_roster")
            // Bot colors are whatever the player leaves; until then the roster stays blank.
            let botColors: [HouseTanksColor?] = model.humanColor.map { human in
                HouseTanksColor.allCases.filter { $0 != human }
            } ?? Array(repeating: nil, count: HouseTanksMatchConfiguration.botNameKeys.count)
            let entries = [("house_tanks_you", "house_tanks_human_role", model.humanColor)]
                + zip(HouseTanksMatchConfiguration.botNameKeys.prefix(HouseTanksMapDefinition.demoStandardPlayerCount - 1), botColors)
                    .map { ($0, "house_tanks_bot_role", $1) }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: AppDesign.Spacing.sm),
                                GridItem(.flexible(), spacing: AppDesign.Spacing.sm)],
                      spacing: AppDesign.Spacing.sm) {
                ForEach(entries, id: \.0) { rosterChip(nameKey: $0.0, roleKey: $0.1, color: $0.2) }
            }
        }
    }

    private func rosterChip(nameKey: String, roleKey: String, color: HouseTanksColor?) -> some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color.map(\.swatchColor) ?? .clear)
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(HouseTanksFieldTheme.ink.opacity(0.4),
                                         style: StrokeStyle(lineWidth: 1, dash: color == nil ? [2, 2] : [])))
            VStack(alignment: .leading, spacing: 1) {
                Text(copy(nameKey))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(HouseTanksFieldTheme.ink)
                    .lineLimit(1)
                Text(copy(roleKey))
                    .font(HouseTanksFieldTheme.stencil)
                    .foregroundStyle(HouseTanksFieldTheme.muted)
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
        .background(HouseTanksMapPalette.sand.opacity(0.5),
                    in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xs, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func fieldLabel(_ key: String) -> some View {
        Text(copy(key).uppercased())
            .font(HouseTanksFieldTheme.stencil)
            .tracking(1.2)
            .foregroundStyle(HouseTanksFieldTheme.muted)
    }
}

/// Starts the match once every pick is made; until then it leads to the next missing pick.
struct HouseTanksDemoStartBar: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @ObservedObject var model: HouseTanksViewModel
    let isLandscapeLayout: Bool
    let isWaitingForLandscape: Bool
    /// Briefly marks the step the button sent the player to.
    @Binding var highlightedStep: HouseTanksSetupStep?
    let proxy: ScrollViewProxy
    let onStart: () -> Void

    private var copy: HouseTanksCopy { HouseTanksCopy(appViewModel) }

    var body: some View {
        let pending = model.pendingSetupStep
        VStack(spacing: AppDesign.Spacing.sm) {
            if let pending {
                HStack(spacing: AppDesign.Spacing.sm) {
                    HStack(spacing: 3) {
                        ForEach(model.setupSteps) { step in
                            Capsule()
                                .fill(model.isComplete(step) ? HouseTanksMapPalette.steel : HouseTanksMapPalette.slate.opacity(0.25))
                                .frame(width: 18, height: 4)
                        }
                    }
                    Text(copy("house_tanks_setup_progress", replacements: ["done": "\(model.completedSetupSteps)",
                                                                             "total": "\(model.setupSteps.count)"]))
                        .font(HouseTanksFieldTheme.stencil)
                        .foregroundStyle(HouseTanksFieldTheme.muted)
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)

                Button { guide(to: pending) } label: {
                    HStack(spacing: AppDesign.Spacing.sm) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text(copy("house_tanks_setup_next", replacements: ["step": copy(pending.titleKey)]))
                    }
                    .font(.headline)
                    .foregroundStyle(HouseTanksMapPalette.paper)
                    .frame(maxWidth: .infinity, minHeight: AppDesign.Size.buttonHeightLarge)
                    .background(HouseTanksMapPalette.umber,
                                in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityHint(copy("house_tanks_setup_hint"))
            } else {
                Button(action: onStart) {
                    HStack(spacing: AppDesign.Spacing.sm) {
                        if isWaitingForLandscape {
                            ProgressView().tint(HouseTanksMapPalette.paper)
                            Text(copy("house_tanks_rotating"))
                        } else {
                            Image(systemName: isLandscapeLayout ? "scope" : "rectangle.landscape.rotate")
                            Text(copy("house_tanks_start"))
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(HouseTanksMapPalette.paper)
                    .frame(maxWidth: .infinity, minHeight: AppDesign.Size.buttonHeightLarge)
                    .background(HouseTanksMapPalette.steel,
                                in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(isWaitingForLandscape)
            }
        }
        .padding(.horizontal, AppDesign.Spacing.xl)
        .padding(.vertical, AppDesign.Spacing.lg)
        .frame(maxWidth: 620)
        .frame(maxWidth: .infinity)
        .background(HouseTanksMapPalette.paper.opacity(0.94))
        .overlay(alignment: .top) { HouseTanksFieldTheme.hairline.frame(height: 1) }
    }

    private func guide(to step: HouseTanksSetupStep) {
        withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(step, anchor: .top) }
        highlightedStep = step
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if highlightedStep == step { highlightedStep = nil }
        }
    }
}

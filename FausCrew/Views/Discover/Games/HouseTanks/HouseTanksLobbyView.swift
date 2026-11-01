import SwiftUI
import FausCrewCore

/// Entry flow: choose demo or online, then set up the match on a field-map sheet.
/// Orientation and match start stay with HouseTanksView.
struct HouseTanksLobbyView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @ObservedObject var model: HouseTanksViewModel
    let isLandscapeLayout: Bool
    let isWaitingForLandscape: Bool
    let orientationRequestFailed: Bool
    let onStart: () -> Void
    /// Briefly marks the step the start button sent the player to.
    @State private var highlightedStep: HouseTanksSetupStep?
    @State private var showsJokers = false

    var body: some View {
        ScrollViewReader { proxy in
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    if let mode = model.selectedMode {
                        modeBar(mode)
                        if mode == .demo {
                            demoSetup
                        } else {
                            onlineRoom
                        }
                    } else {
                        modeSelection
                    }

                    fieldManual

                    if model.selectedMode == .demo || orientationRequestFailed {
                        Label(copy(orientationRequestFailed ? "house_tanks_landscape_error" : "house_tanks_landscape_detail"),
                              systemImage: "rectangle.landscape.rotate")
                            .font(.subheadline)
                            .foregroundStyle(orientationRequestFailed ? HouseTanksFieldTheme.danger : HouseTanksFieldTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, AppDesign.Spacing.xl)
                .padding(.top, AppDesign.Spacing.xl)
                .padding(.bottom, AppDesign.Spacing.xxl)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }

            if model.selectedMode == .demo {
                startButton(proxy: proxy)
            } else if showsOnlineActionBar {
                onlineActionBar
            }
        }
        }
    }

    // MARK: - Header and mode

    private var header: some View {
        HStack(alignment: .center, spacing: AppDesign.Spacing.lg) {
            HouseTanksArenaTank(tint: .white)
                .frame(width: 70, height: 70)
                .frame(width: 88, height: 88)
                .background(HouseTanksMapPalette.steel,
                            in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md, style: .continuous))
                .overlay {
                    HouseTanksCornerMarks(length: 7)
                        .stroke(HouseTanksMapPalette.paper.opacity(0.7), lineWidth: 1.2)
                        .padding(6)
                }

            VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
                Text(copy("house_tanks_kicker"))
                    .font(HouseTanksFieldTheme.stencil)
                    .tracking(1.4)
                    .foregroundStyle(HouseTanksMapPalette.umber)
                Text(copy("house_tanks_title"))
                    .font(.largeTitle.weight(.black))
                    .fontWidth(.condensed)
                    .foregroundStyle(HouseTanksFieldTheme.ink)
                Text(copy(subtitleKey))
                    .font(.subheadline)
                    .foregroundStyle(HouseTanksFieldTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var subtitleKey: String {
        switch model.selectedMode {
        case .demo: "house_tanks_subtitle"
        case .online: "house_tanks_online_subtitle"
        case nil: "house_tanks_mode_prompt"
        }
    }

    private var modeSelection: some View {
        VStack(spacing: AppDesign.Spacing.md) {
            ForEach(HouseTanksMode.allCases) { mode in modeCard(mode) }
        }
    }

    private func modeCard(_ mode: HouseTanksMode) -> some View {
        let isDemo = mode == .demo
        let tint = isDemo ? HouseTanksMapPalette.steel : HouseTanksMapPalette.khaki
        let tintInk = isDemo ? HouseTanksMapPalette.steel : HouseTanksMapPalette.umber
        return Button { model.selectMode(mode) } label: {
            VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
                HStack(spacing: AppDesign.Spacing.md) {
                    Image(systemName: isDemo ? "scope" : "person.2.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(HouseTanksMapPalette.paper)
                        .frame(width: 44, height: 44)
                        .background(tint, in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: isDemo ? "OP-01" : "OP-02")
                            .font(HouseTanksFieldTheme.stencil)
                            .tracking(1.4)
                            .foregroundStyle(HouseTanksFieldTheme.muted)
                        Text(copy(isDemo ? "house_tanks_mode_demo_title" : "house_tanks_mode_online_title"))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(HouseTanksFieldTheme.ink)
                    }
                    Spacer(minLength: 0)
                    Label(copy(isDemo ? "house_tanks_mode_demo_map" : "house_tanks_mode_online_map"),
                          systemImage: isDemo ? "map" : "dice")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tintInk)
                        .padding(.horizontal, AppDesign.Spacing.sm)
                        .padding(.vertical, AppDesign.Spacing.xs)
                        .background(tint.opacity(0.14), in: Capsule())
                }
                Text(copy(isDemo ? "house_tanks_mode_demo_detail" : "house_tanks_mode_online_detail"))
                    .font(.subheadline)
                    .foregroundStyle(HouseTanksFieldTheme.muted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                // A filled action strip makes the whole card read as a control.
                HStack(spacing: AppDesign.Spacing.sm) {
                    Text(copy(isDemo ? "house_tanks_mode_demo_action" : "house_tanks_mode_online_action"))
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right")
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(HouseTanksMapPalette.paper)
                .padding(.horizontal, AppDesign.Spacing.md)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(tintInk, in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xs, style: .continuous))
            }
            .houseTanksFieldCard()
            .overlay(alignment: .leading) {
                Rectangle().fill(tint).frame(width: 3).padding(.vertical, AppDesign.Spacing.lg)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(HouseTanksRaisedButtonStyle(depth: tint))
    }

    private func modeBar(_ mode: HouseTanksMode) -> some View {
        HStack(spacing: AppDesign.Spacing.md) {
            Label(copy(mode == .demo ? "house_tanks_mode_demo_title" : "house_tanks_mode_online_title"),
                  systemImage: mode == .demo ? "scope" : "person.2")
                .font(.title3.weight(.bold))
            Spacer()
            Button(copy("house_tanks_change_mode"), action: model.returnToModeSelection)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(HouseTanksFieldTheme.accent)
                .frame(minHeight: 44)
                .disabled(isWaitingForLandscape)
        }
        .foregroundStyle(HouseTanksFieldTheme.ink)
        .padding(.bottom, AppDesign.Spacing.sm)
        .overlay(alignment: .bottom) {
            HouseTanksFieldTheme.hairline.frame(height: 1)
        }
    }

    // MARK: - Demo

    private var demoSetup: some View {
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
                sectionHeader(code: String(format: "%02d", (model.setupSteps.firstIndex(of: step) ?? 0) + 1),
                              key: stepTitleKey(step))
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

    private func stepTitleKey(_ step: HouseTanksSetupStep) -> String {
        switch step {
        case .map: "house_tanks_map_pick"
        case .color: "house_tanks_step_color"
        case .difficulty: "house_tanks_step_difficulty"
        }
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
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppDesign.Spacing.sm), count: 4),
                      spacing: AppDesign.Spacing.sm) {
                ForEach(HouseTanksColor.allCases) { color in tankSwatch(color) }
            }
        }
    }

    /// The player's own tank in each color, as it will look on the arena.
    private func tankSwatch(_ color: HouseTanksColor) -> some View {
        let selected = model.humanColor == color
        return Button { model.humanColor = color } label: {
            VStack(spacing: AppDesign.Spacing.xs) {
                HouseTanksArenaTank(color: color)
                    .frame(width: 52, height: 52)
                Text(colorName(color))
                    .font(.caption.weight(selected ? .bold : .semibold))
                    .foregroundStyle(selected ? HouseTanksFieldTheme.ink : HouseTanksFieldTheme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, AppDesign.Spacing.sm)
            .frame(maxWidth: .infinity)
            .background(selected ? HouseTanksMapPalette.paper : HouseTanksMapPalette.sand.opacity(0.35),
                        in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous)
                    .stroke(selected ? swatch(color) : HouseTanksFieldTheme.hairline, lineWidth: selected ? 2 : 1)
            }
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(swatch(color))
                        .padding(5)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(colorName(color))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
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
                .fill(color.map(swatch) ?? .clear)
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

    /// Starts the match once every pick is made; until then it leads to the next missing pick.
    private func startButton(proxy: ScrollViewProxy) -> some View {
        let pending = model.pendingSetupStep
        return VStack(spacing: AppDesign.Spacing.sm) {
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

                Button { guide(to: pending, proxy: proxy) } label: {
                    HStack(spacing: AppDesign.Spacing.sm) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text(copy("house_tanks_setup_next", replacements: ["step": copy(stepTitleKey(pending))]))
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

    private func guide(to step: HouseTanksSetupStep, proxy: ScrollViewProxy) {
        withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(step, anchor: .top) }
        highlightedStep = step
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if highlightedStep == step { highlightedStep = nil }
        }
    }

    // MARK: - Online

    @ViewBuilder
    private var onlineRoom: some View {
        if let blockerKey = onlineBlockerKey {
            onlineNotice(title: "house_tanks_online_unavailable", detail: blockerKey, symbol: "wifi.exclamationmark")
        } else if model.onlineCatalog == .unavailable {
            onlineNotice(title: "house_tanks_online_closed", detail: "house_tanks_online_closed_detail", symbol: "lock.fill")
        } else {
            VStack(alignment: .leading, spacing: 28) {
                onlineStatus
                drawnMap
                onlineRoster
            }
            .task(id: roomContext) {
                guard let context = roomContext, let houseID = context.houseID else { return }
                await model.refreshOnlineCatalog(houseID: houseID)
                guard !Task.isCancelled else { return }
                model.enterOnlineRoom(context: context)
            }
        }
    }

    /// The house and player the room belongs to; a change reopens it.
    private var roomContext: GameLaunchContext? {
        guard let userID = appViewModel.currentUserId, let house = appViewModel.currentHouseDetails else { return nil }
        return GameLaunchContext(houseID: house.id, localPlayerID: userID, houseOwnerID: house.ownerId)
    }

    private var onlineBlockerKey: String? {
        guard let userID = appViewModel.currentUserId, !userID.isEmpty else { return "house_tanks_online_sign_in" }
        guard appViewModel.currentHouseDetails != nil else { return "house_tanks_online_house_required" }
        guard model.isOnlineServiceAvailable else { return "house_tanks_online_soon_detail" }
        return nil
    }

    private func onlineNotice(title: String, detail: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            Label(copy(title), systemImage: symbol)
                .font(.headline)
                .foregroundStyle(HouseTanksFieldTheme.ink)
            Text(copy(detail))
                .font(.subheadline)
                .foregroundStyle(HouseTanksFieldTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .houseTanksFieldCard(padding: AppDesign.Spacing.xl)
    }

    private var onlineStatus: some View {
        let state = model.onlineState
        let minimum = state.session?.rules.minimumPlayers ?? 2
        let warns = state.requiresUpdate || state.connection == .failed
        return VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            HStack(alignment: .top, spacing: AppDesign.Spacing.md) {
                Group {
                    if HouseTanksOnlineCopyKeys.showsProgress(state) {
                        ProgressView().tint(HouseTanksMapPalette.steel)
                    } else {
                        Image(systemName: onlineStatusSymbol(state))
                            .foregroundStyle(warns ? HouseTanksFieldTheme.danger : HouseTanksMapPalette.steel)
                    }
                }
                .font(.title3.weight(.bold))
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
                    Text(copy(HouseTanksOnlineCopyKeys.roomStatus(state)))
                        .font(.headline)
                        .foregroundStyle(warns ? HouseTanksFieldTheme.danger : HouseTanksFieldTheme.ink)
                    Text(copy(HouseTanksOnlineCopyKeys.roomDetail(state), replacements: ["minimum": "\(minimum)"]))
                        .font(.subheadline)
                        .foregroundStyle(HouseTanksFieldTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    // A rejected command or timeout while the room stays connected.
                    if state.connection == .connected, let issue = state.issue {
                        Text(copy(HouseTanksOnlineCopyKeys.issue(issue)))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(HouseTanksFieldTheme.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)

            if state.connection == .failed, state.canReconnect(at: .infinity) {
                Button(action: model.retryOnline) {
                    Label(copy("house_tanks_online_retry"), systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(HouseTanksMapPalette.paper)
                        .padding(.horizontal, AppDesign.Spacing.lg)
                        .frame(minHeight: AppDesign.Size.buttonHeightSmall)
                        .background(HouseTanksMapPalette.steel,
                                    in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .houseTanksFieldCard()
    }

    private func onlineStatusSymbol(_ state: HouseTanksOnlineLobbyState) -> String {
        if state.requiresUpdate { return "arrow.down.app.fill" }
        if state.connection == .failed { return "wifi.exclamationmark" }
        if state.isTerminal { return "flag.checkered" }
        return "dot.radiowaves.left.and.right"
    }

    /// Before the draw the card counts down to the match; once the server draws the arena
    /// it shows the map (with the match countdown over it).
    @ViewBuilder
    private var drawnMap: some View {
        if let arena = model.onlineArena {
            VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
                sectionHeader(code: "01", key: "house_tanks_online_map_title")
                VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
                    HouseTanksMapPreview(mapID: arena.map.id, isSelected: true, seats: arena.tanks.map {
                        .init(x: $0.position.x / HouseTanksWorld.arenaSize.width,
                              y: $0.position.y / HouseTanksWorld.arenaSize.height,
                              rotation: $0.rotation, color: $0.color)
                    })
                    .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xs, style: .continuous))
                    .overlay { countdownStamp }
                    .overlay(alignment: .topTrailing) { randomStamp }
                    HStack(alignment: .firstTextBaseline, spacing: AppDesign.Spacing.sm) {
                        Image(systemName: "dice.fill")
                            .foregroundStyle(HouseTanksMapPalette.umber)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(copy(arena.map.id.titleKey))
                                .font(.headline)
                                .foregroundStyle(HouseTanksFieldTheme.ink)
                            Text(copy(arena.map.id.detailKey))
                                .font(.caption)
                                .foregroundStyle(HouseTanksFieldTheme.muted)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    Text(copy("house_tanks_online_map_detail"))
                        .font(.caption)
                        .foregroundStyle(HouseTanksFieldTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .houseTanksFieldCard()
            }
        } else {
            VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
                sectionHeader(code: "01", key: "house_tanks_online_start_title")
                VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
                    startCountdown
                    Text(copy("house_tanks_online_map_pending"))
                        .font(.caption)
                        .foregroundStyle(HouseTanksFieldTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .houseTanksFieldCard()
            }
        }
    }

    /// The ready window's seconds as large as the map that replaces them; before the window
    /// opens, how many ready players start it.
    private var startCountdown: some View {
        let state = model.onlineState
        return TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            let seconds = state.session?.state == .readyWindow || state.session?.state == .countdown
                ? model.onlineCountdown() : nil
            VStack(spacing: AppDesign.Spacing.xs) {
                if let seconds {
                    Text(copy("house_tanks_online_start_until"))
                        .font(HouseTanksFieldTheme.stencil)
                        .foregroundStyle(HouseTanksFieldTheme.muted)
                    HStack(alignment: .firstTextBaseline, spacing: AppDesign.Spacing.xs) {
                        Text(verbatim: "\(seconds)")
                            .font(.system(size: 88, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText(countsDown: true))
                            .foregroundStyle(seconds <= 5 ? HouseTanksFieldTheme.danger : HouseTanksFieldTheme.ink)
                        Text(copy("house_tanks_online_seconds_unit"))
                            .font(.title3.weight(.heavy))
                            .foregroundStyle(HouseTanksFieldTheme.muted)
                    }
                    .animation(.snappy, value: seconds)
                } else {
                    Image(systemName: "hourglass")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(HouseTanksMapPalette.umber)
                    Text(copy("house_tanks_online_start_waiting"))
                        .font(.headline)
                        .foregroundStyle(HouseTanksFieldTheme.ink)
                    Text(copy("house_tanks_online_start_waiting_detail",
                              replacements: ["minimum": "\(state.session?.rules.minimumPlayers ?? 2)"]))
                        .font(.caption)
                        .foregroundStyle(HouseTanksFieldTheme.muted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if state.session != nil {
                    Text(copy("house_tanks_online_ready_count",
                              replacements: ["ready": "\(state.readyCount)", "total": "\(state.participants.count)"]))
                        .font(HouseTanksFieldTheme.stencil)
                        .foregroundStyle(HouseTanksMapPalette.steel)
                }
            }
            .padding(AppDesign.Spacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
        }
        .aspectRatio(872 / 400, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .background(HouseTanksMapPalette.sand.opacity(0.45),
                    in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xs, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xs, style: .continuous)
            .stroke(HouseTanksMapPalette.slate.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
    }

    private var randomStamp: some View {
        Text(copy("house_tanks_random_stamp"))
            .font(.system(.caption, design: .monospaced).weight(.heavy))
            .tracking(1.6)
            .foregroundStyle(HouseTanksMapPalette.umber)
            .padding(.horizontal, AppDesign.Spacing.sm)
            .padding(.vertical, 3)
            .overlay(Rectangle().stroke(HouseTanksMapPalette.umber, lineWidth: 1.5))
            .background(HouseTanksMapPalette.paper.opacity(0.8))
            .rotationEffect(.degrees(-8))
            .padding(AppDesign.Spacing.md)
    }

    /// The match countdown over the drawn map, from the server's deadline.
    private var countdownStamp: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            if model.onlineState.game?.phase == .countdown, let seconds = model.onlineCountdown() {
                Text(verbatim: "\(max(1, seconds))")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(HouseTanksMapPalette.paper)
                    .frame(width: 92, height: 92)
                    .background(HouseTanksMapPalette.ink.opacity(0.72), in: Circle())
                    .accessibilityLabel(copy("house_tanks_online_seconds", replacements: ["seconds": "\(seconds)"]))
            }
        }
    }

    private var onlineRoster: some View {
        let state = model.onlineState
        return VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                sectionHeader(code: "02", key: "house_tanks_online_roster")
                Spacer(minLength: AppDesign.Spacing.sm)
                if state.session != nil {
                    Text(copy("house_tanks_online_ready_count",
                              replacements: ["ready": "\(state.readyCount)", "total": "\(state.participants.count)"]))
                        .font(HouseTanksFieldTheme.stencil)
                        .foregroundStyle(HouseTanksFieldTheme.muted)
                }
            }
            VStack(spacing: AppDesign.Spacing.md) {
                if onlineMembers.isEmpty {
                    Text(copy("house_tanks_online_syncing"))
                        .font(.subheadline)
                        .foregroundStyle(HouseTanksFieldTheme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(onlineMembers) { member in
                    HStack(spacing: AppDesign.Spacing.sm) {
                        Circle()
                            .fill(member.color.map(swatch) ?? HouseTanksMapPalette.slate.opacity(0.5))
                            .frame(width: 10, height: 10)
                        Text(verbatim: member.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(HouseTanksFieldTheme.ink)
                            .lineLimit(1)
                        if member.isLocal {
                            Text(copy("house_tanks_you"))
                                .font(.caption)
                                .foregroundStyle(HouseTanksFieldTheme.muted)
                        }
                        Spacer(minLength: AppDesign.Spacing.sm)
                        Label(copy(HouseTanksOnlineCopyKeys.playerStatus(member.state)),
                              systemImage: member.state == .ready ? "checkmark.seal.fill" : "clock")
                            .font(HouseTanksFieldTheme.stencil)
                            .foregroundStyle(member.state == .ready ? HouseTanksMapPalette.steel : HouseTanksFieldTheme.muted)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .houseTanksFieldCard()
        }
    }

    /// Ready toggle and the creator's cancel, pinned under the room; the window counts down in the room.
    private var onlineActionBar: some View {
        let state = model.onlineState
        let localID = appViewModel.currentUserId
        let isReady = state.localPlayer(localID)?.state == .ready
        return VStack(spacing: AppDesign.Spacing.sm) {
            Button { model.setOnlineReady(!isReady) } label: {
                HStack(spacing: AppDesign.Spacing.sm) {
                    Image(systemName: isReady ? "xmark.circle" : "checkmark.circle.fill")
                    Text(copy(isReady ? "house_tanks_online_not_ready" : "house_tanks_online_ready"))
                }
                .font(.headline)
                .foregroundStyle(HouseTanksMapPalette.paper)
                .frame(maxWidth: .infinity, minHeight: AppDesign.Size.buttonHeightLarge)
                .background(isReady ? HouseTanksMapPalette.umber : HouseTanksMapPalette.steel,
                            in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(!state.canChangeReady(playerID: localID))
            .opacity(state.canChangeReady(playerID: localID) ? 1 : 0.5)

            if model.onlineState.canCancel(context: roomContext ?? GameLaunchContext(houseID: nil, localPlayerID: nil)) {
                Button(copy("house_tanks_online_cancel"), role: .destructive, action: model.cancelOnlineMatch)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HouseTanksFieldTheme.danger)
            }
        }
        .padding(.horizontal, AppDesign.Spacing.xl)
        .padding(.vertical, AppDesign.Spacing.lg)
        .frame(maxWidth: 620)
        .frame(maxWidth: .infinity)
        .background(HouseTanksMapPalette.paper.opacity(0.94))
        .overlay(alignment: .top) { HouseTanksFieldTheme.hairline.frame(height: 1) }
    }

    private var showsOnlineActionBar: Bool {
        model.selectedMode == .online && onlineBlockerKey == nil && model.onlineCatalog != .unavailable
            && model.onlineState.session != nil && model.onlineState.isLobby && !model.onlineState.isTerminal
    }

    private struct OnlineMember: Identifiable {
        let id: String
        let name: String
        let isLocal: Bool
        let state: GameSessionPlayerState
        let color: HouseTanksColor?
    }

    /// The session's players, the local one first, named from the house roster and
    /// colored once the server seats them.
    private var onlineMembers: [OnlineMember] {
        let localID = appViewModel.currentUserId
        let names = Dictionary((appViewModel.currentHouseDetails?.members ?? []).map { ($0.id, $0.fullName) },
                               uniquingKeysWith: { first, _ in first })
        let seated = Dictionary((model.onlineState.game?.players ?? []).map { ($0.playerId, $0) },
                                uniquingKeysWith: { first, _ in first })
        let members = model.onlineState.participants.map { player in
            OnlineMember(id: player.playerId,
                         name: seated[player.playerId]?.displayName ?? names[player.playerId] ?? copy("house_tanks_online_player"),
                         isLocal: player.playerId == localID, state: player.state,
                         color: seated[player.playerId]?.color)
        }
        return members.filter(\.isLocal) + members.filter { !$0.isLocal }
    }

    // MARK: - Field manual

    private var fieldManual: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.lg) {
            sectionHeader(code: fieldManualCode, key: "house_tanks_rules_title")
            VStack(alignment: .leading, spacing: 0) {
                guideStep(title: "house_tanks_rule_fire", detail: "house_tanks_rule_fire_detail",
                          symbol: "scope", tint: HouseTanksMapPalette.steel)
                guideStep(title: "house_tanks_rule_drive", detail: "house_tanks_rule_drive_detail",
                          symbol: "arrow.up", tint: HouseTanksMapPalette.deepSteel)
                guideStep(title: "house_tanks_rule_survive", detail: "house_tanks_rule_survive_detail",
                          symbol: "shield.lefthalf.filled", tint: HouseTanksMapPalette.rust)
                guideStep(title: "house_tanks_rule_crates", detail: "house_tanks_rule_crates_detail",
                          symbol: "shippingbox.fill", tint: HouseTanksMapPalette.khaki)
                guideStep(title: "house_tanks_rule_jokers", detail: "house_tanks_rule_jokers_detail",
                          symbol: "bolt.fill", tint: HouseTanksMapPalette.olive, isLast: true) {
                    jokerAccordion
                }
            }
        }
    }

    private func guideStep(title: String, detail: String, symbol: String,
                           tint: Color, isLast: Bool = false) -> some View {
        guideStep(title: title, detail: detail, symbol: symbol, tint: tint, isLast: isLast) { EmptyView() }
    }

    /// Every joker with its arena glyph, name and effect, folded under "Collect a joker".
    private var jokerAccordion: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { showsJokers.toggle() }
            } label: {
                HStack(spacing: AppDesign.Spacing.sm) {
                    HStack(spacing: -5) {
                        ForEach(HouseTanksPowerUp.allCases, id: \.self) { kind in
                            jokerGlyph(kind, side: 10)
                                .frame(width: 22, height: 22)
                                .background(Color(uiColor: kind.tint), in: Circle())
                                .overlay(Circle().stroke(HouseTanksMapPalette.paper, lineWidth: 1.5))
                        }
                    }
                    Text(copy(showsJokers ? "house_tanks_jokers_hide" : "house_tanks_jokers_show",
                              replacements: ["count": "\(HouseTanksPowerUp.allCases.count)"]))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(HouseTanksFieldTheme.ink)
                    Spacer(minLength: AppDesign.Spacing.xs)
                    Image(systemName: "chevron.down")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(HouseTanksFieldTheme.accent)
                        .rotationEffect(.degrees(showsJokers ? 180 : 0))
                }
                .padding(.horizontal, AppDesign.Spacing.md)
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(copy("house_tanks_jokers_hint"))

            if showsJokers {
                HouseTanksFieldTheme.hairline.frame(height: 1)
                VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
                    ForEach(HouseTanksPowerUp.allCases, id: \.self) { kind in
                        HStack(alignment: .top, spacing: AppDesign.Spacing.md) {
                            jokerGlyph(kind, side: 17)
                                .frame(width: 36, height: 36)
                                .background(Color(uiColor: kind.tint),
                                            in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xs, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(copy(kind.titleKey))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(HouseTanksFieldTheme.ink)
                                Text(copy("house_tanks_joker_\(kind.rawValue)_detail"))
                                    .font(.caption)
                                    .foregroundStyle(HouseTanksFieldTheme.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(AppDesign.Spacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(HouseTanksMapPalette.paper.opacity(0.9),
                    in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous)
                .stroke(showsJokers ? HouseTanksFieldTheme.accent.opacity(0.5) : HouseTanksFieldTheme.hairline, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous))
        .padding(.top, AppDesign.Spacing.xs)
    }

    private func jokerGlyph(_ kind: HouseTanksPowerUp, side: CGFloat) -> some View {
        Image(uiImage: kind.glyph(pointSize: 18) ?? UIImage())
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: side, height: side)
            .foregroundStyle(HouseTanksMapPalette.paper)
    }

    private func guideStep<Accessory: View>(title: String, detail: String, symbol: String,
                                            tint: Color, isLast: Bool = false,
                                            @ViewBuilder accessory: () -> Accessory) -> some View {
        HStack(alignment: .top, spacing: AppDesign.Spacing.lg) {
            VStack(spacing: 0) {
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(HouseTanksMapPalette.paper)
                    .frame(width: 44, height: 44)
                    .background(tint, in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous))
                    .accessibilityHidden(true)
                if !isLast {
                    Rectangle()
                        .fill(HouseTanksFieldTheme.hairline)
                        .frame(width: 1.5)
                        .frame(minHeight: 30, maxHeight: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
                Text(copy(title))
                    .font(.headline)
                    .foregroundStyle(HouseTanksFieldTheme.ink)
                Text(copy(detail))
                    .font(.subheadline)
                    .foregroundStyle(HouseTanksFieldTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                accessory()
            }
            .padding(.top, 2)
            .padding(.bottom, AppDesign.Spacing.lg)
        }
    }

    // MARK: - Helpers

    private func sectionHeader(code: String, key: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppDesign.Spacing.sm) {
            Text(verbatim: "\(code) /")
                .font(.system(.subheadline, design: .monospaced).weight(.bold))
                .foregroundStyle(HouseTanksFieldTheme.accent)
            Text(copy(key))
                .font(.title3.weight(.bold))
                .foregroundStyle(HouseTanksFieldTheme.ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(copy(key))
        .accessibilityAddTraits(.isHeader)
    }

    private func fieldLabel(_ key: String) -> some View {
        Text(copy(key).uppercased())
            .font(HouseTanksFieldTheme.stencil)
            .tracking(1.2)
            .foregroundStyle(HouseTanksFieldTheme.muted)
    }

    private func swatch(_ color: HouseTanksColor) -> Color {
        Color(uiColor: color.uiColor)
    }

    private func colorName(_ color: HouseTanksColor) -> String {
        switch color {
        case .plum: copy("house_tanks_color_plum")
        case .orange: copy("house_tanks_color_orange")
        case .blue: copy("house_tanks_color_blue")
        case .olive: copy("house_tanks_color_olive")
        case .mustard: copy("house_tanks_color_mustard")
        case .crimson: copy("house_tanks_color_crimson")
        case .sky: copy("house_tanks_color_sky")
        case .ivory: copy("house_tanks_color_ivory")
        }
    }

    private var fieldManualCode: String {
        switch model.selectedMode {
        case .demo: String(format: "%02d", model.setupSteps.count + 1)
        case .online: "03"
        case nil: "01"
        }
    }

    private func copy(_ key: String) -> String {
        appViewModel.localized(key, fallback: key)
    }

    private func copy(_ key: String, replacements: [String: String]) -> String {
        appViewModel.localized(key, replacements: replacements)
    }
}

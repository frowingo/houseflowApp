import SwiftUI
import FausCrewCore

// MARK: - Category colours

extension ChoreCategory {
    /// Mid tone: icon glyphs, chip tints and selection rings.
    var tint: Color { Color(hex: tintHex) }
    /// Deep end of the category gradient.
    var deep: Color { Color(hex: deepHex) }

    var gradient: LinearGradient {
        LinearGradient(colors: [tint, deep], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Category glyph

/// Rounded tile painted with the category gradient and its symbol.
struct ChoreCategoryGlyph: View {
    let category: ChoreCategory
    var icon: String? = nil
    var size: CGFloat = 44

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
        ZStack {
            shape.fill(category.gradient)
            // Soft top highlight so the tile reads as a pressed sticker, not a flat swatch.
            shape.fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.28), Color.white.opacity(0)],
                    startPoint: .top,
                    endPoint: .center
                )
            )
            Image(systemName: icon ?? category.icon)
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundStyle(.white)
                .symbolRenderingMode(.hierarchical)
        }
        .frame(width: size, height: size)
        .shadow(color: category.deep.opacity(0.28), radius: size * 0.14, x: 0, y: size * 0.08)
        .accessibilityHidden(true)
    }
}

// MARK: - Meta pills

/// Difficulty pill reused by template tiles and the editor summary.
struct ChoreLevelPill: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    let level: ChoreLevel
    var compact = false

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: level.iconName)
                .font(.system(size: compact ? 8 : 10, weight: .bold))
            Text(appViewModel.localized(level.localizationKey))
                .font(.system(size: compact ? 10 : 11, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(level.color)
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 3 : 4)
        .background(level.color.opacity(0.13), in: Capsule())
    }
}

/// Small grey pill for repeat / duration hints.
struct ChoreMetaPill: View {
    let icon: String
    let text: String
    var tint: Color = AppDesign.Colors.textSecondary

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(text)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(tint.opacity(0.11), in: Capsule())
    }
}

// MARK: - Template tile

/// One catalog card: glyph, title, detail and meta pills. A system template carries a small
/// lock on its glyph (read-only; saving it makes a draft), a draft offers delete.
struct ChoreTemplateTile: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    let template: ChoreTemplate
    let category: ChoreCategory
    /// Shows the category name above the title (search results, Drafts tab).
    var showsCategory = false
    /// How many times this template was added during the current catalog visit.
    var addedCount = 0
    let onTap: () -> Void
    /// Set for the user's drafts: shows a delete button in the corner.
    var onDelete: (() -> Void)? = nil

    private var categoryLine: String {
        guard template.isDraft else { return appViewModel.catalogName(category) }
        return appViewModel.catalogText("chore_catalog_draft_badge", tr: "Taslak", en: "Draft")
            + " · " + appViewModel.catalogName(category)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
                HStack(alignment: .top, spacing: 4) {
                    ChoreCategoryGlyph(category: category, icon: template.icon, size: 40)
                        .overlay(alignment: .bottomTrailing) {
                            if template.isSystem {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 7, weight: .black))
                                    .foregroundStyle(category.deep)
                                    .frame(width: 16, height: 16)
                                    .background(AppDesign.Colors.cardBackground, in: Circle())
                                    .overlay(Circle().strokeBorder(category.tint.opacity(0.35), lineWidth: 1))
                                    .offset(x: 4, y: 4)
                                    .accessibilityHidden(true)
                            }
                        }
                    Spacer(minLength: 0)
                    if addedCount > 0 {
                        addedBadge
                            .transition(.scale.combined(with: .opacity))
                    } else if onDelete == nil {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(category.tint)
                            .frame(width: 26, height: 26)
                            .background(category.tint.opacity(0.13), in: Circle())
                    }
                    if onDelete != nil {
                        // Room for the delete button laid over the card.
                        Color.clear.frame(width: 28, height: 28)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    if showsCategory {
                        HStack(spacing: 3) {
                            if template.isDraft {
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            Text(categoryLine)
                                .font(.system(size: 10, weight: .bold))
                                .textCase(.uppercase)
                                .tracking(0.4)
                                .lineLimit(1)
                        }
                        .foregroundStyle(category.tint)
                    }
                    Text(appViewModel.catalogTitle(template))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppDesign.Colors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(appViewModel.catalogDetail(template))
                        .font(.system(size: 12))
                        .foregroundStyle(AppDesign.Colors.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                repeatPill
            }
            .padding(AppDesign.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: showsCategory ? 204 : 190, maxHeight: showsCategory ? 204 : 190, alignment: .topLeading)
            .contentShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg, style: .continuous))
        }
        .buttonStyle(CatalogCardButtonStyle(tint: category.tint, isHighlighted: addedCount > 0))
        .accessibilityElement(children: .combine)
        .accessibilityValue(template.isSystem
                            ? appViewModel.catalogText("chore_catalog_system_badge", tr: "Hazır şablon", en: "Ready-made template")
                            : "")
        .accessibilityHint(appViewModel.catalogText(
            "chore_catalog_template_accessibility_hint",
            tr: "Düzenlemek ve atamak için aç",
            en: "Opens it to adjust and assign"
        ))
        .overlay(alignment: .topTrailing) {
            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppDesign.Colors.error)
                        .frame(width: 28, height: 28)
                        .background(AppDesign.Colors.error.opacity(0.12), in: Circle())
                }
                .buttonStyle(CatalogPressStyle(scale: 0.9))
                .padding(AppDesign.Spacing.md)
                .accessibilityLabel(appViewModel.catalogText("chore_catalog_draft_delete", tr: "Taslağı sil", en: "Delete draft"))
            }
        }
    }

    private var repeatPill: some View {
        ChoreMetaPill(
            icon: template.repeatDays > 0 ? "arrow.clockwise" : "1.circle",
            text: appViewModel.catalogRepeatLabel(template.repeatDays),
            tint: template.repeatDays > 0 ? category.tint : AppDesign.Colors.textSecondary
        )
    }

    private var addedBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .heavy))
            if addedCount > 1 {
                Text("×\(addedCount)")
                    .font(.system(size: 10, weight: .bold))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .frame(minWidth: 26, minHeight: 26)
        .background(AppDesign.Colors.success, in: Capsule())
    }
}

// MARK: - Loading and status

/// A card-shaped placeholder while the catalog loads, in the tile's size and corner radius.
struct ChoreTemplateSkeletonTile: View {
    @State private var pulse = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg, style: .continuous)
        let bar = AppDesign.Colors.textTertiary.opacity(0.16)
        VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
            RoundedRectangle(cornerRadius: 13, style: .continuous).fill(bar).frame(width: 40, height: 40)
            RoundedRectangle(cornerRadius: 5).fill(bar).frame(height: 14)
            RoundedRectangle(cornerRadius: 5).fill(bar).frame(width: 90, height: 14)
            RoundedRectangle(cornerRadius: 4).fill(bar.opacity(0.7)).frame(height: 10)
            Spacer(minLength: 0)
            Capsule().fill(bar).frame(width: 70, height: 18)
        }
        .padding(AppDesign.Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 190, maxHeight: 190, alignment: .topLeading)
        .background(shape.fill(AppDesign.Colors.cardBackground))
        .overlay(shape.strokeBorder(AppDesign.Colors.hairline, lineWidth: 1))
        .opacity(pulse ? 0.55 : 1)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
        .onAppear { pulse = true }
    }
}

/// A full-width message card in the Drafts empty-card style: an empty shelf, or a list that
/// could not be loaded (with a retry).
struct CatalogStatusCard: View {
    let icon: String
    let tint: Color
    let title: String
    let detail: String
    var actionTitle: String? = nil
    var isBusy = false
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: AppDesign.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 60, height: 60)
                .background(tint.opacity(0.12), in: Circle())
            Text(title)
                .font(AppDesign.Typography.headline)
                .foregroundStyle(AppDesign.Colors.pageText)
                .multilineTextAlignment(.center)
            Text(detail)
                .font(AppDesign.Typography.subheadline)
                .foregroundStyle(AppDesign.Colors.pageTextSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 6) {
                        if isBusy {
                            ProgressView().controlSize(.small).tint(tint)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .bold))
                        }
                        Text(actionTitle)
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(tint)
                    .padding(.horizontal, AppDesign.Spacing.lg)
                    .frame(height: 36)
                    .background(tint.opacity(0.12), in: Capsule())
                }
                .buttonStyle(CatalogPressStyle(scale: 0.96))
                .disabled(isBusy)
                .padding(.top, AppDesign.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppDesign.Spacing.xxl)
        .padding(.horizontal, AppDesign.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg, style: .continuous)
                .fill(AppDesign.Colors.cardBackground.opacity(0.7))
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Button styles

/// Card surface with a category-tinted outline that deepens and dips on press.
struct CatalogCardButtonStyle: ButtonStyle {
    let tint: Color
    var isHighlighted = false
    var cornerRadius: CGFloat = AppDesign.CornerRadius.lg

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        configuration.label
            .background {
                ZStack {
                    shape.fill(AppDesign.Colors.cardBackground)
                    shape.fill(
                        LinearGradient(
                            colors: [tint.opacity(0.09), tint.opacity(0.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
            }
            .overlay {
                shape.strokeBorder(
                    isHighlighted ? AppDesign.Colors.success.opacity(0.55) : tint.opacity(configuration.isPressed ? 0.5 : 0.18),
                    lineWidth: isHighlighted || configuration.isPressed ? 1.5 : 1
                )
            }
            .shadow(color: tint.opacity(configuration.isPressed ? 0.10 : 0.14), radius: configuration.isPressed ? 4 : 10, x: 0, y: configuration.isPressed ? 2 : 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// A gentle press dip for small tappable tiles.
struct CatalogPressStyle: ButtonStyle {
    var scale: CGFloat = 0.94

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

// MARK: - Section header

struct CatalogSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var tint: Color = HouseJourneyTheme.accentOrange

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
                .textCase(.uppercase)
                .tracking(0.6)
            if let subtitle {
                Text(subtitle)
                    .font(AppDesign.Typography.caption)
                    .foregroundStyle(AppDesign.Colors.pageTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Catalog mosaic button

/// The small catalog entry in the corner of Today's tasks: a 2×2 mosaic of category colours
/// with a plus badge, hinting at the shelves behind it.
struct ChoreCatalogMosaicButton: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.fausTheme) private var theme
    let action: () -> Void

    @State private var tick = 0

    private let mosaic: [ChoreCategory] = Array(ChoreCatalog.categories.prefix(4))

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            tick += 1
            action()
        } label: {
            ZStack(alignment: .bottomTrailing) {
                Grid(horizontalSpacing: 3, verticalSpacing: 3) {
                    GridRow {
                        tile(mosaic[0])
                        tile(mosaic[1])
                    }
                    GridRow {
                        tile(mosaic[2])
                        tile(mosaic[3])
                    }
                }
                .padding(7)
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(AppDesign.Colors.background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(AppDesign.Colors.hairline, lineWidth: 1)
                )
                .shadow(color: AppDesign.Colors.shadow.opacity(0.10), radius: 6, x: 0, y: 3)

                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(AppDesign.Colors.onAccent)
                    .frame(width: 20, height: 20)
                    .background(
                        LinearGradient(colors: theme.decor.fabColors, startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: Circle()
                    )
                    .overlay(Circle().strokeBorder(AppDesign.Colors.cardBackground, lineWidth: 2))
                    .offset(x: 6, y: 6)
                    .symbolEffect(.bounce, value: tick)
            }
            .padding(.trailing, 6)
            .padding(.bottom, 6)
        }
        .buttonStyle(CatalogPressStyle(scale: 0.9))
        .accessibilityLabel(appViewModel.catalogText("chore_catalog_open_accessibility", tr: "İş kataloğunu aç", en: "Open the chore catalog"))
    }

    private func tile(_ category: ChoreCategory) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(category.gradient)
            .overlay(
                Image(systemName: category.icon)
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
            )
    }
}

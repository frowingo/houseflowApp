import SwiftUI
import FausCrewCore

/// A chore's category in the catalog's colours: the shelf icon and name, or a neutral
/// "Uncategorized" for chores created before categories (`0`) and unknown values.
/// Android mirrors this as `ChoreCategoryTag` in `ui/dashboard/ChoreVisuals.kt`.
struct ChoreCategoryTag: View {
    enum Style {
        /// Icon and name only, above a row's title.
        case inline
        /// A tinted capsule, for the detail sheet.
        case pill
    }

    @EnvironmentObject private var appViewModel: AppViewModel

    let kind: ChoreCategoryKind
    var style: Style = .inline

    private var category: ChoreCategory? { ChoreCatalog.category(kind: kind) }
    private var tint: Color { category?.tint ?? AppDesign.Colors.textSecondary }

    var body: some View {
        let size: CGFloat = style == .pill ? 11 : 10
        HStack(spacing: 4) {
            Image(systemName: category?.icon ?? "tag.slash")
                .font(.system(size: size - 1, weight: .bold))
            Text(appViewModel.choreCategoryName(kind))
                .font(.system(size: size, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundColor(tint)
        .padding(.horizontal, style == .pill ? 8 : 0)
        .padding(.vertical, style == .pill ? 4 : 0)
        .background {
            if style == .pill {
                Capsule().fill(tint.opacity(0.12))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

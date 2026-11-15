import Foundation
import FausCrewCore

// MARK: - Chore Catalog (shelves on the client, chores from the server)
//
// The nine shelves (name, tagline, icon and colours) ship with the app in Turkish and English;
// each piece of copy also has a localization key (`chore_catalog_*`), so the backend can override
// it. The chores on the shelves, system templates and the user's drafts alike, come from
// `GET chore/catalog` (`ChoreCatalogStore`) and are shown as the server wrote them. Creating a
// chore from a card goes through the regular create-chore endpoint.
//
// Android mirrors this in `ui/dashboard/catalog/ChoreCatalog.kt`. The shelves are checked against
// `shared/Fixtures/choreCatalog.json` and their API values against `choreCatalogApi.json`.

/// Built-in Turkish/English copy for one catalog string.
struct ChoreCatalogCopy: Hashable {
    let tr: String
    let en: String

    init(_ tr: String, _ en: String) {
        self.tr = tr
        self.en = en
    }
}

/// A catalog card: a server record shaped for the grid and the editor, or the blank card.
struct ChoreTemplate: Identifiable, Hashable {
    enum Origin: Hashable {
        /// A system template: read-only, saved as a new draft.
        case system
        /// One of the user's drafts: can be updated and deleted.
        case user
        /// "Create your own chore".
        case blank
    }

    let id: String
    let categoryId: String
    let icon: String
    let title: String
    let detail: String
    let level: ChoreLevel
    /// Suggested repeat interval in days; 0 means a one-off chore.
    let repeatDays: Int
    let origin: Origin
    /// The server record behind the card; `nil` for the blank card.
    let record: ChoreCatalogRecord?

    var isDraft: Bool { origin == .user }
    var isSystem: Bool { origin == .system }

    init(record: ChoreCatalogRecord) {
        let shelf = ChoreCatalog.shelf(for: record.categoryKind)
        self.init(
            id: record.id ?? "",
            categoryId: shelf.id,
            icon: shelf.icon,
            title: record.title,
            detail: record.description,
            level: ChoreLevel(rawValue: record.level) ?? .easy,
            repeatDays: record.recurringInterval,
            origin: record.isSystem ? .system : .user,
            record: record
        )
    }

    init(id: String, categoryId: String, icon: String, title: String, detail: String, level: ChoreLevel,
         repeatDays: Int, origin: Origin, record: ChoreCatalogRecord?) {
        self.id = id
        self.categoryId = categoryId
        self.icon = icon
        self.title = title
        self.detail = detail
        self.level = level
        self.repeatDays = repeatDays
        self.origin = origin
        self.record = record
    }
}

/// A shelf of the catalog (kitchen, bathroom, pets…).
struct ChoreCategory: Identifiable, Hashable {
    let id: String
    let icon: String
    /// Mid tone (`#RRGGBB`): icon glyphs, chip tints and selection rings.
    let tintHex: String
    /// Deep end of the category gradient (`#RRGGBB`); white text sits on it.
    let deepHex: String
    let name: ChoreCatalogCopy
    let tagline: ChoreCatalogCopy

    var nameKey: String { "chore_catalog_category_\(id)_name" }
    var taglineKey: String { "chore_catalog_category_\(id)_tagline" }

    /// The category value the API uses for this shelf.
    var kind: ChoreCategoryKind { ChoreCatalog.kindsByCategoryId[id] ?? .uncategorized }
}

/// Repeat presets offered by the editor; values are days between occurrences (0 = once).
enum ChoreRepeatPreset {
    static let all: [Int] = [0, 1, 2, 3, 7, 14, 30]
}

/// When a catalog chore is due. The editor offers an optional time; without one the chore runs
/// until the end of the chosen day, sent as 23:59:59 local time. (00:00 of the next day would be
/// listed under tomorrow, and 00:00 of the same day would already be overdue.)
enum ChoreDueDate {
    static let endOfDay = (hour: 23, minute: 59, second: 59)

    static func resolve(day: Date, hour: Int?, minute: Int?, calendar: Calendar = .current) -> Date {
        guard let hour else {
            return calendar.date(bySettingHour: endOfDay.hour, minute: endOfDay.minute, second: endOfDay.second, of: day) ?? day
        }
        return calendar.date(bySettingHour: hour, minute: minute ?? 0, second: 0, of: day) ?? day
    }
}

// MARK: - Shelves

enum ChoreCatalog {
    /// Shelf preselected for a chore written from scratch; the user can pick another.
    static let defaultCustomCategoryId = "kitchen"

    /// The blank card behind "create your own chore".
    static let blankTemplate = ChoreTemplate(
        id: "custom.blank",
        categoryId: defaultCustomCategoryId,
        icon: "square.and.pencil",
        title: "",
        detail: "",
        level: .easy,
        repeatDays: 0,
        origin: .blank,
        record: nil
    )

    static func category(id: String) -> ChoreCategory? {
        categories.first { $0.id == id }
    }

    /// Wire value of each shelf (`ChoreCategoryKind`). Checked against
    /// `shared/Fixtures/choreCatalogApi.json` on both platforms.
    static let kindsByCategoryId: [String: ChoreCategoryKind] = [
        "kitchen": .kitchen,
        "bath_laundry": .bathLaundry,
        "toilet": .toilet,
        "rooms": .rooms,
        "floors": .floorsGeneral,
        "pets": .pets,
        "trash": .trashRecycling,
        "plants": .plantsBalcony,
        "shopping": .shoppingHome,
    ]

    /// The shelf for a wire category; `nil` for uncategorized (and unknown) values.
    static func category(kind: ChoreCategoryKind) -> ChoreCategory? {
        categories.first { $0.kind == kind && kind.isAssignable }
    }

    /// The shelf a catalog record sits on; a value this build does not know lands on the default.
    static func shelf(for kind: ChoreCategoryKind) -> ChoreCategory {
        category(kind: kind) ?? category(id: defaultCustomCategoryId) ?? categories[0]
    }

    static let categories: [ChoreCategory] = [
        kitchen, bathLaundry, toilet, rooms, floors, pets, trash, plants, shopping
    ]

    private static let kitchen = ChoreCategory(
        id: "kitchen",
        icon: "fork.knife",
        tintHex: "#F07A3A",
        deepHex: "#B8461A",
        name: .init("Mutfak", "Kitchen"),
        tagline: .init("Ortak sofranın, temiz tezgahın işleri.", "Shared meals and clean counters.")
    )

    private static let bathLaundry = ChoreCategory(
        id: "bath_laundry",
        icon: "shower.fill",
        tintHex: "#3A8FD6",
        deepHex: "#1D5A99",
        name: .init("Banyo & Çamaşır", "Bath & Laundry"),
        tagline: .init("Parlayan fayanslar, mis kokulu çamaşırlar.", "Shiny tiles and fresh laundry.")
    )

    private static let toilet = ChoreCategory(
        id: "toilet",
        icon: "toilet.fill",
        tintHex: "#21A79B",
        deepHex: "#11695F",
        name: .init("Tuvalet", "Toilet"),
        tagline: .init("Kimsenin sevmediği ama herkesin istediği temizlik.", "Nobody's favourite, everybody's wish.")
    )

    private static let rooms = ChoreCategory(
        id: "rooms",
        icon: "bed.double.fill",
        tintHex: "#6C63D9",
        deepHex: "#3F379A",
        name: .init("Odalar", "Rooms"),
        tagline: .init("Yatak odası, salon ve ortak alanlar.", "Bedrooms, living room and shared spaces.")
    )

    private static let floors = ChoreCategory(
        id: "floors",
        icon: "bubbles.and.sparkles.fill",
        tintHex: "#2F9E5B",
        deepHex: "#1B6539",
        name: .init("Zemin & Genel", "Floors & General"),
        tagline: .init("Süpürge, paspas ve evin genel düzeni.", "Vacuuming, mopping and keeping things in order.")
    )

    private static let pets = ChoreCategory(
        id: "pets",
        icon: "pawprint.fill",
        tintHex: "#D99A2B",
        deepHex: "#9A6410",
        name: .init("Evcil hayvan", "Pets"),
        tagline: .init("Evin tüylü üyeleri de bakım bekliyor.", "The furry housemates need care too.")
    )

    private static let trash = ChoreCategory(
        id: "trash",
        icon: "trash.fill",
        tintHex: "#6E8A73",
        deepHex: "#3F5944",
        name: .init("Çöp & Geri dönüşüm", "Trash & Recycling"),
        tagline: .init("Çöp kapıda beklemesin.", "Don't let the bags pile up.")
    )

    private static let plants = ChoreCategory(
        id: "plants",
        icon: "leaf.fill",
        tintHex: "#5FA83A",
        deepHex: "#386E1C",
        name: .init("Bitki & Balkon", "Plants & Balcony"),
        tagline: .init("Yeşil köşeler ve açık alanlar.", "Green corners and outdoor space.")
    )

    private static let shopping = ChoreCategory(
        id: "shopping",
        icon: "cart.fill",
        tintHex: "#E0517A",
        deepHex: "#A02A4E",
        name: .init("Alışveriş & Ev", "Shopping & Home"),
        tagline: .init("Dolap boşalmadan, fatura gecikmeden.", "Before the cupboards empty and bills go late.")
    )
}

// MARK: - Copy resolution

extension AppViewModel {
    func catalogText(_ copy: ChoreCatalogCopy, key: String) -> String {
        localized(key, tr: copy.tr, en: copy.en)
    }

    func catalogText(_ key: String, tr: String, en: String) -> String {
        localized(key, tr: tr, en: en)
    }

    func catalogName(_ category: ChoreCategory) -> String {
        catalogText(category.name, key: category.nameKey)
    }

    /// Name of a chore's category, or "Uncategorized" for `0` and values this build does not know.
    func choreCategoryName(_ kind: ChoreCategoryKind) -> String {
        guard let category = ChoreCatalog.category(kind: kind) else {
            return catalogText("chore_category_none", tr: "Kategorisiz", en: "Uncategorized")
        }
        return catalogName(category)
    }

    func catalogTagline(_ category: ChoreCategory) -> String {
        catalogText(category.tagline, key: category.taglineKey)
    }

    /// Catalog chores come from the server in one language and are shown as they are.
    func catalogTitle(_ template: ChoreTemplate) -> String { template.title }

    func catalogDetail(_ template: ChoreTemplate) -> String { template.detail }

    /// "Every day", "Every 3 days", "Weekly"… for a repeat interval in days.
    func catalogRepeatLabel(_ days: Int) -> String {
        switch days {
        case ..<1: return catalogText("chore_catalog_repeat_once", tr: "Tek sefer", en: "One-off")
        case 1: return catalogText("chore_catalog_repeat_daily", tr: "Her gün", en: "Every day")
        case 7: return catalogText("chore_catalog_repeat_weekly", tr: "Haftada bir", en: "Weekly")
        case 14: return catalogText("chore_catalog_repeat_biweekly", tr: "2 haftada bir", en: "Every 2 weeks")
        case 30: return catalogText("chore_catalog_repeat_monthly", tr: "Ayda bir", en: "Monthly")
        default:
            return catalogText("chore_catalog_repeat_every_n_days", tr: "{days} günde bir", en: "Every {days} days")
                .replacingOccurrences(of: "{days}", with: "\(days)")
        }
    }
}

// MARK: - Search

extension ChoreCatalog {
    /// Case- and diacritic-insensitive match on the title and detail.
    static func search(
        _ query: String,
        among templates: [ChoreTemplate],
        resolve: (ChoreTemplate) -> (String, String)
    ) -> [ChoreTemplate] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return templates.filter { template in
            let (title, detail) = resolve(template)
            return [title, detail]
                .contains { $0.range(of: needle, options: options, locale: Locale(identifier: "tr_TR")) != nil }
        }
    }
}

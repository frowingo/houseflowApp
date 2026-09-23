import Foundation

enum LuckySpinLocalization {
    static func value(for key: String, language: String?) -> String? {
        guard let copy = values[key] else { return nil }
        return language?.lowercased().hasPrefix("en") == true ? copy.en : copy.tr
    }

    private static let values: [String: (tr: String, en: String)] = [
        "lucky_spin_home_title": ("Lucky Spin", "Lucky Spin"),
        "lucky_spin_home_subtitle": ("Evde kararsız kaldığınız sırayı çarka bırakın.", "Let the wheel settle the next turn at home."),
        "lucky_spin_home_guide_title": ("Bu tur nasıl işler?", "How this round works"),
        "lucky_spin_home_count": ("{count} isim", "{count} names"),
        "lucky_spin_home_rule_names_title": ("İsimleri belirle", "Choose the names"),
        "lucky_spin_home_rule_names_detail": ("Çarka girecek ev üyelerini ekle veya çıkar.", "Add or remove the household members on the wheel."),
        "lucky_spin_home_rule_pointer_title": ("İşaretçiyi takip et", "Follow the pointer"),
        "lucky_spin_home_rule_pointer_detail": ("Çark durduğunda üstteki işaretçinin gösterdiği dilim seçilir.", "When the wheel stops, the segment under the top pointer is selected."),
        "lucky_spin_home_rule_result_title": ("Sonucu hemen gör", "See the selection"),
        "lucky_spin_home_rule_result_detail": ("Seçilen isim sonraki ekranda açıkça gösterilir.", "The selected name appears clearly on the next screen."),
        "lucky_spin_home_names_title": ("Çarktaki isimler", "Names on the wheel"),
        "lucky_spin_home_new_name_label": ("Yeni isim", "New name"),
        "lucky_spin_home_name_empty_error": ("Çarka eklemek için bir isim yaz.", "Enter a name to add it to the wheel."),
        "lucky_spin_home_name_duplicate_error": ("Bu isim zaten çarkta.", "That name is already on the wheel."),
        "lucky_spin_home_remove_name": ("{name} ismini kaldır", "Remove {name}"),
        "lucky_spin_home_spin_button": ("Çarkı döndür", "Spin the wheel"),
        "lucky_spin_home_spinning_title": ("Çark dönüyor", "The wheel is spinning"),
        "lucky_spin_home_spinning_detail": ("Üstteki işaretçi durduğu dilimi seçecek.", "The top pointer will select the segment where the wheel stops."),
        "lucky_spin_home_selected_label": ("Bu tur sıra onda", "It’s their turn"),
        "lucky_spin_home_result_detail": ("Seçim tamamlandı. Yeni bir tur başlatabilir veya oyunlara dönebilirsin.", "The selection is complete. Start another round or return to Games."),
        "lucky_spin_home_again_button": ("Yeni tur döndür", "Spin another round"),
        "lucky_spin_home_exit_button": ("Oyunlara dön", "Back to Games"),
    ]
}

import Foundation

/// Bundled copy keeps House-Switch usable before the plaintext endpoint is updated.
/// Remote translations continue to take precedence in LocalizationStore.
enum HouseSwitchLocalization {
    static func value(for key: String, language: String?) -> String? {
        guard let copy = values[key] else { return nil }
        return language?.lowercased().hasPrefix("en") == true ? copy.en : copy.tr
    }

    private static let values: [String: (tr: String, en: String)] = [
        "games_house_switch_title": ("House-Switch", "House-Switch"),
        "games_house_switch_card_description": ("Yüzeylerden yerçekimini değiştir, yatay parkuru tamamla.", "Flip gravity from solid surfaces and complete the landscape course."),
        "games_house_switch_badge": ("SOLO · YENİ", "SOLO · NEW"),
        "house_switch_title": ("House-Switch", "House-Switch"),
        "house_switch_subtitle": ("Zemin de tavan da senin yolun.", "The floor and ceiling are both your path."),
        "house_switch_start": ("Koşuyu başlat", "Start the run"),
        "house_switch_start_landscape": ("Yatay moda geç ve başlat", "Rotate and start"),
        "house_switch_rotating": ("Yatay moda geçiliyor…", "Rotating to landscape…"),
        "house_switch_resume": ("Devam et", "Resume"),
        "house_switch_restart": ("Baştan başla", "Restart"),
        "house_switch_exit": ("Oyunlara dön", "Back to games"),
        "house_switch_pause": ("Oyunu duraklat", "Pause game"),
        "house_switch_playfield_accessibility": ("House-Switch oyun alanı", "House-Switch playfield"),
        "house_switch_playfield_hint": ("Bir yüzeye basarken yerçekimini değiştirmek için dokun.", "While supported by a surface, tap to flip gravity."),
        "house_switch_flip_action": ("Yerçekimini değiştir", "Flip gravity"),
        "house_switch_landscape_title": ("Yatay ekran gerekli", "Landscape required"),
        "house_switch_landscape_detail": ("Koşuyu başlattığında ekran otomatik döner. House-Switch dikey oynanamaz.", "The screen rotates automatically when the run starts. House-Switch cannot be played in portrait."),
        "house_switch_landscape_error": ("Yatay moda geçilemedi. Cihazını yatay çevirip yeniden dene.", "Landscape mode could not be activated. Rotate your device and try again."),
        "house_switch_landscape_badge": ("ZORUNLU", "REQUIRED"),
        "house_switch_rule_tap_title": ("Yüzeyden yön değiştir", "Flip from a surface"),
        "house_switch_rule_tap_detail": ("Yerçekimi yalnızca evin tabanı bir yüzeye değdiğinde değişir; havadaki dokunuşlar kabul edilmez.", "Gravity changes only while the house base touches a surface; mid-air taps are ignored."),
        "house_switch_rule_solid_title": ("Duvarlar güvenli", "Walls are safe"),
        "house_switch_rule_solid_detail": ("Ön ve yan temas öldürmez ama parkur akmaya devam eder. Ekranın gerisinde kalma.", "Front and side impacts are safe, but the course keeps moving. Do not fall behind the screen."),
        "house_switch_rule_laser_title": ("Lazerlerden uzak dur", "Avoid active lasers"),
        "house_switch_rule_laser_detail": ("Aktif lazer teması da koşuyu bitirir.", "Touching an active laser also ends the run."),
        "house_switch_rule_gap_title": ("Boşlukları atlat", "Avoid the gaps"),
        "house_switch_rule_gap_detail": ("Zemin ve tavandaki boşluğa düşersen ekran dışına çıkarsın. Yönünü boşluktan önce değiştir.", "Floor and ceiling gaps send you off-screen. Flip before reaching them."),
        "house_switch_rule_boost_title": ("Hız şeritlerini kullan", "Use the speed pads"),
        "house_switch_rule_boost_detail": ("Oklu mint şeritler kısa süre hızlandırır ve seni ekranda biraz sağa taşır.", "Mint arrow pads give a short speed boost and move you slightly right on screen."),
        "house_switch_tap_hint": ("Yüzeye basınca yerçekimini değiştir", "Flip gravity while on a surface"),
        "house_switch_progress": ("İlerleme", "Progress"),
        "house_switch_start_short": ("BAŞLANGIÇ", "START"),
        "house_switch_finish_short": ("BİTİŞ", "FINISH"),
        "house_switch_flips": ("Değişim", "Flips"),
        "house_switch_paused": ("Koşu duraklatıldı", "Run paused"),
        "house_switch_paused_detail": ("Koşu durdu. Devam Et ile kaldığın yerden sürdür.", "The run is paused. Choose Resume to continue."),
        "house_switch_crashed_laser": ("Lazere yakalandın", "Caught by a laser"),
        "house_switch_crashed_laser_detail": ("Platform temasları güvenli. Bu kez lazer zamanlamasını değiştir.", "Platform impacts are safe. Change your laser timing this run."),
        "house_switch_crashed_boundary": ("Hattın dışına çıktın", "Left the line"),
        "house_switch_crashed_boundary_detail": ("Bir sonraki geçişte yerçekimini biraz daha erken değiştir.", "Flip gravity a little earlier on the next crossing."),
        "house_switch_crashed_left_behind": ("Parkurun gerisinde kaldın", "Left behind"),
        "house_switch_crashed_left_behind_detail": ("Engele takıldığında parkur durmaz. Ekranın solundan çıkmadan önce yüzeye basıp yön değiştir.", "The course keeps moving when you hit an obstacle. Reach a surface and flip before leaving the left edge."),
        "house_switch_finished": ("Hat tamamlandı!", "Line complete!"),
        "house_switch_finished_detail": ("Evin iki yüzünde de yolu buldun.", "You found the path on both sides of the house."),
        "house_switch_time": ("Süre", "Time"),
    ]
}

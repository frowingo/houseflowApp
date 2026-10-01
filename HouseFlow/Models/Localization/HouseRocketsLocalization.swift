import Foundation

/// Remote plaintext can override these bundled demo strings.
enum HouseRocketsLocalization {
    static func value(for key: String, language: String?) -> String? {
        guard let copy = values[key] else { return nil }
        return language?.lowercased().hasPrefix("en") == true ? copy.en : copy.tr
    }

    private static let values: [String: (tr: String, en: String)] = [
        "games_house_rockets_title": ("House Rockets", "House Rockets"),
        "games_house_rockets_card_description": ("Roketini yönlendir, engelleri aş ve son kalan ol.", "Guide your rocket past obstacles and be the last one flying."),
        "games_house_rockets_badge": ("1 OYUNCU · DEMO", "1 PLAYER · DEMO"),
        "house_rockets_title": ("House Rockets", "House Rockets"),
        "house_rockets_subtitle": ("Sen pilot koltuğunda, rakiplerin bot.", "You’re the pilot. Your rivals are bots."),
        "house_rockets_mode": ("Botlarla demo", "Bot demo"),
        "house_rockets_online_later": ("Çevrim içi odalar sonraki aşamada", "Online rooms are planned for a later phase"),
        "house_rockets_bot_count": ("Bot sayısı", "Number of bots"),
        "house_rockets_rule_aim": ("Sağ veya sol kenara dokunup sürükleyerek yön ver", "Touch and drag along either edge to steer"),
        "house_rockets_rule_drive": ("İtki sürekli açık; bıraktığında son yön korunur", "Thrust stays on; releasing keeps your heading"),
        "house_rockets_rule_fields": ("Mavi çift ok kısa süre hızlandırır; kırmızı fren yavaşlatır", "Blue double arrows briefly boost speed; red brakes slow you down"),
        "house_rockets_boost_active": ("Hız ×1,45", "Speed ×1.45"),
        "house_rockets_slow_active": ("Hız ×0,65", "Speed ×0.65"),
        "house_rockets_turn": ("Turn", "Turn"),
        "house_rockets_spectating_short": ("İzliyorsun", "Spectating"),
        "house_rockets_vertical_transition": ("Parkur yukarı dönüyor · Ekranı yatay tut", "Course turning upward · Keep your screen landscape"),
        "house_rockets_horizontal_transition": ("Parkur sağa dönüyor · Ekranı yatay tut", "Course turning right · Keep your screen landscape"),
        "house_rockets_rule_survive": ("Temas öldürmez. Liderin gerisinde ekran dışına düşme", "Contact is safe. Stay on screen behind the leader"),
        "house_rockets_landscape": ("Oyun yatay ekranda açılır.", "The game opens in landscape."),
        "house_rockets_landscape_error": ("Yatay moda geçilemedi. Cihazı çevirip yeniden dene.", "Couldn’t enter landscape. Rotate your device and try again."),
        "house_rockets_start": ("Uçuşu başlat", "Start flight"),
        "house_rockets_rotating": ("Pist hazırlanıyor…", "Preparing the course…"),
        "house_rockets_pause": ("Duraklat", "Pause"),
        "house_rockets_resume": ("Devam et", "Resume"),
        "house_rockets_paused": ("Uçuş duraklatıldı", "Flight paused"),
        "house_rockets_joystick": ("Yön çubuğu", "Steering joystick"),
        "house_rockets_joystick_hint": ("Ekranın sağ veya sol kenarına dokunup istediğin yöne sürükle. Yön çubuğu sürüklerken görünür, bıraktığında kaybolur ve son yön korunur. Erişilebilirlik ayarı yönü 15 derece değiştirir.", "Touch either edge and drag in the direction you want to fly. The joystick appears while dragging and disappears on release, keeping your heading. Accessibility adjustments turn by 15 degrees."),
        "house_rockets_you": ("Sen", "You"),
        "house_rockets_bot_one": ("Bot Nova", "Bot Nova"),
        "house_rockets_bot_two": ("Bot Mavi", "Bot Blue"),
        "house_rockets_bot_three": ("Bot Güneş", "Bot Sun"),
        "house_rockets_alive": ("Kalan {count}", "{count} left"),
        "house_rockets_time": ("Süre", "Time"),
        "house_rockets_countdown_go": ("UÇ!", "FLY!"),
        "house_rockets_eliminated": ("Roketin elendi", "Your rocket is out"),
        "house_rockets_bot_eliminated": ("{name} elendi", "{name} is out"),
        "house_rockets_spectating": ("Botların yarışını izliyorsun", "Watching the remaining bots"),
        "house_rockets_won": ("Kazandın!", "You won!"),
        "house_rockets_lost": ("{name} kazandı", "{name} won"),
        "house_rockets_draw": ("Berabere", "Draw"),
        "house_rockets_result_detail": ("Son kalan roket yarışı aldı.", "The last rocket flying took the race."),
        "house_rockets_draw_detail": ("Son gemiler aynı anda ekranın gerisinde kaldı.", "The final rockets left the rear edge together."),
        "house_rockets_rematch": ("Yeniden oyna", "Play again"),
        "house_rockets_exit": ("Oyunlara dön", "Back to games"),
    ]
}

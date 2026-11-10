# Faus Switch online — canlı test listesi

Deploy'dan sonra çalıştırılır. Her satıra sonucu yaz: ✅ geçti, ❌ kaldı (ne oldu), — denenmedi.
Sonuçları istemci agent'ına ilet; raporun §6'sına (`fausSwitchClientReport.md`) eklenecek.

## 0. Hazırlık

- [ ] Backend deploy edildi.
- [ ] İki (tercihen üç) hesap aynı evde. Biri evin sahibi.
- [ ] Cihazlar:
  - iOS: en az iki cihaz ya da simülatör;
  - Android: en az iki cihaz ya da emülatör.
- [ ] Uygulamalar bu dalın derlemesi (iOS ve Android debug).
- [ ] Katalog: `GET /game/catalog?houseId=…` cevabında `fausSwitch` ve `settings` var. Uygulamada
  Faus Switch → Online seçince "kapalı" bildirimi çıkmıyor.

Not: Demo modunda en çok 3 bot var. Kalabalık yarış (5+ robot) yalnız online'da denenebilir.

## 1. Ortak senaryolar

Her senaryoyu üç eşleşmede dene. Sütunlar:

- **iOS–iOS:** iki iOS cihaz.
- **And–And:** iki Android cihaz.
- **Karışık:** bir iOS, bir Android cihaz.

### 1.1. Lobi

| # | Adım | Beklenen | iOS–iOS | And–And | Karışık |
|---|---|---|---|---|---|
| L1 | İki cihaz da Online'ı açar | İkisi aynı odada. Liste: kendin en üstte "· Sen" ekiyle, diğer oyuncu ev üyesi adıyla | | | |
| L2 | A bir renk seçer | B'nin ekranında o renk kişi rozetli ve soluk; B o rengi seçemiyor | | | |
| L3 | B, A'nın rengini hatırlanan renk olarak açar (önce demoda o rengi seç, sonra Online) | B'ye başka renk verilir, "renk başkasında" uyarısı görünür | | | |
| L4 | A odadan çıkar | B'nin istediği renk boşalınca B'ye geçer | | | |
| L5 | A "Hazırım" der | Hazır sayısı 1/2 olur; A'nın satırında yeşil onay. A'nın renk seçici kilitlenir (kilit notu görünür, renklere dokunmak bir şey yapmaz); hazırı kaldırınca açılır | | | |
| L6 | İkisi de hazır | En üstteki durum kartı "Başlamak üzere" der. Oyuncular ile Kurallar arasındaki "Başlangıç sayacı" kartı (hazırdan önce kum saati ve "Sayaç hazır bekliyor") büyük saniye sayacına geçer (≤5 sn'de kırmızı), sonra yarış ekranı açılır. Sayaç kartı ekrandan kaydırılınca üst çubuğun sağında küçük sayaç görünür; kart geri gelince kaybolur | | | |
| L7 | Sahip olmayan oyuncu | "Maçı iptal et" görünmez; sahipte görünür | | | |
| L8 | Sahip lobide iptal eder | İki cihazda da oda kapandı bildirimi; sonuç paneli açılmaz | | | |

### 1.2. Yarış

| # | Adım | Beklenen | iOS–iOS | And–And | Karışık |
|---|---|---|---|---|---|
| R1 | Yarış ilk durumu gelir | Ekran yataya döner, müzik başlar, isim etiketleri ve 3-2-1 sayacı görünür; renkler lobidekiyle aynı | | | |
| R2 | Zeminde dokun | Kendi robotun hemen döner (ses ve titreşim). Karşı cihazda en geç bir snapshot sonra görünür | | | |
| R3 | Havada dokun | Hiçbir şey olmaz, yalnız hafif "hayır" titreşimi | | | |
| R4 | Portal | Robot karşı raya fırlar; portal sesi ve titreşim | | | |
| R5 | Bir robot elenir (boşluktan düş ya da geride kal) | Elenen cihazda alt kartta "izleniyor" ve elenme nedeni; yarış diğerinde sürer | | | |
| R6 | Son robot da durur | Kısa "Sonuç kesinleşiyor" bildirimi, sonra sonuç paneli | | | |
| R7 | Sonuç paneli | Sıralama ve süreler iki cihazda aynı. Kazanan sen değilsen "{ad} kazandı" doğru adı gösterir | | | |
| R8 | 120 sn dolar (iki robot da kasıtlı yavaş, hiç bitirmeden) | Sonuç geçerli, bağlantı kopmaz; başlık "Kazanan yok" (en öndeki 1. sırada görünür ama kazanan sayılmaz) | | | |
| R9 | Müzik ve ses düğmeleri | Müzik ve efekt ayrı ayrı kapanır; sonuç panelinde müzik kısılır | | | |

### 1.3. Bağlantı ve kontrol

| # | Adım | Beklenen | iOS–iOS | And–And | Karışık |
|---|---|---|---|---|---|
| C1 | Yarışta bir cihazın ağını 3–5 sn kes, aç | Robot girdisiz koşmaya devam eder. Dönüşte bildirim kalkar ve flip yine çalışır | | | |
| C2 | Yarışta uygulamayı arka plana al, 3 sn sonra dön | Kontrol geri gelir; gerekirse "geri al" düğmesiyle alınır | | | |
| C3 | Aynı hesapla ikinci cihazdan aynı odaya gir | İlk cihazda "kontrol başka cihazda" bildirimi ve "geri al" düğmesi | | | |
| C4 | Elendikten hemen sonra (≤250 ms) dokun | Nadiren robot kurtarılır. Kurtarılırsa bağlantı **kopmamalı**, yarış sürmeli | | | |
| C5 | Hızlı art arda dokun (saniyede ~10) | Bağlantı kopmaz, "çok hızlı" hatası görünmez | | | |
| C6 | Yarışta sol üstteki ✕ (Android'de geri tuşu da) | Önce onay sorulur. Onaylayınca modlara dönülür; karşı cihazda robot "ayrıldı" olur | | | |

### 1.4. Rövanş ve çıkış

| # | Adım | Beklenen | iOS–iOS | And–And | Karışık |
|---|---|---|---|---|---|
| X1 | Sonuç panelinde "Rövanş" | Ekran dikey odaya döner, durum "rövanş odası". Diğer oyuncu da rövanş derse ikisi aynı yeni odada | | | |
| X2 | Rövanş yarışı | Yeni yarış normal başlar; renkler korunur | | | |
| X3 | Sonuç panelinde "Modlara dön" | Mod seçimine dönülür, oda kapanır | | | |
| X4 | Lobideyken evden çıkar ya da ev değiştir | Oda kapanır, yeni evin odası açılır | | | |
| X5 | (Yapılabiliyorsa) oturumu sunucuda geçersiz kıl; sunucu 401 dönsün | Oda kapanır, uygulama oturum açma ekranına döner | | | |

## 2. Kalabalık yarış (3+ cihaz, varsa)

| # | Adım | Beklenen | Sonuç |
|---|---|---|---|
| K1 | 5 oyuncuyla yarış | Robotlar %75 boy; start platformları üst üste binmez | |
| K2 | 8 oyuncu (elde varsa) | Aynı; akıcılık kabul edilebilir | |

## 3. Platforma özgü

| # | Adım | Beklenen | Sonuç |
|---|---|---|---|
| A1 | Android: yarışta cihazı döndür | Yatay kalır; tam ekran (sistem çubukları gizli) | |
| A2 | Android: TalkBack açık, lobide renk seç | Alınmış renk "başka oyuncuda" diye okunur ve seçilemez | |
| A3 | Android: sistem animasyonları kapalı (Reduce motion) | Portal titreşimi ve arka plan kayması sakinleşir | |
| I1 | iOS: VoiceOver ile yarış alanına çift dokun | Flip yapılır | |

## 4. Sonuçları bildirirken

Kalan her satır için şunları yaz:

- eşleşme;
- ne yaptın;
- ne gördün;
- yaklaşık saat (backend logları için).

Ekran görüntüsü varsa ekle.

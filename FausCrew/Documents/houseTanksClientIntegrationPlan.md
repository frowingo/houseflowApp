# FauseTanks online — istemci entegrasyon planı

Tarih: 25 Ekim 2026 · Hazırlayan: mobil (istemci) · Dayanak: `houseTanksClientIntegration.md`
(backend, `houseTanks.v1`, protocol 2, katalog 1)

Bu belge backend'in entegrasyon belgesine göre istemcide yapılacak işleri, mimari
kararları ve sırayı tanımlar. Wire sözleşmesi, ürün kuralları ve fizik sabitleri
backend belgesindeki gibidir; burada tekrar edilmez, yalnızca istemcideki karşılıkları
anlatılır.

## 0. Önce karar verilmesi gerekenler

| # | Konu | Neden önemli | Öneri |
|---|---|---|---|
| K1 | **Arenanın ekrandaki boyutu** — **Karar ve uygulama (25 Ekim 2026): arena 872×400** | Sabit 1180×640 arena cihazda denendi: tank ve jokerler eskinin ~%61'ine (Bodrum ~%44) küçüldü, oynanabilirlik bozuldu. | Arena telefon boyutuna (872×400) çekilir; fizik sabitleri aynı kalır, eski demo hissi döner. Bu backend'de **kod değişikliği**: `ArenaWidth/Height` Go sabiti ve 15 yerde kullanılıyor. Fixture'lar yeniden üretilir, courtyard başlangıç 4 düzeltilir. Ayrıntı: `houseTanksArenaResizeBriefing.md`. (Önceki "yalnızca yapılandırma" ifadesi yanlıştı.) |
| K2 | **Demoda standart haritaların oyuncu sayısı** | Katalogda standart haritalar artık 2–5 oyunculu. Demoya doğrudan uygulanırsa her haritada oyuncu sayısı adımı çıkar. | Demoda standart haritalar bugünkü gibi 4 tank kalsın; oyuncu sayısı adımı yalnızca Bodrum'da çıksın. Demo kuralı katalogdan ayrı tutulur. |
| K3 | **iOS'ta WebSocket sıkıştırması** | Backend `permessage-deflate` istiyor (8 oyuncuda ~280 KB/s → ~74 KB/s). Android'de OkHttp bunu kendiliğinden yapıyor; iOS'taki `URLSessionWebSocketTask`'ın bu uzantıyı müzakere ettiği bilinmiyor. | F1'de canlı sunucuyla ölç. Sıkıştırma yoksa ya sıkıştırmasız kabul edilir ya da sıkıştırma destekleyen bir WebSocket katmanı değerlendirilir (yeni bağımlılık, ayrıca onayınla). |
| K4 | **Ortak online katmanın genelleştirilmesi** | Ortak mesaj çözücü (`GameRealtimeServerMessage`) ve lobi makinesi HouseRockets'e bağlı. FauseTanks ya bunları genelleştirerek kullanır ya da kendi kopyasını alır. | Genelleştir (§2.2). HouseRockets mevcut test paketiyle güvence altında taşınır. Kopya yolu daha hızlı ama ~700 satır yinelenen ve zamanla ayrışan kod demek. |

## 1. Fixture'lar (tamamlandı)

- Üç dosya backend deposundan **byte byte** kopyalandı: `FausCrew/shared/Fixtures/`
  - `houseTanksMaps.json`, `houseTanksSimulation.json`, `houseTanksProtocol.json`
  - sha256 değerleri backend belgesi §2 ile birebir aynı (doğrulandı).
- Neden burası: House Rockets'in protokol dosyası da burada ve üç test paketinin üçü de
  buradan okuyabiliyor:
  - Ortak çekirdek testleri (`swift test`): dosyanın konumuna göre göreli yol.
  - Android birim testleri: `app/build.gradle.kts` test kaynağı olarak bu klasörü
    zaten ekliyor.
  - iOS uygulama testleri FauseTanks için fixture'a ihtiyaç duymayacak şekilde
    tasarlanır (fixture testleri çekirdekte). Böylece ikinci bir kopya tutulmaz.
- Bir **hash testi** eklenir: dosyaların sha256'ı belgedeki değerlerden saparsa testler
  düşer. Fixture'lar elle düzenlenmez; backend yeni sürüm verdiğinde yeniden kopyalanır.

## 2. Mimari hedef

### 2.1. Katmanlar

```
FausCrewCore (Swift, iOS + Android ortak)
├─ Games/HouseTanks/            motor: dünya, kurallar, katalog, render modeli, demo maçı
├─ Games/HouseTanks/Online/     wire DTO'ları, online maç makinesi, ara değer/tahmin, sonuç
└─ Games/Online/  (yeni, ortak) zarf, ortak mesajlar, lobi/bağlantı/heartbeat makinesi
                                (House Rockets ve FauseTanks paylaşır)

Platform (yalnız G/Ç ve çizim)
├─ iOS:     HouseTanksOnlineHost (URLSession), SpriteKit sahnesi, SwiftUI ekranları
└─ Android: HouseTanksOnlineBridge (JNI) + HouseTanksOnlineSession (OkHttp),
            Compose çizicisi ve ekranları
```

Kural: bütün oyun ve protokol kararları çekirdekte, platform yalnızca G/Ç yapar ve
çizer. Bu, House Rockets'te kurulan "effect" modelinin aynısıdır: çekirdek "şu isteği at,
şu soketi aç, şunu gönder" der, platform yapar ve sonucu geri bildirir.

### 2.2. Ortak online katmanın genelleştirilmesi (K4)

Bugün oyundan bağımsız olanlar: iOS `GameRealtimeTransport`, Android
`OkHttpRealtimeSocketFactory`, HTTP uç oluşturucu (`GameRoute`, `GameEndpointBuilder`),
bağlantı durumları, yeniden bağlanma politikası. Bunlar olduğu gibi kullanılır.

House Rockets'e bağlı olanlar ve yapılacaklar:

1. **Zarf ayrımı:** `GameRealtimeServerMessage` bugün payload'ı doğrudan House Rockets
   tiplerine çözüyor ve `validateCompatibility` oyun anahtarını sabit kodluyor. Zarf
   (`protocolVersion`, `messageId`, `sequence`, `sentAt`, `type`, ham `payload`) genel bir
   tipe ayrılır; ortak mesajlar (`gameSession.*`, `realtime.pong`,
   `commandAccepted/Rejected`) orada çözülür; oyuna özel mesajları her oyun kendi
   çözücüsüyle okur.
2. **Lobi makinesi:** Oturum açma, soket, join/ready/leave/cancel, ortak oturum anlık
   görüntüsü, heartbeat, yeniden bağlanma ve reddetme işleme genel bir makineye taşınır.
   Oyuna özel kısımlar (welcome ayarları, kontrol yetkisi, oyun anlık görüntüsü, sonuç
   DTO'su) bir adaptör protokolüyle verilir.
3. **Sonuç makinesi:** HTTP yedekli sonuç okuma ve tekrar deneme genelleştirilir.
4. **Katalog:** `GameCatalogEntryDTO` FauseTanks ayarlarını da çözer; `GameKey.houseTanks`
   eklenir.
5. **Sıra:** Önce genel katman çıkarılır ve House Rockets ona taşınır; House Rockets'in
   mevcut testleri (çekirdek, köprü, Android, iOS) hiç değişmeden geçmelidir. Ardından
   FauseTanks aynı katmanın üstüne kurulur.

### 2.3. Ortak render modeli

Bugün iOS sahnesi doğrudan `HouseTanksWorld`'ü çiziyor, Android köprüsü de dünyayı JSON'a
çeviriyor. Online modda elimizde dünya değil sunucu anlık görüntüleri olacak.
Çekirdeğe tek bir **`HouseTanksRenderFrame`** eklenir (arena/harita, tanklar, kasalar,
mermiler, joker, olaylar, `controllable` gibi online alanlar):

- Demo maçı bu modeli kendi dünyasından üretir.
- Online maç makinesi aynı modeli sunucu anlık görüntülerinden (ara değer + tahmin ile)
  üretir.
- iOS SpriteKit sahnesi ve Android Compose çizicisi yalnızca bu modeli çizer. Böylece
  çizim kodu tek kalır ve demo ile online birebir aynı görünür.

## 3. F0 — Motor eşitliği (online işten önce)

Hedef: Swift motoru Go'nun 17 fizik senaryosunu 1e-6 toleransla geçer; demo çalışmaya
devam eder.

1. **Sabit arena:** `resize(to:)` kalkar, dünya her zaman katalogdaki boyuttadır (872×400,
   K1). Platformlar arenayı ekrana en-boy oranını koruyarak
   sığdırır, kenarda kalan alanı kağıt harita zemini doldurur. iOS sahnesi `resizeFill` ile
   ekranı doldurur, bir kamera arenayı sığdırır; Android çizicisi tek bir ölçek ve öteleme
   uygular.
2. **Tam sayı tick:** Dünyanın zamanı tick sayacıdır; tüm süreler tick cinsindendir
   (ateş 70, hızlı ateş 20, koruma 44, mermi 336, roket 384, joker etkisi 960, yerde
   1440, aralık 840–1320, yeniden deneme 120). Demo host'u gerçek kare süresini yine
   biriktirip tam tick'lere çevirir.
3. **Katalog fixture'dan:** `HouseTanksMapCatalog.swift`, `houseTanksMaps.json`'dan bir
   betikle üretilir; bir test, Swift kataloğunun fixture ile aynı olduğunu doğrular.
   Çalışma zamanında dosya okunmaz (Android'de paket kaynağı riskini önler). Standart
   haritalar 5 başlangıç noktası ve sürüm 3 ile gelir.
4. **Demo kuralı ayrı (K2):** Demonun oyuncu sayısı haritanın online aralığından değil,
   ayrı bir demo kuralından gelir (standart haritalar 4, Bodrum 6–8).
5. **Hareketsiz hedef:** Dünyaya kontrol kaybı/geri kazanımı eklenir (basılı tutma
   bırakılır, dönmez, ateş etmez, itilebilir). Senaryolardaki `loseControl` /
   `regainControl` girdileri bunu kullanır; demo kullanmaz.
6. **Go'nun bilinçli sapmaları:** Vadesi gelen yeni joker yerdekinin yerini alır; aynı
   tick'te son tanklar ölürse tur berabere biter (isabetler tick sonunda topluca
   işlenir); torba kuralı aynı.
7. **Olay modeli:** Olaylar `tick` ve sıra numarası taşır; `hit` (kalan zırh, ölümcül),
   `eliminated` (atan), `roundEnded` wire'daki karşılıklarıyla aynı alanlara sahip olur.
   Bu, online ile demo arasında tek olay modeli sağlar.
8. **Kaydet/yükle:** Dünya durumu `Codable` olur (test ve demo için).
9. **Eşitlik testi:** Çekirdek testleri senaryo dosyasını okur; dünyayı kurar, tank
   ezmelerini ve girdileri uygular, her kontrol noktasında tankları, kasaları, mermileri,
   jokeri ve olayları karşılaştırır.
10. **Çıkış:** 17 senaryo geçer; demonun motor testleri ve iki platformun testleri geçer;
    fixture hash testi geçer.

**Durum (F0 tamamlandı):**

- `HouseTanksWorld` Go `world.go`/`jokers.go` ile adım adım aynı: tick sayacı, sabit
  1180×640 arena, dünyada zırh/koruma/joker etkisi, `setControllable`, tick sonunda isabet,
  Go joker dağıtımı (`below`/`between`, yerdekinin yerine geçme, 120 tick yeniden deneme),
  `Codable` durum. Oyuncu kimlikleri artık `String` (demo `UUID.uuidString` kullanır).
- 17 senaryonun hepsi 1e-6 içinde geçti (`HouseTanksParityTests`); fixture'larda fark
  çıkmadı, backend'e bildirilecek bir uyumsuzluk yok. Sabitler ve üç fixture'ın sha256'sı
  da test ediliyor.
- Katalog `Scripts/generate_house_tanks_maps.py` ile `HouseTanksMapCatalog+Maps.swift`'e
  üretiliyor; doğrulama kuralları Go'nunkiyle aynı.
- Demo kuralı `demoPlayerCounts` (standart 4, Bodrum 6–8); köprü ve lobiler bunu kullanıyor.
- Olaylarda `tick` var; sıra numarası ve `roundEnded`, Go'da olduğu gibi maç/çalışma
  zamanı katmanında (F2) eklenecek — dünya bunları üretmez.
- iOS sahnesi `resizeFill` + arenayı sığdıran kamera (ilk denemedeki `aspectFit` iOS'ta
  yanlarda siyah şerit bırakıyordu); Android çizicisi sığdır-ortala. Tanks viewport JNI
  çağrısı kaldırıldı, köprü API sürümü 12.
- K1 uygulandı (25 Ekim 2026): arena 872×400, sözleşme `houseTanks.v2`, katalog 2
  (courtyard 4). Backend'in yeni üç fixture'ı bayt bayt kopyalandı (sha256 testte), katalog
  yeniden üretildi; 17 senaryo yine 1e-6 içinde geçiyor, backend'e bildirilecek fark yok.
  Lobi/harita önizlemelerinin en-boy oranı ve ilgili testler 872×400'e çekildi. Köprü JSON
  şekli değişmediği için API sürümü 12 kaldı.

## 4. F1 — Wire katmanı ve ortak online katman

1. §2.2'deki genelleştirme (House Rockets taşınır, testleri değişmeden geçer).
2. `Games/HouseTanks/Online/` altında wire tipleri: welcome + ayarlar, `controlGranted`,
   oyun anlık görüntüsü (oyuncular, tanklar, kasalar, joker, mermiler, olaylar), sonuç,
   istemci mesajları (`press`, `roundReady`, `resync`).
   - Kimlikler metin, tick/sıra/epoch `Int64`, kesirli UTC tarihler, 8 renk.
   - Boş (null) ve hiç yazılmamış alanlar ayrı ayrı korunur.
3. **Protokol fixture testleri:**
   - Tüm `serverMessages` örnekleri çözülüp yeniden kodlanınca aynı JSON'u verir.
   - İstemcinin ürettiği `clientMessages` örneklerle birebir aynıdır.
   - `invalidClientMessages`'taki hiçbir biçim istemci tarafından üretilemez.
4. **Uyumluluk:** `contractRevision` ya da `mapCatalogVersion` farklıysa, ya da
   `mapId` + `mapVersion` katalogda yoksa maç oynanabilir gösterilmez, "güncelleme gerekli"
   denir.
5. **Sıkıştırma (K3):** Android'de doğrulanır; iOS'ta canlıda ölçülür.
6. **Çıkış:** Fixture testleri; HTTP 401/403/404/409/429/503 ve iptal testleri.

**Durum (F1 çekirdek tarafı tamamlandı, 25 Ekim 2026):**

- **Ortak katman (K4)** `Games/Realtime/` altında (plandaki `Games/Online/` yerine mevcut
  klasör kullanıldı):
  - `GameRealtimeGame` adaptör protokolü: welcome, snapshot, sonuç, intent'ler,
    uyumluluk kontrolleri, kontrol koltuğu.
  - Genel zarf ve istemci mesajı: `GameRealtimeServerMessageOf<Game>` ve
    `GameRealtimeClientMessageOf<Game>`.
  - Genel lobi ve sonuç makineleri: `GameOnlineLobbyMachine<Game>` ve
    `GameOnlineResultMachine<Game>`.
  - Oyundan bağımsız tipler: `GameOnlineEffect`, `GameLaunchContext`,
    `GameReconnectPolicy`.
- **House Rockets:** `HouseRocketsRealtime` adaptörüne bağlandı. Herkese açık adlar
  typealias olarak kaldı. House Rockets testlerinde tek satır değişmedi:
  - Çekirdek (135) ve köprü (19) testleri geçiyor.
  - Android birim testleri geçiyor.
  - iOS uygulaması ve testleri derleniyor (simülatörde çalıştırılmadı).
- **FauseTanks wire tipleri** `Games/HouseTanks/Online/` altında: welcome ve ayarlar,
  oyun anlık görüntüsü (oyuncu, tank, kasa, joker, mermi, olay) ve sonuç.
  - Boş (null) alanlar null olarak yazılır, olay alanları yalnız varken yazılır.
  - İstemci intent'leri `press` ve `roundReady`. Sunucunun reddedeceği değerler
    (sıra < 1, negatif tick, sonsuz açı, boş nesil) kodlanmadan reddedilir.
  - Katalog `houseTanks` ayarlarını çözer. `GameKey.houseTanks` eklendi.
- **Uyumluluk:** Aşağıdakiler `requiresUpdate` verir ve otomatik yeniden bağlanmayı
  durdurur:
  - Farklı `contractRevision` ya da `mapCatalogVersion`.
  - Farklı fizik hızı, arena, zırh ya da tur kuralı.
  - Katalogda olmayan `mapId` + `mapVersion`.
- **Testler:**
  - `HouseTanksWireContractTests`: 14 sunucu örneği aynı JSON'a döner, 11 istemci
    örneği birebir üretilir, 25 geçersiz örneğin hiçbiri üretilemez. Ayrıca kurallar,
    uyumluluk, sonuç kuralları ve katalog.
  - `HouseTanksOnlineLobbyTests`: Ortak lobi makinesi FauseTanks ile çalışıyor:
    - Bağlanma ve join.
    - Güncelleme isteği.
    - HTTP 401, 403, 404, 409, 429 ve 503.
    - İptal.
    - Kontrol kapısı ve devralma.
    - Ayrılan oyuncunun geri dönememesi.
- **Sıkıştırma (K3):** Android'de `RealtimeCompressionTest`, OkHttp'nin
  `permessage-deflate` teklif ettiğini ve sıkıştırılmış kareyi okuduğunu doğruluyor. iOS
  ölçümü canlı sunucuyla yapılacak.
- **F2'ye kalanlar:**
  - Sonuç makinesinin FauseTanks maçına bağlanması.
  - Online maç makinesi ve render modeli.
  - Platform host'ları (iOS `HouseTanksOnlineHost`, Android köprüsü).

### F2 durumu (25 Ekim 2026)

- **Çekirdek:**
  - `HouseTanksOnlineEngine` (`Games/HouseTanks/Online/`), House Rockets'in effect
    modelinde. Ortak lobi ve sonuç makinesini FauseTanks'e bağlıyor.
  - Akış: `PUT` → soket → welcome + oturum → join → hazır.
  - Ping 2 sn'de bir. `controlHeartbeatMilliseconds` welcome ayarından okunuyor.
  - `arena`: her anlık görüntüden sunucunun dünyası. Yeni `HouseTanksWorld(server:)` ile
    kuruluyor: tanklar, kasalar, mermiler ve joker. `phase = countdown` iken önizleme
    olarak çiziliyor.
  - `roomCountdown(at:)`: hazır penceresi, maç geri sayımı ve tur geri sayımı.
  - Harita katalogda yoksa ya da sözleşme uyuşmazsa `requiresUpdate` doğru oluyor ve
    otomatik yeniden bağlanma yapılmıyor.
  - `HouseTanksOnlineCopyKeys` hangi durumda hangi metnin görüneceğini belirliyor.
    TR/EN metinler `HouseTanksLocalization`'a eklendi.
- **Ortak katman değişikliği:** "Hazırım" yalnız yatay ekranda sayılıyordu (House
  Rockets kuralı). Artık bu oyuna göre seçiliyor: `GameRealtimeGame.readyRequiresLandscape`.
  FauseTanks'in odası dikey; ekran maç başında döner.
- **iOS:**
  - House Rockets host'u genel `GameOnlineHost<Engine>` oldu
    (`Services/Games/General/GameOnlineHost.swift`). House Rockets aynı adları
    typealias ile koruyor.
  - `HouseTanksOnlineHost` ve `HouseTanksOnlineFactory` uygulama bağımlılıklarına
    eklendi.
  - Online oda gerçek oturuma bağlı:
    - Durum kartı ve tekrar deneme.
    - Güncelleme uyarısı.
    - Kadro: hazır durumu, sunucunun verdiği ad ve renk.
    - Hazırım / Hazır değilim düğmesi ve pencere sayacı.
    - Kurucu için iptal.
    - Geri sayımda tankları yerleşmiş harita önizlemesi ve sayaç.
  - Katalogda `houseTanks` yoksa oda kapalı gösteriliyor. Odadan çıkışta `leave`
    gönderiliyor.
- **Android:**
  - `HouseTanksOnlineBridge.swift` (köprü API 13, 62 JNI metodu).
  - `HouseRocketsOnlineSession`'ın genel kısmı `GameOnlineSession`'a taşındı; üstüne
    `HouseTanksOnlineSession` eklendi.
  - Oda ekranı iOS ile aynı.
- **Testler:**
  - Çekirdek: 156/156. Yeni `HouseTanksOnlineEngineTests` (6 test): oda akışı ve geri
    sayım önizlemesi, ping aralığı, bilinmeyen harita, koltukların katalogla eşleşmesi,
    sunucu arenası, odadan çıkış.
  - Köprü: 21/21.
  - Android: 67 test, 0 hata.
  - iOS: uygulama ve test hedefi derleniyor; simülatörde çalıştırılmadı.
- **Canlı kabul:** Yapılmadı (ortam engelli). Mock testi canlı kabul sayılmaz. Gereken:
  aynı evde iki hesap, iki cihaz, odaya gir, ikisi de hazır. İkisi de geri sayımı ve
  aynı haritayı görmeli.
- **Bilerek F3'e bırakılanlar:**
  - Maç başlayınca oda "Maç sürüyor" diyor; oyun ekranı yok.
  - Düğme, girdi ve tur akışı yok.

### F3 durumu (25 Ekim 2026)

- **Çekirdek:**
  - `HouseTanksOnlinePlayMachine` (`Games/HouseTanks/Online/`), `HouseTanksOnlineEngine`
    içinde. Ayarlar `HouseTanksPlayConfiguration`'da. Bunlar sunum bütçeleri, oyun kuralı
    değil:
    - 100 ms gecikme
    - 150 ms ileri tahmin
    - 8 kare tampon
    - 350 ms'de "eşitleniyor"
  - **Düğme:** Yalnız `validControl` doğruysa açılıyor. Bunun için grant, eşleşen
    `runtimeEpoch`, kendi `controlGeneration`, yatay ekran, ön plan, oynanan tur ve canlı
    tank gerekiyor.
    - Basma ve bırakma yalnız durum değişince gidiyor. `inputSequence` her nesilde
      sunucunun ACK'inden devam ediyor.
    - `clientTick` ve `heading` çizilen son kareden alınıyor.
    - Gönderim kendi sınırıyla 30/sn'yi geçmiyor.
  - **Çizim:**
    - Diğer tanklar ve kasalar iki kare arasında aradeğerleniyor. Mermiler ileri
      taşınıyor.
    - Kendi tankın dönüşü, onaylanmamış basışlarla ortak motordan tahmin ediliyor.
      Sunucu karesi gelince fark 80 ms'de eritiliyor; 40 px / 0,6 rad'dan büyükse
      doğrudan atlanıyor.
    - Eski ve tekrar eden kareler atılıyor. Tick geri giderse eşitleme yeniden kuruluyor.
  - **Olaylar:** `(runtimeEpoch, sequence)` ile bir kez gösteriliyor. Yeni bir zaman
    çizelgesinde geçmiş olaylar tekrar oynatılmıyor.
  - **Reddedilen mesajlar:**
    - `stale_control` → kontrol temizleniyor, bir kez resync.
    - `player_eliminated` → "bu turda öldün".
    - `rate_limited` / `unavailable` → kısa bekleme, sonra tutulan durum yeniden
      gönderiliyor.
  - **Ekran durumu:** Enkazlar, joker göstergeleri, bağlantısı kopan tank (soluk + işaret)
    ve 8 koltuklu durum çubuğu `HouseTanksOnlinePresentation`'da.
  - **Afiş:** Hangi afişin görüneceğini `HouseTanksOnlineCopyKeys.matchNotice` seçiyor:
    çıkış, güncelleme, sonlanıyor, bitti, yeniden bağlanıyor, hata, kontrol taşındı,
    kurtarılıyor, eşitleniyor, öldün ve tur bitti.
- **iOS:** `HouseTanksOnlineMatchView`.
  - Sunucu arenası yatayda ve tüm alan tek düğme.
  - Koltuk çubuğu, tur sayacı, afiş (tekrar dene, kontrolü geri al, çık) ve çıkış onayı.
  - Sahne bağlantısı kopan tankı soluk ve `wifi.slash` işaretiyle çiziyor.
- **Android:**
  - Köprü API 14 (63 JNI metodu). Yeni `houseTanksOnlineFrame(handle, now)` her karede
    arenayı ve çubukları veriyor.
  - `HouseTanksOnlineGameLayer` iOS ile aynı. Ekran maç başlayınca yataya dönüyor ve
    tam ekran oluyor. Geri tuşu çıkış onayını açıyor.
  - APK: `~/Downloads/FausCrew-F3-Oynanis-debug.apk`.
- **Testler:**
  - Çekirdek: 174/174. Yeni `HouseTanksOnlinePlayTests` (18 test):
    - düğme kapısı ve dikey ekran
    - değişimde basma/bırakma ve ACK
    - geç ve tekrar eden kareler
    - aradeğerleme ve mermiler
    - tahmin ve yumuşak düzeltme
    - olay tekrarı
    - enkaz
    - red kodları
    - bağlantısı kopan tank
    - aynı nesle yeniden bağlanınca sıranın sürmesi
    - yeni tura basılı giren parmak
    - kare boşluğunda kaydırmama
  - Köprü: 22/22.
  - Android: 67 test, 0 hata. Bağlama denetimi geçti.
  - iOS: uygulama ve test hedefi derleniyor; simülatörde çalıştırılmadı.
- **Canlı kabul:** Yapılmadı (kullanıcı sonra yapacak). Kontrol edilecekler:
  - İki cihaz aynı turu görüyor.
  - Basınca dönme/ateş gecikmesi hissediliyor mu? Gerekirse 100 ms gecikme ayarlanacak.
  - Bir cihaz uçağa alınınca öbüründe soluk tank ve işaret çıkıyor mu?
  - Ölünce "bu turda öldün" görünüyor mu?
- **Gözden geçirme düzeltmeleri (25 Ekim 2026):** Backend'in `press` kurallarıyla
  (`runtime.go`) karşılaştırıldı:
  - **Sıra numarası:** Sunucu, kabul ettiği en yüksek sıranın altını ve kendisini
    `stale_control` ile reddediyor. Bu sınır ACK'in üstünde olabilir; örneğin süresi geçen
    girdiler işlenmiş sayılmıyor. Aynı nesle yeniden bağlanınca (yatay → dikey → yatay,
    resync) istemci ACK'ten başlıyordu ve düğme kalıcı olarak ölebiliyordu. Artık nesil
    başına gönderilen en yüksek sıra tutuluyor ve oradan devam ediliyor.
  - **Bırakma:** `canPress` kısa bir an kapanınca (geç kare) arayüz bırakma
    gönderiyordu. Tank duruyor; iOS'ta parmak kıpırdayınca yeniden basılıp fazladan ateş
    ediliyordu. Artık bas/bırak yalnız parmak inip kalkınca gidiyor; iptal edilen dokunuş
    da bırakma sayılıyor. Yeni tura basılı girilen parmağı çekirdek zaten yok sayıyor.
  - **Kare boşluğu:** Yeniden bağlanma ya da kayıp kareden sonra tanklar eski kareden
    yenisine kayıyordu. Artık 350 ms'den uzun boşlukta tampon sıfırlanıyor ve yeni kare
    tutuluyor.
  - **Eski ya da eşit kare:** Erken dönüş, aynı yayındaki grant'i atlıyordu. Artık yalnız
    çizim atlanıyor.
- **Bilerek F4'e bırakılanlar (F4'te yapıldı):** `roundReady` sırasında yalnız "tur bitti /
  kazanan" afişi vardı. Oylama paneli, sonuç ekranı ve rövanş F4'te eklendi.

### F4 durumu (25 Ekim 2026)

- **Tur oylaması (çekirdek, `HouseTanksOnlinePlayMachine`):**
  - `houseTanks.roundReady {controlGeneration, ready}` yalnız `roundReady` sırasında,
    kontrol oyuncudayken ve izleyici değilken gönderiliyor. Tankı ölen oyuncu da oy veriyor.
  - Oy hemen gösteriliyor (bekleyen oy), anlık görüntü aynı değeri gösterince, tur ya da
    epoch değişince, faz `roundReady`'den çıkınca ya da 2 sn içinde yanıt gelmezse
    düşüyor. Reddedilen oy anlık görüntüye döner; `stale_control` kontrolü bırakıp resync
    istiyor.
  - Panel: tur başlığı (berabere / sen kazandın / X kazandı), 30 sn pencere sayacı
    (`roundReadyWindowEndsAt`'ten), pencere yoksa "en az iki oy" açıklaması, bağlı
    oyuncular içinde hazır sayısı ve hazır/vazgeç düğmesi. Koltuk çiplerinde oy işareti.
  - Tur geri sayımı maç başındaki `phase = countdown` sırasında da gösteriliyor.
- **Sonuç (ortak `GameOnlineResultMachine`):** Socket sonucu, kaybolursa HTTP, `sessionId`
  ile tekilleştirme. Şampiyon yalnız tamamlanmış sonuçta (`phase = ended`, `championId`).
  Panel: "sonuç kaydediliyor", şampiyon (sen / X), iptal nedenleri, sıralama (eşitler aynı
  sırada, iptalde sırasız), tur galibiyetleri, yeniden dene, çık ve rövanş.
- **Rövanş:** Biten oturum dışlanarak yeni oturum açılıyor; oyun ekranı kalıyor ve ilk
  anlık görüntüye kadar ekranda rövanş odası (üyeler, hazır, pencere sayacı, iptal)
  gösteriliyor. Lobi ekranına dönülmüyor.
- **Çıkış:** Sonuç ya da rövanş odası açıkken çıkış onaysız. Biten motor kendini "kapandı"
  saymadığı için çıkışta oturum doğrudan kapatılıyor (iki platform).
- **Android:** Köprü JSON'una oy, panel ve sonuç alanları eklendi; yeni JNI yöntemi yok
  (sürüm 14 kaldı). Çıkış onayındaki "kal" düğmesi yanlış metin anahtarını kullanıyordu,
  düzeltildi.
- **Doğrulama:**
  - Çekirdek: 180/180 (24 oynanış testi; 6'sı F4).
  - Köprü: 22/22 (oy, panel ve sonuç JSON'u dahil).
  - Android: 67 test, 0 hata. Bağlama denetimi geçti.
  - iOS: uygulama ve test hedefi derleniyor; simülatörde çalıştırılmadı.
  - APK: `~/Downloads/FausCrew-F4-TurSonuc-debug.apk`.
- **Canlı kabul:** Yapılmadı. Kontrol edilecekler:
  - İki oy 30 sn pencereyi açıyor mu, herkes hazır olunca tur hemen başlıyor mu?
  - Ölen oyuncunun oyu sayılıyor mu?
  - Maç sonunda şampiyon ve sıralama iki cihazda aynı mı?
  - Rövanş yeni oturumu açıyor ve iki cihaz aynı odaya düşüyor mu?

### F5 durumu (25 Ekim 2026)

- **Önceden hazır olanlar (F1–F3'ten, ortak lobi makinesi):**
  - Kopmada aynı maça sınırlı backoff ile yeniden bağlanma. Bekleme süresi
    `reconnectGraceMilliseconds`'tan alınıyor; yeni `PUT` atılmıyor.
  - İkinci cihaz devrinin anlık görüntüden anlaşılması ve "kontrolü geri al".
  - Yeni epoch'ta eski grant, sıra sayacı, tahmin ve olay geçmişinin düşmesi.
  - `recovering` afişi.
  - Arka planda ping kesiliyor; ön plana dönünce resync atılıyor.
  - Açık çıkış (`leave`) ve ekran kapanınca temizlik.
- **F5'te düzeltilenler (çekirdek):**
  - **Devir yarışı:** `stale_control` gelince istemci hemen resync istiyordu. Backend'de
    resync bağlantıyı yeniden bind ediyor (`gatewayV2.go`, `needBind`). Yeni cihazın
    bind'i, onu gösteren kareden önce red olarak gelirse eski cihaz tankı geri alıyordu;
    iki cihaz arasında döngü oluşabiliyordu. Artık önce sonraki kareler bekleniyor
    (0,5 sn): devir görünürse resync yok, yalnız "kontrolü geri al" bind ediyor. Grant
    hâlâ geçerli görünüyorsa tek bir resync gidiyor.
  - **Bırakma:** Arka plana geçerken ya da dikeye dönerken basılı düğme, grant hâlâ
    gönderebilirken bırakılıyor. Önceden tank, sunucu kontrolü düşürene kadar (6 sn)
    sürmeye devam edebiliyordu.
  - **Hareketsiz hedef bildirimi:** Kendi tankın canlıyken grant 0,5 sn'den uzun gelmezse
    (yeniden bağlanma, yeni epoch) "Tankın bağlanıyor…" afişi çıkıyor. Tank zaten soluk
    ve işaretli çiziliyor. Daha kısa beklemeler (tur başı, rebind) sessiz geçiyor.
  - **İzleyici:** Oyuncu snapshot'ta yoksa, ayrılmışsa ya da `control_unavailable`
    aldıysa "İzliyorsun" afişi ve çık düğmesi çıkıyor; "bu turda öldün" ve oy paneli
    gösterilmiyor.
- **Platformlar:**
  - **Oturum düşmesi (401):** Lobi ya da sonuç 401 alınca House Rockets'teki gibi oyun
    kapanıyor ve uygulama çıkış yapıyor (iOS ve Android).
  - **iOS:**
    - Maç sırasında ev ya da hesap değişince oda kapanıyor; lobi yeni evin odasını açıyor.
    - Uygulamadan çıkış yapılınca oyun duruyor.
  - **Android:** Ev sahibi değişince sürmekte olan maçtan çıkılıyordu; artık yalnız
    kurucu bilgisi güncelleniyor. Ev ya da hesap değişince çıkılıyor.
  - Köprüye `isSpectating` alanı eklendi; JNI değişmedi (sürüm 14).
- **Doğrulama:**
  - Çekirdek: 189/189. 9 yeni test, 1 test güncellendi:
    - devirle kavga etmeme
    - kopma, yeniden açılma ve yeni nesille dönüş
    - `recovering` ve yeni epoch
    - yeni epoch'ta oyun düşmesi
    - arka plan
    - dikey ekran
    - grant bekleme afişi
    - izleyici
    - ekran kapanınca temizlik
    - güncellenen: `stale_control` sonrası tek resync
  - Köprü: 22/22.
  - Android: 67 test, 0 hata. Bağlama denetimi geçti.
  - iOS: uygulama ve test hedefi derleniyor; simülatörde çalıştırılmadı.
  - APK: `~/Downloads/FausCrew-F5-Dayaniklilik-debug.apk`.
- **Canlı kabul:** Yapılmadı. Sahip kaybı ancak staging'de backend ile birlikte
  denenebilir. Kontrol edilecekler:
  - Uçak modu 2–5 sn: aynı maça dönüş, kısa "Tankın bağlanıyor…", sonra kontrol.
  - Aynı hesapla ikinci cihaz: eski cihazda "Kontrol başka cihazda", geri al çalışıyor
    ve cihazlar birbirinden kontrolü kapmıyor.
  - Arka plana al ve geri dön: tank durmuş, dönüşte düğme çalışıyor.
  - Backend'in sahip instance'ını düşürmesi: "Arena yeniden kuruluyor", sonra oyun sürüyor.

## 5. F2–F5 — Online maç

### 5.1. Çekirdek: online maç makinesi

`HouseTanksOnlineEngine` (House Rockets'in effect modelinde), genel lobi makinesinin
üstünde:

- **Lobi ve maç başı (F2):** `PUT` → soket → welcome + oturum anlık görüntüsü → join →
  ready; lobi geri sayımında önizleme arenası (`roundPhase = null`); 2 sn'de bir ping.
- **Kontrol (F3):** Düğme yalnızca grant + eşleşen epoch + kendi `controlGeneration`'ı
  görünen bir `playing` anlık görüntüsü varken açılır. Bas/bırak yalnız değişimde,
  `inputSequence` nesle göre baştan; `clientTick` ve `heading` ekranda gösterilen
  durumdan alınır. Sunucunun basışı uyguladığı varsayılmaz; durum anlık görüntüden okunur.
- **Çizim zamanı (F3):** Diğer tanklar ve kasalar küçük bir tampondan ara değerle çizilir
  (başlangıç 100 ms, ölçümle ayarlanır). Oyuncunun kendi tankının dönüşü tahmin edilir
  (1,5 rad/s, `rotationDirection` yönünde) ve sunucu karesiyle uzlaştırılır. Mermiler
  konum ve hızdan tick farkıyla ilerletilir. İsabet, ölüm, kasa ve kazanan yalnızca
  sunucudan gelir.
- **Olaylar (F3):** `(runtimeEpoch, sequence)` ile tekilleştirilir; her biri bir kez
  oynatılır.
- **Tur akışı (F4):** Tur geri sayımı ve hazır paneli sunucunun son tarihlerinden çizilir;
  tankı ölen oyuncu da oy verir; berabere tur; şampiyon yalnız `phase = ended`'da.
- **Sonuç ve rövanş (F4):** Socket sonucu, kaybolursa HTTP'den okuma (commit bekleyen 404
  sınırlı tekrarla), `sessionId` ile tekilleştirme; rövanş yeni oturum, panel oyun ekranında.
- **Dayanıklılık (F5):** Hareketsiz hedef gösterimi (`controllable = false`,
  `connected = false`), yeniden bağlanma, ikinci cihaz devri, epoch değişimi ve
  `recovering`, arka plandan dönüşte `resync`, açık çıkış (`leave`), çıkış yapma ve ev
  değişiminde temizlik.

### 5.2. Platform host'ları

- **iOS:** `HouseTanksOnlineHost` House Rockets host'unun genel kısmını paylaşır
  (URLSession ile HTTP ve WebSocket, 25 ms'lik motor tick'i). Uygulama bağımlılıklarına
  FauseTanks oturum fabrikası eklenir.
- **Android:** `HouseTanksOnlineBridge.swift` (JNI) ve `HouseTanksOnlineSession.kt`,
  House Rockets'teki ikiliyle aynı yapıda; OkHttp soket fabrikası ve HTTP adaptörü yeniden
  kullanılır.

### 5.3. Ekranlar (iki platform)

- **Online oda:** Gerçek oturuma bağlanır. Üyeler ve hazır durumları, hazır/hazır değil,
  30 sn pencere ve geri sayım; geri sayımda harita önizlemesi; katalogda `houseTanks`
  yoksa oda kapalı gösterilir (oyunun açık olduğu sabit kabul edilmez).
- **Oyun içi:**
  - 8 oyuncuya kadar üst bilgi çubuğu.
  - Bağlantısı kopan tank için görsel işaret (soluk görünüm + bağlantı simgesi).
  - "Bu turda öldün" bildirimi (maçtan elenmek değil).
  - Oyun içi tur hazır paneli (kim hazır, pencere sayacı).
  - "Yeniden bağlanıyor" ve "sonuç kaydediliyor" durumları.
  - Şampiyon ya da iptal sonucu ve rövanş paneli; lobiye dönülmez.
- **Metinler:** Yeni metin anahtarları çekirdekteki FauseTanks metin tablosuna eklenir
  (TR/EN).

## 6. F6 — Gerçek cihaz kabulü

İki (ideal olarak 4–8) gerçek cihazla tam maç; 100/200/400 ms gecikme, oynama ve kısa
kopmalar; iPhone ve Android. Senin talimatın gereği simülatör ya da emülatörle test
yapılmaz; cihaz testlerini sen yaparsın. Yayın kararı backend ile ortaktır.

### F6 hazırlığı (25 Ekim 2026)

> **26 Ekim 2026:** Ağ paneli ve uygulama içi gecikme seçimi ilk cihaz denemesinden sonra
> kaldırıldı; yerlerine her derlemede görünen FPS çipi geldi (aşağıda "Cihaz geri bildirimi
> revizyonu"). Bu bölüm o zamanki hâli anlatıyor.

F6 cihaz kabulüdür; istemcide ürün özelliği eklenmedi. Cihaz testini ölçülebilir kılmak
için **yalnız debug derlemelerde** iki araç eklendi.

- **Ağ paneli:**
  - Maç ekranında kapat düğmesinin yanında anten düğmesi var (iOS `#if DEBUG`, Android
    `FLAG_DEBUGGABLE`). Satırlar çekirdekten geliyor, iki platformda aynı
    (`HouseTanksOnlineDiagnostics.lines`).
  - Gösterdikleri:
    - bağlantı ve epoch
    - RTT (son ping → pong)
    - snapshot aralığı ± sapma ve son karenin yaşı
    - basış → ACK süresi (hissedilen gecikme) ve bekleyen basış
    - çizim gecikmesi, FPS ve KB/s (açılmış metin; deflate ile kablodaki daha az)
    - geç kare, boşluk sıfırlaması, yumuşak düzeltme ve atlama sayısı
    - `stale_control`, `rate_limited` ve yeniden bağlanma sayısı
- **Gecikme benzetimi:**
  - Aynı panelde RTT +0/100/200/400 ms ve jitter ±0/30/60 ms seçiliyor.
  - Çekirdekte, soket mesajlarını iki yönde RTT/2 ± jitter tutuyor; sıra korunuyor (TCP
    gibi). Soket kapanınca bekleyen gönderimler düşüyor.
  - Seçim, uygulama kapanana kadar odalar ve rövanşlar boyunca kalıyor.
  - Sınırlar: HTTP (oturum, sonuç) geciktirilmiyor; gerçek radyo kaybının yerine
    geçmez. iOS'ta gerçekçi ağ için ayrıca Ayarlar → Geliştirici → Network Link
    Conditioner kullanılabilir.
- **Release:** iOS Release derlemesi panelsiz derleniyor (doğrulandı). Android release'te
  düğme görünmüyor.
- **Doğrulama:**
  - Çekirdek: 191/191. Yeni testler: benzetimin iki yönde ve sırayla tutması, kapanan
    soketin bekleyenleri düşürmesi, kapatınca hepsini göndermesi; ölçümlerin (RTT,
    aralık, yaş, ACK, geç kare, FPS) doğru çıkması.
  - Köprü: 22/22 (panel açıkken kare satırları taşıyor).
  - Android: 67 test, 0 hata. Bağlama denetimi geçti; JNI sürüm 14 kaldı.
  - iOS: Debug ve Release derleniyor; simülatörde çalıştırılmadı.
  - APK: `~/Downloads/FausCrew-F6-CihazKabul-debug.apk`.

### Cihaz geri bildirimi revizyonu (26 Ekim 2026)

Bir iPhone ve bir Android ile oynanan ilk maçtan sonra gelen dört revizyon:

- **Başlangıç sayacı:**
  - Lobide harita çekilmeden önce "Kura haritası" kartının yerinde, harita önizlemesi
    boyutunda (872:400) bir "Başlangıç sayacı" kartı var.
  - Hazır penceresi açıkken büyük saniye gösteriliyor (son 5 sn kırmızı), altında hazır
    sayısı. Pencere açılmadan önce "en az {minimum} kişi hazır olunca başlar" yazıyor.
  - Alt çubuktaki küçük saniye etiketi kaldırıldı. Harita çekilince (maç geri sayımı)
    kart yine haritayı ve üstündeki sayacı gösteriyor.
- **FPS çipi:**
  - Ağ paneli (anten düğmesi, satırlar, RTT/jitter seçimi) iki platformdan kaldırıldı.
  - Sol üstte kapat düğmesinin yanında her derlemede sade bir FPS çipi var; açılır
    değil, dokunulmaz.
  - Değer çekirdekten geliyor (`HouseTanksOnlineEngine.displayFramesPerSecond`, son 1 sn'de
    çizilen sunum); saniyede iki kez yenileniyor.
  - Renk `HouseTanksFrameRate.quality`: 20 fps ve altı kırmızı, 55 fps ve üstü yeşil,
    arası tondan tona.
  - Çekirdekteki ölçüm ve gecikme benzetimi testlerde kaldı; uygulamadan erişilmiyor.
  - Köprü: kare JSON'unda `fps` var; `setDiagnostics` ve `setLatencySimulation`
    olayları kaldırıldı.
- **Ortalanmış oyun sonu menüsü:**
  - Maç bittiği anda açılıyor: `finalizing`, `ended`, `cancelled`, `matchEnded` ya da
    terminal oda (`HouseTanksOnlineCopyKeys.isMatchOver`). Sonucun gelmesi beklenmiyor.
  - Ekran ortasında; çıkış ve rövanş düğmeleri, gerekirse sonucu yeniden deneme var.
  - Alttaki "Maç bitti" ve "Sonuç kaydediliyor" afişleri artık çıkmıyor.
  - Oyun sonunda ve rövanş odasında sol üstteki kapat düğmesi ve FPS çipi gizli.
- **Sonuçlar herkese:**
  - Menü sıralamayı hep gösteriyor (`HouseTanksOnlineCopyKeys.standings`).
  - Kalıcı sonuç gelmeden önce son koltuklar tur galibiyetine göre geçici ve sırasız
    listeleniyor, "kalıcı sonuç gelince netleşir" notuyla. Sonuç gelince kayıtlı sıralar
    yerini alıyor.
  - Böylece erken çıkan oyuncu da çıkmadan önce sonucu görüyor.
  - Sonuç gelmeden başlık "Sonuç kaydediliyor" (`idle` artık `waiting` gibi).
- **Doğrulama:**
  - Çekirdek: 192/192 (yeni: maç sonu algısı, geçici ve kayıtlı sıralama, FPS).
  - Köprü: 22/22 (karede `fps`; kaldırılan olay reddediliyor).
  - Android: 67 test, 0 hata; bağlama denetimi geçti, JNI sürüm 14 kaldı.
  - iOS: Debug derleniyor; simülatörde çalıştırılmadı.
  - APK: `~/Downloads/FausCrew-Revize1-debug.apk`. Canlı kabul henüz yapılmadı.

### Cihaz geri bildirimi revizyonu 2 (26 Ekim 2026)

İlk revizyonda oyun sonu menüsü ortalanmamıştı ve tur arası paneli alttaydı.

- **Neden:**
  - Kart görünümü (`houseTanksFieldCard`) kendini sunulan tüm genişliğe yayıp içeriği
    sola yaslıyor.
  - 460 pt sınırı kartın içine uygulandığı için kart ekran boyu genişliyor, içerik de
    solda kalıyordu.
- **Oyun sonu menüsü ve rövanş odası (iOS):**
  - Genişlik sınırı kartın dışında; menü yatayda ve dikeyde ortada.
  - Yükseklik satırlar kadar; sığmazsa kaydırılıyor (`ViewThatFits`).
- **Tur arası paneli (iki platform):**
  - Ekranın ortasında, hafif karartmalı bir popup (en fazla 460 genişlik).
  - Turu kimin aldığı, pencere süresi ve hazır sayısı her cihazda gösteriliyor.
  - İzleyici de paneli görüyor: `roundReady`'de "İzliyorsun" afişi artık çıkmıyor.
  - "Maçtan çık" ve "Hazırım" yan yana. Çıkış onay sorusuyla, çünkü maçın ortasında
    kalıcı ayrılık.
- **Sol üstteki X:** Yalnız aktif turda görünüyor. Tur arasında, oyun sonunda ve
  rövanş odasında gizli. FPS çipi tur arasında kalıyor.
- **Doğrulama:**
  - Çekirdek 192/192 (izleyicinin tur arasında afiş görmemesi dahil), köprü 22/22.
  - iOS Debug derleniyor.
  - Android: 67 test, 0 hata; bağlama denetimi geçti (JNI 14).
  - APK: `~/Downloads/FausCrew-Revize2-debug.apk`. Cihazda henüz denenmedi.

### F6 kabul protokolü

> Uygulama içi benzetim kaldırıldı. "Benzetim" sütunundaki gecikmeler iOS'ta Ayarlar →
> Geliştirici → Network Link Conditioner ile, Android'de ağ tarafında (ör. yönlendirici ya
> da paylaşılan hotspot üzerinden) verilir. Ekranda yalnız FPS okunur; diğer ölçüler
> göz testi ve backend log'larıyla not edilir.

- **Ön koşullar:**
  - Backend deploy edilmiş, oyun test evinde açık (`GET /game/catalog`).
  - Aynı evde en az iki test hesabı. Production açılmaz; token ya da secret not edilmez.
- **Cihazlar:** En az bir iPhone ve bir Android. Varsa iPad (uygulama iPad'i destekliyor),
  120 Hz bir cihaz ve 4–8 kişilik bir tur.
- **Her senaryoda not edilecekler:** FPS çipindeki değer ve rengi. Göz testi: tank
  kayıyor ya da zıplıyor mu, basış geç mi hissediliyor?

| # | Senaryo | Benzetim | Beklenen |
|---|---|---|---|
| 1 | Tam maç (3 galibiyet) → sonuç → rövanş | 0 | Maç bitince iki cihazda ortada menü ve sıralama; aynı şampiyon; rövanş aynı odaya |
| 2 | Tam maç | RTT 100 | Dönüş tepkisi anında; diğer tanklar akıcı; atlama ≈ 0 |
| 3 | Tam maç | RTT 200 ± 30 | Oynanabilir; düzeltmeler küçük; ateş geç ama tutarlı |
| 4 | 2–3 tur | RTT 400 ± 60 | Bozulma kabul edilebilir mi? Atlama sayısı ve "eşitleniyor" sıklığı not edilir |
| 5 | Uçak modu 2–5 sn, tur ortasında | 0 | "Yeniden bağlanıyor" → kısa "Tankın bağlanıyor…" → kontrol; maçtan düşmeme |
| 6 | Uçak modu > 10 sn | 0 | Bağlantı hatası ve "Tekrar dene"; rakipte tank hareketsiz hedef |
| 7 | Aynı hesap ikinci cihazda | 0 | Eskisinde "Kontrol başka cihazda"; geri al çalışıyor; kapışma yok |
| 8 | Basılıyken arka plana al, 5 sn sonra dön | 0 | Tank durmuş; dönüşte kısa eşitleme, sonra düğme çalışıyor |
| 9 | Ölünce oy ver; iki oy → 30 sn pencere; herkes hazır | 0 | Ölen oyuncu oy veriyor; herkes hazır olunca tur hemen başlıyor |
| 10 | Maç ortasında "Çık" | 0 | Rakipte tank kalıyor (hareketsiz); 1 oyuncu kalırsa iptal sonucu |
| 11 | Sahip instance kaybı (backend ile, staging) | 0 | "Arena yeniden kuruluyor", sonra aynı skorla devam; oylar sıfırlanmış |
| 12 | 8 oyuncu ağır atış | 0 | FPS not edilir; çip sarı ya da kırmızıya düşüyor mu? |

- **Ayar kararı:** Senaryo 2–4'te diğer tanklar takılıyorsa çizim gecikmesi
  (`interpolationDelay`, şu an 100 ms) yükseltilir. Basış hissi kötüyse ileri tahmin
  sınırına bakılır. Değerler yalnız sunum bütçesidir, wire kuralı değil.
- **Backend'e iletilecek:**
  - Senaryo 11 için zamanlama koordinasyonu.
  - K3: iOS'un `permessage-deflate` teklif edip etmediği, gateway'in el sıkışma
    log'undan doğrulanabilir mi?
- **Raporlama:** Her senaryo için cihaz, sürüm, benzetim, ölçüler, geçti/kaldı ve not.
  Mock testi canlı kabul sayılmaz.

## 7. Test ve raporlama

- Her fazdan sonra değişen dosyalar, çalıştırılan testler ve canlı kabul durumu ayrı
  raporlanır. Mock testi canlı kabul diye yazılmaz.
- Testler:
  - Çekirdek: `swift test` (eşitlik, protokol, online makine).
  - Köprü: `swift test`.
  - Android: JVM birim testleri.
  - iOS: derleme (simülatör olmadığı için testleri ancak sen bir simülatör açarsan
    çalıştırırım).
- Canlı kabul için: deploy, test hesapları ve aynı evde en az iki üye gerekir. Bunlar
  yokken DTO, mock ve fixture işleri sürer; canlı kabul "ortam engelli" olarak raporlanır.
- Fixture ile uyuşmazlık görülürse fixture değiştirilmez; somut fark (dosya, alan,
  senaryo, beklenen/gerçek değer) backend'e bildirilir.

## 8. Sıra ve bağımlılıklar

| Faz | Bağımlı olduğu | Canlı ortam gerekir mi |
|---|---|---|
| F0 motor eşitliği | K1, K2 | Hayır |
| F1 wire + ortak katman | F0 (render modeli), K4 | Yalnız sıkıştırma ölçümü (K3) |
| F2 lobi | F1 | Kabul için evet |
| F3 oynanış | F2 | Kabul için evet |
| F4 tur ve sonuç | F3 | Kabul için evet |
| F5 dayanıklılık | F4 | Kabul için evet (sahip kaybı backend ile) |
| F6 cihaz kabulü | F5 | Evet |

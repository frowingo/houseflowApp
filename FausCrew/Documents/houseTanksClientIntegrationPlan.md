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

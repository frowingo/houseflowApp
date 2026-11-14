# Backend agent prompt'u — Faus Switch online (2–8 oyuncu)

Aşağıdaki metin `houseflowApi` backend agent'ına olduğu gibi verilmek için yazıldı.

---

## Görev

`houseflowApi` içinde **Faus Switch** (`gameKey = fausSwitch`) için gerçek zamanlı, sunucu
otoriter bir oyun modülü yaz: `internal/application/game/games/fausSwitch`. Oyun 2–8 oyuncuyla
oynanır. Modül şu an hiç yok; `games/builtin.go` yalnız `houseRockets`, `houseTanks`,
`ticTacToe` kaydediyor.

İstemci (iOS) tarafı hazır ve bu sözleşmeyle konuşan bir sunucu bekliyor. Senin işin istemcinin
fiziğini Go'ya **birebir** taşımak ve ortak realtime çekirdeğine bağlamak.

## Kısıt: `houseflowApp` salt okunur

`/Users/frowing/Projects/houseflowApp` altındaki hiçbir dosyayı değiştirme, silme ya da oluşturma.
Bu dizinde git komutu çalıştırma (commit, checkout, stash vb.) ve build ya da test çalıştırma.
Bütün yazma işin `/Users/frowing/Projects/houseflowApi` içinde. Fixture'ı oradan **kopyala**.
İstemci tarafında bir değişiklik gerekiyorsa (fixture düzeltmesi, simülasyon fixture'ı, sözleşme
sorusu) kendin yapma, notunda iste.

## Önce oku (tek doğru kaynak bunlar)

1. **Brifing (tam kurallar ve sözleşme):**
   `/Users/frowing/Projects/houseflowApp/FausCrew/Documents/fausSwitchBackendBriefing.md`
   Fizik adım sırası (§4.4), kamera ve geride kalma çizgisi (§4.2.1), start platformları,
   geri sarmalı flip (§6), snapshot alanları, kalıcı sonuç (§7) ve test beklentileri (§8) orada.
2. **Swift referans motoru:**
   `/Users/frowing/Projects/houseflowApp/FausCrew/shared/Sources/FausCrewCore/Games/FausSwitch/`
   - `FausSwitchModels.swift`: sabitler.
   - `FausSwitchCourse.swift`: parkur verisi, portallar, şeritler, `FausSwitchStartGrid`.
   - `FausSwitchTrack.swift`: kamera ve `turnCarry`.
   - `FausSwitchPhysics.swift`: adım, temas, destek ve sıralama.
   - `Online/FausSwitchWireModels.swift` ve `Online/FausSwitchRealtime.swift`: wire modelleri.
   - Bot dosyaları (`FausSwitchBot*`) yalnız demo içindir. Online'da bot yok, taşıma.

   Parkur koordinatlarını Swift dosyasından **aynen** al, elle yeniden yazma.
3. **Sözleşme fixture'ı:** `/Users/frowing/Projects/houseflowApp/FausCrew/shared/Fixtures/fausSwitchProtocol.json`.
   Modülün `fixtures/` klasörüne kopyala, encode/decode eşitlik testlerini buna karşı yaz.
4. **Şablon modül:** `internal/application/game/games/houseRockets`. Dosya düzeni aynı olsun:
   - `definition.go`, `module.go`, `runtime.go`, `simulation*.go`
   - `wireSnapshot.go`, `protocol.go`, `settings.go`
   - `resultPersistence.go`, `resultValidation.go`, `recoveryResult.go`, `runtimeCheckpoint.go`
   - `fixtures/`

## Brifinge eklenen yeni kural: kalabalık yarışta küçük robotlar (`courseVersion` 7)

Brifing ve Swift motoru `courseVersion` 7'dedir; kural brifingde §4.2.2'dir. Aşağıda
yine özetlendi, çünkü 6'ya göre tek fark budur. Geri kalan her şey brifingdeki gibidir.

**Neden:** 8 robotta start bandı koltuk başına yalnız 41,9 birim yüksekliğinde. Tam boy robot
(33,6) ile platformu (6) bu şeride ancak sığıyor ve komşu robotlar arasında 2,3 birim kalıyor.
Demoda 8 robotla denendi; robotlar %75 boyla rahat sığıyor ve yarış oynanabilir kalıyor.

### Kural

- `n`: yarış başladığında (geri sayıma girerken) yarıştaki robot sayısı.
- `runnerScale = n > 4 ? 0.75 : 1`. Yarış boyunca sabittir; oyuncu çıksa ya da elense de
  değişmez. Bütün robotlar aynı ölçeği kullanır.
- **Ölçek değişen yerler:** yalnız şu üçü.
  1. **Robot kutusu:** genişlik `27.2 * runnerScale`, yükseklik `33.6 * runnerScale`, merkez
     `(x, y)`. Ölçek 0,75 iken 20,4 × 25,2.
  2. **Destek probu:** `width = 27.2 * runnerScale`, `inset = min(7, 0.2 * width)`.
     Ayak kenarı `y + gravity.sign * 33.6 * runnerScale / 2`, probe o kenarın ±0,5'i.
  3. **Start platformları ve doğuş noktaları:** brifing §4.2'deki tam sayı hesabında yalnız
     `height = round(33.6 * runnerScale * 10)` değişir; ölçek 0,75 iken 252 olur, dolayısıyla
     `halfBlock = (252 + 60) / 2 = 156`. Formüllerin geri kalanı aynıdır.
- **Ölçeğin değiştirmediği yerler:** bunlar tam boy sabitlerle aynen kalır.
  - Portal çıkışı: `exitY` yüzeyden ±16,8. Küçük robot çıkışta 4,2 birim havada belirir ve
    düşer, bu beklenen davranış.
  - `landingX` içindeki 13,6.
  - Boşluk sensörü içeri payı (`27.2 + 10`).
  - Hız, yerçekimi, flip, boost, yavaşlatma, kamera, sınırlar.
- **Kayan nokta tuzağı:** Swift ölçekli boyutu çalışma anında `float64` çarpımıyla hesaplar.
  Go'da bunu **değişken üzerinden** yap (`width := runnerWidth * scale`, `runnerWidth` ve
  `scale` typed `float64`). Untyped sabit ifadesi (`27.2 * 0.75`) kullanma: Go onu derleme
  anında tam hassasiyetle katlar. Örneğin `33.6 * 0.75` çalışma anında
  `25.200000000000003` çıkar, sabit katlamayla `25.2` çıkar. Bu 1 ulp fark deterministik
  eşitliği bozar.

### Kontrol değerleri

`n = 8`, ölçek 0,75 (platform minY–maxY → doğuş y):

| Koltuk | Yerçekimi | Platform | Doğuş y |
|---|---|---|---|
| 0 | down | 32,6–38,6 | 51,2 |
| 1 | up | 351,3–357,3 | 338,7 |
| 2 | down | 74,5–80,5 | 93,1 |
| 3 | up | 309,4–315,4 | 296,8 |
| 4 | down | 116,5–122,5 | 135,1 |
| 5 | up | 267,4–273,4 | 254,8 |
| 6 | down | 158,4–164,4 | 177,0 |
| 7 | up | 225,5–231,5 | 212,9 |

`n = 5`, ölçek 0,75:

| Koltuk | Yerçekimi | Platform | Doğuş y |
|---|---|---|---|
| 0 | down | 45,2–51,2 | 63,8 |
| 1 | up | 338,7–344,7 | 326,1 |
| 2 | down | 112,3–118,3 | 130,9 |
| 3 | up | 271,6–277,6 | 259,0 |
| 4 | down | 179,4–185,4 | 198,0 |

`n ≤ 4` için değerler brifingdekiyle aynıdır. Örnek `n = 2`: platformlar 91,3 ve 292,6,
robotlar y = 114,1 ve 275,8.

### Sözleşme değişikliği

- `courseVersion` her yerde **7**: `realtime.welcome`, `fausSwitch.snapshot` ve
  `fausSwitch.result`. İstemci farklı sürümü reddeder; eski istemci 5+ kişilik yarışı yanlış
  simüle etmesin diye bu bilerek yapılıyor.
- `fausSwitch.snapshot`'a yeni zorunlu alan: **`runnerScale`** (number, `1` veya `0.75`).
  Geri sayımdaki tick 0 snapshot'ı dahil her snapshot'ta yazılır. İstemci platformları ve
  robot kutularını bundan kurar.
- Fixture güncel: `rules` içinde `crowdedRunnerThreshold: 4` ve `crowdedRunnerScale: 0.75`
  var. Snapshot örneklerinde `runnerScale` var. `crowdedCountdown` 8 robotlu yarışın tick 0
  snapshot'ıdır (ölçek 0,75, aşağıdaki tablo).
- Kalıcı sonuç (`fausSwitch.result`) şeması değişmez.

## Modül gereksinimleri (özet; ayrıntı brifingde)

- **Tanım:**
  - `GameKey = "fausSwitch"`, `ProtocolVersion = 2`, `CourseVersion = 7`.
  - `MinimumPlayers = 2`, `MaximumPlayers = 8`, bot yok.
  - Hazır penceresi 30 sn, geri sayım 3 sn, azami yarış 120 sn (14.400 tick).
  - Fizik 120 Hz, snapshot 20 Hz, girdi en çok 20/sn.
  - Yeniden bağlanma payı 10 sn, kontrol heartbeat 2 sn, kontrol zaman aşımı 6 sn.
- **Katalog:** `fausSwitch` kaydı fixture'daki `settings` alanıyla oluşturulur. Varsayılan
  olarak kapalı başlar, ev bazında açılır. `settings` yoksa istemci oyunu katalogda göstermez.
- **Lobi niyeti `fausSwitch.selectColor { color }`:** yalnız `lobby` ve `readyWindow`
  aşamalarında, katılmış oyuncudan kabul edilir. Her renk için ilk talep kazanır. Yarış
  başlarken rengi olmayan ya da çakışan oyuncuya koltuk sırasıyla ilk boş renk verilir.
  Sekiz renk sekiz oyuncuya yeter. Ortak çekirdeğin lobi niyetini modüle nasıl ileteceğine
  sen karar ver; kararını belgele.
- **Koltuk sırası:** katılım sırasıdır ve yarış boyunca değişmez. `runners[]` her snapshot'ta
  bu sırayla yazılır.
- **Fizik:** brifing §4.4 sırası birebir uygulanır. Robotlar birbirine katıdır, koltuk
  sırasıyla tek tek adımlanır, bitiren ya da elenen robot çarpışmaya katılmaz.
- **Geri sarmalı flip:**
  - `clientTick` en fazla 30 tick geri kırpılır.
  - **Bütün dünya** o tick'e geri sarılır ve kabul edilmiş tüm flip'ler kendi tick'lerinde
    yeniden uygulanarak şimdiye kadar yeniden simüle edilir.
  - Son 31 tick'in dünya durumu ve tick'e göre flip listesi tutulur.
  - Destek kontrolü geri sarılmış dünyada yapılır. Desteksiz flip hata değil, no-op'tur.
  - Yinelenen `inputSequence` tekrar uygulanmaz.
- **Bağlantı kopması:** robot girdisiz koşmaya devam eder (`connected = false`). Açık çıkış
  `forfeit`, üyelik düşmesi `membershipRevoked` ile eler.
- **Bitiş:** `raceComplete` (koşan robot kalmadı) veya `timeLimit`. Sıralama brifing §4.5'teki
  gibidir. `winnerId` 1. sıradaki tek bitirendir; kimse bitirmediyse `null`.
- **Kayıt noktası ve kurtarma:** checkpoint'e her robotun tam durumu (`usedBoosts` ve
  `usedSlows` dahil), `runnerScale`, kabul edilmiş son flip'ler ve son işlenen girdi sıraları
  yazılır.

## 8 oyuncu için performans

- **Geri sarma maliyeti:** en kötü durumda 8 oyuncu × 20 flip/sn = 160 geri sarma/sn. Her biri
  30 tick × 8 robot yeniden adım demek, normal akışın kabaca 40 katı iş.
  - Aynı scheduling adımında gelen flip'leri **birleştir**: en erken `clientTick`'e tek bir
    geri sarma yap, hepsini kendi tick'lerinde uygula.
  - Oturum başına CPU'yu ölçen bir benchmark ekle (8 robot, her robot 20 flip/sn, 120 sn
    yarış). `runtimeOverloaded` eşiğini buna göre doğrula.
- **Bant genişliği:** 8 robotlu snapshot yaklaşık 2 KB. 20 Hz × 8 izleyici ≈ 320 KB/sn oturum
  başına çıkış. İlk sürümde tam snapshot yeterli, delta gerekmiyor.

## Testler

- **Protokol fixture'ı:** her mesaj tipi için encode/decode eşitliği; `runnerScale` alanı dahil.
- **Start platformları:** `n = 1…8` için platform ve doğuş değerleri Swift ile birebir. Ölçekli
  durum için yukarıdaki tablolar kullanılır.
- **Fizik eşitliği:**
  - `fausSwitchSimulation.json`: tick'li flip listeleri ve belirli tick'lerde beklenen
    `(x, y, vy, gravity, status)`.
  - En az bir 2 kişilik, bir 4 kişilik ve bir **8 kişilik** (ölçek 0,75) senaryo.
  - Fixture'ı istemci tarafı Swift motorundan üretebilir. Gerekirse iste, kendin üretme.
- **Çarpışma:** 8 robotlu tam yarışta hiçbir tick'te iki koşan robotun kutusu iç içe geçmez
  (Swift karşılığı `FausSwitchCollisionTests`).
- **Geri sarma:**
  - 250 ms gecikmeli flip, gecikmesiz flip ile aynı sonuca varır; üst üste duran iki robotun
    alttakinin geç flip'i dahil.
  - Aynı tick'te birden çok oyuncudan gelen flip'lerin birleştirilmiş geri sarması, tek tek
    uygulamayla aynı sonucu verir.
- **Ölçek:** 4 kişilik yarış ölçek 1, 5 kişilik yarış 0,75 ile başlar. 5 kişiden biri
  geri sayımda çıkınca ölçek 0,75 kalır.
- **Diğer:** yinelenen `inputSequence`, `not_in_lobby`, `runner_finished`, `stale_control`
  ve rate limit.

## Bitti sayılması için

- `go build ./...` ve `go test ./...` temiz.
- Modül `games/builtin.go`'da kayıtlı, katalog kaydı kapalı başlıyor.
- Fixture eşitlik testleri geçiyor.
- Kısa bir not yaz:
  - verdiğin kararlar: lobi niyeti yönlendirmesi, renklerin nerede tutulduğu;
  - istemciden beklediğin bir şey: simülasyon fixture'ı gibi;
  - benchmark sonucu.

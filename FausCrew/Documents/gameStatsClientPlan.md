# Oyun İstatistikleri — Client Geliştirme Planı (tek faz)

**Tarih:** 27 Kasım 2026 · **Dal:** `dev` · **Kapsam:** ortak Swift çekirdeği (`FausCrew/shared`), iOS (SwiftUI), Android (Compose + `swift-bridge`) · **Kaynak:** [gameStatsBackendContract.md](gameStatsBackendContract.md) · **Durum:** Uygulandı (G1–G6), commit edilmedi. Sonuçlar ve kontrol listesi: [gameStatsClientReport.md](gameStatsClientReport.md).

## 1. Özet

Backend yeni bir uç nokta ekledi: `GET game/stats?houseId=…`. Uç nokta, evin güncel üyelerinin oyun başına galibiyet ve oynanan maç sayılarını sıralı olarak döner. Sayım ve sıralama tamamen backend'de yapılır. Client hiçbir sayıyı yeniden hesaplamaz, yalnızca gösterir.

Bu faz şunları yapar:

1. Çekirdeğe istek, yanıt modeli ve hata eşlemesi eklenir. Ekranın göstereceği "pano" (üye eşleme, bilinmeyen oyunu atlama, lider) da Core'da saf fonksiyon olarak yazılır.
2. iOS'a servis ve store, Android'e köprü, repository ve ViewModel eklenir. Biçimleri chore arşivinin aynısıdır.
3. İki platforma istatistik görünümü eklenir. Yeri ve biçimi kullanıcının tasarım kararına göre belirlenir.

## 2. Mimari uyum: hangi parça nereye

Yeni bir katman kurulmaz. Her parça, aynı işi bugün yapan en yakın örneğin yerine ve biçimine konur. En yakın örnek chore arşividir: Core'da `ChoreArchiveWireContract`, iOS'ta `ChoreArchiveService` ve `ChoreArchiveStore`, Android'de `ChoreArchiveBridge`, `ChoreArchiveRepository` ve `ChoreArchiveViewModel`. Oyun tarafındaki yol ve anahtarlar ise `GameWireContract.swift`'te durur.

| Parça | Yer | Örnek alınan | Kural |
|---|---|---|---|
| Rota | Core `Games/GameWireContract.swift`, `GameRoute`'a `.stats(houseId:)` | `.catalog(houseId:)` | Yol `game/stats`, query `houseId`. `houseId`, `validateIdentifier` ile denetlenir. |
| Model, decode, hata türü | yeni Core `Games/GameStatsWireContract.swift` | `decodeCatalog` (girdi girdi lossy decode), `ChoreArchiveFailure` | Bozuk bir oyun girdisi diğerlerini gizlemez. `data: null` ya da `success: false` gelirse `invalidResponse` döner. |
| Pano (ekran modeli) | aynı dosya, saf fonksiyon | — | Girdiler: istatistik, üye id'leri, client'ın tanıdığı oyun anahtarları. Çıktı: oyun başına sıralı satırlar ve lider. Sıra korunur, sayı türetilmez. |
| HTTP, token, `Accept-Language`, 401 | iOS `GameStatsService` (`HTTPClient` portu), Android `GameStatsRepository` (`AndroidHttpAdapter`) | `ChoreArchiveService`, `ChoreArchiveRepository` | JWT köprüden geçmez. `Authorization` başlığını Kotlin ekler. |
| UI durumu (yükleniyor, veri, hata, epoch, 429) | iOS `GameStatsStore`, Android `GameStatsViewModel` | `ChoreArchiveStore`, `ChoreArchiveViewModel` | UI durumu platformdadır. Core'a durum makinesi eklenmez. |
| Köprü | yeni `swift-bridge/.../GameStatsBridge.swift` | `ChoreArchiveBridge.swift` | İstek başına bir, yanıt başına bir JNI çağrısı yapılır. Giriş ve çıkış JSON'dur. Köprü sürümü 22'den 23'e çıkar. |
| gameKey → ad, ikon, renk | iOS ve Android oyun hub'ı | `GamesHubView.swift:26-46` (`GameInfo`), `GamesHubScreen.kt` | Hub ile istatistik aynı tanımı kullanır. Hub'daki özel `GameInfo` listesinden, online oyunlar için küçük ve paylaşılan bir eşleme çıkarılır. Kopya liste yazılmaz. |
| Metinler | iOS `LocalizedText`, Android `copy(key)` / `strings.social(key, tr, en)` | mevcut | Core kullanıcıya metin üretmez. |

## 3. Kodda doğrulanan mevcut durum

| Konu | Mevcut durum | Etki |
|---|---|---|
| Oyun anahtarları | `GameKey` içinde `houseRockets`, `houseTanks`, `fausSwitch` var (`GameWireContract.swift:5-9`). Uygulamadaki online oyunların tamamı bunlar. | Bu üç anahtar dışındaki her `gameKey` atlanır (kural 4). |
| Hub kataloğu | iOS `GamesHubView.swift:26-46`: oyun kimlikleri tamsayı (`id: 5…7`), başlık anahtarları `games_*_title`, ikonlar SF Symbol. Android `GamesHubScreen.kt` kartları ayrı ayrı çiziyor. | gameKey → görsel eşlemesi bugün hiçbir yerde gameKey ile kurulmuyor. Eşleme bu fazda eklenir. |
| Ev üyeleri | iOS `DashboardStore.members: [User]` (`id`, `name`, `initials`, `imageUrl`). Android `HouseSessionRepository.kt:19` `HouseMember(id, firstName, lastName, imageUrl)`. Kaynak `house/details`. | İsim ve avatar buradan userId ile eşlenir. Üye listesinde olmayan userId satırı gösterilmez. Bu, ev verisi eskiyken oluşabilecek bir yarış durumudur. |
| 403 akışı | iOS: `ChoreArchiveStore.onAccessLost` → `AppViewModel.swift:300`. Android: `ChoreArchiveEffect` → `MainActivity.kt:208-211`. | Aynı bağlantı kullanılır, yeni bir akış yazılmaz. |
| 401 akışı | `ChoreArchiveService.onUnauthorized` ve Android `SessionRejected` efekti. | Aynısı kullanılır. |
| 429 | Online oyunlarda 429 metni ve tekrar deneme var (`GameOnlineResultMachine.swift:98`). REST store'larda 429 için özel bir yol yok. | Yeni kural §4'te. |
| Hata gövdesi | `HTTPStatusFailure` (`HTTPClient.swift:67`) `error` alanını okuyor. | Sunucunun yerelleştirilmiş mesajı buradan gelir. Dallanma yalnızca durum koduna göre yapılır. |
| Oyundan dönüş | Oyun ekranları hub'dan açılıyor (`GamesHubView.swift:134-140`). Kapanış `onlineGameLifecycle` ile oluyor. | "Maç bitip dönünce yenile" isteği, istatistik görünümü yeniden göründüğünde tetiklenir. Kesin bağlantı yeri tasarım kararına göre belirlenir. |
| Backend ortamı | Tek backend fly.dev ve bu backend prod. Staging ya da yerel backend yok. | Brifteki "staging ile test et" adımı yapılamaz. Doğrulama fixture testleriyle yapılır, canlı test backend release'inden sonra yapılır (§6). |

## 4. Davranış kararları

- **Yükleme zamanı.** Görünüm açıldığında ve görünüme geri dönüldüğünde istek atılır (maç sonrası dönüş dahil). Polling yapılmaz. Bağlam (kullanıcı, ev) değişince epoch artar, veri temizlenir ve eski epoch'a ait yanıt atılır.
- **Yenilemede eski veri kalır.** Yeniden çekme sırasında liste boşaltılmaz. Yeni yanıt gelince yerine konur.
- **Pano kuralları (Core).**
  - Oyun sırası ve oyuncu sırası backend'den geldiği gibi korunur.
  - Client'ın görsel eşlemesinde olmayan `gameKey` atlanır.
  - Üye listesinde olmayan `userId` satırı atlanır.
  - Lider, ilk oyuncudur ve yalnızca `wins > 0` ise gösterilir.
  - `matchesPlayed == 0` olan üye "oynamadı" olarak işaretlenir.
  - Hiçbir sayı toplanmaz ve türetilmez. Beraberlik nedeniyle wins toplamının az olması normaldir ve düzeltilmez.
  - Atlamalardan sonra hiç oyun kalmazsa boş durum gösterilir.
- **Boş durum.** `data = []` gelirse ya da pano boşsa "Henüz tamamlanmış oyun yok" yazılır.
- **Hata eşlemesi (durum koduna göre).**
  - 401: mevcut oturum reddi akışı çalışır.
  - 403 ve 404: `onAccessLost` ile ev bağlamı yenilenir. Bağlam değişmezse aynı epoch'ta ikinci kez tetiklenmez, döngü oluşmaz.
  - 429: eldeki veri varsa sessizce gösterilir. Veri yoksa 2 saniye sonra **bir kez** tekrar denenir; o da başarısız olursa hata durumu gösterilir.
  - 400 ve diğerleri: hata durumu gösterilir. Varsa sunucunun mesajı gösterilir, yoksa genel metin.
- **Prod'a çıkış sırası.** Backend deploy edilmeden bu client yayınlanırsa prod'daki rota 404 döner. Bu da "ev bulunamadı" sanılıp ev bağlamını yeniler. Bu yüzden client release'i backend release'inden **sonra** çıkmalı. Yukarıdaki tek seferlik 404 koruması, sıra kaçarsa döngü oluşmasını engeller.

## 5. Tasarım

### 5.1 Kullanıcının kararı (27 Kasım 2026)

- **Yer: dashboard.** `ChoreProgressCard` (iOS `Views/Dashboard/Components/ChoreProgressCard.swift`, Android `ui/dashboard/ChoreProgressCard.kt`) yatayda genişliğin **1/3**'üne iner ve dikeyde biraz uzar. Kalan **2/3**'e yeni `GameStatsCard` gelir. İki kart aynı satırda ve aynı yükseklikte durur (`HouseDashboardView.swift:28`, Android `DashboardScreen.kt`).
- **Kartın altında oyun geçişi: küçük kareler.** Kartın altında yan yana küçük kareler bulunur: her oyun için bir kare ve en sonda "Tümü". Her karenin içinde, oyunun kendi içinde kullanılan ve oyunla özdeşleşmiş görsel yer alır (§5.4). Bir oyun seçilince o oyunun sıralaması, "Tümü" seçilince genel sıralama gösterilir.
- **Grafik: C · Zirve çizgisi** (27 Kasım 2026'da seçildi). Uygulamanın genel diline uyar (teal/indigo, yuvarlak köşe, `FausCardSheen`), etkileşimli ve sıra dışıdır.

### 5.2 Bu kararın getirdiği teknik sonuçlar

- **Zaman ekseni yok.** Endpoint yalnızca toplam sayı döner, maç geçmişi dönmez. Bu yüzden "zaman içinde çizgi" çizilemez. Çizgi; oyuncular, sıra ya da oyunlar ekseninde kurulur. Seçenekler §5.3'te.
- **"Tümü" türetilmiş bir değer.** Backend genel sıralama göndermez. Genel sıralama, oyunlar arasında wins ve matchesPlayed **toplanarak** bulunur. Sıralama kuralı backend'inkiyle aynıdır: wins azalan, sonra matchesPlayed azalan, sonra ev üyeliği sırası (`house/details` üye sırası). Bu toplam sayım kurallarını yeniden hesaplamaz, yalnızca toplar. Toplama Core'daki `GameStatsBoard` içinde yapılır ve test edilir. Atlanan (bilinmeyen) oyunlar toplama girmez.
- **İlerleme kartı küçülür.** 1/3 genişlikte (~105pt) yüzde halkası ve kısa bir alt yazı kalır. Başlık, tier mesajı ve chore noktaları sığmaz. Dokununca çalışan kutlama animasyonu korunur.
- **Yer darlığı.** 2/3 kart ~215pt genişliğinde. Evde 2–8 üye olabilir (`MemberCountPicker.swift:9-10`). C'de düğümler yan yana dizildiği için 5 ve daha fazla üyede grafik aynı alan içinde yatay kaydırılır (kullanıcı kararı, ayrıntı §5.3).
- **Boş durum.** `data = []` gelirse kart kaybolmaz, içinde "Henüz tamamlanmış oyun yok" yazar. Böylece dashboard düzeni sabit kalır.
- **Kareler.** Yalnızca `data`'da bulunan ve client'ın tanıdığı oyunlar için kare çıkar. "Tümü" karesi yalnızca en az 2 oyun varsa gösterilir. Bağlam değişince ya da seçili oyun artık yoksa seçim ilk kareye döner.

### 5.3 Çizgisel grafik seçenekleri (karar: C)

Sohbette gösterilen maketteki üç seçenek aşağıda. Seçilen C; A ve B yalnızca kayıt için duruyor.

| | Ad | Çizgi neyi gösterir | Artı | Eksi |
|---|---|---|---|---|
| A | Yarış şeritleri | Her üye bir şerit. Avatar, şerit üzerinde lidere göre galibiyet oranında ilerler. Oynamamış üye kesik şeritte başlangıçta durur. | Okuması en kolay olanı, oyunlu bir dil. Dokununca avatarın "koşması" doğal bir animasyon verir. | Satır sayısı üye sayısıyla artar. |
| B | Sıralama çizgileri (bump chart) | X ekseni oyunlar + Tümü, Y ekseni sıra. Her üye oyunlar arasında sırasını birleştiren bir çizgi. Chip, ilgili sütunu vurgular. | Gerçek bir çizgi grafiği ve en sıra dışı olanı. Oyunlar arası karşılaştırmayı tek bakışta verir. | 2/3 kartta küçük kalır. Tek oyun varken anlamsızlaşır. |
| C | Zirve çizgisi | X ekseni sıradaki oyuncular, Y ekseni galibiyet. Avatar düğümlerini birleştiren tek bir çizgi. | Sade. Lider tepede durur. | Çizgi bir trend gibi algılanabilir, oysa noktalar arasında bir ilişki yok. |

**C'nin ayrıntısı:**
- X ekseni sıradaki oyunculardır (backend sırası), Y ekseni galibiyettir. Avatar düğümleri tek bir teal çizgiyle birleşir. Her düğümden tabana kesik bir dikey çizgi iner. Düğümün üstünde galibiyet sayısı yazar.
- Lider (`wins > 0` ise ilk oyuncu) daha büyük bir düğümle tepede durur.
- `matchesPlayed == 0` olan üyenin düğümü soluktur ve sayı yerine "—" yazar. Yine de çizginin sonunda, tabanda yer alır.
- Tüm galibiyetler 0 ise çizgi düz bir taban çizgisi olur ve lider gösterilmez.
- **Kendi düğümün her zaman vurgulanır** (kullanıcı kararı). Oturumdaki kullanıcının düğümünün (`currentUserId`) çevresinde teal bir halka bulunur ve düğümün altında küçük bir "Sen" etiketi yazar (TR "Sen", EN "You"). Bu vurgu, dokunma ile yapılan geçici vurgudan ayrıdır ve kalıcıdır. Kendi düğümün lider düğümüyle aynıysa iki işaret birlikte görünür. Kendi düğümün "oynamadı" durumundaysa düğüm soluk kalır ama halkası görünür.
- **Çok üyeli ev: grafik aynı alanda yatay kaydırılır** (kullanıcı kararı). Kartın ve grafik alanının boyutu değişmez.
  - 4 ve daha az üyede düğümler alana eşit aralıkla yayılır, kaydırma olmaz.
  - 5 ve daha fazla üyede düğüm aralığı sabittir (~48pt, avatar boyutu küçülmez). Çizgi, taban ve düğümler bu genişlikte tek bir çizim olarak kaydırılabilir bir alanın içine konur: iOS'ta yatay `ScrollView`, Android'de `Modifier.horizontalScroll`.
  - Y ölçeği her zaman tüm üyelere göre hesaplanır, yalnızca görünen kısma göre değil. Böylece kaydırınca yükseklikler değişmez.
  - Kaydırılabilir olduğu, sağ ve sol kenardaki yumuşak solmalarla anlatılır; başa ya da sona gelinen kenarda solma kaybolur. Kaydırma çubuğu gösterilmez.
  - Kart açılınca ve her kare değişiminde grafik başa (lidere) döner. Kendi düğümün görünen alanın dışındaysa, kısa bir gecikmeyle kendi düğümüne doğru kaydırılır; `reduceMotion` açıksa animasyonsuz.
  - Dashboard dikey kaydırılıyor. Yatay kaydırma yalnızca grafik alanında çalışır, iki yön birbirine karışmaz.
  - Erişilebilirlik etiketi kaydırmadan bağımsız olarak tüm sıralamayı okur.
- Çizgi bir trend gibi algılanmasın diye eksen etiketi konmaz. Düğümler eşit aralıklı durur ve alt satırda "Sıralama" yazar.

**Etkileşim:**
- Avatara dokunulunca o üye vurgulanır, diğerleri soluklaşır ve alt satırda "Ayşe · 5 galibiyet / 9 maç" yazar.
- Kare değişince çizgi animasyonla yeni şekline geçer: düğümler yeni sıralarına kayar, yükseklikler yaylanır.
- Karta ilk girişte çizgi soldan sağa çizilir. `accessibilityReduceMotion` açıksa animasyon yapılmaz.

### 5.4 Oyun seçici kareler

Her karede, oyunun içinde zaten kullanılan çizim yer alır. Bunlar iki platformda da mevcut ve hub dışından erişilebilir durumda. Yeni bir görsel üretilmez.

| Kare | iOS | Android | Not |
|---|---|---|---|
| Faus Switch | `FausSwitchRobot(color:)` (`FausSwitchArtwork.swift:7`) | `FausSwitchRobot(color, …)` (`fausswitch/FausSwitchArtwork.kt:190`) | Sabit renk: `olive`. |
| House Rockets | `HouseRocketsRocketMark()` (`HouseRocketsArtwork.swift:202`) | `HouseRocketsRocketMark()` (`rockets/HouseRocketsArtwork.kt:237`) | Hub kapağındaki roketin aynısı. |
| House Tanks | `HouseTanksArenaTank(color: .olive)` (`HouseTanksLobbyArtwork.swift:283`) | `HouseTanksArenaTank(TanksColor…)` (`tanks/HouseTanksArtwork.kt:257`) | Hub kapağındaki zeytin yeşili tankın aynısı. |
| Tümü | SF Symbol `chart.bar.fill` | Material `Icons.Rounded.Poll` (`material-icons-extended` zaten bağımlı, `app/build.gradle.kts:59`) | Anket / sıralama sembolü (kullanıcı kararı). Teal ile boyanır. |

- **Karelerde yazı yok.** Kareler yalnızca görsel taşır. Oyunun adı kartın başlığında yazar (aşağıda).
- **Kart başlığı seçime göre değişir.** Kartın en üstünde, sabit bir "Oyun ligi" yazısı yerine seçili oyunun adı yazar. Ad, hub'daki başlık anahtarından gelir (`games_faus_switch_title`, `games_house_rockets_title`, `games_house_tanks_title`). "Tümü" seçiliyse başlıkta "Genel" yazar (yeni anahtar `game_stats_overall_title`: TR "Genel", EN "Overall"). Başlık değişimi kısa bir çapraz geçişle olur. Liderin adı başlığın sağında kalır.
- **Boyut:** Kareler ~34pt boyutunda, aralarında 6pt boşluk var. Görsel ~24pt. 4 kare 2/3 kartın iç genişliğine (~195pt) rahatça sığar.
- **Dokunma alanı:** Dokunma alanı 44pt'e genişletilir (iOS `contentShape`, Android `minimumInteractiveComponentSize`). Görünen kare küçük kalır.
- **Durumlar:**
  - Seçili kare: teal kenarlık, açık teal zemin, hafif büyüme ve görselin küçük bir "zıplaması". Robot zıplar, roket yükselir, tank namlusunu çevirir; `reduceMotion` açıksa bu yapılmaz.
  - Seçili olmayan kare: nötr zemin ve soluk görsel.
- **Erişilebilirlik:** Her kare, oyunun hub'daki başlığıyla etiketlenir (`games_*_title`). Seçili kare "seçili" olarak duyurulur.
- **Ortak eşleme:** gameKey → görsel eşlemesi, G4'teki ortak eşlemeye eklenir. Hub ile istatistik kartı aynı kaynaktan beslenir.

### 5.5 Kararların özeti

Tüm tasarım soruları yanıtlandı (27 Kasım 2026):
- "Tümü" karesinin görseli anket sembolü oldu (§5.4).
- Kendi düğümün vurgulanacak (§5.3).
- Çok üyeli evde grafik aynı alanda yatay kaydırılacak (§5.3).
- İstatistikte yalnızca uygulamadaki üç online oyun gösterilecek.
- Ayrıntılı bir popup açılmayacak; kart tek başına yeterli.

## 6. Görevler

### G1 Core: rota, model, decode, pano · M
- **Dosyalar:** `Games/GameWireContract.swift` (`GameRoute.stats`), yeni `Games/GameStatsWireContract.swift`, `shared/README.md` (sahiplik satırı).
- **Yapılacak:**
  - Modeller: `HouseGameStats { gameKey, players }` ve `PlayerGameStats { userId, wins, matchesPlayed }`. İkisi de `Decodable, Equatable, Sendable`.
  - `GameStatsWireContract.request(houseID:jwt:)` yazılır. `houseId` geçersizse istek atılmaz, `invalidRequest` döner.
  - `GameStatsWireContract.decode(_ response:)` yazılır. Envelope `{success, data}` biçimindedir ve oyun girdileri tek tek lossy çözülür.
  - `GameStatsFailure { kind, message }` tanımlanır. `kind` değerleri: `invalidRequest`, `unauthorized`, `accessLost` (403 ve 404), `rateLimited`, `invalidResponse`, `server`.
  - `GameStatsBoard.make(stats:memberIDs:knownGameKeys:)` saf fonksiyonu yazılır (§4 pano kuralları).
  - Aynı yerde "Tümü" sıralaması kurulur: tanınan oyunların toplamı, backend'in sıralama kuralıyla (§5.2).
- **Test:** `shared/Tests/FausCrewCoreTests/GameStatsWireContractTests.swift`. Kapsam §7'de.

### G2 iOS: servis ve store · M
- **Dosyalar:** yeni `Services/Games/General/GameStatsService.swift`, yeni `ViewModels/Stores/GameStatsStore.swift`, `Services/AppDependencies.swift`, `ViewModels/AppViewModel.swift` (store, `setContext`, `onAccessLost`).
- **Yapılacak:** `ChoreArchiveService` ve `ChoreArchiveStore`'un biçimi izlenir: `Accept-Language`, `onUnauthorized`, epoch ve log yazılır, log'a id yazılmaz. 429 kuralı uygulanır, bekleme süresi test için enjekte edilir. `refresh()` görünümün açılış ve dönüş noktasından çağrılır.
- **Test:** `FausCrewTests/GameStatsStoreTests.swift`. Sahte servisle: epoch atma, yenilemede eski verinin kalması, 429'da tek tekrar ve sessiz veri, 403/404'te tek `onAccessLost`, 401.

### G3 Android: köprü, repository, ViewModel · M
- **Dosyalar:** yeni `swift-bridge/Sources/FausCrewAndroidBridge/GameStatsBridge.swift`, `InviteCodeBridge.swift` ve `InviteCodeBridge.kt` (sürüm 23), yeni `platform/GameStatsRepository.kt`, yeni `viewmodel/GameStatsViewModel.kt`, `MainActivity.kt` (bağlam ve efekt bağlantısı).
- **Yapılacak:**
  - Köprüye iki fonksiyon eklenir: `gameStatsRequest(houseId)` yolu ve query'yi döner, `gameStatsResponse(status, body)` panoya hazır JSON'u ya da `{ok:false, kind, message}` döner.
  - Pano, üye id'leri ve tanınan anahtarlarla Kotlin'de değil Core'da kurulur. Köprü bu girdileri JSON olarak alır.
  - ViewModel `StateFlow` ve efektlerle çalışır (`SessionRejected`, `AccessLost`). 429 kuralı uygulanır.
- **Test:** `swift-bridge/Tests/.../GameStatsBridgeTests.swift` yazılır. `app/src/test/.../GameStatsRepositoryTest.kt` ve `GameStatsViewModelTest.kt` sahte wire ile çalışır.

### G4 gameKey görsel eşlemesi · S
- **Dosyalar:** iOS `GamesHubView.swift`, Android `GamesHubScreen.kt` (paylaşılan küçük eşleme: gameKey → başlık anahtarı, ikon, renk).
- **Yapılacak:** Hub, online oyunlarda bu eşlemeyi kullanacak şekilde değiştirilir; hub'ın görünümü değişmez. Tanınan anahtar kümesi (`knownGameKeys`) bu eşlemeden türetilir ve Core'a verilir.

### G5 UI · L
- **Dosyalar:**
  - iOS: `HouseDashboardView.swift` (iki kartlık satır), `ChoreProgressCard.swift` (dar düzen), yeni `Views/Dashboard/Components/GameStatsCard.swift`.
  - Android: `DashboardScreen.kt`, `ChoreProgressCard.kt`, yeni `ui/dashboard/GameStatsCard.kt`.
- **Yapılacak:**
  - Satır düzeni: 1/3 + 2/3, aynı yükseklikte.
  - Zirve çizgisi grafiği (§5.3 C).
  - Oyun görselli seçici kareler (§5.4).
  - Dokunma ile vurgulama ve animasyonlu geçiş.
  - Yükleniyor, boş, hata ve veri durumları, kartın boyutu değişmeden çizilir.
  - Yenileme: dashboard göründüğünde ve oyundan dashboard'a dönüldüğünde `refresh()` çağrılır.
  - Metin anahtarları TR ve EN olarak eklenir. Erişilebilirlik etiketi sıralamayı düz metin olarak okur.

### G6 Doğrulama ve rapor · S
- iOS build ve testleri çalıştırılır (`generic/platform=iOS Simulator`, `FausCrewTests`).
- `swift test` çalıştırılır (shared, swift-bridge).
- Android Gradle build ve unit testleri çalıştırılır.
- `gameStatsClientReport.md` yazılır. Raporda iki platform için ekran kontrol listesi bulunur.
- Canlı test, backend release'inden sonra kullanıcı tarafından yapılır.

**Sıra:** önce G1 ve G4, sonra G2 ile G3 paralel, sonra G5, en son G6.

## 7. Test kapsamı (brif madde 6)

| Durum | Core (decode + pano) | iOS store | Android köprü/repo/VM |
|---|---|---|---|
| Boş ev (`data: []`) | ✓ boş pano | ✓ boş durum | ✓ |
| Tek oyun | ✓ | ✓ | ✓ |
| Birden çok oyun, sıra korunur | ✓ | — | ✓ |
| Hiç oynamamış üye (0/0 → "oynamadı") | ✓ | — | ✓ |
| Beraberlik (wins toplamı < matchesPlayed) değişmeden geçer | ✓ | — | — |
| Lider yalnızca `wins > 0` ise | ✓ | — | — |
| "Tümü" toplamı ve eşitlik sırası (wins → maç → üyelik sırası) | ✓ | — | ✓ |
| Bilinmeyen gameKey atlanır, çökme yok | ✓ | — | ✓ |
| Bozuk bir oyun girdisi diğerlerini gizlemez | ✓ | — | — |
| Üye listesinde olmayan userId atlanır | ✓ | — | — |
| `data: null` / `success: false` → invalidResponse | ✓ | — | ✓ |
| 400 / 401 / 403 / 404 / 429 eşlemesi | ✓ | ✓ akışlar | ✓ akışlar |
| Geçersiz houseId → istek atılmaz | ✓ | — | ✓ |
| Eski epoch yanıtı atılır | — | ✓ | ✓ |

"Görünüm testi" olarak projede snapshot altyapısı yok. Görünümün çizdiği her karar (`GameStatsBoard`) Core'da test edilir. Görünüm yalnızca bu modeli çizer.

## 8. Kapsam dışı

- Polling ve WebSocket.
- Client'ta sayı hesabı ya da yeniden sıralama.
- Staging ya da yerel backend kurulumu.

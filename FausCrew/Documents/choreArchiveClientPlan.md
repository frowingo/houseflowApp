# Chore Arşivi — Client Geliştirme Planı (tek faz)

**Tarih:** 24 Kasım 2026 (mimari gözden geçirme aynı gün) · **Dal:** `dev` · **Kapsam:** ortak Swift çekirdeği (`FausCrew/shared`), iOS (SwiftUI), Android (Compose + `swift-bridge`) · **Kaynak:** [choreArchiveBackendContract.md](choreArchiveBackendContract.md) · **Durum:** Uygulandı (24 Kasım 2026, commit edilmedi). Ayrıntı: [choreArchiveClientReport.md](choreArchiveClientReport.md).

## 1. Özet

Backend dört şeyi değiştirdi:
- `house/details` artık yalnızca açık chore'ları ve son 48 saatte kapanmışları dönüyor.
- Daha eski kapanmış chore'lar `GET chore/archive` ile tarih aralığına göre 10'arlı sayfalarla geliyor.
- Failed chore'larda `completedAt` ve `completedBy` artık dolu.
- `dueDate` zorunlu.

Bu faz şunları yapar:

1. Çekirdeğe arşiv uç noktasının wire sözleşmesi eklenir: istek, `nextUrl` ve yanıt kuralları. Model aynı kalır.
2. Failed nedeni `completedAt` ile kesinleşir ve review reddi ayrı bir neden olur.
3. İki platforma "Arşiv" popup'ı eklenir. Popup'ta ay gezgini, "Daha fazla göster" ve salt okunur detay bulunur.

Puan, istatistik ya da leaderboard hesabı **yok** (`User.points` her yerde `0`, `DashboardStore.swift:74,82`). Bu yüzden 48 saat kesintisi hiçbir hesabı bozmuyor. Değişen tek şey, ana ekrandaki "Geçmiş" bölümünün kısalması. Bu da istenen davranış.

## 2. Mimari uyum: hangi parça nereye

Bu plan yeni bir katman ya da çerçeve kurmaz. Her parça, aynı işi bugün yapan en yakın örneğin yerine ve biçimine konur. En yakın örnek sayfalı bildirim listesi: Core'da `NotificationWireContract`, iOS'ta `NotificationService` ve `NotificationStore`, Android'de `NotificationBridge`, `NotificationRepository` ve `NotificationViewModel`.

| Parça | Yer | Örnek alınan | Kural |
|---|---|---|---|
| İstek, `nextUrl`, yanıt ve hata türleri | Core `UseCases/ChoreArchiveWireContract.swift` | `NotificationWireContract`, `ChoreCatalogWireContract` | Path, query, tarih wire biçimi ve hata eşlemesi yalnızca Core'da bulunur (`shared/README.md`: wire ve HTTP sözleşmeleri Core'dadır). |
| Hazır kodlanmış query taşıma | Core `Ports/HTTPClient.swift` → `HTTPRequest.percentEncodedQuery` | — | Port alanı Core'da. Uygulaması iki platformun HTTP adapter'ında. |
| Failed nedeni | Core `ChoreModels.swift` (`ChoreFailureReason`) | mevcut kural | Saf iş kuralı. Metni platformlar üretir. |
| Ay sınırları (yerel takvim) | iOS store ve Android ViewModel | Android `ChoreDueDate.wire` ve iOS `FausCrewDateFormatter` | Takvim ve saat dilimi platformun işidir. Core yalnızca `Date` alır ve wire biçimine çevirir. Android bunu epoch saniye ile geçirir (`choreCanRemind` örneği). |
| Sayfa durumu (liste, `nextUrl`, yükleniyor, hata, epoch) | iOS `ChoreArchiveStore`, Android `ChoreArchiveViewModel` | `NotificationStore`, `NotificationViewModel` | UI durumu platformdadır (`shared/README.md`: `ObservableObject` state iOS'ta; geçiş planı: Android'de `StateFlow` + ViewModel). Core'a sayfa durum makinesi **eklenmez**. |
| HTTP, token, `Accept-Language`, 401 | iOS `ChoreArchiveService` (`HTTPClient` portu ile), Android repository (`AndroidHttpAdapter`) | `NotificationService`, `NotificationRepository` | JWT köprüden geçmez; `Authorization` başlığını Kotlin ekler. |
| DTO → ekran modeli | iOS `DashboardStore` mapping'i (paylaşılır), Android `JSONObject.toHouseChore()` | mevcut | Kopya mapping yazılmaz. |
| Ekran | Dashboard popup'ı: iOS `HouseDashboardView.popupsOverlay`, Android `DashboardPopup` | `NotificationsPopup`, `ChoreCatalogPopup` | Dashboard yeni bir navigasyon yığını kullanmaz; her şey popup olarak açılır. |
| Köprü | yeni `swift-bridge/.../ChoreArchiveBridge.swift` | `NotificationBridge.swift` | İstek başına bir, yanıt başına bir JNI çağrısı. JSON giriş ve JSON çıkış. Satır başına çağrı yapılmaz. |
| Metinler | iOS `Models/Chore/ChoreModels.swift` (`localized`), Android `strings.social(key, tr, en)` | `failureMessage` ve `ChoreVisuals.kt:119-122` | Core kullanıcıya metin üretmez. |

İlk plandan çıkarılanlar:
- **Core'daki sayfa durum makinesi:** mimari, UI durumunu platformlara veriyor. Bildirimler de aynı kuralı her platformda ayrı tutuyor.
- **`dueDate` koruması:** iki editör her zaman tarih üretiyor. Koruma iOS `ChoreService`'i `DashboardWireContract`'a taşımayı gerektiriyordu ve bu kapsam dışı bir refaktör.
- **`ChoreCompletion.isSystem` yardımcısı:** "tamamlayan" bilgisi zaten status ile seçiliyor, `"system"` değerine hiç bakılmıyor.
- **Ayrı arşiv ekranı ya da navigasyon:** dashboard her şeyi popup olarak açıyor.

## 3. Kodda doğrulanan mevcut durum

| Konu | Mevcut durum | Etki |
|---|---|---|
| Model | `HouseChoreDTO` (`HouseModels.swift:522-620`) `completedAt`/`completedBy` alanlarını okuyor; `{ "time.Time": … }` biçimini de kabul ediyor. | Arşiv yanıtı aynı DTO ile çözülür. |
| Ana ekran | iOS `TodaysChoresCard.swift:16-30,196-222`, Android `TodaysChoresCard.kt:95`. Sayaç ve Geçmiş bölümü `details.chores` üzerinden hesaplanıyor. | Kod değişmez. Kartın altına "Tüm geçmiş" satırı eklenir. |
| `completedAt`/`completedBy` | UI'da okunmuyor. | `"system"` için bir risk yok. |
| Failed nedeni | `ChoreModels.swift:104-123`: `statusHistories` ile tahmin ediliyor, review reddi `unspecified` sayılıyor. Android'deki karşılığı `HouseSessionRepository.kt:62-70` (`wire` string), köprüde `HouseProjection.swift:37` `rawValue`. | Yeni neden üç katmana eklenir. |
| Popup düzeni | iOS `HouseDashboardView.swift:185-243`: popup'lar bir `Group` içinde. `ChoreDetailPopup` ilk sırada, yani en altta çiziliyor. `syncOverlayPresentation` ve `closeAllPopups` tüm popup'ları listeliyor. Android `DashboardScreen.kt:224-228`: tek değerli `DashboardPopup`. Detay yalnızca `details.chores` içindeki id ile açılıyor (`:200`). | Arşiv detayı arşiv popup'ının **içinde** açılır. Dashboard'daki detay akışı değişmez. |
| Detay bileşenleri | iOS `ChoreDetailPopup.swift:46-49` chore'u store'da bulamazsa verilen nesneyi kullanıyor. Android `ChoreDetailPopup(chore: HouseChore, …)` (`ChoreDetailPopup.kt:120`). | İkisi de arşiv nesnesiyle olduğu gibi çalışır. |
| Taban adres | iOS `AppEnvironment.swift:5`, Android `AndroidHttpAdapter.kt:120`: `…/api/v1`. | `nextUrl` (`/api/v1/…`) olduğu gibi eklenirse `/api/v1/api/v1` olur. |
| Query kurma | iOS `URLSessionHTTPClient.swift:50-56` `URLComponents.queryItems` kullanıyor, bu `+` karakterini kodlamaz. Android `AndroidHttpAdapter.kt:91` `addQueryParameter` her şeyi yeniden kodluyor. | `nextUrl` query'si iki adapter'da da hazır kodlanmış haliyle konmalı. `cursor` base64 olabilir: `+` ya da `/` çözülüp yeniden kodlanırsa sunucu 400 döner. |
| İsteği yeniden kuran yerler | iOS `NotificationService.swift:60`, `ChoreCatalogService.swift:44`, `SocialAuthService.swift:90` başlık eklemek için `HTTPRequest`'i alan alan yeniden kuruyor. | Arşiv servisi bu kalıbı izlerse yeni alanı kopyalamayı unutabilir. Bunun için test yazılacak. |
| Köprü sürümü | `InviteCodeBridge.swift:5` ve `InviteCodeBridge.kt:7`: 21. | 22 olur. |
| `dueDate` | iOS `ChoreStore.swift:73`, Android `ChoreCatalog.kt:112` her zaman tarih üretiyor. | Kod değişmez. 400 olursa mevcut hata yolu sunucunun mesajını gösterir. |
| Push → chore | `PushRouting.swift:47-49`: yüklü olmayan chore için `.finished`. | 48 saatten eski chore için gelen push dashboard'da kalır. Bu fazda değişmez. |

## 4. Tasarım kararları

- **Ay gezgini.** `‹ Kasım 2026 ›`. Varsayılan ay bu ay. İleri ok bu ayda kapalı. Popup her açılışta bu aydan ve ilk sayfadan başlar.
- **Tarih wire biçimi Core'da.** Platform yerel ayın başını ve sonraki ayın başını `Date` olarak verir. Core bunları UTC, saniye hassasiyetinde, `Z` ile yazar (`2026-10-31T21:00:00Z`). Böylece `+` sorunu hiç doğmaz. `from >= to` ise Core `invalidRequest` döner ve istek atılmaz.
- **`nextUrl` dokunulmadan kullanılır.** Core yalnızca baştaki `/api/v1/` önekini atar. `?` öncesi `path` olur, sonrası `percentEncodedQuery` olur. İki parça da çözülmez ve yeniden kodlanmaz. Core yalnızca geçerliliği denetler:
  - önek var,
  - path yalnızca göreli segmentlerden oluşuyor,
  - query yalnızca RFC 3986 query karakterleri ve geçerli `%XX` dizileri içeriyor.
  
  Denetim geçmezse sonuç `nil` olur ve buton gizlenir. Bu denetim gerekli, çünkü iOS'ta `URLComponents.percentEncodedQuery`'ye geçersiz değer verilirse uygulama çöker.
- **Sayfa kuralları platform state'inde.** `NotificationStore`/`NotificationViewModel` ile aynı kurallar geçerli: bağlam (kullanıcı, ev) değişince epoch artar ve her şey sıfırlanır; ay değişince ilk sayfa `cursor` olmadan istenir; eski epoch'a ait yanıt atılır; yeni sayfa listenin sonuna eklenir ve aynı id ikinci kez eklenmez; 403 alınınca mevcut "evden çıkarıldı" akışı tetiklenir.
- **"Tamamlayan" bilgisi status'a göre seçilir.** Completed için `completedBy` üye listesinde aranır; üye bulunamazsa "Eski üye" yazılır. Failed için kullanıcı aranmaz, neden metni gösterilir ("Süresi doldu" / "İncelemede reddedildi"). Böylece `"system"` hiçbir koşulda bir kullanıcı gibi ele alınmaz.
- **Detay arşivin içinde açılır.** Detay kapanınca kullanıcı arşive döner. Kapanmış chore eylem almaz. Review fotoğrafı mevcut yoldan görüntülenir.

## 5. Görevler

### A1 Core: arşiv wire sözleşmesi · M
- **Dosyalar:** yeni `shared/Sources/FausCrewCore/UseCases/ChoreArchiveWireContract.swift`, `Ports/HTTPClient.swift`, `shared/README.md` (sahiplik satırı).
- **Yapılacak:**
  - `HTTPRequest`'e `percentEncodedQuery: String? = nil` eklenir. Init'te varsayılanlı olduğu için mevcut çağrılar değişmez. Belge yorumunda şu yazar: alan doluysa `queryItems` boştur ve değer olduğu gibi kullanılır.
  - `ChoreArchiveWireContract` (`NotificationWireContract` biçiminde):
    - `path = "chore/archive"`, `pageSize = 10` (yalnızca bilgi amaçlı, gönderilmez).
    - `firstPageRequest(houseID:from:to:jwt:) throws(ChoreArchiveFailure) -> HTTPRequest`: query'de `houseId`, `from`, `to` olur. Başlıkta yalnızca `Authorization` olur.
    - `nextPageRequest(nextURL:jwt:) -> HTTPRequest?`: Tasarım kararları bölümündeki denetimle çalışır.
    - `page(_:decoder:) throws(ChoreArchiveFailure) -> ChoreArchivePage`. `ChoreArchivePage` iki alan taşır: `chores: [HouseChoreDTO]` ve `nextURL: String?`. Boş ya da yalnızca boşluk olan `nextUrl` `nil` sayılır. Zarf `{success, data:{chores, nextUrl}}` biçimindedir; `success:false` → `invalidResponse`.
  - `ChoreArchiveFailure` (`NotificationFailure` biçiminde). `kind` değerleri: `invalidRequest` (400), `unauthorized` (401), `notMember` (403), `server`, `invalidResponse`. `message` alanı sunucunun yerelleştirilmiş metnini taşır.
  - `shared/README.md` "Mevcut sahiplik" bölümüne arşiv sözleşmesi için bir satır eklenir.
- **Bitti:** `ChoreArchiveWireContractTests`:
  - query değerleri ve UTC `Z` biçimi;
  - `from == to` ve `from > to` → `invalidRequest`;
  - `nextUrl` içindeki `%2B`, `%3A`, `+`, `/` ve `=` bayt bayt korunuyor;
  - önek yok, `..` segmenti var, boşluk ya da bozuk `%` var → `nil`;
  - `nextUrl` null, boş ya da yok;
  - 400/401/403/500 ve `success:false` eşlemesi;
  - `time.Time` biçimli `completedAt` çözülüyor.
  
  Fixture: `shared/Tests/FausCrewCoreTests/Fixtures` altında arşiv yanıtı örneği.

### A2 Core: Failed nedeni · S
- **Dosyalar:** `ChoreModels.swift:98-124`, `HouseModels.swift:622-633`, `ChoreFailedStatusTests.swift`.
- **Yapılacak:** `ChoreFailureReason`'a `.reviewRejected` eklenir. `reason(...)` fonksiyonu `completedAt` parametresini de alır. Kural sırası:
  1. `completedAt` geçerliyse ve `dueDate` ile aynı anı gösteriyorsa (en fazla 1 sn fark) → `.dueDatePassed`.
  2. `completedAt` geçerliyse ve son turda (3 ya da sonrası) ret varsa → `.reviewRejected`.
  3. `completedAt` boşsa ya da `0001-01-01…` ise (önbellekte kalmış eski veri) mevcut `statusHistories` kuralı yedek olarak çalışır.
  4. Hiçbiri tutmazsa → `.unspecified`.
  
  `HouseChoreDTO.failureReason` `completedAt` değerini geçirir.
- **Bitti:** Testler: deadline, üçüncü turda ret, InTest iken süre dolması (→ `.dueDatePassed`), migration öncesi boş `completedAt`, Completed bir chore için `nil`. Ayrıca bir chore'un başarılı olup olmadığına `completedAt` ile karar verilmediği bir testle sabitlenir.

### B1 iOS: HTTP adapter, servis, store · M
- **Dosyalar:**
  - `Services/Platform/URLSessionHTTPClient.swift`: `percentEncodedQuery` doluysa `components.percentEncodedQuery` kullanılır.
  - yeni `Services/ChoreArchiveService.swift`
  - `Services/AppDependencies.swift` ve `AppDependencies+Preview.swift`
  - yeni `ViewModels/Stores/ChoreArchiveStore.swift`
  - `ViewModels/Stores/DashboardStore.swift`
  - `ViewModels/AppViewModel.swift`
- **Yapılacak:**
  - `ChoreArchiveServicing` (`@MainActor`) ve `ChoreArchiveService`, `NotificationService` ile birebir aynı biçimde yazılır: `HTTPClient` portu, `keychain`, `onUnauthorized`, `Accept-Language`. Fonksiyonlar: `firstPage(houseID:from:to:)` ve `nextPage(nextURL:)`. İstek başlık eklemek için yeniden kurulurken `percentEncodedQuery` **de kopyalanır**.
  - `DashboardStore`'daki DTO → `Chore` dönüşümü (`:42-64`) `func chore(from dto: HouseChoreDTO) -> Chore` olarak dışarı açılır. Fonksiyon store'un güncel `members` listesini kullanır. `rebuild` de bu fonksiyonu çağırır.
  - `ChoreArchiveStore`, `NotificationStore` yapısında yazılır:
    - `@Published` alanlar: `phase`, `chores: [Chore]`, `month`, `isLoadingMore`, `loadMoreFailed`.
    - Fonksiyonlar: `setContext(userID:houseID:)`, `open()` (bu aya döner), `select(month:)`, `loadMore()`, `refresh()`, `onAccessLost`.
    - Ay sınırları, enjekte edilebilen `Calendar` ile hesaplanır (varsayılan `Calendar.current`).
    - Mapping için init'e `chore: (HouseChoreDTO) -> Chore` closure'ı verilir. AppViewModel bunu `dashboardStore.chore(from:)` olarak geçer.
  - `AppViewModel`: store `notificationStore` ile aynı yerde oluşturulur. `bindNotifications` içindeki `CombineLatest3` akışı bu store'un `setContext`'ini de çağırır. `onAccessLost` aynı `refreshForAppEvent(profile: true)` çağrısına bağlanır. Store `AppViewModel.objectWillChange`'e **bağlanmaz**: view store'u doğrudan gözler (F2-1 kuralı).
- **Bitti:** `FausCrewTests` altında testler:
  - `URLSessionHTTPClient`: `percentEncodedQuery` URL'ye bayt bayt geçiyor.
  - `ChoreArchiveService`: sahte `HTTPClient` ile `Authorization`, `Accept-Language` ve `percentEncodedQuery` korunuyor; 401'de `onUnauthorized` çağrılıyor.
  - `ChoreArchiveStore`: ay sınırları (`Europe/Istanbul`; `Europe/Berlin` Mart ve Ekim; Aralık → Ocak), sona ekleme ve tekrar elemesi, ay ya da bağlam değişince eski yanıtın atılması, 403'te `onAccessLost`.

### B2 iOS: arşiv popup'ı · M
- **Dosyalar:**
  - yeni `Views/Dashboard/Archive/ChoreArchivePopup.swift`
  - `TodaysChoresCard.swift` ("Tüm geçmiş" satırı ve `onOpenArchive` closure'ı)
  - `HouseDashboardView.swift`
  - `Models/Chore/ChoreModels.swift` (metinler ve `.reviewRejected`)
- **Yapılacak:**
  - Popup `NotificationsPopup(store:)` gibi store'u doğrudan alır.
  - İçerik: ay gezgini, `ModernChoreRow` listesi, kapanış tarihi ve tamamlayan/neden satırı, "Daha fazla göster" (yüklenirken spinner), boş durum, hata durumu ve yeniden deneme, pull-to-refresh.
  - `ModernChoreRow`'a varsayılanı `nil` olan bir `detail: String?` parametresi eklenir. Böylece dashboard görünümü değişmez.
  - Tarih gösterimi `FausCrewDateFormatter.displayDate(from:)` ile yapılır.
  - Satıra dokununca `ChoreDetailPopup` popup'ın içinde açılır.
  - `HouseDashboardView`: `showArchive` durumu eklenir. Bu durum `syncOverlayPresentation` ve `closeAllPopups` içine yazılır (push gelince arşiv de kapanır).
- **Bitti:** iOS build geçer. Preview'lar ağa çıkmaz (`AppViewModel.preview`, F3-10). Dashboard'daki diğer popup'ların davranışı değişmez.

### C1 Android köprü · S
- **Dosyalar:**
  - yeni `android/swift-bridge/Sources/FausCrewAndroidBridge/ChoreArchiveBridge.swift`
  - `InviteCodeBridge.swift:5`
  - yeni `Tests/FausCrewAndroidBridgeTests/ChoreArchiveBridgeTests.swift`
- **Yapılacak:** `NotificationBridge.swift` ile aynı biçimde iki fonksiyon. JWT köprüden geçmez.
  - `choreArchiveRequest(action, fieldsJson)`
    - `first` alanları: `{houseId, fromEpochSeconds, toEpochSeconds}`
    - `next` alanları: `{nextUrl}`
    - Dönüş: `{"ok":true,"path","method","query":[…],"percentEncodedQuery"?}` ya da `{"ok":false,"kind"}`.
  - `choreArchiveResponse(status, body)`
    - Dönüş: `{"ok":true,"chores":[choreObject…],"nextUrl"?}` ya da `{"ok":false,"kind","message"?}`.
  
  `choreObject` (`HouseProjection.swift:19`) yeniden kullanılır. Yeni `reviewRejected` değeri `failureReason` alanında kendiliğinden gelir. `bridgeVersion` 22 olur.
- **Bitti:** Köprü testleri: iki eylem, geçersiz `nextUrl` için `ok:false`, chore projeksiyonu ve hata türleri. JNI binding kontrolü geçer.

### C2 Android HTTP, repository, ViewModel · M
- **Dosyalar:**
  - `platform/AndroidHttpAdapter.kt`
  - `platform/InviteCodeBridge.kt:7` (`API_VERSION = 22`)
  - yeni `platform/ChoreArchiveRepository.kt`
  - `platform/HouseSessionRepository.kt:62-70` (`REVIEW_REJECTED("reviewRejected")`)
  - yeni `viewmodel/ChoreArchiveViewModel.kt`
  - `MainActivity.kt`
- **Yapılacak:**
  - `PlatformHttpRequest`'e `encodedQuery: String? = null` eklenir. Doluysa `makeRequest` `HttpUrl.Builder.encodedQuery(...)` çağırır, `addQueryParameter` çağrılmaz.
  - `ChoreArchiveRepository`, `NotificationRepository` ile aynı biçimde yazılır:
    - `ChoreArchiveWire` arayüzü ve sürüm denetimli `NativeChoreArchiveWire`.
    - `ChoreArchiveRequestException(kind, status, message)`.
    - Fonksiyonlar: `firstPage(houseId, fromEpochSeconds, toEpochSeconds, jwt)` ve `nextPage(nextUrl, jwt)`. İkisi de `ChoreArchivePageData(chores: List<HouseChore>, nextUrl: String?)` döner.
    - Chore'lar `toHouseChore()` ile çözülür. `Authorization` başlığını Kotlin ekler.
    - `companion live(http)`.
  - `ChoreArchiveViewModel`, `NotificationViewModel` yapısında yazılır:
    - `StateFlow` ve `Factory`.
    - Fonksiyonlar: `setContext(userId, houseId)`, `open()`, `selectMonth(YearMonth)`, `loadMore()`, `reload()`.
    - Eski sonuçlar `generation` sayacı ve `Job.cancel` ile atılır.
    - `effects` iki değer taşır: `SessionRejected` ve `RefreshProfile`.
    - Ay sınırları `java.time` ile hesaplanır. `ZoneId` ve saat enjekte edilir.
  - `MainActivity`: ViewModel `notificationModel` ile aynı yerde oluşturulur. `setContext` ve `effects` aynı biçimde bağlanır.
- **Bitti:** JVM testleri:
  - adapter: `encodedQuery` URL'ye bayt bayt geçiyor, `+` korunuyor;
  - repository: sahte wire ve `send` ile;
  - ViewModel: ay sınırları (`Europe/Istanbul`, `Europe/Berlin` DST, yıl geçişi), sona ekleme ve tekrar elemesi, ay ya da bağlam değişince eski yanıtın atılması, 401/403 effect'leri.

### C3 Android arşiv popup'ı · M
- **Dosyalar:**
  - yeni `ui/dashboard/archive/ChoreArchivePopup.kt`
  - `TodaysChoresCard.kt` ("Tüm geçmiş" satırı; `ModernChoreRow` `private` → `internal`, varsayılanı `null` olan bir `detail` parametresi)
  - `DashboardScreen.kt` (`DashboardPopup.Archive`)
  - `ChoreVisuals.kt` (`REVIEW_REJECTED` metni)
- **Yapılacak:**
  - iOS ile aynı içerik.
  - Detay popup'ın içinde `ChoreDetailPopup(chore = …)` ile açılır. Mutasyon callback'leri boş geçilir; kapanmış chore'da hatırlatma kapalıdır.
  - Geri tuşu önce detayı, sonra arşivi kapatır.
  - `closePopupsSignal` ve ev değişimi arşivi de kapatır (`popup = null` zaten bunu yapıyor).
- **Bitti:** Android build ve unit testleri geçer. Dashboard'daki diğer popup'lar değişmez.

### D1 Lokalizasyon anahtarları · S
Anahtarlar kod içi tr/en yedekleriyle eklenir. Ayrıca backend'e bildirilecek listeye yazılır.

| Anahtar | Türkçe | İngilizce |
|---|---|---|
| `chore_archive_title` | Arşiv | Archive |
| `chore_archive_entry` | Tüm geçmiş | Full history |
| `chore_archive_load_more` | Daha fazla göster | Show more |
| `chore_archive_empty` | Bu ayda kapanmış görev yok | No chores closed this month |
| `chore_archive_error` | Arşiv yüklenemedi | Couldn't load the archive |
| `chore_archive_retry` | Tekrar dene | Try again |
| `chore_archive_closed_at` | Kapandı: {date} | Closed {date} |
| `chore_archive_completed_by` | Tamamlayan: {name} | Completed by {name} |
| `chore_archive_former_member` | Eski üye | Former member |
| `chore_failed_reason_review_rejected` | İncelemede üç kez reddedildi | Rejected in review three times |

## 6. Sıra ve ajan dağılımı

Faz kuralı: Claude yönetir; 2 Sonnet yazar ve 1 Sonnet inceleyici çalışır. Build'ler `lockf` ile sırayla alınır. Her brief'te Bölüm 2 tablosu ve ilgili "örnek alınan" dosya bulunur.

1. **Yazar 1:** A1 ve A2. Core testleri geçmeden platform işi başlamaz.
2. Core onaylanınca iki yazar paralel çalışır. Dosyalar çakışmaz.
   - **Yazar 1:** B1, B2 ve D1'in iOS kısmı.
   - **Yazar 2:** C1, C2, C3 ve D1'in Android kısmı.
3. **İnceleyici** önce Core diff'ine, sonra iki platforma bakar. Kontrol listesi:
   - Her parça Bölüm 2'deki yerde ve örnek alınan dosyanın biçiminde mi?
   - Core'da UI durumu ya da metin var mı?
   - JWT köprüden geçiyor mu?
   - `percentEncodedQuery` hiçbir katmanda düşüyor ya da yeniden kodlanıyor mu?
   - Eski yanıtlar atılıyor mu?
   - `"system"` değeri üye listesinde aranıyor mu?
   - Mapping kopyalanmış mı?
   - Gereksiz soyutlama ya da yeni framework var mı?
4. Claude her diff'i okur. Düzeltmeler aynı ajana gönderilir.

## 7. Doğrulama

- `swift test --package-path shared`, köprü testleri, Android `./gradlew :app:testDebugUnitTest` ve build, iOS `xcodebuild build` ve `test` (`generic/platform=iOS Simulator`). Simülatör ya da emülatör açılmaz.
- **Kullanıcı ekranda kontrol eder (iki platformda):**
  1. Ana ekranda Geçmiş bölümünde yalnızca son 48 saatte kapanan chore'lar var ve "Tüm geçmiş" satırı görünüyor.
  2. Arşiv bu ayla açılıyor ve dün kapanan chore da listede (ana ekranda da görünmesi normal).
  3. 10'dan fazla kapanmış chore olan bir ayda "Daha fazla göster" listeyi sona ekliyor, tekrar yok; son sayfada buton kayboluyor.
  4. Yüklenirken ay değiştirince eski ayın chore'ları yeni listeye karışmıyor.
  5. Süresi dolan chore "Süresi doldu", üçüncü turda reddedilen chore "İncelemede reddedildi" gösteriyor; hiçbir yerde "system" yazmıyor.
  6. Arşivdeki bir chore'a dokununca detay salt okunur açılıyor, kapatınca arşive dönülüyor, review fotoğrafı görüntüleniyor.
  7. Boş bir ayda boş durum, uçak modunda hata ve yeniden deneme görünüyor.
  8. Arşiv açıkken push'a dokununca arşiv kapanıyor ve mevcut push akışı çalışıyor.
  9. Chore oluşturma ve düzenleme eskisi gibi çalışıyor.

## 8. Kapsam dışı ve açık sorular

- **Kapsam dışı:**
  - Push ile 48 saatten eski bir chore'u açmak: şu an dashboard'da kalıyor. Gerekirse backend'den tekil chore endpoint'i istenir.
  - Puan ve istatistik: eklenirse sunucuda hesaplanmalı, client listeden saymamalı.
  - Diğer servislerin `HTTPRequest`'i alan alan yeniden kurma kalıbını değiştirmek.
- **Açık soru 1:** Ay gezgini yerine "Bu hafta / Bu ay / Geçen ay / Özel" seçenekleri istenir mi? Core yalnızca `from`/`to` aldığı için iki tasarım da yalnızca platform tarafını etkiler.
- **Açık soru 2:** Arşiv yalnızca kullanıcının kendi chore'larına süzülsün mü? Endpoint ev genelinde dönüyor ve client tarafında süzmek sayfalamayı bozar. Plan tüm evi gösteriyor.

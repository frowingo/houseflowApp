# Push bildirimleri — istemci geliştirme planı (iOS + Android)

Tarih: 21 Kasım 2026 · Hazırlayan: mobil (istemci) · Dayanak: backend agent'ının istemci prompt'u
(cihaz kaydı, bildirim paneli, hatırlatma, `notification.created` olayı, push içeriği, push dili)

Bu belge, backend sözleşmesine göre iki platformda yapılacak işleri, repodaki mevcut durumu,
karar bekleyen noktaları ve iş sırasını tanımlar. Wire sözleşmesi prompt'taki gibidir; burada
yalnız istemciyi ilgilendiren yorumlar var.

## Durum

- **P1 ve P2 tamam (21 Kasım 2026), commit edilmedi:** K1–K5, K7 ve K8 öneriler olduğu gibi onaylandı.
  Core + bridge + platform push altyapısı ve cihaz kaydı/silme iki platformda bağlandı. Ayrıntılar,
  doğrulama ve elle test listesi: [pushNotificationsP1P2Report.md](pushNotificationsP1P2Report.md).
  iOS testleri yalnız derlendi (simülatör yok).
- **P3 tamam (21 Kasım 2026), commit edilmedi:** panel + rozet, "Hatırlat" düğmesi, push'a dokunma
  yönlendirmesi (Core `PushRouting`). Ayrıntılar ve elle test listesi:
  [pushNotificationsP3Report.md](pushNotificationsP3Report.md).
- **P4 tamam (21 Kasım 2026):** yerelleştirme anahtarları iki platformda doğrulandı (kod değişmedi).
  Backend'e istemci entegrasyon raporu: [pushNotificationsClientReport.md](pushNotificationsClientReport.md).
  Backend raporu cevapladı; açık soru kalmadı, istemcide değişiklik gerekmedi.
  Sıradaki: P5 elle test (kullanıcı).
- Firebase kurulumu tamam ve commit edilmedi: plist/json, SPM/Gradle, entitlements, `UIBackgroundModes`.
- **21 Kasım 2026:** Backend cevapları geldi ve plan buna göre güncellendi (§8).
  - K6 kapandı; istemcide iş yok.
  - Hatırlatma kuralları netleşti (§3.2).
  - Panel kişiye göre filtreleniyor (K2 sadeleşti).
  - Açık kalan üç soru P1'i bloklamıyor.

## 0. Başlangıçtaki durum (repo incelemesi, 21 Kasım 2026)

### Hazır olan (doğrulandı)

- **iOS:**
  - `FausCrew/GoogleService-Info.plist` Resources'ta.
  - FirebaseMessaging 12.19.3 target'a bağlı.
  - `aps-environment`:
    - Debug: `FausCrew/FausCrew.entitlements`.
    - Release: kökteki `FausCrew.entitlements` (Sign in with Apple ile birlikte).
  - İki Info plist'te `UIBackgroundModes = remote-notification`.
  - Release dosyasında değer `development`. App Store dağıtımında Xcode bunu imzalarken `production` yapar; ek iş gerekmez.
- **Android:**
  - `app/google-services.json` yerinde.
  - google-services 4.6.0, BoM 35.2.0 (`firebase-messaging` 26.0.2).
  - `assembleDebug` geçiyor.

### İstemcide henüz olmayan

- Hiçbir push kodu yok: `FirebaseApp.configure`, UN delegate, `FirebaseMessagingService`, kanal, izin.
- `POST chore/{id}/remind` yok:
  - iOS `ChoreService` ve Android `DashboardRepository` bu çağrıyı içermiyor.
  - `ChoreDetailPopup` (iki platform) hatırlatma butonu göstermiyor.
- `AppEventsWire.event(from:)` yalnız `ready`, `user.changed`, `house.changed` tiplerini tanıyor. `notification.created` sessizce atılıyor.

### Desenler (yeni kod bunlara uyacak)

- **Core `*WireContract`:**
  - İstek gövdesini/isteği kurar ve yanıtı doğrular.
  - Hatalar `HTTPStatusFailure` üzerinden gelir.
  - Örnekler: `DashboardWireContract`, `ChoreCatalogWireContract`.
- **Core sans-IO makineleri:**
  - `AppEventsChannel` örneği: girdi fonksiyonları, `drainEffects()`, saat dışarıdan verilir.
  - Android bunları `swift-bridge` içindeki handle registry ve JSON ile kullanır (`AppEventsBridge.swift`).
- **Portlar:** `HTTPClient`, `SecureSessionStore`, `PreferencesStore`.
- **iOS katmanları:**
  - Servisler `network` + `keychain` alır ve `AppDependencies.live()` içinde kurulur.
  - Akış `AppSessionCoordinator` → `AppViewModel` üzerinden geçer.
- **Android katmanları:**
  - Repository'ler (`platform/`) bridge'i istek ve yanıt başına birer kez çağırır.
  - ViewModel'ler (`viewmodel/`) üstte durur.
  - `MainActivity` olayları ViewModel'lere bağlar.
- **Ev içi okundu bilgisi zaten var:** `AnnouncementReadStore`, UserDefaults anahtarı `fauscrew.read-announcements.<userId>.<houseId>`. Bildirimler için aynı kapsam (kullanıcı + ev) kullanılacak.
- **Profil → Ayarlar kartındaki "Bildirimler" satırının (`profile_notifications_label`) iki platformda da aksiyonu yok.**

### Prompt ile çelişen ya da prompt'un atladığı noktalar

| # | Bulgu | Etki |
|---|---|---|
| B1 | **Çıkış yalnızca istemcide.** Sunucuda logout endpoint'i yok: iOS `AuthService.logout()` ve Android `session.logout()` yalnız yerel depoyu siliyor. JWT süresi dolana kadar geçerli kalır. | Silme isteği, JWT önceden alınarak **arka planda** gönderilebilir. Çıkış ekranı beklemez ve "oturum temizlenmeden önce" şartı yine sağlanır. |
| B2 | **Çıkışa giden yollar farklı:** (a) kullanıcı çıkışı, (b) 401 / reddedilen token, (c) hesap silme, (d) **dil değişince zorunlu yeniden giriş** (iki platform da `logout` çağırıyor). | DELETE yalnız (a) ve (d)'de gider. (b)'de JWT geçersiz. (c)'de backend tüm cihaz token'larını hesapla aynı transaction'da siliyor (backend onayladı). (b) ve (c)'de yalnız yerel `deleteToken` çalışır. |
| B3 | **Profil dili zaten esas alınıyor.** Girişte iki platform da `profile.language` değerini uygulama diline uyguluyor (iOS: `finishAuthentication` + `$currentUserProfile` sink; Android: `applyLanguageBestEffort`). Ayarlardan dil değişimi zaten `PUT user/profile {language}` gönderiyor. | Prompt'taki "uygulama dili ≠ profil dili ise gönder" kuralı için **ek iş gerekmez.** E-posta kaydındaki `en` sorunu backend'de çözüldü: kayıt dili artık `Accept-Language`'dan alınıyor. İki platform bu başlığı zaten her istekte gönderiyor (iOS `NetworkService.swift:174`, Android `AndroidHttpAdapter.kt:111`). Bkz. K6. |
| B4 | **Android'de `Application` sınıfı yok.** `MainActivity` launch mode'u standart; launcher'lar `activity-alias`. | Kanal, aktivite hiç açılmadan gelen push'tan önce var olmalı; bu yüzden `Application` gerekiyor. Arka planda dokunulan bildirimin extras'ının kaybolmaması için `singleTop` + `onNewIntent` gerekiyor. Bkz. K7. |
| B5 | **Panel ev bazlı** (`houseId` zorunlu); profil ekranı ise kullanıcı bazlı. | Panel ve rozet için en doğal yer dashboard hero kartı. Bkz. K1. |
| B6 | **iOS'ta açık görev detayı yerel `@State`'te** (`HouseDashboardView.selectedChore`). Sekme de `MainTabView` içinde `@State`. Android'de oyun ekranları `MainActivity` bayraklarıyla açılıyor. | Bildirime dokunma için router seviyesinde bir "bekleyen hedef" gerekiyor. Ekranlar bunu tüketecek. |
| B7 | **Swizzling.** `FirebaseAppDelegateProxyEnabled` tanımlı değil, yani açık. | Plist'e dokunmadan çalışır. Bkz. K5. |

## 1. Kararlar

**Onay (21 Kasım 2026):** K1–K5, K7 ve K8 aşağıdaki önerilerle onaylandı; K6 backend'de çözüldü.

| # | Konu | Neden önemli | Öneri |
|---|---|---|---|
| K1 | **Panelin giriş noktası** | Profil satırı ev bağımsız, panel ise ev bazlı. | **Dashboard hero kartında, megafon butonunun yanında zil butonu.** Okunmamış varsa rozet (1–9, sonra "9+"). Panel, `NewAnnouncementPopup` gibi tam ekran popup olarak açılır. **Profil → "Bildirimler" satırı** sistemdeki bildirim ayarlarını açar ve izin durumunu gösterir. Böylece aksiyonsuz satır da işe yarar ve izni reddeden kullanıcıya geri dönüş yolu kalır. |
| K2 | **Okunmamış nasıl sayılır** | Backend okundu tutmuyor. Panel kişiye göre filtreli: kişi kendi gönderdiğini görmez, yalnız kendisine yapılan hatırlatmaları görür. | Core'da `NotificationSeenState`: kullanıcı + ev başına en son görülen `(createdAt, id)`. Okunmamış = ilk sayfada bundan yeni olan öğeler. Gönderen filtresi backend'de olduğu için istemcide gerekmez. Panel açılınca görülen en yeni öğe kaydedilir. **İlk kez (kayıt yoksa):** ilk sayfadaki tüm öğeler okunmamış sayılır. Bildirimler 30 gün tutulduğu için liste kısa kalır. |
| K3 | **Bildirim izni ne zaman istenir** | Prompt "girişten sonra ya da eve katılınca" diyor. | Kullanıcı bir evle dashboard'a **ilk ulaştığında**, splash ve giriş animasyonu bittikten sonra, izin durumu "belirlenmemiş" ise. Özel ön ekran yok; sistem penceresi açılır. Android 13+ `POST_NOTIFICATIONS` için de aynı an. Reddederse bir daha sorulmaz; profil satırı ayarlara götürür. |
| K4 | **Bildirime dokunma: oyun açıksa / görev bulunamazsa** | Oyunlar yatay kilitli tam ekran. Görev bugünün listesinde olmayabilir. | Hedef **bekletilir.** Oyun kapanıp ana ekran görününce uygulanır; oyun zorla kapatılmaz. Ev değiştirme mevcut `switchHouse` akışıyla yapılır. `choreId`, yüklü ev detayındaki görevlerde yoksa yalnız ev açılır; toast gösterilmez. Ev kullanıcının değilse sessizce ana ekrana dönülür. |
| K5 | **iOS swizzling** | Kapatmak iki Info plist'e anahtar eklemek demek; prompt proje ayarına dokunmamayı istiyor. | **Açık kalsın.** Yine de `didRegisterForRemoteNotificationsWithDeviceToken` içinde `Messaging.messaging().apnsToken` açıkça verilsin; iki yol birlikte çalışır. UN delegate'i biz atarız; Firebase bunu bozmaz. |
| K6 | **E-posta kaydında dil** — **Kapandı (21 Kasım 2026)** | Profil `en` yazılıyordu; Türkçe kullanıcının uygulaması girişte İngilizceye dönüyor, push'lar İngilizce geliyordu. | **Backend çözdü:** `POST auth/signup` dili `Accept-Language`'dan alıyor; istemci bunu zaten gönderiyor. **İstemcide iş yok,** geçici PUT de yazılmayacak. Normal girişte profil dili esas kalır (mevcut davranış). Not: backend'in bir sonraki deploy'una kadar canlıda kayıt `en` yazmaya devam eder; push da o deploy'dan önce canlıda olmayacak. |
| K7 | **Android `Application` + `singleTop`** | Manifest değişikliği. | `FausCrewApplication` eklenir (`android:name`). Kanal ve Firebase hazırlığı orada yapılır. `MainActivity`'ye `launchMode="singleTop"` eklenir ve `onCreate` ile `onNewIntent` aynı push hedefi ayrıştırıcısını kullanır. Facebook/Snap yönlendirmeleri kendi aktivitelerinde olduğu için etkilenmez. |
| K8 | **Android bildirim ikonu** | Monokrom `default_notification_icon` gerekiyor; repoda hazır vektör yok (`FausMark` Compose'da çiziliyor). | Faus işaretinden tek renkli bir `ic_stat_fauscrew.xml` vektörü çizilir. Tasarım onayı istenir. |

## 2. Mimari hedef

```
FausCrewCore (Swift, iOS + Android ortak)
  NotificationModels.swift
    PushPlatform               "ios" | "android"
    NotificationKind           announcement | choreReminder | unknown(String)
    HouseNotification          id, kind, houseId, senderUserId, choreId?, title, message, createdAt
    NotificationPage           items, nextCursor?
    PushTarget                 houseId, choreId?, notificationId?  ← push data / intent extras
  UseCases/NotificationWireContract.swift
    registerDeviceRequest(token:platform:jwt:)   POST notification/devices (4096 sınırı istemcide de)
    unregisterDeviceRequest(token:jwt:)          DELETE notification/devices
    listRequest(houseId:before:limit:jwt:)       GET notification (limit 1…50'ye kırpılır)
    remindRequest(choreId:jwt:)                  POST chore/{id}/remind (gövdesiz)
    page(from:)       {success, data: {items: [], nextCursor?}} → NotificationPage
                      items hiç null gelmez; choreId / nextCursor yoksa alan hiç gelmez
                      createdAt: UTC, saniye hassasiyetli, "Z" (ISO8601DateFormatter varsayılanı)
                      400 → .invalidRequest, 403 → .notMember, 404 → .houseNotFound
    accepted(from:)   POST/DELETE devices → {success: true}
    remind(from:)     409 → .alreadyReminded; 400 (kural ihlali) → .rejected(message);
                      403 → .notMember; 404 → .choreNotFound; mesaj sunucudan, yerelleştirilmiş
    pushTarget(from userInfo/data: [String: String]) → PushTarget?
  ChoreReminderRules.swift
    canRemind(assignedToId:currentUserId:status:dueDate:now:) — backend'in kontrol sırasıyla aynı:
      atanmış · bana atanmamış · Draft(0)/Progress(1) · dueDate−12s ≤ now < dueDate
    window = 12 saat; dueDate mevcut `apiDate` ayrıştırıcısıyla okunur
  Notifications/PushRegistrationChannel.swift   (sans-IO, AppEventsChannel gibi)
    girdiler: setSession(userId?, jwtAvailable) · setToken(String?) · launched() · signedIn()
              registered(ok:) · unregistered()
    efektler: .register(token, platform) · .unregister(token, jwtSnapshot?) · .deleteLocalToken
    kural:    oturum açık + token var + (bu süreçte ilk açılış | token değişti | giriş yapıldı)
              aynı (userId, token) için süreç içinde tek gönderim; başarısızlık → sonraki açılış
              çıkış: kullanıcı çıkışı → unregister(+jwt) sonra deleteLocalToken
                     reddedilen oturum/hesap silme → yalnız deleteLocalToken
              çıkış temizliği bitmeden yeni girişin register'ı ertelenir (yarış: eski token
              yeni hesaba yazılıp ardından silinmesin)
  Notifications/NotificationSeenState.swift
    unreadCount(items:seen:) · markSeen(items:) · Codable (PreferencesStore'da JSON)
  Events/AppEventsChannel.swift
    AppEvent.notificationCreated(houseID)  →  efekt .refreshNotifications(houseID) (seçili ev)
    ready / öne dönüş tam yenilemesi seçili evin bildirimlerini de yeniler

swift-bridge (Android)
  NotificationBridge.swift: istek gövdeleri, yanıt doğrulama, pushTarget, seen-state hesapları
  PushRegistrationBridge.swift: handle registry + JSON olay/efekt (AppEventsBridge deseni)
  AppEventsBridge: yeni efekt tipi "refreshNotifications"

iOS
  Push/PushNotificationService.swift   Firebase + UN delegate + MessagingDelegate, token sağlayıcı,
                                        PushRegistrationChannel efektlerini HTTP ile uygular
  FausCrewAppDelegate                   FirebaseApp.configure, registerForRemoteNotifications,
                                        apnsToken, UN delegate ataması
  NotificationService.swift            list / remind (NetworkService + Core contract)
  NotificationStore (ViewModels/Stores) seçili evin sayfaları, rozet, seen-state
  Router: pendingPushTarget             MainTabView + HouseDashboardView tüketir
  Views/Dashboard/Notifications/        NotificationsPopup, satır, boş/hata/iskelet durumları

Android
  FausCrewApplication                   kanal (fauscrew_default, yerelleştirilmiş ad), Firebase hazır
  push/FausCrewMessagingService         onNewToken → kayıt akışı; onMessageReceived → öndeyse göster
  push/PushNotifier                     NotificationCompat, tag = notificationId, PendingIntent→MainActivity
  push/PushTokenProvider                FirebaseMessaging.token / deleteToken (await)
  platform/NotificationRepository       list / remind / devices (bridge ile)
  viewmodel/NotificationViewModel       sayfalar, rozet, seen-state (AndroidPreferencesStore)
  ui/dashboard/notifications/           NotificationsPopup + satırlar
  Manifest                              servis, POST_NOTIFICATIONS, default channel/icon meta-data,
                                        Application, MainActivity singleTop
```

**Tasarım ilkeleri**

- Token ne zaman kaydedilir ve ne zaman silinir, buna **yalnız Core** karar verir. Platform sadece token verir, HTTP isteğini atar ve bildirimi gösterir.
- Token log'a en fazla ilk 8 karakteriyle yazılır (`token.prefix(8)`). İstek gövdesi test dışında log'lanmaz.
- Ağ hataları kullanıcıya gösterilmez. Kayıt sessizce yapılır; başarısız olursa sonraki açılışta zaten tekrar denenir.
- Bilinmeyen `type` değerleri panelde genel bir ikonla gösterilir; backend yeni tip ekleyebilir.

## 3. Ekran ve akış ayrıntıları

### 3.1 Bildirim paneli (iki platform aynı)

- **Giriş noktası:** Hero kartta zil butonu (K1). Megafonla aynı boyutta (40pt daire, `heroOrnament` zemini). Rozet, tema vurgu rengiyle küçük bir daire.
- **Popup ve satır yapısı:** Görünüm `NewAnnouncementPopup` / `ChoreCatalogPopup` popup diliyle aynı (DESIGN.md: aynı kart, köşe yarıçapı, renk ve yazı tipleri). Her satırda:
  - gönderenin avatarı ve adı. Üye listesinde yoksa (evden ayrılmış ya da hesabı silinmiş) genel avatar ve "Eski üye" yazar,
  - tür ikonu (`megaphone.fill` / `bell.fill`),
  - başlık, mesaj ve göreli zaman,
  - okunmamışsa solda vurgu çizgisi.
- **Sayfalama:** Listenin sonuna yaklaşınca `before = nextCursor`. `nextCursor` yoksa yükleme durur.
- **Yenileme:** Aşağı çekerek yenileme yapılır. `notification.created` olayı gelince ve öne dönülünce ilk sayfa sessizce yenilenir.
- **Durumlar:** iskelet satırlar, boş durum ("Henüz bildirim yok"), hata + "Tekrar dene" kartı.
- **403 ya da 404 gelirse** (artık üye değilsin ya da ev silindi): panel kapanır ve profil/ev listesi yenilenir. Ev listeden düşerse mevcut `leaveRemovedHouse` akışı devreye girer.
- **Liste sınırı:** Liste en fazla 30 günü kapsar (backend saklama süresi). Boş durum metni bunu söyleyebilir: "Son 30 günde bildirim yok".
- **Okundu:** Panel açılınca görülen en yeni öğe kaydedilir ve rozet sıfırlanır.
- **Satıra dokunma:** Görev hatırlatmasıysa görev detayı açılır (aynı evde). Duyuruysa panel kapanır ve duyuru kartı görünür.

### 3.2 Hatırlatma (`POST chore/{id}/remind`)

- **Nerede:** `ChoreDetailPopup` (iki platform), bilgi kartlarının altında ikincil buton: "Hatırlat" (`bell.badge`).
- **Kimde görünür:** Kural Core'da `ChoreReminderRules.canRemind`. Backend'in önerisi ve kontrol sırasıyla aynı. Buton yalnız şu dört koşulun hepsi tutunca görünür:
  - görev birine atanmış,
  - **bana atanmamış,**
  - durumu **Draft (0) ya da Progress (1),**
  - **son tarihe 12 saatten az kalmış ve son tarih geçmemiş** (`dueDate − 12 saat ≤ şimdi < dueDate`).
  
  Pencere dışında buton hiç gösterilmez; pasif buton ya da açıklama yok. Popup açıkken pencere açılır ya da kapanırsa buton bir sonraki açılışta güncellenir; zamanlayıcı kurulmaz. Asıl karar backend'in; cihaz saati kaymışsa 400 mesajı gösterilir.
- **"Hatırlatıldı" durumu:**
  - Başarıdan sonra ya da **409 gelince** buton o görev için pasif "Hatırlatıldı" etiketine döner (`checkmark`).
  - Bu bilgi oturum boyunca bellekte tutulur: kullanıcı + görev id kümesi, çıkışta temizlenir.
  - Uygulama yeniden açılınca buton tekrar görünebilir. Basılırsa 409 gelir ve aynı duruma geçilir. 409 kalıcı olduğu için cihazda kalıcı kayıt tutmaya değmez.
- **Geri bildirim:**
  - İstek sürerken buton dönen göstergeyle bekler.
  - Başarı: bilgi toast'u "Hatırlatma gönderildi".
  - 409: toast yok, sessizce "Hatırlatıldı".
  - 400 / 403 / 404: sunucunun yerelleştirilmiş mesajıyla hata toast'u. 404'te ev detayı yenilenir.

### 3.3 Bildirime dokunma

```
push data / intent extras ─► Core PushTarget ─► Router.pendingPushTarget
  ├─ oturum yok / yükleniyor → bekle (oturum + ev listesi yüklenince tekrar değerlendir)
  ├─ houseId profil.houseList'te yok → hedefi at, ana ekran
  ├─ houseId ≠ seçili ev → switchHouse(houseId) bekle
  ├─ oyun açık → kapanana kadar bekle (K4)
  └─ ana sekme + dashboard görünür → choreId varsa ve yüklüyse ChoreDetail aç
```

- **iOS:** Soğuk açılışta UN delegate `didReceive`, `AppViewModel` oluşmadan çağrılabilir. Bu yüzden hedef küçük bir `PushInbox` (main actor) içinde tutulur ve `AppViewModel` hazır olunca alınır.
- **Android:** Hedef, `onCreate(intent)` ve `onNewIntent(intent)` ile aynı ayrıştırıcıdan geçer. Arka plandaki `notification` mesajlarında extras, `data` alanlarıdır.

### 3.4 Uygulama öndeyken gelen push

- **iOS:** `willPresent` → `[.banner, .list, .sound]`. Aynı evse rozet/panel yenilenir (socket olayı da gelir; çift yenileme Core'daki birleştirme penceresiyle önlenir).
- **Android:**
  - `onMessageReceived` içinde `notification` varsa bildirim kendimiz gösterilir: kanal `fauscrew_default`, `tag = notificationId`, `setAutoCancel`, içerik `PendingIntent` ile `MainActivity`'ye extras olarak gider.
  - İzin yoksa (`areNotificationsEnabled() == false`) gösterim atlanır, yalnız UI yenilenir.

## 4. İş sırası (fazlar)

Çalışma düzeni: Claude yönetici; **2 Sonnet yazar + 1 Sonnet gözden geçiren**. Görevler dosya sahipliğine göre bölünür, build'ler `lockf` ile sıraya alınır. Her fazın sonunda Core testleri, bridge testleri, Android unit testleri, iOS `build-for-testing` ve Android `assembleDebug` çalışır.

| Faz | İçerik | Yazar | Bağımlılık |
|---|---|---|---|
| **P0** | K1–K5, K7, K8 kararları (backend soruları cevaplandı, K6 kapandı) | Kullanıcı | — |
| **P1** | **Core + bridge:** modeller, `NotificationWireContract`, `PushRegistrationChannel`, `NotificationSeenState`, `AppEventsChannel` genişletmesi; Core testleri; `NotificationBridge`, `PushRegistrationBridge`, `AppEventsBridge` + bridge testleri | Yazar A | P0 |
| **P1'** | **Platform push altyapısı (Core'a bağımlı değil):**<br>- iOS: AppDelegate'te Firebase, UN delegate, `MessagingDelegate`, `registerForRemoteNotifications`, token sağlayıcı, izin yardımcısı, `PushInbox`.<br>- Android: `FausCrewApplication`, kanal, `FausCrewMessagingService`, `PushNotifier`, manifest, ikon, izin yardımcısı.<br>Bu fazda HTTP çağrısı yok; token yalnız kısaltılmış olarak log'lanır. | Yazar B | P0 |
| **P2** | **Kayıt/silme bağlantısı:**<br>- iOS: `PushNotificationService` ↔ `PushRegistrationChannel`; açılış, giriş, token değişimi, çıkış yolları (B2).<br>- Android: aynısı `AuthViewModel.logout` / dil değişimi / 401 / hesap silme yolları için. | A: Android, B: iOS | P1 + P1' |
| **P3** | **Hatırlatma + panel + rozet + dokunma yönlendirmesi** (iki platform, aynı görünüm) | A: Android, B: iOS | P2 |
| **P4** | Yerelleştirme anahtarları (§6), istemci entegrasyon raporu, kontrol listesi | Yönetici | P3 |
| **P5** | Elle test: Firebase Console test mesajı; gerçek iOS cihaz; Android 13+ cihaz/emülatör | Kullanıcı | P4 |
| **P6** | Uçtan uca test (backend canlıya çıkınca) | Kullanıcı + backend | Backend haberi |

## 5. Test planı

### Otomatik (bu repoda)

- **Core:**
  - `NotificationWireContractTests`:
    - gövdeler, 4096 sınırı, limit kırpma,
    - backend'in örnek yanıtıyla sayfa ayrıştırma: `nextCursor` ve `choreId` var/yok, `items: []`,
    - `createdAt` biçimi `2026-11-20T22:15:33Z`,
    - 400/403/404/409 eşlemesi ve `{success:false, error}` mesajı,
    - bilinmeyen tip.
  - `ChoreReminderRulesTests`:
    - pencere sınırları: `dueDate − 12s` dahil, `dueDate` hariç, geçmiş son tarih,
    - Draft/Progress dışındaki durumlar,
    - kendine atanmış ve atanmamış görev,
    - ayrıştırılamayan `dueDate`.
  - `PushTargetTests`: eksik/boş alanlar.
  - `PushRegistrationChannelTests`: açılış, giriş, token değişimi, aynı token tekrarı, başarısız kayıt, çıkış türleri (B2), çıkış ile yeni giriş yarışı, hesap değişimi.
  - `NotificationSeenStateTests`: ilk kez, eşit `createdAt` (id ile ayrım), sayfa sınırı.
  - `AppEventsChannelTests`: `notification.created` seçili/seçili olmayan ev, birleştirme, `ready`.
- **Bridge:** her yeni fonksiyon için JSON gidiş-dönüş testi (mevcut `*BridgeTests` deseni).
- **Android unit:**
  - `NotificationRepositoryTest`: mockwebserver; istek yolu, gövde, `Authorization`, `Accept-Language`.
  - Push hedefi ayrıştırıcısı testi.
- **iOS unit:**
  - `NotificationServiceTests`.
  - `AppSessionCoordinatorTests` içinde çıkış sırası: DELETE, JWT temizlenmeden önce kurulmalı.
- **Derleme:** iOS simülatör (`generic/platform=iOS Simulator`), Android `assembleDebug` (JDK 21 ve ortam değişkenleriyle).

### Elle (kullanıcı, P5)

1. **Token ve izin:**
   - İlk girişte dashboard'da izin penceresi çıkıyor; reddedince uygulama normal çalışıyor.
   - Log'da `notification/devices` isteği ve token'ın ilk 8 karakteri görünüyor.
2. **Android kanalı:** Ayarlar → Uygulama → Bildirimler'de "FausCrew" kanalı uygulamanın dilinde görünüyor.
3. **Console test mesajı** (`data: houseId, choreId`):
   - Uygulama arkadayken sistem bildirimi geliyor; dokununca doğru ev ve görev açılıyor.
   - Uygulama öndeyken banner çıkıyor (iOS) / bildirim kendimiz gösteriliyor (Android).
   - Uygulama kapalıyken dokununca soğuk açılış sonrası doğru ekran açılıyor.
4. **Çıkış:** DELETE isteği gidiyor; yeniden girişte yeni token kaydediliyor.
5. **iOS:** Gerçek cihazda dene. Simülatörde APNs token'ı yalnız Apple Silicon + Xcode 14 ve üstünde gelir; asıl doğrulama cihazda.

## 6. Yeni yerelleştirme anahtarları (tr/en yerleşik metinle)

Anahtar listesi:

- `notifications_title`
- `notifications_empty`
- `notifications_error_retry`
- `notifications_open_accessibility_label`
- `notifications_unread_badge_accessibility`
- `notifications_former_member` ("Eski üye" / "Former member")
- `chore_detail_remind_action`
- `chore_detail_reminded` ("Hatırlatıldı" / "Reminded")
- `chore_remind_sent`
- `profile_notifications_status_on` / `_off`

Kurallar:

- Sunucu metni varsa o kullanılır; yoksa `localized(key, tr:, en:)` deseniyle yerleşik metin.
- Android kanal adı uygulama dili değişince güncellenir: aynı kanal id'siyle yeniden `createNotificationChannel` çağrılır.
- **P4 sonucu (21 Kasım 2026):**
  - Anahtarlar ve tr/en metinler iki platformda birebir aynı. Tablo:
    [pushNotificationsClientReport.md §4](pushNotificationsClientReport.md).
  - `notifications_channel_name` kullanılmadı. Kanal, katalog yüklenmeden uygulama açılırken
    oluşturulduğu için adı yalnız yerleşik tr/en metinden gelir.

## 7. Kapsam dışı

- Seçili olmayan evlerin okunmamış sayısı. Bunun için backend'de çok evli bir sayım uç noktası gerekir.
- Bildirimleri sunucuda okundu işaretleme ve bildirim tercihleri (tür bazlı kapatma).
- iOS uygulama ikonu rozeti (`applicationIconBadgeNumber`). Backend `badge` göndermiyor.
- Rich notification (görsel) ve Notification Service Extension.

## 8. Backend cevapları (21 Kasım 2026) ve açık kalanlar

### Cevaplandı

| # | Soru | Cevap | Plana etkisi |
|---|---|---|---|
| 1 | `GET /notification` yanıt şekli | `{success, data: {items, nextCursor?}}`. `items` boşsa `[]` gelir. `choreId` ve `nextCursor` yoksa alan hiç gelmez. `limit` 0/negatif/eksikse 20 olur, en fazla 50. `createdAt` UTC, saniye hassasiyetinde, `Z` ile biter. Sayfa sınırı id'ye göre olduğu için kayma yok. Hatalar: 400 (`houseId` yok / `before` geçersiz), 403 (üye değil), 404 (ev yok). | §2 `page(from:)`, §3.1 hata durumları, §5 testleri |
| 2 | Panel ev akışı mı, kişiye özel mi? | Evin akışı, kişiye göre filtreli: duyurular herkese, hatırlatma yalnız alıcıya; **kişi kendi gönderdiğini görmez.** Push da aynı kişilere gider. | K2 sadeleşti: istemcide gönderen filtresi yok |
| 3 | Hatırlatma kuralları | Atanmış + bana değil + Draft/Progress + `dueDate − 12s ≤ şimdi < dueDate`. Aynı gönderen aynı göreve bir kez; 409 pratikte kalıcı. Farklı üyeler ayrı ayrı hatırlatabilir. İstek gövdesiz. | §3.2 yeniden yazıldı; Core'a `ChoreReminderRules` |
| 4 | Hesap silinince token'lar | Hesabı silen tüm yollarda token'lar aynı transaction'da siliniyor. İstemci ayrıca DELETE göndermez; yalnız yerel `deleteToken`. | B2 doğrulandı |
| 5 | E-posta kaydında dil | `auth/signup` dili `Accept-Language`'dan alıyor (`tr…` → tr, diğerleri → en). Ek PUT gerekmez. Sonraki backend deploy'uyla canlıya çıkacak. | K6 kapandı, istemcide iş yok |
| 8 | Saklama süresi | Bildirimler ve hatırlatma kayıtları 30 gün sonra silinir. | §3.1 boş durum metni |
| — | Ek bilgi | Silinmiş kullanıcının `senderUserId`'si gelebilir; "Eski üye" yedeği gösterilmeli. FCM'in geçersiz saydığı token'ı backend kendisi siliyor (ör. yanlışlıkla gönderilmiş APNs token'ı). | §3.1, §6 `notifications_former_member` |

### Sonradan cevaplananlar (21 Kasım 2026, istemci raporuna cevap)

Açık soru kalmadı. Hiçbiri istemcide değişiklik gerektirmedi; ayrıntı
[pushNotificationsClientReport.md §7](pushNotificationsClientReport.md)'de.

- **6. Duyuruda iki olay:** Evet, önce `house.changed` (yazan dahil), sonra `notification.created` (yazan hariç). Hatırlatmada yalnız atanan kişiye `notification.created` gider. Birleştirme penceresi ikisini de kapsıyor.
- **7. Yeni bildirim tipleri:** Yakın planda yok; eklenirse `type`'ta yeni string olarak gelir ve backend önceden haber verir.
- **9. iOS `data` anahtarları:** APNs `userInfo` üst seviyesinde, değerler hep String; FCM'in kendi anahtarları yok sayılır.
- **DELETE:** Yalnız (kullanıcı, token) eşleşmesini siler; eşleşme yoksa yine `200 {"success": true}`.
- **Metin anahtarları:** SuperAdmin hesabıyla `POST /api/v1/language` üzerinden kataloğa eklenecek. Backend kod/deploy işi değil.

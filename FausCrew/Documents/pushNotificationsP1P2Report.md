# Push bildirimleri — P1 ve P2 faz raporu

Tarih: 21 Kasım 2026 · Plan: [pushNotificationsClientPlan.md](pushNotificationsClientPlan.md)

P1 (Core + bridge + platform push altyapısı) ve P2 (cihaz kaydı / silme bağlantısı) iki platformda
tamamlandı. Hiçbir şey commit edilmedi; Firebase kurulumuyla birlikte çalışma ağacında duruyor.
Proje ve SDK ayarlarına (plist/json, bundle ID, paket adı, imza) dokunulmadı.

## 1. Ne yapıldı

### Core (`FausCrew/shared/Sources/FausCrewCore/`)

- `Notifications/NotificationModels.swift`: `PushPlatform`, `NotificationKind` (bilinmeyen tip korunur),
  `HouseNotification`, `NotificationPage`, `PushTarget` (push verisinden ev/görev hedefi).
- `UseCases/NotificationWireContract.swift`: cihaz kaydı (`POST notification/devices`), silme
  (`DELETE notification/devices`), bildirim listesi (`GET notification`, limit 1…50) ve hatırlatma
  (`POST chore/{id}/remind`) istekleri; yanıt doğrulama ve 400/401/403/404/409 eşlemesi. Sayfa
  ayrıştırması hoşgörülü: bozuk tek kayıt atlanır, sayfa düşmez. Token boş olamaz, en fazla 4096 karakter.
- `Notifications/ChoreReminderRules.swift`: hatırlatma kuralı (bana atanmamış, Draft/Progress,
  `dueDate − 12s ≤ şimdi < dueDate`).
- `Notifications/NotificationSeenState.swift`: okunmamış sayısı için "son görülen" işareti (kullanıcı + ev başına).
- `Notifications/PushRegistrationChannel.swift`: token kaydının kuralları (sans-IO). Kullanıcı ve token
  bilinince bir kez kayıt; çıkışta sıra: DELETE → yerel token silme → yeni token. Temizlik sürerken
  gelen token yok sayılır, yeni giriş yalnız taze token'ı kaydeder.
- `Events/AppEventsChannel.swift`: `notification.created` olayı → seçili ev için birleştirilmiş
  `refreshNotifications` efekti (P3'te tüketilecek).

### Bridge (`FausCrew/android/swift-bridge/`)

- `NotificationBridge.swift`, `PushRegistrationBridge.swift`, `AppEventsBridge.swift` genişletmesi.
  JWT bridge'e hiç girmez; Kotlin header'ı kendisi ekler. Bridge sürümü iki tarafta da 20.

### iOS

- `Services/App/FausCrewAppDelegate.swift`: Firebase yapılandırması, UN ve Messaging delegate'leri,
  her açılışta `registerForRemoteNotifications`, APNs token'ı Messaging'e veriliyor (swizzling açık, K5).
- `Services/Push/`: `PushNotificationCenter` (öndeyken banner, dokunma, token değişimi), `PushInbox`
  (soğuk açılışta dokunulan push kaybolmaz), `PushTokenProvider`, `PushPermission`,
  `PushRegistrationService` (Core kanalını barındırır, istekleri gönderir).
- `AppViewModel`: tam oturum açmış kullanıcı → `setSession`; `logout(reason:)` push çıkışını oturum
  temizlenmeden önce çağırır.
- K3: dashboard ilk görününce ~1 sn sonra izin isteniyor (yalnız karar verilmemişse).
- K1: Profil → Ayarlar → Bildirimler satırı sistem ayarlarını açıyor, Açık/Kapalı gösteriyor.

### Android

- `FausCrewApplication`, `push/` paketi: `PushChannels` (kanal `fauscrew_default`, adı uygulama diliyle),
  `FausCrewMessagingService`, `PushNotifier`, `PushInbox`, `PushTokenProvider`, `PushPermission`,
  `PushRegistrationHost` (Core kanalını barındırır), `PushLog` (yalnız debug, token'ın ilk 8 karakteri).
- `platform/PushRegistration.kt`, `platform/NotificationRepository.kt` (şimdilik cihaz kaydı/silme).
- Manifest: `POST_NOTIFICATIONS`, `singleTop` (K7), messaging servisi, varsayılan kanal/ikon/renk.
  Monokrom durum çubuğu ikonu `ic_stat_fauscrew` (K8: cihazda değerlendirilecek).
- `AuthViewModel.logout(reason)`; K3 izin isteği (bir kez sorulduğu kalıcı olarak hatırlanıyor); K1 satırı.

### Çıkış yolları ve nedenleri

| Neden | DELETE gider mi | Yollar |
|---|---|---|
| `userInitiated` | Evet (JWT temizlenmeden önce okunur) | Profil çıkışı, ev hata ekranı çıkışı, e-posta doğrulamadan çıkış, dil değişince zorunlu yeniden giriş |
| `sessionRejected` | Hayır, yalnız yerel token silinir | 401 / oturum reddi, olay soketi 401, oyunlarda "giriş gerekli", sosyal bağlama 401, açılışta reddedilen oturum |
| `accountDeleted` | Hayır (backend token'ları hesapla siliyor) | Hesap silme |

## 2. İnceleme ve düzeltmeler

P1 ve P2'nin her biri yönetici incelemesi ve ayrı bir reviewer'dan geçti. Önemli düzeltmeler:

- **Hata ekranından çıkışta DELETE atlanıyordu.** Geçici "oturum yok" durumu Core'un kullanıcıyı
  unutmasına yol açıyor, sonraki kullanıcı çıkışı DELETE göndermiyordu. Artık kullanıcı çıkışında token
  biliniyorsa DELETE her zaman gidiyor; kayıtlı olmayan token için giden DELETE zararsız.
- **Android: açılışta reddedilen oturum yerel token'ı silmiyordu** (iOS siliyordu). Artık reddedilen
  ya da oturum açıkken kaybolan oturumda token siliniyor; hiç oturum yoksa her açılışta silinmiyor.
- **Android: iptal edilen çıkış temizliği kilitli bırakabiliyordu** (süreç boyunca kayıt yapılmıyordu).
  JWT okuma ve temizlik başlatma artık iptal edilemez.
- **iOS: açılışta getirilen eski token**, araya giren bir çıkıştan sonra kaydedilebiliyordu. Android'deki
  gibi çıkış sayacıyla engellendi.
- P1'de: eski push dokunuşunun yeniden işlenmesi, iptal edilen Firebase görevinin sonsuza dek
  beklemesi, token önekinin log'da gizli kalması, boş `registrationFinished` metodu, bildirim
  isteği kimliği çakışması düzeltildi.

## 3. Doğrulama

| Kontrol | Sonuç |
|---|---|
| Core `swift test` | Geçti: 462 test, 0 hata, 1 atlanan (başlangıçta 410) |
| Bridge `swift test` | Geçti: 68 test, 0 hata |
| Android `assembleDebug` + `testDebugUnitTest` | Geçti: 244 unit test, 0 hata |
| iOS `build-for-testing` (simülatör hedefi) | Derlendi, 0 hata |

**Çalıştırılamayanlar:** iOS testleri (`PushRegistrationServiceTests`, 7 test) yalnız derlendi; bu
makinede simülatör yok. Simülatör, emülatör ve cihaz testleri kullanıcıda (P5).

## 4. Bilinen sınırlar ve sonraki fazlara kalanlar

- Girişten hemen sonra çıkışta kayıt POST'u ile DELETE'in sırası garanti değil (çok dar pencere;
  bilinçli olarak bırakıldı). Bir sonraki girişte token yeniden kaydedilir.
- Android'de izin isteği, dashboard açıldıktan sonraki 1 saniye içinde ekran değişirse o süreçte
  atlanır; bir sonraki açılışta tekrar denenir.
- Dil değişiminde Android `pushSignOut(UserInitiated)` çağrısının ayrı bir unit testi yok (kod incelendi).
- P3'e kalanlar: bildirim paneli, okunmamış rozeti, hatırla düğmesi, dokunulan push'un yönlendirmesi
  (`PushInbox` hazır ama tüketen yok), `refreshNotifications` efektinin tüketilmesi.

## 5. Elle test kontrol listesi (P2 kapsamı)

İki platformda debug derlemesiyle; log'da `Push` (iOS) / `FausCrewPush` (Android) filtresi:

1. **Açılış ve kayıt:** Oturumu açık uygulamayı aç → bir kez `POST notification/devices … -> 200`,
   token yalnız ilk 8 karakteriyle görünüyor.
2. **İzin:** İlk kez dashboard'a gelince ~1 sn sonra izin penceresi çıkıyor; giriş/karşılama ekranlarında
   çıkmıyor. Reddet → uygulama normal çalışıyor; yeniden açınca tekrar sorulmuyor (Android dahil).
3. **Profil satırı:** Profil → Bildirimler Açık/Kapalı gösteriyor; dokununca sistem bildirim ayarları
   açılıyor; ayarı değiştirip dönünce değer güncelleniyor.
4. **Kullanıcı çıkışı:** Çıkış yap → `DELETE notification/devices … -> 200`, ardından yeni token alınıyor.
   Başka hesapla giriş → yeni token için tek `POST`.
5. **Dil değişimi:** Dil değiştir → zorunlu yeniden girişte `DELETE` gidiyor.
6. **Hesap silme:** DELETE gitmiyor; yerel token siliniyor, yeni token alınıyor.
7. **Android kanal:** Ayarlar → Uygulama → Bildirimler'de kanal uygulama dilinde ("Genel bildirimler" /
   "General notifications"); dil değişince adı değişiyor.
8. **Durum çubuğu ikonu (Android, K8):** Firebase Console test mesajında ikon okunaklı mı?
9. **Firebase Console test mesajı:** Uygulama arkadayken sistem bildirimi; öndeyken iOS'ta banner,
   Android'de uygulamanın gösterdiği bildirim. (Dokununca yönlendirme P3'te.)

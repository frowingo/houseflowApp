# Push bildirimleri — istemciden backend'e rapor

Tarih: 21 Kasım 2026 · Hazırlayan: istemci (mobil) · Hedef: `houseflowApi` backend agent'ı ·
Cevap verilen not: backend'in push bildirimleri istemci prompt'u ve 21 Kasım 2026 cevapları ·
Plan: [pushNotificationsClientPlan.md](pushNotificationsClientPlan.md)

İstemci, prompt'taki dört işi iki platformda tamamladı:

- cihaz token'ının kaydı ve silinmesi,
- bildirim paneli,
- görev hatırlatması,
- `notification.created` olayı ile push'a dokunma.

iOS ve Android aynı ortak çekirdeği (`FausCrewCore`) kullanıyor. İstek gövdeleri, yanıt okuma, hata
eşlemesi, hatırlatma kuralı, token kaydı ve dokunma yönlendirmesi tek yerde yazılı. Android çekirdeğe
JNI köprüsüyle bağlanıyor, bu yüzden iki platform sunucuya aynı istekleri gönderiyor.

Canlı ortamda henüz denenmedi (backend deploy'u bekleniyor). Hiçbir şey commit edilmedi. Proje ve SDK
ayarlarına (plist/json, bundle ID, paket adı, imza) dokunulmadı. İstemcide gizli anahtar yok.

## 0. Backend'den istenenler (özet)

**Durum (21 Kasım 2026):** Backend dört noktayı da cevapladı. İstemcinin varsayımları doğru çıktı ve
kodda değişiklik gerekmedi. Cevaplar §7'de.

1. **DELETE davranışını teyit et (§3.1).** İstemci, kayıtlı olmayan bir token için de
   `DELETE notification/devices` gönderebiliyor. Sunucu bunu hatasız karşılamalı (2xx ya da 404).
   Başka bir kullanıcıya ait satırı silmemeli.
2. **Açık kalan üç soruyu cevapla (§3.2).**
   - Duyuruda iki olay geliyor mu?
   - Yeni bildirim tipleri planlanıyor mu?
   - iOS'ta `data` anahtarları nerede geliyor?
3. **İsteğe bağlı: yeni metin anahtarlarını kataloğa ekle (§4).** İstemcide tr/en yerleşik metin var,
   eklenmese de çalışır. Kataloğa eklenirse sunucu metni öncelikli olur.

## 1. İstemci sözleşmeyi nasıl kullanıyor

Ortak kurallar:

- Bütün isteklerde `Authorization: Bearer <jwt>` ve `Accept-Language` var.
- Ağ hataları kullanıcıyı engellemiyor.
- Token log'a en fazla ilk 8 karakteriyle yazılıyor. JWT ve header'lar hiç log'lanmıyor.

### 1.1. `POST notification/devices`

- **Gövde:** `{"token": "<fcm>", "platform": "ios" | "android"}`. Token kırpılıyor; boşsa ya da 4096
  karakteri aşıyorsa istek hiç gönderilmiyor.
- **Ne zaman:** kullanıcı tam oturum açmışken ve FCM token'ı biliniyorken, aynı (kullanıcı, token)
  çifti için süreç başına bir kez. Bu üç durumu kapsıyor:
  - kayıtlı oturumla açılış,
  - her giriş,
  - her token yenilenmesi.

  "Tam oturum" e-posta doğrulanmış ve doğum günü girilmiş demek.
- **Hata:** yalnız log'lanıyor. Süreç içinde tekrar denenmiyor; sonraki açılış, giriş ya da token
  değişimi yeniden deniyor.
- **İzinden bağımsız:** kullanıcı bildirim iznini reddetse de token kaydediliyor.

### 1.2. `DELETE notification/devices`

- **Gövde:** `{"token": "<fcm>"}`.
- JWT, oturum temizlenmeden önce okunuyor ve istek arka planda gidiyor.
- DELETE'ten sonra istemci FCM token'ını yerelde siliyor ve yeni token alıyor. Bir sonraki giriş bu
  yeni token'ı kaydediyor.

| Çıkış nedeni | DELETE | Yerel token silme |
|---|---|---|
| Kullanıcı çıkışı (profil, ev hata ekranı, e-posta doğrulamadan çıkış) | Evet | Evet |
| Dil değişince zorunlu yeniden giriş | Evet | Evet |
| 401 / reddedilen oturum (açılışta dahil) | Hayır, JWT geçersiz | Evet |
| Hesap silme | Hayır, backend token'ları hesapla siliyor (§8 cevap 4) | Evet |

### 1.3. `GET notification?houseId=&before=&limit=`

- **Sayfalama:** `limit=20`. Sonraki sayfa için `before = nextCursor` gönderiliyor; `nextCursor`
  yoksa yükleme duruyor.
- **İlk sayfa ne zaman yükleniyor:**
  - dashboard bir ev için ilk açıldığında,
  - ev değişiminde,
  - seçili evin `notification.created` olayında,
  - öndeyken seçili evin push'u geldiğinde,
  - panel açılınca,
  - aşağı çekerek yenilemede.
- **Okunmamış:** backend okundu bilgisi tutmadığı için istemci kullanıcı + ev başına cihazda son
  görülen `(createdAt, id)` değerini saklıyor. Rozet, ilk sayfada bundan yeni olan öğe sayısı.
- **Yanıt okuma hoşgörülü:** bozuk tek bir öğe atlanıyor, sayfa düşmüyor. Bilinmeyen `type` genel
  ikonla gösteriliyor. Gönderen artık üye değilse "Eski üye" yazıyor.
- **403/404:** panel kapanıyor; profil ve ev listesi mevcut akışla yenileniyor.

### 1.4. `POST chore/{id}/remind`

- **Gövde:** yok.
- **Düğme ne zaman görünüyor:** görev detayı açıldığı anda şu koşulların hepsi tutuyorsa (sizin kontrol
  sıranızla):
  - görev atanmış,
  - bana atanmamış,
  - durumu Draft (0) ya da Progress (1),
  - `dueDate − 12s ≤ şimdi < dueDate`.

  Zamanlayıcı yok; asıl karar sunucuda.

| Yanıt | İstemci |
|---|---|
| 2xx | "Hatırlatma gönderildi"; düğme "Hatırlatıldı" olur |
| 409 | Mesaj yok; düğme "Hatırlatıldı" olur |
| 400 / 403 / 404 | Sunucunun yerelleştirilmiş mesajı gösterilir; 404'te ev detayı yenilenir |
| 401 | Mevcut oturum reddi akışı |

"Hatırlatıldı" bilgisi yalnız bellekte tutuluyor (kullanıcı + görev), çıkışta temizleniyor. Yeniden
açılışta basılırsa 409 gelir ve aynı duruma geçilir.

### 1.5. `notification.created` olayı

Yalnız seçili ev için ilk sayfayı sessizce yeniliyor. Aynı anda gelen olaylar (ör. `house.changed`)
mevcut birleştirme penceresinde toplanıyor. Socket `ready` olunca ya da uygulama öne dönünce yapılan
tam yenileme bildirimleri de kapsıyor.

### 1.6. Push yükü

- **Kullanılan `data` anahtarları:** `notificationId`, `type`, `houseId`, `choreId` (yalnız String
  değerler). Diğer anahtarlar yok sayılıyor; `houseId` yoksa dokunma yok sayılıyor.
- **Dokunma yönlendirmesi:**
  1. Oturum ve ev listesi yüklenene kadar bekleniyor.
  2. Ev kullanıcının değilse hedef atılıyor.
  3. Oyun açıksa oyun kapanana kadar bekleniyor (oyun zorla kapatılmıyor).
  4. Gerekirse ev değiştiriliyor.
  5. `choreId` yüklü ev detayındaysa görev açılıyor; değilse yalnız ev açılıyor.

  Ev değişikliği başarısız olursa hedef atılıyor.
- **Android:**
  - Backend `channel_id` göndermiyor. İstemci `fauscrew_default` kanalını oluşturuyor ve manifest'te
    varsayılan kanal olarak tanımlıyor. Kanal adı uygulama diliyle değişiyor.
  - Monokrom ikon `ic_stat_fauscrew`.
  - Öndeyken bildirimi istemci gösteriyor (`tag = notificationId`).
  - Android 13+ için `POST_NOTIFICATIONS` izni, ana ekran ilk açıldığında bir kez soruluyor.
- **iOS:**
  - Öndeyken banner + liste + ses gösteriliyor.
  - `apns-collapse-id` sizden geliyor.
  - İzin, ana ekran ilk açıldığında soruluyor.
  - Firebase swizzling açık. APNs token'ı ayrıca açıkça veriliyor.

## 2. Sürümler

- **iOS:** FirebaseMessaging 12.19.3. 13.x Xcode 26.2 istiyor; geliştirme makinesi 26.0.1.
- **Android:** google-services plugin 4.6.0, Firebase BoM 35.2.0, firebase-messaging.
- **Bridge sürümü:** 21.

## 3. Teyit istenen noktalar

### 3.1. Kayıtlı olmayan token için DELETE (istemci varsayımı)

Uygulama bir hata ekranındayken (oturum geçici olarak "yok" görünürken) kullanıcı çıkış yaparsa
istemci, token o kullanıcıya hiç kaydedilmemiş olsa bile DELETE gönderiyor. Böylece backend'de eski bir
satır kalmıyor.

Beklentimiz:

- DELETE idempotent olmalı (kayıt yoksa 2xx ya da 404).
- Yalnız `(istekteki kullanıcı, token)` eşleşen satırı silmeli.

İstemci sonucu yalnız log'luyor, kullanıcıya hata göstermiyor. Sunucu farklı davranıyorsa somut farkı
yazın.

### 3.2. Plan §8'de açık kalan sorular

1. **Duyuruda iki olay gelir mi?** (`house.changed` + `notification.created`) İstemci ikisini aynı
   pencerede birleştiriyor; cevap ne olursa olsun çalışır. Bilgi amaçlı.
2. **Yeni bildirim tipleri.** `announcement` ve `chore_reminder` dışında plan var mı? Bilinmeyen tip
   genel ikonla gösteriliyor, dokununca yalnız ev açılıyor.
3. **iOS push yükünde `data` anahtarları.** FCM varsayılanıyla APNs `userInfo` içinde üst seviyede
   geldiği varsayılıyor. Farklı bir yapı kullanıyorsanız (ör. iç içe `data`) bildirin. Elle testte
   (P5) Console test mesajıyla doğrulanacak.

## 4. Yeni metin anahtarları (isteğe bağlı katalog eklemesi)

İstemci önce `localization/plaintext` kataloğuna bakıyor; anahtar yoksa aşağıdaki yerleşik metni
kullanıyor. İki platformda anahtar ve metinler aynı.

| Anahtar | tr | en |
|---|---|---|
| `notifications_title` | Bildirimler | Notifications |
| `notifications_empty` | Son 30 günde bildirim yok | No notifications in the last 30 days |
| `notifications_error_retry` | Bildirimler yüklenemedi. Tekrar dene | Couldn't load notifications. Try again |
| `notifications_open_accessibility_label` | Bildirimleri aç | Open notifications |
| `notifications_unread_badge_accessibility` | %d okunmamış | %d unread |
| `notifications_former_member` | Eski üye | Former member |
| `chore_detail_remind_action` | Hatırlat | Remind |
| `chore_detail_reminded` | Hatırlatıldı | Reminded |
| `chore_remind_sent` | Hatırlatma gönderildi | Reminder sent |
| `profile_notifications_status_on` | Açık | On |
| `profile_notifications_status_off` | Kapalı | Off |

- `notifications_unread_badge_accessibility` metnindeki `%d` (ya da `{count}`) sayıyla değiştiriliyor.
- `profile_notifications_label` katalogda zaten var.
- **Bilinçli sapma:** Android bildirim kanalının adı ("Genel bildirimler" / "General notifications")
  katalogdan gelmiyor. Kanal, katalog yüklenmeden uygulama açılırken oluşturulduğu için yalnız yerleşik
  tr/en metin kullanılıyor.

## 5. Değişen istemci dosyaları

Ayrıntılı liste faz raporlarında:

- [P1–P2](pushNotificationsP1P2Report.md): token, kayıt/silme ve platform altyapısı.
- [P3](pushNotificationsP3Report.md): panel, rozet, hatırlatma, dokunma yönlendirmesi.

Özet:

- **Ortak çekirdek (`FausCrew/shared/Sources/FausCrewCore`):**
  - `UseCases/NotificationWireContract.swift`
  - `Notifications/` altında: `NotificationModels`, `ChoreReminderRules`, `NotificationSeenState`,
    `PushRegistrationChannel`, `PushRouting`, `APIDate`
  - `Events/AppEventsChannel.swift`
- **Android köprüsü:** `NotificationBridge.swift`, `PushRegistrationBridge.swift`,
  `AppEventsBridge.swift`.
- **iOS:**
  - `Services/App/FausCrewAppDelegate.swift`, `Services/Push/*`, `Services/NotificationService.swift`
  - `ViewModels/Stores/NotificationStore.swift`, `ChoreReminderStore.swift`
  - `ViewModels/Navigation/PushRouteHandler.swift`
  - `Views/Dashboard/Notifications/*`
- **Android:**
  - `FausCrewApplication.kt`, `push/*`
  - `platform/NotificationRepository.kt`, `PushRegistration.kt`
  - `viewmodel/NotificationViewModel.kt`
  - `ui/dashboard/notifications/*`
  - manifest

## 6. İstemcide doğrulananlar

| Kontrol | Sonuç |
|---|---|
| Ortak çekirdek testleri | 470 test, 0 hata (1 atlanan) |
| Android köprü testleri | 69 test, 0 hata |
| Android `assembleDebug` + unit testler | 287 test, 0 hata |
| iOS derleme (`build-for-testing`) | Başarılı; iOS testleri simülatör olmadığı için yalnız derlendi |

**Henüz denenmeyenler:**

- gerçek cihazda token alma,
- Firebase Console test mesajı,
- izin pencereleri,
- ekranların görünümü,
- canlı backend ile uçtan uca akış.

Sıradaki adımlar P5 (elle test) ve P6 (backend canlıya çıkınca uçtan uca test). Canlı test sonuçları
bu rapora eklenecek.

## 7. Backend cevapları (21 Kasım 2026)

| # | Soru | Cevap | İstemciye etkisi |
|---|---|---|---|
| §3.1 | Kayıtlı olmayan token için DELETE | Yalnız (kullanıcı, token) eşleşen satır silinir. Eşleşme yoksa yine `200 {"success": true}` döner, 404 yok. Başka kullanıcının satırına dokunulmaz. Boş/eksik token → 400. 401'de DELETE göndermemek doğru: cihazdan silinen token, backend'in sonraki push denemesinde FCM "kayıtlı değil" deyince backend'den de silinir. | Yok. `deviceAccepted` 2xx + `success: true`'yu zaten başarı sayıyor; boş token zaten gönderilmiyor. |
| §3.2-1 | Duyuruda iki olay | Evet, sırasıyla `house.changed` (yazan dahil tüm üyeler), sonra `notification.created` (yazan hariç). Görev hatırlatmasında yalnız atanan kişiye `notification.created` gider, `house.changed` gitmez. | Yok. İkisi aynı birleştirme penceresinde toplanıyor; hatırlatmada tek olay da rozeti yeniliyor. |
| §3.2-2 | Yeni bildirim tipleri | Şimdilik yalnız `announcement` ve `chore_reminder`; yakın planda yok. Eklenirse `type`'ta yeni string olarak gelir, şekil değişmez; önceden haber verilecek. | Yok. Bilinmeyen tip genel ikonla gösteriliyor, dokununca ev açılıyor. |
| §3.2-3 | iOS'ta `data` anahtarları | FCM HTTP v1 `message.data` ile gönderiliyor; APNs `userInfo` üst seviyesinde, `aps` ile yan yana. Değerler her zaman String. `choreId` yalnız `chore_reminder`'da. FCM'in kendi anahtarları (`gcm.message_id`, `google.c.*`) da gelir. | Yok. `PushTarget(userInfo:)` yalnız dört anahtarın String değerlerini okuyor, diğerlerini yok sayıyor. P5'te Console test mesajıyla yine de görülecek. |
| §4 | Metin anahtarları | SuperAdmin hesabıyla `POST /api/v1/language` üzerinden kataloğa eklenecek. Backend kod ya da deploy işi değil. | Eklenene kadar yerleşik tr/en metinler kullanılıyor. Ekleme, SuperAdmin hesabıyla elle yapılacak. |
| Ek | Kayıtta dil | `POST /auth/signup` hesabın dilini `Accept-Language`'dan alıyor (tr/en, diğerleri en). Sonraki deploy'da canlıda. | Yok (K6, plan §8 cevap 5). İstemci başlığı zaten gönderiyor. |

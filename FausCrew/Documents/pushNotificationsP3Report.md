# Push bildirimleri — P3 faz raporu

Tarih: 21 Kasım 2026 · Plan: [pushNotificationsClientPlan.md](pushNotificationsClientPlan.md) ·
Önceki faz: [pushNotificationsP1P2Report.md](pushNotificationsP1P2Report.md)

P3 iki platformda tamamlandı: bildirim paneli ve okunmamış rozeti, görev detayındaki "Hatırlat"
düğmesi ve dokunulan push'un doğru eve ve göreve yönlendirilmesi. Hiçbir şey commit edilmedi.
Proje ve SDK ayarlarına dokunulmadı.

## 1. Ne yapıldı

### Core + bridge

- `Notifications/PushRouting.swift`: dokunulan push için sıradaki adım. Kurallar sırasıyla:
  1. Oturum yoksa ya da ev listesi yükleniyorsa → bekle.
  2. Ev kullanıcının değilse → hedefi at.
  3. Oyun açıksa → bekle (K4).
  4. Ev değişiyorsa → bekle.
  5. Seçili ev farklıysa → ev değiştir.
  6. Ana ekran görünmüyorsa → popup'ları kapat ve Ana sekmeye geç.
  7. Ev detayı yükleniyorsa → bekle.
  8. Görev yüklüyse → görevi aç; değilse → bitti.

  İki platform aynı kararı verir.
- Bridge: `notificationPushRoute`. Bridge sürümü 21.

### iOS

- `Services/NotificationService.swift`: bildirim listesi ve hatırlatma istekleri.
- `ViewModels/Stores/NotificationStore.swift`: panel ve rozet. Durum kullanıcı + ev başına tutulur.
  - "Son görülen" işareti panel açılınca kaydedilir.
  - Sayfalama `nextCursor` bitince durur.
  - Panel açıkken gelen sessiz yenileme listeyi ezmez; ilk sayfa başa birleştirilir.
  - 403/404 gelince panel kapanır ve profil yenilenir.
- `ViewModels/Stores/ChoreReminderStore.swift`: hatırlatma sonuçlarını işler ve "hatırlatıldı" kümesini
  tutar (oturum boyunca, çıkışta temizlenir).
  - Başarı: toast.
  - 409: sessizce "Hatırlatıldı".
  - 400/403/404: sunucunun mesajıyla hata toast'u. 404'te ev detayı da yenilenir.
- `ViewModels/Navigation/PushRouteHandler.swift`: dokunulan push'u adım adım ekranına götürür. Seçili
  sekme ve "oyun açık" bilgisi de burada tutulur; `MainTabView` ve `HouseDashboardView` doğrudan bunu
  gözler.
- `Views/Dashboard/Notifications/`: zil düğmesi (rozet 1–9, sonra "9+"), panel, satır ve
  iskelet/boş/hata durumları.
- `ChoreDetailPopup`: "Hatırlat" düğmesi. Yalnız kural tutarsa görünür.

### Android

- `platform/NotificationRepository.kt` (liste/hatırlatma), `NotificationRules.kt`, `NotificationStrings.kt`
  (tr/en yerleşik metinler).
- `viewmodel/NotificationViewModel.kt`: iOS'taki store'larla aynı kurallar.
- `push/PushRouter.kt` ve `push/PushSession.kt`: yönlendirme adımı ve "gerçek çıkış" kararı. Uzun
  arka plan sonrası oturum geri yüklenirken bekleyen dokunuş silinmez.
- `ui/dashboard/notifications/`: zil, panel, satırlar, göreli zaman.
- `ChoreDetailPopup.kt`: "Hatırlat" düğmesi.
  - Hata mesajı popup içindeki hata alanında gösterilir; Android'de popup ayrı bir pencere olduğu için
    dashboard toast'u popup'ın arkasında kalıyordu.
  - Başarıda düğmenin altında kısa bir "Hatırlatma gönderildi" notu çıkar. iOS'ta bu bir toast.

### Görünüm (cihazda görülmedi)

- **Zil:** megafonun solunda, onunla aynı 40pt daire.
- **Rozet:** turuncu vurgu renginde, 1–9 sonra "9+". 0'da gizli.
- **Panel:** görev detayı popup'ıyla aynı kabuk.
- **Satır:** gönderen avatarı ve adı (üye değilse "Eski üye"), tür ikonu, başlık, mesaj, göreli zaman.
  Okunmamışsa solda turuncu çizgi.
- **"Hatırlat" düğmesi:** bilgi kartlarının altında, 44pt, turuncu metin.

## 2. İnceleme ve düzeltmeler

Her platform ayrı bir reviewer'dan geçti. Düzeltilen hatalar:

- **iOS: açık popup'ta gelen push sonrası kilitlenme.** Popup açıkken başka bir evin push'una
  dokunulunca "popup açık" bayrağı takılı kalıyordu. Push hiç açılmıyor, sekme çubuğu gizli kalıyordu.
- **İki platform: başarısız ev değişikliği.** Hedef bekliyor ve dakikalar sonra kullanıcı o evi elle
  açınca birden görev açılıyordu. Artık hedef atılıyor. Android'de geçiş başlamadan gelen ilgisiz bir
  değişikliğin hedefi erkenden atması ya da ev değiştirmeyi iki kez istemesi de engellendi.
- **İki platform: panel açıkken gelen sessiz yenileme sayfalanmış listeyi ilk sayfaya düşürüyordu.**
- **iOS: iptal edilen yükleme hata sayılıyor, rozet 0'da kalabiliyordu.**
- **Android: uzun arka plan sonrası dokunulan push kayboluyordu.** Oturum geri yüklenirken kısa bir
  "oturum yok" anı çıkış sanılıyordu.
- **Android: hatırlatma toast'u popup'ın arkasında kalıyordu.**
- **Android: oturum kapanırken gelen yenileme ikinci bir çıkışı tetikleyebiliyordu.**
- **Android: okunmamış hesabı ana iş parçacığında yapılıyordu.**
- **iOS performansı:** sekme değişimi artık tüm uygulamayı yeniden çizdirmiyor.

Bilinçli olarak bırakılan: yönlendirme sırasında kullanıcı yeni bir popup açarsa zorla kapatılmaz; push,
popup kapanınca uygulanır (iki platform aynı).

## 3. Doğrulama

| Kontrol | Sonuç |
|---|---|
| Core `swift test` | Geçti: 470 test, 0 hata, 1 atlanan |
| Bridge `swift test` | Geçti: 69 test, 0 hata |
| Android `assembleDebug` + `testDebugUnitTest` | Geçti: 287 unit test, 0 hata |
| iOS `build-for-testing` | Derlendi, 0 hata |

**Çalıştırılamayanlar:**

- **iOS testleri:** 37 yeni test yalnız derlendi; bu makinede simülatör yok.
- **Android native kurallar:** `ChoreReminder.canRemind` ve `NativeNotificationRules` bridge'in native
  koduna gidiyor; JVM testleri bunları çalıştırmıyor.

**Bilinen test riski:**

- `ChoreCatalogViewModelTest > signOutDiscardsALateGetAndCancelsItsQueuedSave` ara sıra başarısız oluyor.
  P3 öncesi bir test ve P3 dokunmadı.
- `NotificationViewModelTest`'in bir kısmı gerçek bir iş parçacığı ve kısa beklemelerle çalışıyor.
  Yük altında yavaşlayabilir ve zamanlamaya bağlı hata riski taşıyor.

## 4. Elle test kontrol listesi (P3)

Hazırlık: iki hesap, aynı evde. A görev oluşturup B'ye atar, son tarihi 12 saatten yakın bir zamana koyar.

1. **Zil ve rozet:** B duyuru yazar → A'nın ana ekranında zilde rozet çıkıyor (uygulama açıkken
   socket ya da push ile). Panel açılınca rozet sıfırlanıyor, yeni öğelerin solunda turuncu çizgi var.
2. **Panel:** Aşağı çekerek yenileme çalışıyor. 20'den fazla bildirimde kaydırınca sonraki sayfa geliyor.
   Bildirim yoksa "Son 30 günde bildirim yok". İnternet kapalıyken hata kartı, dokununca tekrar deneniyor.
3. **Satır:** Evden ayrılmış birinin bildirimi "Eski üye" görünüyor. Hatırlatma satırına dokununca görev
   detayı açılıyor; duyuruya dokununca panel kapanıyor.
4. **Hatırlat:** A, B'ye atanmış görevi açınca "Hatırlat" görünüyor. Kendi görevinde, tamamlanmış görevde
   ya da son tarihe 12 saatten fazla varken görünmüyor. Basınca "Hatırlatma gönderildi" ve düğme
   "Hatırlatıldı" oluyor. Uygulamayı yeniden açıp tekrar basınca sessizce "Hatırlatıldı" oluyor.
5. **Push'a dokunma:**
   - Uygulama arkadayken hatırlatma push'una dokun → doğru ev ve görev açılıyor.
   - Uygulama kapalıyken (soğuk açılış) aynısı.
   - Başka bir evdeyken dokun → ev değişiyor, görev açılıyor.
   - Oyun açıkken dokun → oyun kapanmıyor; oyundan çıkınca görev açılıyor.
   - Panel ya da bir popup açıkken başka evin push'una dokun → ev değişiyor ve görev açılıyor.
   - Uygulamayı 15+ dakika arkada bırakıp push'a dokun (Android) → görev açılıyor.
6. **Öndeyken push:** Aynı evdeyken push gelince rozet artıyor; panel açıksa liste kaydırılmış konumunu
   koruyor.
7. **Çıkış:** Çıkış yapıp başka hesapla girince rozet ve "Hatırlatıldı" durumları sıfır.

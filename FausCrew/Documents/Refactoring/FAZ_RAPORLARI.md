# FausCrew Geliştirme Planı — Faz 0–4 Raporları

**Dal:** `refactore` · **Tarih:** 14–15 Kasım 2026 · **Plan:** [GELISTIRME_PLANI.md](GELISTIRME_PLANI.md)

Bu dosya beş faz raporunun birleştirilmiş halidir. Başlıklar bir seviye aşağı kaydırıldı.

## İçindekiler

- Faz 0 Raporu
- Faz 1 Raporu
- Faz 2 Raporu
- Faz 3 Raporu
- Faz 4 Raporu

---

## Faz 0 Raporu

**Tarih:** 14-15 Kasım 2026 · **Dal:** `dev` · **Plan:** `GELISTIRME_PLANI.md` (Bölüm 4 ve F1-1)

### Özet

Faz 0'daki 9 görev ve F1-1 uygulandı. Faz 0 görevleri yazan modelden farklı bir model tarafından incelendi. Ortak çekirdek testleri ve Android derlemesi ile unit testleri geçti. iOS testleri hiç çalıştırılmadı, çünkü makinede hazır bir simülatör cihazı yok. Hiçbir şey commit edilmedi: 30 dosya değişti (+270 / −223 satır) ve kök dizine yeni bir `.gitignore` eklendi.

### Ne değişti

| Görev | Değişiklik | Yazan | İnceleyen | Sonuç |
|---|---|---|---|---|
| F0-1 | Kök `.gitignore` eklendi; 3 kişisel Xcode dosyası takipten çıkarıldı (diskte duruyor) | Opus 5.5 | Sol 6.1 | Onay |
| F0-2 | Android yeni şifre alanı maskeli; gönderilen değer özgün şifre | Sol 6.1 | Opus 5.5 | Onay |
| F0-3 | iOS API oturumunda disk önbelleği kapatıldı | Opus 5.5 | Sol 6.1 | Onay |
| F0-4 | iOS çıkışta ad, soyad ve Apple'dan gelen bekleyen ad da siliniyor | Opus 5.5 | Sol 6.1 | Onay |
| F0-5 | iOS Keychain öğeleri yalnızca bu cihazda kalıyor; kayıt başarısız olursa eski token korunuyor | Opus 5.5 | Sol 6.1 | Silme kısmı geri alındı (bkz. aşağısı) |
| F0-6 | Android `mavenLocal()` yalnızca `org.swift.swiftkit` grubuyla sınırlandı ve listenin sonuna alındı | Sol 6.1 | Opus 5.5 | Onay |
| F0-7 | iOS oyun logları sunucu metnini yazmıyor; yalnızca hata kategorisi ve HTTP durum kodu | Opus 5.5 | Sol 6.1 | Onay |
| F0-8 | Sessizce atlanan 13 test gerçek hataya çevrildi | Sol 6.1 | Opus 5.5 | Onay |
| F0-9 | iOS'ta kullanılmayan kod silindi; `houseError` dokunulmadı | Opus 5.5 | Sol 6.1 | Onay |
| F1-1 | Backend adresi tek `baseURL` oldu; dev/prod ayrımı ve `api.houseflow.app` kaldırıldı | Sol 6.1 | Ayrı kayıt yok | iOS build geçti |

### Plandan sapmalar

- **F0-5:** Plan, uygulama silinip yeniden kurulunca Keychain'in temizlenmesini de istiyordu. Bu kısım uygulandı, ama Sol iki inceleme turunda da onaylamadı. Güncelleme ile yeni kurulum kesin ayırt edilemediği için mevcut kullanıcı çıkış yapmak zorunda kalabilirdi. Silme başarısız olursa da eski oturum geri gelebiliyordu. Yönetici bu kısmı tamamen geri çıkardı. Sonuç: yeniden kurulumda otomatik giriş bilinçli olarak sürüyor.
- **F0-8:** Planda 9 yer sayılmıştı. 13 yer bulundu.
- **F1-1:** İlk analizdeki "release build demo backend'e gidiyor" bulgusu yanlıştı. Proje sahibi `houseflowapi.fly.dev` adresinin tek backend ve production olduğunu bildirdi. Dev veya demo backend yok ve olmayacak.

### Doğrulama

| Platform | Çalıştı | Çalışmadı |
|---|---|---|
| Ortak çekirdek | `swift test`: 334 geçti, 0 kaldı, 1 atlandı (bilinçli fixture üretim testi). Sol ve Opus ayrı ayrı çalıştırdı, sonuç aynı. | Yok |
| Android | Kotlin derlemesi geçti, androidTest kaynakları derlendi, 159 unit test geçti, bağımlılık çözümlemesinde hata yok. | Yeni Compose testi (şifre maskesi) çalıştırılmadı; emülatör gerektiriyor. |
| iOS | Uygulama build'i geçti; test hedefi derlendi (`build-for-testing`). | Hiçbir iOS testi çalıştırılmadı. Hazır simülatör yok, yeni simülatör oluşturmak kullanıcı kuralına aykırı. Yeni iOS testleri (çıkış temizliği, Keychain geçişi, log kategorisi, sosyal çıkış) koşmadı. |

**Ortam notu:** Android Gradle, sistemdeki varsayılan JDK 25 ile açılmıyor. JDK 21 ve `ANDROID_HOME` ortam değişkeniyle çalıştırıldı; `local.properties` yok. Bu durum öncesinden vardı.

### Sizden beklenenler

1. iOS testlerini bir simülatörde çalıştırın.
2. Android'de şifre belirleme alanının maskeli olduğunu görün ve yeni Compose testini çalıştırın.
3. iOS'ta giriş yapılmış eski build'in üstüne bu build'i kurun; oturumun açık kaldığını görün.
4. iOS'ta çıkış yapın; tekrar girişte ad ve soyadın doğru geldiğini, Apple ile girişte adın gittiğini görün.
5. Dashboard'daki "bugünkü görevler" boş durumunun görsel olarak aynı kaldığını görün.
6. Değişiklikleri gözden geçirin ve commit kararını verin.
7. Karar: `houseError` ekranda gösterilsin mi, silinsin mi?
8. Karar: yeniden kurulumda otomatik girişe izin verilsin mi?

---

## Faz 1 Raporu

**Tarih:** 15-16 Kasım 2026 · **Dal:** `dev` · **Plan:** `GELISTIRME_PLANI.md` (Bölüm 5)

### Özet

F1-2'den F1-6'ya kadar olan beş görev uygulandı ve F1-8 kısmen yapıldı. F1-1 önceki turda tamamlanmıştı. F1-7 bu turda yapılmadı, çünkü plan önce sizin cihazda doğrulamanızı istiyor. Ortak çekirdek testleri (346 geçti) ve Android unit testleri (195 geçti) çalıştı. iOS testleri hiç çalıştırılmadı, çünkü makinede simülatör yok. Hiçbir şey commit edilmedi. Faz 0 ile birlikte toplam 67 dosya değişti (+2001 / −428 satır).

### Ne değişti

| Görev | Değişiklik | Platform | Durum |
|---|---|---|---|
| F1-1 | Backend adresi tek `baseURL` oldu. | iOS | Önceki turda tamamlandı |
| F1-2 | Açılışta geçersiz token artık giriş ekranına düşürüyor; token'lı istekte 401 tek noktadan çıkış yaptırıyor. Refresh token eklenmedi. | iOS, Android | Uygulandı |
| F1-3 | Profil yenileme, katalog ve oyun işleri hesap değişiminde iptal ediliyor. | Android | Uygulandı |
| F1-4 | Değişiklik sonuçları güncel veriye uygulanıyor; eski yenileme yanıtları sıra numarasıyla eleniyor. Katalogda GET ve PUT aynı kuyrukta. | Android | Uygulandı |
| F1-5 | Token okuma hatası çıkış yerine geçici bağlantı hatası sayılıyor. | Android | Uygulandı |
| F1-6 | Tanks ve Switch'te bozuk sunucu verisi çöküş yerine protokol hatası veriyor. | Ortak çekirdek | Uygulandı |
| F1-7 | Online maçta sekme çubuğu sorunu. | iOS | Yapılmadı, sizin doğrulamanız bekleniyor |
| F1-8 | Ortak HTTP katmanı ham sunucu metni yerine kısa, düz mesaj veriyor; iOS'ta `userMessage(for:)` eklendi. | Ortak çekirdek, iOS | Kısmi |

### Denetimde düzeltilenler

- Yönetici üç düzeltme yaptırdı:
  - iOS'ta yeni hata metinlerinin yedeği yalnızca İngilizceydi. Türkçe için tr/en yedek eklendi.
  - Tick sınırı 10 dakikalık maç için sıkıydı (Tanks 72.000, Switch 28.800). Sınır taşma güvenliği düzeyine gevşetildi; 3 saatlik oturum tick'ini kabul eden test eklendi.
  - Android'de değişiklik sırasında atılan yenileme telafi edilmiyordu. Tek takip yenilemesi eklendi.
- Opus denetçilerinin düzelttirdikleri:
  - Android testindeki `sun.misc.Unsafe` hilesi reddedildi; yerine küçük bir test dikişi açıldı.
  - İmzalı depolama adresinden gelen fotoğraf 401'i yanlışlıkla çıkış yaptırıyordu; bu yol kaldırıldı.
  - Her soğuk açılışta yapılan sosyal SDK çıkış çağrısı düzeltildi.
  - Ortak çekirdekteki keyfi "×100" sınırı reddedildi.

### Doğrulama

| Platform | Çalıştı | Çalışmadı |
|---|---|---|
| Ortak çekirdek | `swift test`: 346 geçti, 0 kaldı, 1 atlandı (bilinçli fixture testi). Başlangıç 334'tü. | Yok |
| Android | Kotlin ve androidTest derlemesi geçti; 195 unit test geçti (başlangıç 159); Swift köprüsü son çekirdekle iki mimari için derlendi. | Emülatör testleri çalıştırılmadı |
| iOS | Uygulama build'i ve test hedefi derlemesi geçti; yeni uyarı yok. | Hiçbir iOS testi çalıştırılmadı; makinede simülatör yok |

### Kalanlar ve riskler

- iOS'ta koşulması gereken testler: `AppSessionCoordinatorTests`, `NetworkServiceTests`, `LocalizationUserMessageTests`, `FausCrewCoordinatorTests`, `DashboardCoordinatorTests`.
- Altı yeni lokalizasyon anahtarı backend'de yok (`error_session_expired`, `error_network_unavailable`, `error_generic`, `error_email_verification_failed`, `error_invite_code_invalid`, `error_house_details_required`). Eklenene kadar kod içi yedek görünür.
- F1-8 kısmi. 19 `error.localizedDescription` çağrısı, login/signup hata metni ve servislerdeki sabit "Not authenticated." metni kaldı.
- Android'de genel hata metni `Request failed.` hâlâ sabit İngilizce.
- Android'de iki test sınıfı gerçek IO dispatcher ile çalışıyor. Kararlı, ama sanal zamanlı testlerden daha kırılgan.
- Tanks açı sınırı ±100.000 radyan. Sunucu davranışı bu repodan doğrulanamadığı için bu sınır kesin değil.

### Sizden beklenenler

1. iOS testlerini bir simülatörde çalıştırın.
2. İki platformda, süresi dolmuş token ile açılışta giriş ekranına düştüğünü görün. Oturum açıkken token geçersizleşince bir ekran işleminde çıkış yapıldığını görün.
3. Yanlış şifreyle girişte sunucu mesajının hâlâ göründüğünü, çevrimdışıyken bağlantı mesajının göründüğünü görün.
4. Android'de çıkış yapıp başka hesapla girince katalogun yeni hesabın listesini gösterdiğini görün. Görev veya duyuru eklerken yeni öğenin kaybolmadığını görün.
5. Online Tanks ve Switch maçını baştan sona oynayın. Snapshot reddi görülmemeli.
6. F1-7 için online maçta başka sekmeye dokunup maçtan çıkıp çıkmadığınıza bakın.
7. Altı lokalizasyon anahtarını backend'e ekleyin.
8. Değişiklikleri gözden geçirin ve commit kararını verin.

---

## Faz 2 Raporu

**Tarih:** 15 Kasım 2026 · **Dal:** `refactore` · **Plan:** `GELISTIRME_PLANI.md` (Bölüm 6)

### Özet

Faz 2'deki 14 performans görevinin hepsi uygulandı. Üç görevde plandan bilinçli olarak sapıldı: F2-2, F2-5 ve F2-10. Ortak çekirdek testleri ve Android unit testleri geçti; iOS uygulaması ve test hedefi derlendi. iOS testleri çalıştırılmadı, çünkü makinede simülatör yok. Hiçbir şey commit edilmedi. Faz 2'de 34 dosya değişti (+679 / −248 satır) ve 7 yeni test dosyası eklendi.

### Nasıl çalışıldı

- Kodu altı Sol 6.1 ajanı yazdı. Her ajanın dosya sahipliği ayrıydı, yani iki ajan aynı dosyaya dokunmadı.
- Her paketi bir Sonnet 5.5 ajanı inceledi. İnceleme ölçütleri: plana uygunluk, doğruluk, mimari, okunabilirlik, performans ve testler.
- Yönetici (Opus 5.5) görevleri paylaştırdı, brief'leri yazdı ve her diff'i satır satır okudu. Build ve testleri de yönetici çalıştırdı. Düzeltmeleri aynı Sol oturumuna geri gönderdi.

| Paket | Görevler | Yazan | İnceleyen | Tur | Sonuç |
|---|---|---|---|---|---|
| A | F2-1, F2-2 | Sol 6.1 | Sonnet 5.5 | 1 | Onay |
| B | F2-3, F2-4, F2-6 | Sol 6.1 | Sonnet 5.5 | 2 | Onay (2. tur) |
| C | F2-5 | Sol 6.1 | Sonnet 5.5 | 5 | Onay (yönetici ek turları dahil) |
| D | F2-7, F2-8, F2-11 | Sol 6.1 | Sonnet 5.5 | 1 | Onay |
| E | F2-9, F2-10 | Sol 6.1 | Yönetici | 2 | Onay (2. tur) |
| F | F2-12, F2-13, F2-14 | Sol 6.1 | Sonnet 5.5 | 1 | Onay |

### Ne değişti

| Görev | Değişiklik | Platform |
|---|---|---|
| F2-1 | `AppViewModel` artık toast ve overlay değişikliklerini yeniden yayınlamıyor. Toast'u yalnızca küçük bir `ToastOverlay` view'ı, overlay'i yalnızca `MainTabView` izliyor. `OverlayStore` aynı değeri tekrar yayınlamıyor. | iOS |
| F2-2 | Oyun ekranları yalnızca açılınca kuruluyor (`NavigationLink(value:)`). `HouseTanksView` gereksiz demo oturumu ve SpriteKit sahnesi yaratmıyor. | iOS |
| F2-3 | İnceleme fotoğrafının önizlemesi bir kez üretilip saklanıyor; artık her çizimde 2048 px JPEG çözülmüyor. İki popup `@EnvironmentObject` kullanıyor. | iOS |
| F2-4 | Önbellekteki görsel ilk karede görünüyor, yer tutucu yanıp sönmüyor. İndirme 5 MB ile sınırlı. Görseller kısa kenarı 282 px olacak şekilde küçültülüyor; küçük görseller büyütülmüyor. Çözme işi ana thread dışında. | iOS |
| F2-5 | Keychain değerleri bellekte tutuluyor ve değişmeyen değer yeniden yazılmıyor. JSON çözme ana thread dışında yapılıyor. | iOS |
| F2-6 | Duyuru kartında okunmuş listesi `.task(id:)` ile yükleniyor ve tarih her duyuru için bir kez ayrıştırılıyor. Görev listesi `LazyVStack` oldu. | iOS |
| F2-7 | Tek bir temel `OkHttpClient` var. API, soket ve görsel istemcileri ondan türüyor ve aynı bağlantı havuzunu paylaşıyor. | Android |
| F2-8 | API zaman aşımları: bağlantı 15 sn, okuma 30 sn, yazma 60 sn; toplam süre sınırı yok. 1 MB'ı aşan soket mesajı bağlantıyı kapatıyor ve tek bir hata bildiriyor. | Android |
| F2-9 | Oyun ekranları her karede yeniden oluşturulmuyor (`derivedStateOf`). | Android |
| F2-10 | Dashboard tek bir `LazyColumn` oldu. Görev satırları `chore.id` ile anahtarlı. | Android |
| F2-11 | İnceleme popup'ı yalnızca gösterilen turun fotoğrafını tutuyor. Görsel indirme coroutine iptaliyle birlikte duruyor. | Android |
| F2-12 | HouseRockets çarpışma geometrisi düzeltme başına bir kez hesaplanıyor. | Ortak çekirdek |
| F2-13 | HouseTanks tahmini yalnızca girdileri değişince yeniden hesaplanıyor. Önbellek anahtarı şunlar: snapshot kimliği, hedef tick, girdi sürümü. | Ortak çekirdek |
| F2-14 | Bot planlayıcısı tüketilmiş tick'lerin cevaplarını saklamıyor; bot başına en fazla bir cevap kalıyor. | Ortak çekirdek |

### Plandan sapmalar

- **F2-2:** Kökteki `NavigationStack` bırakıldı. Sekiz kök ekran navigasyon çubuğunu gizlemiyor; stack kaldırılırsa bu ekranların yerleşimi kayar. Oyunları kök stack'e taşımak sekme çubuğunu gizlerdi. Bu, F1-7'deki karar sizde olduğu için yapılmadı.
- **F2-5:** Decode'un ana thread'den çıkması için birkaç ek değişiklik gerekti:
  - Dört lokalizasyon DTO'su `nonisolated` yapıldı.
  - `NetworkService` jeneriklerine `Sendable` kısıtı eklendi.
  - Ortak çekirdekte `HouseAPIResponse`'a koşullu `Sendable` eklendi.
- **F2-10:** Görev satırları anahtarlı, ama tembel çizilmiyor. Kart tek bir `LazyColumn` öğesi. Satırları ayrı öğe yapmak kartın gradyan, kenarlık ve gölgesini parçalara bölmeyi gerektiriyordu. Sol'un ilk denemesi bunu karmaşık ve birebir aynı görünmeyen bir çözümle yaptı; yönetici reddetti.

### Denetimde düzeltilenler

- **Yöneticinin yakaladıkları:**
  - **F2-5:** İlk sürüm, değişmeyen değeri yazmadığı için F0-5'teki erişim sınıfı geçişini durduruyordu. Mevcut kullanıcıların e-posta ve ad kayıtları yedeklenebilir sınıfta kalacaktı. Artık bir değer, bu süreçte yazılmadıysa bir kez yazılıyor.
  - **F2-5:** Sol decode taşımasını "kapsam dışı" diye ertelemişti; gereken dosyalar açılınca tamamlandı.
  - **F2-5:** Keychain önbelleği iki sözlükten tek bir enum'a (`missing`, `loaded`, `written`) indirildi. Böylece sözlükler arasındaki gizli bağımlılık kalktı.
  - **F2-10:** Kartı satır satır elle çizen çözüm geri alındı.
- **Sonnet'in yakaladıkları (F2-4):**
  - Bayt bayt indirme yavaştı; `data(for:)` ile değiştirildi.
  - Küçültme uzun kenara göre yapıldığı için 16:9 ev görselleri bulanık çıkıyordu; artık kısa kenara göre yapılıyor.
  - URL değişince bir kare yer tutucu görünüyordu; düzeltildi.
  - Önizleme fotoğrafı fill yerine fit boyutlanıyordu; düzeltildi.

### Doğrulama

| Platform | Çalıştı | Çalışmadı |
|---|---|---|
| Ortak çekirdek | `swift test`: 350 test koştu, 349 geçti, 0 kaldı, 1 atlandı (bilinçli fixture testi). Test sayısı 345'ten 350'ye çıktı. Faz 1 raporundaki "346" sayımı bir fazlaydı. | Yok |
| Android | 205 unit test geçti (başlangıç 195). androidTest kaynakları derlendi. Swift köprüsü son çekirdekle derlendi. | Emülatör testleri, `DashboardScreenTest` dahil |
| iOS | `build-for-testing` geçti; uygulama dosyalarında yeni uyarı yok. | Hiçbir iOS testi çalıştırılmadı; makinede simülatör yok |

**Ortam notu:** Android build için şu üç ayar gerekiyor:
- `ANDROID_NDK_HOME` → `~/Library/Android/sdk/ndk/30.0.16248370`
- `SWIFT_ANDROID_SDK_BUNDLE` → `swift-6.4.0-RELEASE_android.artifactbundle`
- `PATH` başında Swift 6.4 araç zinciri

JDK 21 kuralı önceden olduğu gibi geçerli.

### Kalanlar ve riskler

- **Görev listesi sınırsız.** İki platformda da dashboard'a evin tüm görev geçmişi geliyor. `house/details` sayfalama ya da tarih filtresi uygulamıyor. Liste büyürse Android'de satırlar tembel çizilmediği için maliyet artar. Önerim: sunucu yalnızca güncel ve son N geçmiş görevi döndürsün, ya da istemci geçmişi sınırlasın. Bu bir ürün kararı.
- **Paylaşılan Android dispatcher.** API ve görsel istemcileri aynı dispatcher'ı kullanıyor. Avatarlar API ile aynı sunucudan geliyorsa, ana bilgisayar başına 5 eşzamanlı istek sınırını paylaşırlar. Görsellerin nereden sunulduğu doğrulanmadı.
- **Android büyük mesaj hatası.** Büyük soket mesajı Android'de `Transport` hatası olarak bildiriliyor, iOS'ta ise `messageTooLarge` olarak. Yeniden bağlanma davranışı aynı.
- **Plan dışı Rockets maliyeti.** `HouseRocketsOnlineFlightModels.swift:116` her adımda çarpışma geometrisini yeniden üretiyor. Planda olmadığı için dokunulmadı.
- **İnceleme fotoğrafının yeniden indirilmesi.** Android'de aynı tur yeniden açılınca fotoğraf yeniden indiriliyor; plan yalnızca gösterilen fotoğrafın tutulmasını istiyor. iOS'ta tur fotoğrafları popup açık kaldıkça hâlâ bellekte birikiyor; bu bir plan maddesi değildi.
- **Keychain testleri atlanabilir.** Keychain testleri, Keychain erişimi yoksa `XCTSkip` ile atlanıyor. Simülatörde gerçekten koştuklarını test çıktısında kontrol edin.
- **Geçici git referansı.** Faz 2 farkını ayırmak için `refs/faz2/base` referansı oluşturuldu. Hiçbir dala bağlı değil; incelemeden sonra `git update-ref -d refs/faz2/base` ile silinebilir.

### Sizden beklenenler

1. iOS testlerini bir simülatörde çalıştırın. Özellikle şunları: `AppViewModelObservationTests`, `KeychainServiceTests`, `RemoteImageDecodingTests`, `NetworkServiceTests`, `PlatformPortContractTests`, `AuthServiceTests`, `ChoreReviewPhotoTests`, `DashboardCoordinatorTests`.
2. iOS'ta cihazda kontrol edin:
   - Toast animasyonu ve sekme çubuğunun gizlenip görünmesi.
   - Yedi oyunda açılış, kapanış ve geri kaydırma.
   - Sekme değişince avatarlarda yanıp sönme olmaması.
   - Ev görselleri ve avatar seçicideki görsellerin netliği.
   - İnceleme fotoğrafı önizlemesi.
   - Duyuru rozeti, ilk açılışta ve ev değişiminden sonra.
3. Toast sırasında dashboard satırlarının yeniden çizilmediğini Instruments ile kontrol edin.
4. Android'de `DashboardScreenTest`'i emülatörde çalıştırın. Ayrıca kontrol edin:
   - Dashboard giriş animasyonları, kaydırma ve sekme çubuğu boşluğu.
   - Oyun ekranlarında Layout Inspector ile yeniden çizim sayısı.
   - İnceleme turları arasında hızlı geçiş.
   - Yavaş ağda fotoğraf yükleme.
5. Karar: Dashboard görev listesi sınırlanmalı mı (sunucu ya da istemci)?
6. Değişiklikleri gözden geçirin ve commit kararını verin.

---

## Faz 3 Raporu

**Tarih:** 15 Kasım 2026 · **Dal:** `refactore` · **Plan:** `GELISTIRME_PLANI.md` (Bölüm 7)

### Özet

Faz 3'teki 11 görevin hepsi uygulandı. Bu faz davranışı değiştirmeyen sadeleştirmeydi. Bilinçli istisnalar "Davranış ve görünüm değişiklikleri" bölümünde listeli. Ortak çekirdek, Swift köprüsü ve Android unit testleri geçti; iOS uygulaması ve test hedefi derlendi. iOS testleri çalıştırılmadı, çünkü makinede simülatör yok. Hiçbir şey commit edilmedi.

Faz 3'te 109 dosya değişti (+3988 / −2967 satır); 22 dosya yeni, biri silindi (`SocialText.swift`).

Büyük dosyalar şöyle küçüldü:

| Dosya | Önce | Sonra |
|---|---|---|
| `HouseInfoPopup.swift` | 1060 | 631 |
| `HouseTanksLobbyView.swift` | 1019 | 261 |
| `ChoreTemplateEditorView.swift` | 1113 | 823 |
| `ChoreDetailPopup.swift` | 1033 | 678 |
| `ProfileView.swift` | 496 | 389 |

### Nasıl çalışıldı

- Kodu iki Sonnet 5.5 yazar ajanı yazdı. Dosya sahiplikleri ayrıydı, yani iki ajan aynı dosyaya dokunmadı.
- Her paketi tek bir Sonnet 5.5 denetçi ajanı inceledi. İnceleme ölçütleri: davranış korunumu, plana uygunluk, mimari, okunabilirlik, performans ve testler.
- Yönetici (Opus 5.5) brief'leri yazdı. Brief'lerde koddan doğrulanmış mevcut durum, tuzaklar ve "bitti" ölçütü vardı.
- Yönetici kritik diff'leri kendisi okudu, denetçi bulgularını karara bağladı ve düzeltmeleri aynı ajana geri gönderdi. Son doğrulamayı da kendisi çalıştırdı.
- Sol 6.1 kullanılmadı.

| Paket | Görevler | Yazan | Tur | Sonuç |
|---|---|---|---|---|
| 1. dalga | F3-1, F3-2, F3-3 | Sonnet (Yazar 1) | 2 | Onay |
| 1. dalga | F3-4, F3-5, F3-6 | Sonnet (Yazar 2) | 2 | Onay |
| 2. dalga | F3-9, F3-10 (oyun dışı), önizleme altyapısı | Sonnet (Yazar 2) | 2 | Onay |
| 2. dalga | F3-7, F3-8, F3-10 (oyunlar), F3-11, görev detayı kabuğu | Sonnet (Yazar 1) | 2 | Onay |

### Ne değişti

| Görev | Değişiklik | Platform |
|---|---|---|
| F3-1 | İnceleme kuralları çekirdekte `ChoreReviewSummary` oldu: uygun inceleyici sayısı, turlar, oy sayıları, oranlar, `canReview`. 15 test eklendi. iOS doğrudan kullanıyor; inceleme arayüzü `ChoreReviewRoundList.swift`'e taşındı. Android popup açılışında tek köprü çağrısı yapıyor (`ChoreReview.of`); görev başına çağrı yok. İki platformda yerel kopya kalmadı. | Çekirdek, iOS, Android |
| F3-2 | Köprü artık ham gövdeyi değil, çekirdeğin çözdüğü normalize JSON'u döndürüyor (`HouseProjection.swift`). Kapsamı ev detayı ile görev ve duyuru yanıtları; `failureReason` ve `category` de çekirdekten geliyor. Kotlin'deki anahtar takma ad listeleri ve `ChoreFailureReason` mantığı silindi. İç içe yayıncı kimliği artık iki platformda aynı. Köprü sürümü 19. | Çekirdek, köprü, Android |
| F3-3 | Ev adı kuralı çekirdekte (`HouseCreationRules.limitedName`). Kurala göre ad en fazla 30 görünen karakter olabiliyor ve emoji ortadan bölünmüyor. Android kesme, sayaç ve geçerlilik için köprüyü kullanıyor. Kapsamı `CreateHousePopup`, `HouseInfoPopup` ve onboarding'deki `CreateHouseScreen`; sonuncusu planda yoktu. | Çekirdek, köprü, Android |
| F3-4 | Ortak popup kabuğu `FausPopupShell` eklendi. Dokuz popup kabuğa geçti: About, AvatarPicker, Language, Theme, EditProfile, JoinHouse, CreateHouse, HouseInfo, ChoreDetail. `ProfileView`'daki 10 ayrı durum tek bir `enum` oldu. | iOS |
| F3-5 | `HouseInfoDraft` saf yapısı eklendi (13 test). Ev tipi eşlemesi `HouseTypeCard`'dan geliyor. Sahip düzenleyicisi ve üye bölümü `Popups/HouseInfo/` altına ayrıldı. | iOS |
| F3-6 | HouseTanks lobisi Demo, Online ve ortak bileşenler olarak üç dosyaya bölündü. Şablon editöründeki "Ne zaman" bölümü `ChoreDueEditor.swift`'e taşındı. `FlowLayout` `Shared`'e taşındı. | iOS |
| F3-7 | Üç online oyun ortak yaşam döngüsü modifier'ını kullanıyor (`OnlineGameLifecycle.swift`). "Ayrıl, 3 sn sonra kapat" sırası `GameOnlineHost.leaveGracefully()` içinde; işlem sırası aynen korundu. F1-7 birleştirilmedi. | iOS |
| F3-8 | Dashboard'daki örnek kullanıcılar ve görevler silindi. Ev detayı yokken liste boş görünüyor. Test eklendi. | iOS |
| F3-9 | Hazır metin için tek giriş noktası var: `localized(_:tr:en:)`. `social()` silindi. Oyun sözlükleri dili `APILanguage`'dan alıyor. Dil kuralı çekirdekte iki platform için aynı: `tr` ise Türkçe, değilse İngilizce. | iOS, çekirdek, Android |
| F3-10 | Üye listeleri değer tabanlı oldu. Toast kapatma görevleri saklanıp iptal ediliyor. İptal edilen `Task.sleep` sonrası durum değişmiyor. Önizlemeler gerçek ağ ve Keychain yerine `AppViewModel.preview` kullanıyor; bu altyapı DEBUG dışında derlenmiyor. `MidnightCleanupView.swift` dosyasının adı `VaultRushView.swift` oldu. | iOS |
| F3-11 | HouseTanks demo botları fizik tick'ine bağlandı. Aynı seed 30, 60 ve 120 FPS'te ve düzensiz karelerde aynı sonucu veriyor; bunu bir test doğruluyor. Dünya yalnızca botların karar verdiği tick'te kopyalanıyor. | Çekirdek |

Ek olarak uygulamadaki `ChoreResponse.houseChoreDTO`, çekirdekteki aynı dönüşümün kopyasıydı; silindi.

### Davranış ve görünüm değişiklikleri

Bunlar bilinçli kararlar; cihazda kontrol edilmeli.

- **Popup başlıkları tek tipe çekildi:**
  - Başlık rengi temaya bağlı `onHero` oldu. Bir temada beyaz yerine krem tonu.
  - Watermark her popup'ta 56pt.
  - Kapatma düğmesi 44pt dokunma alanı içinde 28pt daire.
  - Alt başlık 12pt ve tek satır; uzun başlık da tek satıra kesiliyor.
  - Başlık yüksekliği 64pt. Edit'te önceden 60pt'ydi.
  - Tüm kabuk popup'larında VoiceOver odağı açılışta başlığa gidiyor.
  - Join, HouseInfo, Edit ve Create başlıkları artık sistem yazı boyutuyla büyümüyor.
- **Görev detayı başlığı:**
  - Seviye rengi kayboldu. Eski beyaz hap ve seviye renkli yazı yerine seviye adı alt başlıkta, ikonu rozette duruyor.
  - Uzun görev adı artık ortadan değil sondan kısalıyor.
- **Dil:** Bilinmeyen bir uygulama dilinde (ör. Almanca) oyun metinleri ve büyük harf kuralı artık iki platformda da İngilizce. Önceden Türkçeydi.
  - Dil henüz seçilmemişken oyun metni iOS'ta cihaz diline göre seçiliyor; önceden her zaman Türkçeydi.
- **Dashboard:** Evi olmayan kullanıcıda örnek veri yerine boş liste görünüyor.
- **İnceleme oranları:** Oranlar 1 ile sınırlandı. Bu yalnızca oy sayısı inceleyici sayısını aşarsa fark eder.
  - iOS'ta API kimliği olmayan üye uygun inceleyici sayılmıyor. Dashboard üyelerinin hepsinde kimlik olduğu doğrulandı.

### Denetimde düzeltilenler

- **Denetçinin yakaladıkları:**
  - `CreateHousePopup` kabuk dışında kalmıştı; kabuk watermark'ı view olarak alacak şekilde genişletildi ve popup geçirildi.
  - `PhoneManagementPopup` başlığı temaya bağlandı ve kapatma etiketi eklendi.
  - Android yazı alanlarında her yeniden çizimde köprü çağrısı vardı; artık yalnızca girdi değişince çağrılıyor.
  - Çekirdekte ev detayı iki kez çözülüyordu; tek yola indirildi.
  - FausSwitch başlıklarında büyük harf kuralı metnin diliyle çelişiyordu; düzeltildi.
  - Bot döngüsünde her tick'te bütün dünya kopyalanıyordu; kaldırıldı.
  - Android büyük harf kuralı iOS'la eşitlendi.
  - Testler sıkılaştırıldı:
    - `HouseInfoDraft` uç durumları.
    - Kopya metne bağlı lokalizasyon testleri.
    - Botların gerçekten karar verdiğini ve turun bittiğini doğrulayan FPS testi.
- **Yöneticinin kararları:**
  - Android'de inceleme özeti beklenmedik yanıtta uygulamayı çökertmek yerine boş gösteriliyor.
  - Platformlar arası dil farkı çekirdekte kapatıldı. Yazar 2 bunu fark etmişti, yönetici yazar 1'e verdi.
  - Görev detayı popup'ı, 1. dalgada başka ajanın düzenlediği için kabuğa 2. dalgada geçirildi.
  - Oyunlardaki `copy()` yardımcıları bilinçli olarak bırakıldı. Bunlar iki satırlık özel yönlendiriciler.

### Doğrulama

| Platform | Çalıştı | Çalışmadı |
|---|---|---|
| Ortak çekirdek | `swift test`: 372 test koştu, 0 kaldı, 1 atlandı (önceden de atlanan bilinçli fixture testi). Faz 2 sonunda 350'ydi. | Yok |
| Swift köprüsü | `swift test` (macOS): 53 test, 0 hata (başlangıç 44). | Yok |
| Android | 208 unit test geçti, 0 hata (başlangıç 205). Swift köprüsü Android için çapraz derlendi; androidTest kaynakları derlendi. | Emülatör testleri (`BridgeRoundtripTest` dahil) |
| iOS | `build-for-testing` geçti (uygulama + `FausCrewTests`); uygulama dosyalarında hata ya da yeni uyarı yok. | Hiçbir iOS testi çalıştırılmadı; makinede simülatör yok |

### Kalanlar ve riskler

- **Android JVM testleri ve köprü:** Android'de `HouseCreationRules` köprüyü doğrudan çağırıyor; `InviteCodeBridge` emsali var.
  - İleride `HouseViewModel.createFromProfile` için yazılacak bir JVM testi native kütüphane yüklenemediği için hata verir.
  - Ad kuralları şu anda çekirdek, köprü ve androidTest ile kapsanıyor.
- **Eski betik:** `android/scripts/check-android-bindings.sh` zaten eskimişti (82 metot bekliyor, köprüde 90 var). Hiçbir şey onu çalıştırmıyor; F4-4'te ele alınabilir.
- **Ayrı bırakılan popup'lar:**
  - `PhoneManagementPopup` kendi başlığını koruyor: başlık yüksekliği, fontu ve altbilgisi farklı.
  - Yalnızca arka plan karartması olan popup'lar (NewAnnouncement, ChoreCatalog, Logout, InviteCode, Summary) kabuğa uymuyor.
- **VaultRush listeleri:** İki üye listesi birleştirilmedi. Biri hazır olma düğmesi, diğeri düzenlenebilir satır; birleştirmek sadeleştirmezdi.
- **Silinebilir lokalizasyon anahtarları:** Backend'den kaldırılabilecek `demo_*` anahtarları:
  - `demo_user_{mahmut,jane,abdullatif,katya}_{first,last}_name`
  - `demo_chore_{take_trash,kitchen_counter,vacuum_living_room,clean_bathroom,laundry}_{title,description}`
- **LuckySpin varsayılan adları:** Dört varsayılan ad tekillik kontrolünden geçmiyor. Adlar farklı olduğu için pratikte sorun yok; sunucu bunları aynı adlara çevirirse liste kimlikleri çakışır.
- **Geçici git referansı:** Faz 3 farkını ayırmak için `refs/faz3/base` oluşturuldu. Hiçbir dala bağlı değil; incelemeden sonra `git update-ref -d refs/faz3/base` ile silinebilir.

### Sizden beklenenler

1. iOS testlerini bir simülatörde çalıştırın. Öncelik sırası:
   - `HouseInfoDraftTests`
   - `LocalizationValueTests`
   - `DashboardCoordinatorTests`
   - Oyun testleri: `HouseTanksTests`, `FausSwitchTests`, `HouseRockets*Tests`, `GameReleaseOneContractTests`
   - `ChoreReviewPhotoTests`
2. Popup'ları dört temada kontrol edin (özellikle krem `onHero` olan tema):
   - Başlık, watermark, kapatma düğmesi ve Edit rozeti.
   - En büyük erişilebilirlik yazı boyutu.
   - Uzun Türkçe alt başlıklar.
3. Profil overlay'lerini kontrol edin:
   - Her popup'ın açılıp kapanması ve animasyonu.
   - Edit, Join, Create, Phone ve HouseInfo kapanırken klavyenin inmesi.
   - VoiceOver'ın House Information kartına dönmesi.
4. HouseInfo'yu kontrol edin:
   - Sahip düzenlemesi: 30 karakter sınırı ve yalnızca değişiklikte aktif olan Kaydet.
   - Üye çıkarma ve evden ayrılma.
5. Görev detayını kontrol edin:
   - Yeni başlık (seviye rengi yok) ve uzun görev adı.
   - İnceleme turları.
   - Android'de de aynı popup.
6. HouseTanks lobisini kontrol edin:
   - Demo kurulumu ve başlat düğmesi yönlendirmesi.
   - Online oda, geri sayım ve araç çubuğu sayacı.
7. Şablon editöründe "Ne zaman?" bölümünü ve tekrar çiplerini kontrol edin.
8. Online oyunlarda şunları deneyin:
   - Çıkış ve oturum kapatma.
   - Yön kilidi.
   - Odadan ayrılınca koltuğun boşalması.
9. HouseTanks demosunda zor seviye botların hissini kontrol edin.
10. Dashboard'u evi olmayan bir hesapla açın.
11. Android'de şunları kontrol edin:
    - Emoji içeren ev adı oluşturma.
    - Duyuru yayıncı adları.
    - Emülatörde `BridgeRoundtripTest`.
12. Değişiklikleri gözden geçirin ve commit kararını verin.

---

## Faz 4 Raporu

**Tarih:** 15 Kasım 2026 · **Dal:** `refactore` · **Plan:** `GELISTIRME_PLANI.md` (Bölüm 8)

### Özet

Faz 4'teki 5 görev uygulandı. F4-4'ün bir maddesi ertelendi: minify edilmiş release üzerinde JNI testi. Faz 4 test ve CI fazıydı; uygulamanın davranışı değişmedi. Uygulama koduna yalnızca test için iki varsayılanlı seam eklendi.

Ortak çekirdek, Swift köprüsü ve Android unit testleri geçti. iOS uygulaması ve test hedefi derlendi. Yeni iOS testleri çalıştırılmadı, çünkü makinede simülatör yok. CI işleri GitHub'da henüz hiç çalışmadı. Hiçbir şey commit edilmedi.

16 dosya değişti (+776 / −23 satır). 5 dosya yeni:
- `fauscrew-ios.yml`
- `SHA256SUMS`
- iki iOS test dosyası (`HouseSessionStoreTests`, `LocalizationStoreLanguageSelectionTests`)

### Nasıl çalışıldı

- Kodu iki Sonnet 5.5 yazar ajanı yazdı. Dosya sahiplikleri ayrıydı:
  - **Yazar A:** CI, Android betikleri ve belgeler.
  - **Yazar B:** iOS testleri ve iki seam.
- Bir Sonnet 5.5 denetçi her paketi inceledi. iOS testleri burada çalıştırılamadığı için denetçi her testi üretim koduna ve sahte servislere karşı satır satır izledi. Her test için "geçer / riskli / kalır" kararı verdi; 34 testin hepsi "geçer" çıktı.
- Yönetici (Opus 5.5) brief'leri yazdı, diff'leri okudu ve düzeltmeleri aynı yazara geri gönderdi. Son doğrulamayı da kendisi çalıştırdı.

| Paket | Görevler | Yazan | Tur | Sonuç |
|---|---|---|---|---|
| CI, Android, belgeler | F4-1, F4-2, F4-4, F4-5 | Sonnet (Yazar A) | 2 | Onay |
| iOS testleri | F4-3 | Sonnet (Yazar B) | 2 | Onay |

### Ne değişti

| Görev | Değişiklik |
|---|---|
| F4-1 | Yeni `.github/workflows/fauscrew-ios.yml`. Tetikleyiciler:<br>- iOS yollarına dokunan PR (`FausCrew/**`, Android hariç; `shared/**` dahil)<br>- elle tetikleme (`workflow_dispatch`)<br>İş `macos-26` üzerinde Xcode 26.5'i seçer ve paketleri çözer. Uygun bir iPhone simülatörünü dinamik bulur (cihaz adı sabit değil). Sonra imzasız `xcodebuild test` çalıştırır. İzinler `contents: read`, süre sınırı 45 dk. Eski çalışmalar iptal edilir. Projede CI'da eksik kalacak git-ignore'lu bir dosya referansı yok. |
| F4-2 | `FausCrew/shared/Fixtures/SHA256SUMS`: dört fixture'ın tek hash listesi. Bunlar HouseTanks'in üç fixture'ı ve FausSwitch simülasyonu; sonuncusunda aynı açık vardı. Linux CI `swift test`'ten önce `sha256sum --check` çalıştırıyor. İki test dosyasındaki yorumlar bu dosyayı gösteriyor: hash değişirse ikisi birlikte güncellenmeli. |
| F4-3 | 34 yeni iOS testi (ayrıntı aşağıda). |
| F4-4 | **Gradle:** `compileSwift*` görevleri artık `shared/Package.swift`'i, Swift SDK kimliğini ve `swift --version` çıktısını girdi sayıyor. Manifest ya da toolchain değişince native çıktı yeniden üretiliyor.<br>**`check-android-package.sh`:** İsteğe bağlı ikinci argüman ABI listesi oldu (varsayılan `arm64-v8a x86_64`). `.so` sayımı yalnızca kontrol edilen ABI'leri kapsıyor.<br>**`check-android-bindings.sh`:** Kırıktı (82 metot ve sürüm 16 bekliyordu). Sürüm 19 / 88 metoda güncellendi; 14 yeni sembol kontrolü eklendi. CI bu betiği çalıştırdığı için Android işi de kırılacaktı.<br>**Emülatör smoke:** Elle tetiklenen test API 31'den minSdk olan API 30'a alındı. |
| F4-5 | Geçiş planında Faz 10 ve Faz 11 durum satırları `Games/README.md` ile eşitlendi. README'deki köprü satırı güncellendi (16/82 → 19/88). |

#### F4-3 testleri

| Dosya | Test | Kapsam |
|---|---|---|
| `AppSessionCoordinatorTests` | 9 yeni | Uygulama olayıyla yenilemenin bütün yolları:<br>- oturum yok<br>- bekleme süresini aşan zorunlu yenileme<br>- başka ev<br>- profil yenileme ve hatası<br>- yeni akışın eskisini geçersiz kılması<br>Evden çıkarılınca:<br>- başka eve geçiş<br>- son evden sonra ev seçimi<br>- yükleme hatasında hata ekranı ve toast |
| `HouseSessionStoreTests` (yeni) | 10 | 30 sn önbellek sınırı (29 sn önbellekten, 30 sn yeniden çekim), `forceRefresh`, başka ev, istek iptali. Aynı ev için eşzamanlı iki çağrının tek isteği paylaşması, hatada bekleyen isteğin temizlenmesi. Üye çıkarma sonrası durum, duyuru ekleme/değiştirme. |
| `LocalizationStoreLanguageSelectionTests` (yeni) | 8 | Profilde seçili dilin korunması. Cihaz dilinin (`tr-TR` → `tr`) seçilmesi. Cihaz dili sunulmuyorsa varsayılana, o da yoksa ilk aktif dile dönüş. Aktif olmayan dilin yok sayılması. Aktif dil yoksa seçim yapılmaması. `APILanguage`'ın uyumu. |
| `DashboardCoordinatorTests` | 7 yeni | Duyuru, görev oluşturma ve görev inceleme (onay, geri gönderme). Her biri için başarı ve hata yolları: store güncellemesi, toast metni, servise giden istek. |

Seam'ler:
- `HouseSessionStore(now:)`, varsayılanı `Date.init`.
- `LocalizationStore(deviceLanguages:)`, varsayılanı `Locale.preferredLanguages`.

Üretimdeki davranış aynı; başka uygulama dosyası değişmedi.

### Denetimde düzeltilenler

- **Göç planı:** Durum satırında iç içe ters tırnak markdown'ı bozuyordu; düzeltildi.
- **`check-android-package.sh`:** `.so` sayımı tek ABI kontrolünde bile her iki ABI'yi sayıyordu; düzeltildi.
- **Fixture hash yorumları:** Test dosyalarındaki yorumlar yeni `SHA256SUMS` dosyasını göstermiyordu; eklendi.
- **Eşzamanlı istek testi:** MainActor sırasına dayanıyor. Pay için ikinci bir `Task.yield()` eklendi ve varsayım yorumda açıklandı.

### Doğrulama

| Platform | Çalıştı | Çalışmadı |
|---|---|---|
| Ortak çekirdek | `swift test`: 372 test, 0 hata, 1 atlandı (bilinçli). | Yok |
| Swift köprüsü | `swift test`: 53 test, 0 hata. | Yok |
| Android | 208 unit test, 0 hata. androidTest kaynakları derlendi. `check-android-bindings.sh` geçti (sürüm 19). `check-android-package.sh` debug APK'ya karşı iki ABI ile 44, yalnızca arm64 ile 22 `.so` saydı. | Emülatör testleri |
| CI | İki workflow YAML olarak geçerli. `shasum -c SHA256SUMS` dört fixture için OK verdi; bir baytı değiştirilmiş kopya reddedildi. | Hiçbir CI işi GitHub'da çalışmadı |
| iOS | `build-for-testing` geçti (`TEST BUILD SUCCEEDED`). Test dosyalarında uyarı yok. | 34 yeni test dahil hiçbir iOS testi çalıştırılmadı |

### Kalanlar ve riskler

- **iOS CI:** `macos-26` etiketi ve `/Applications/Xcode_26.5.app` yolu, GitHub runner imajı belgelerine göre seçildi. İlk çalışmada doğrulanmalı. Xcode 26.5 yoksa yalnızca bu satır değişir.
- **Minify edilmiş release JNI testleri ertelendi:** Release build için test imzası ve R8 keep kuralları gerekiyor. Bu, geçiş planındaki Faz 12 kapsamında.
- **Emülatör smoke:** API 30 `google_apis` x86_64 imajı GitHub'da elle tetiklenince çalışacak; burada denenmedi.
- **Eşzamanlı istek testi:** Swift'in garanti etmediği ama pratikte tutarlı olan FIFO MainActor sırasına dayanıyor. Kırılırsa test hata vermez, zaman aşımına uğrayarak takılır.
- **Geçici git referansları:** `refs/faz3/base` ve `refs/faz4/base` faz farklarını ayırmak için oluşturuldu. İncelemeden sonra silinebilir:
  ```
  git update-ref -d refs/faz3/base
  git update-ref -d refs/faz4/base
  ```

### Sizden beklenenler

1. iOS testlerini bir simülatörde çalıştırın. Önce Faz 4'ün yeni testleri:
   - `HouseSessionStoreTests`
   - `LocalizationStoreLanguageSelectionTests`
   - `AppSessionCoordinatorTests`
   - `DashboardCoordinatorTests`

   Ardından tüm test hedefi; Faz 3 raporundaki liste de hâlâ açık.
2. Değişiklikleri bir PR'a koyduğunuzda iki şeyi kontrol edin:
   - "FausCrew iOS" işinin başlayıp geçtiği.
   - "FausCrew Android bridge" işinde fixture ve bindings adımlarının geçtiği.
3. İsterseniz Android workflow'unu elle tetikleyip API 30 emülatör smoke testini çalıştırın.
4. Değişiklikleri gözden geçirin ve commit kararını verin.

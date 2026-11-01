# FausCrew yeniden adlandırma raporu

Tarih: 22 Ekim 2026. Dal: `rename/fauscrew`; taban: `dev` (`da8e2bc`).

## Uygulanan kapsam

- iOS bundle ID: `Iworf.FausCrew`; test bundle ID: `Iworf.FausCrewTests`.
- Android applicationId/namespace: `com.fauscrew`; bridge namespace: `com.fauscrew.androidbridge`.
- Xcode proje, target, scheme, ürün ve kaynak kökü: `FausCrew`; test kökü: `FausCrewTests`.
- Ortak paket/ürün: `FausCrewShared` / `FausCrewCore`; bridge: `FausCrewAndroidBridge`.
- Kotlin kaynak, test ve cihaz testi paketleri, tip/dosya adları, Swift importları, CI, dokümanlar, log adları ve cihaz depolama anahtarları güncellendi.
- İki iOS yapılandırmasına display name eklendi; Android etiketi `app_name` kaynağına taşındı.
- Snap scheme ve dönüş adresi `fauscrew://snap-kit/oauth2` oldu.
- Şifreli Android oturum deposuyla backup dışlama kurallarının adları eşleştirildi.
- Test fixture sembolik bağlantısı yeni kaynak köküne düzeltildi; takip edilen yedi sembolik bağlantı doğrulandı.
- Taşımalar `git mv` ile yapıldı. Projeye ait Android/shared build çıktı klasörleri taşımadan önce temizlendi. iOS doğrulaması eski DerivedData yerine temiz `/tmp/FausCrewDerivedData` ile yapıldı.

## Doğrulama sonuçları

| Kontrol | Sonuç |
|---|---|
| `plutil -lint`: pbxproj, plist ve entitlement | Geçti |
| Takip edilen XML dosyalarının parse kontrolü | Geçti |
| `swift test --package-path FausCrew/shared` | 111 XCTest + 2 Swift Testing = 113 başarılı |
| `swift test --package-path FausCrew/android/swift-bridge` | 15 başarılı |
| JNI bindings kontrolü | 44 public yöntem, sürüm 10 sözleşmesi geçti |
| iOS simülatör `build test` | 168 test başarılı |
| Android `:app:assembleDebug :app:testDebugUnitTest` | 54 test başarılı, APK üretildi |
| `aapt dump badging` | `com.fauscrew`, `FausCrew`, arm64-v8a + x86_64 |
| APK native paket kontrolü | İki ABI için gerekli kütüphaneler mevcut, toplam 44 .so |
| `git diff HEAD --check` | Geçti |

Toplam 350 test başarılı, sıfır başarısızlık. Kaynak test tanımı sayısı önce/sonra 383/383: shared 113, bridge 15, iOS 168, Android unit 54, Android cihaz testi 33. Karşılaştırma eski ve yeni kaynak tanımları üzerinden yapıldı; eski dal ayrıca derlenmedi.

Android cihaz testleri çalıştırılamadı: ADB bağlı cihaz listesi boş, kurulu AVD bulunmuyor. Bu 33 testin kaynakları korunup paket adları güncellendi; çalıştıkları doğrulanmadı. Yayın imzası ve gerçek OAuth login/signup doğrulaması, aşağıdaki harici yapılandırmalardan sonra yapılmalı.

iOS simülatöründe ana ekran etiketi, açılış/onboarding ve giriş ekranı görsel olarak doğrulandı. Giriş ekranı kontrolünde yalnızca çalıştırma argümanı olarak `-hasSeenOnboarding YES` kullanıldı. Eski geliştirme kurulumu ve yeni kimlikli uygulama simülatörde yan yana bulunabilir.

Yerel kanıtlar: `/tmp/fauscrew-home.png`, `/tmp/fauscrew-screen.png`, `/tmp/fauscrew-auth.png`; test günlükleri `/tmp/fauscrew-{shared,bridge,ios,android}-test.log`. iOS test sonucu `/tmp/FausCrewDerivedData/Logs/Test/` altında. APK: `FausCrew/android/app/build/outputs/apk/debug/app-debug.apk`.

İlk Android denemesi varsayılan JDK 25 ile başarısız oldu; projenin Android CI aşamasındaki JDK 21 ile yeniden çalıştırılıp geçti. İlk iOS test derlemesinde eski fixture bağlantısı bulundu, düzeltildi ve tam build/test tekrar geçti. Derleyici deprecation/concurrency uyarıları bulundu; bu yeniden adlandırma davranış değişikliğiyle genişletilmedi.

## Korunan içerikler

Kullanıcının staged prompt dosyası ve Xcode binary kullanıcı durumu değiştirilmedi; içerikleri başlangıç SHA-256 değerleriyle eşleşiyor. Xcode durum dosyasının index içeriği de önceki haliyle korunuyor. Kullanıcıya ait değişiklik yeni proje yolunda hâlâ unstaged olarak mevcut. Binary kullanıcı durumu eski proje adını içerebilir; bilinçli olarak yeniden yazılmadı.

İki `Package.resolved` dosyası birebir korundu; harici bağımlılık sürümleri değişmedi. Google istemci ID'leri, Google dönüş scheme'i, Facebook/Snap harici değerleri ve placeholder'ları korundu. Ev/hane ve oyun domain isimleri korundu.

Prompt hariç başlangıç metin taraması 1995 satırdı. Uygulama ve mevcut dokümanlarda 20 satır kaldı; hepsi korunması istenen API adresi veya yerel repo kök yolu. Yeni rapor bu istisnaları ayrıca listeler. Takip edilen dosya yollarında eski ürün adı kalmadı. Prompt dosyası kapsam dışı tutuldu.

## Manuel / harici takip işleri

1. Apple Developer: `Iworf.FausCrew` App ID oluştur, Sign in with Apple yeteneğini aç ve provisioning profillerini yeni kimlikle yenile. Mevcut Debug Apple giriş bayrağı kapalı, Release açık; gerçek cihaz doğrulaması yapılırken capability ve yapılandırma birlikte kontrol edilmeli.
2. App Store Connect: FausCrew uygulama kaydını yeni bundle ID ile oluştur; mağaza adının kullanılabilirliğini panelde doğrula.
3. Google Play Console: FausCrew kaydını, `com.fauscrew` paketini ve upload/app signing yapılandırmasını hazırla.
4. Google Cloud OAuth: `Iworf.FausCrew` için iOS istemcisini oluştur/yapılandır; yeni `GIDClientID` ve ters istemci ID scheme'ini iki plist'e uygula. `com.fauscrew` ve debug/release/Play imza SHA-1 değerlerini Android istemcilerinde kaydet. Android `google_web_client_id` ile backend audience eşleşmesini doğrula. Eski değerler korunduğundan yeni kimlikle Google girişinin hazır olduğu varsayılmamalı.
5. Facebook/Snap Kit: bundle ID, paket adı ve Snap `fauscrew://snap-kit/oauth2` dönüş adresini panellerde güncelle. Placeholder değerler gerçek panel değerleriyle ayrıca tamamlanmalı.
6. Backend: Apple/Google token audience doğrulamalarını yeni kimlik ve istemci değerleriyle eşleştir. Uzaktan gelen `app_name` ve marka içeren çevirileri FausCrew yap; çeviri önbelleğinin yenilenmesini mevcut kurulumlarda doğrula. `https://houseflowapi.fly.dev/api/v1` ve `https://api.houseflow.app/api/v1` adresleri korundu; alan adı taşıması ayrı iş.
7. İsteğe bağlı: GitHub repo adı ve yerel `houseflowApp` kök klasörünü ayrıca değiştir. Bu görevde ikisi de korundu.

Commit, push ve PR oluşturulmadı. Kullanıcının verdiği kesin commit mesajı olmadan commit yapılmaması talimatı uygulandı; promptun örnek commit düzeni otomatik commit yetkisi olarak kullanılmadı.

## Bilerek bırakılan kaynak eşleşmeleri

Aşağıdaki çıktı rapor eklenmeden önce alınmıştır; prompt hariçtir.

```text
FausCrew/Documents/houseRocketsMultiplayerPlan.md:288:- iOS: `/Users/frowing/Projects/houseflowApp`.
FausCrew/Documents/houseRocketsMultiplayerPlan.md:356:| [GamesHubView.swift](/Users/frowing/Projects/houseflowApp/FausCrew/Views/Discover/GamesHubView.swift) | House Rockets ekranını varsayılan initializer ile açıyor; production oyun bağımlılığı taşımıyor. |
FausCrew/Documents/houseRocketsMultiplayerPlan.md:357:| [HouseRocketsView.swift](/Users/frowing/Projects/houseflowApp/FausCrew/Views/Discover/Games/HouseRockets/HouseRocketsView.swift) | Varsayılan servis demo; bot seçimi, landscape bekleme, pause, sonuç ve rematch burada. `scenePhase` değişimi yerel pause çağırıyor. |
FausCrew/Documents/houseRocketsMultiplayerPlan.md:358:| [HouseRocketsViewModel.swift](/Users/frowing/Projects/houseflowApp/FausCrew/ViewModels/Games/HouseRockets/HouseRocketsViewModel.swift) | Sıra numaralı niyet gönderiyor; tek revision filtresi var; her komut önceki Task'i bekliyor. Online direksiyon için kuyruk birikmesi önlenmeli. |
FausCrew/Documents/houseRocketsMultiplayerPlan.md:359:| [HouseRocketsGameServicing.swift](/Users/frowing/Projects/houseflowApp/FausCrew/Services/Games/HouseRockets/HouseRocketsGameServicing.swift) | Servis enjeksiyonu mevcut; ancak `start(botCount)`, `scene`, pause/resume ve yalnız snapshot akışına bağlı. Online lobby ve bağlantı hataları için yeterli değil. |
FausCrew/Documents/houseRocketsMultiplayerPlan.md:360:| [DemoHouseRocketsSession.swift](/Users/frowing/Projects/houseflowApp/FausCrew/Services/Games/HouseRockets/DemoHouseRocketsSession.swift) | Bir insan ve botları üretir; sonucu yerel hesaplar. Snapshot/bot görev aralığı 120 ms, fizik sahnede çalışır. Countdown'ın her sayısı 750 ms bekler. |
FausCrew/Documents/houseRocketsMultiplayerPlan.md:361:| [HouseRocketsModels.swift](/Users/frowing/Projects/houseflowApp/FausCrew/Models/Games/HouseRockets/HouseRocketsModels.swift) | Oyuncu ve match kimlikleri UUID; isim `nameKey`; yerel `.human` ve `.remote` rolleri var. Wire DTO değildir. |
FausCrew/Documents/houseRocketsMultiplayerPlan.md:362:| [HouseRocketsSimulation.swift](/Users/frowing/Projects/houseflowApp/FausCrew/Models/Games/HouseRockets/HouseRocketsSimulation.swift) | Ekrandan bağımsız dünya fiziği; 1/120 s alt adımlar; lider kamera takibi, yüzey teması ve hız alanları. |
FausCrew/Documents/houseRocketsMultiplayerPlan.md:363:| [HouseRocketsCourse.swift](/Users/frowing/Projects/houseflowApp/FausCrew/Models/Games/HouseRockets/HouseRocketsCourse.swift) | İndeksle belirlenen parkur geometrisi; her üretimde rastgele UUID; zamana bağlı parkur dönüşü ve viewport projection. |
FausCrew/Documents/houseRocketsMultiplayerPlan.md:364:| [HouseRocketsScene.swift](/Users/frowing/Projects/houseflowApp/FausCrew/Views/Discover/Games/HouseRockets/HouseRocketsScene.swift) | Simülasyonu sahiplenir, `update` ile ilerletir ve çizimi simulation state'inden üretir. Online snapshot uygulama yolu yok. |
FausCrew/Documents/houseRocketsMultiplayerPlan.md:365:| [HouseRocketsTests.swift](/Users/frowing/Projects/houseflowApp/FausCrewTests/HouseRocketsTests.swift) | Geometri, yön, hız, kamera, elenme ve dönüşler için mevcut regresyon senaryoları. |
FausCrew/Documents/houseRocketsMultiplayerPlan.md:366:| [AppDependencies.swift](/Users/frowing/Projects/houseflowApp/FausCrew/Services/AppDependencies.swift) | Ortak network/keychain grafiği; henüz oyun servisi veya realtime transport yok. |
FausCrew/Documents/houseRocketsMultiplayerPlan.md:367:| [NetworkService.swift](/Users/frowing/Projects/houseflowApp/FausCrew/Services/Network/NetworkService.swift) | HTTP transport; enjekte edilebilir executor; HTTP status bilgisini üst katmana yapılandırılmış biçimde taşımıyor. |
FausCrew/Documents/houseRocketsMultiplayerPlan.md:368:| [AppEnvironment.swift](/Users/frowing/Projects/houseflowApp/FausCrew/Services/Network/AppEnvironment.swift) | Development URL'i Fly HTTP API'si; local multiplayer denemesi için ayrı base URL seçimi gerekecek. |
FausCrew/Documents/houseRocketsMultiplayerPlan.md:369:| [AppViewModel.swift](/Users/frowing/Projects/houseflowApp/FausCrew/ViewModels/AppViewModel.swift) | `currentUserId` ve `currentHouseDetails.id` mevcut. Online açılışta context buradan oluşturulabilir; token keychain bağımlılığından okunur. |
FausCrew/Documents/houseRocketsMultiplayerPlan.md:370:| [GameOrientationController.swift](/Users/frowing/Projects/houseflowApp/FausCrew/Services/Games/General/GameOrientationController.swift) | Landscape kilidi ve failure callback'i kullanılabilir. |
FausCrew/Documents/houseRocketsMultiplayerPlan.md:1914:| Canlı servis | macOS native URLSession WebSocket; mevcut development API `https://houseflowapi.fly.dev/api/v1`; aynı evde iki yetkili test hesabı | Join/ready/countdown/playing, ACK, background/foreground servis çağrıları, socket kesintisi/reconnect, aynı kullanıcıda kontrol devri, event/HTTP result, rematch ve iptal **geçti** | Headless istemciler; gerçek iOS suspension, joystick hissi ve FPS ölçülmedi. |
FausCrew/Services/Network/AppEnvironment.swift:11:            return URL(string: "https://houseflowapi.fly.dev/api/v1")!
FausCrew/Services/Network/AppEnvironment.swift:14:            return URL(string: "https://api.houseflow.app/api/v1")!
FausCrew/android/app/src/main/java/com/fauscrew/platform/AndroidHttpAdapter.kt:95:        const val LIVE_BASE_URL = "https://houseflowapi.fly.dev/api/v1/"

```

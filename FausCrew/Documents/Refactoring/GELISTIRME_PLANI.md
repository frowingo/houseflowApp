# FausCrew Geliştirme Planı

**Tarih:** 14 Kasım 2026 · **Kapsam:** iOS (SwiftUI), Android (Compose), ortak Swift çekirdeği (`FausCrew/shared`), CI · **Durum:** Faz 0, Faz 1 (F1-7 hariç), Faz 2, Faz 3 ve Faz 4 uygulandı (14-15 Kasım 2026, commit edilmedi). Ayrıntı: [FAZ_RAPORLARI.md](FAZ_RAPORLARI.md).

## 1. Özet

Kod tabanı genel olarak sağlam: TLS gevşetilmemiş, loglarda token yok, Android token deposu iyi kurulmuş, oyunlar sunucu otoriteli, oturum akışları eski yanıtlara karşı korunuyor. Büyük bir yeniden yazım gerekmiyor.

Asıl iyileştirme alanları dört başlıkta toplanıyor:

1. **Yayın hazırlığı ve oturum doğruluğu.** Süresi dolmuş token kullanıcıyı hata ekranında bırakıyor, Android'de hesap değişimi sırasında eski isteklerin sonucu yeni hesaba yazılabiliyor.
2. **Performans.** iOS'ta `AppViewModel` her küçük değişiklikte tüm ekran ağacını yeniden çizdiriyor; Android'de her ekran kendi HTTP istemcisini kuruyor ve dashboard listesi tembel değil.
3. **Tekrar eden kod.** Aynı iş kuralları iOS view'ında ve Android'de ayrı ayrı yazılmış; iOS'ta 12 popup aynı kabuğu kopyalıyor.
4. **Test ve CI.** CI iOS'u hiç derlemiyor; bazı testler başarısız olmak yerine sessizce atlanıyor.

Plan 5 faza bölündü ve toplam 47 görev içeriyor. Faz 0 ve Faz 1 yayın öncesi yapılmalı; diğerleri sırayla ve bağımsız ilerleyebilir.

| Faz | Konu | Görev | Tahmini efor |
|---|---|---|---|
| 0 | Hızlı kazanımlar ve hijyen | 9 | ~1 gün |
| 1 | Ortam, oturum ve veri doğruluğu | 8 | ~4-6 gün |
| 2 | Performans | 14 | ~4-5 gün |
| 3 | Tekrarı azaltma ve okunabilirlik | 11 | ~6-8 gün |
| 4 | Test ve CI | 5 | ~2-3 gün |

Efor harfleri: **S** = birkaç saat, **M** = yarım-bir gün, **L** = birkaç gün.

## 2. Analiz nasıl yapıldı

| Alan | Model | Bulgu |
|---|---|---|
| iOS uygulama katmanı (Views, ViewModels, Services) | Opus 5.5 · High | 21 |
| Güvenlik ve ağ/oturum (iki platform) | Opus 5.5 · High | 15 |
| Android uygulaması ve swift-bridge | Sol 6.1 · High | 14 |
| Ortak çekirdek, platform tutarlılığı, CI | Sol 6.1 · High | 12 |

Ajanlar salt-okunur çalıştı; build ve test çalıştırılmadı. Yönetici oturum (Fable 5.2) bulgulardan 20 tanesinin kanıt satırını kodda tek tek açıp kontrol etti; hepsi doğru çıktı. Bu görevler aşağıda **✔ kodda doğrulandı** ile işaretli. Diğerleri ajan raporuna dayanıyor; uygulayan ajan önce kanıt satırını kendisi okumalı.

Hiçbir bulgu cihazda ölçülmedi. Performans görevlerindeki kazanç tahmini koda bakılarak yapıldı; FPS, bellek ve süre rakamları yok.

## 3. Bu planı uygulayan ajanlar için kurallar

- Her görev kendi başına bir commit/PR olacak şekilde yazıldı. Faz içinde sıra önerilen sıradır; "Bağımlı" satırı olan görev belirtilen görevden sonra yapılır.
- Göreve başlamadan önce "Kanıt" satırlarını oku. Kod plandan sonra değişmiş olabilir; satır numaraları 14 Kasım 2026 tarihli `dev` dalına (commit `a797724`) aittir.
- Doğrulama: iOS ve Android'de yalnızca **build al ve testleri çalıştır**. Simülatör/emülatör testi yapma; görsel ve cihaz doğrulamalarını kullanıcı yapar. "Kullanıcı doğrular" yazan adımları rapora açık madde olarak yaz.
- Görevin "Bitti" koşulu sağlanmadan görevi kapatma. Koşulu sağlayamıyorsan nedenini yaz.
- Kapsamı genişletme. Bölüm 10'daki "Yapılmayacaklar" listesine uy; Bölüm 11'deki "Dokunma" alanlarını değiştirme.
- `FausCrew/Documents` altındaki planlardaki bilinçli kararlar geçerlidir (ör. katalog PUT sıralaması, fotoğraf baytlarının JNI'dan geçmemesi).
- Sır veya anahtar değerlerini commit'leme, loglama, rapora yazma.

## 4. Faz 0 — Hızlı kazanımlar ve hijyen

Hepsi küçük, birbirinden bağımsız ve düşük riskli.

### F0-1 Kök `.gitignore` ekle, `xcuserdata` takibini bırak · S · ✔ kodda doğrulandı
- **Sorun:** Repo kökünde `.gitignore` yok. Kişisel Xcode dosyaları (`UserInterfaceState.xcuserstate`, breakpoint listesi, scheme yönetimi) takip ediliyor.
- **Etki:** İleride eklenecek `GoogleService-Info.plist`, sertifika veya `.env` kazara commit'lenebilir; `xcuserstate` gereksiz diff üretir.
- **Yapılacak:** Kök `.gitignore`: `xcuserdata/`, `*.xcuserstate`, `.DS_Store`, `DerivedData/`, `build/`, `.build/`, `.swiftpm/`, `*.p12`, `*.mobileprovision`, `*.jks`, `*.keystore`, `.env*`, `*.local.xcconfig`. Sonra `git rm -r --cached` ile `xcuserdata` klasörlerini takipten çıkar.
- **Bitti:** `git ls-files | grep xcuserdata` boş döner.

### F0-2 Android "şifre belirle" alanını maskele · S · ✔ kodda doğrulandı
- **Sorun:** `ui/profile/AccountDialogs.kt:121` yalnızca `KeyboardType.Password` veriyor; `PopupTextField` (`ui/components/FausCrewPopup.kt:337`) maske uygulamıyor. Yeni şifre ekranda açık görünüyor.
- **Yapılacak:** `PopupTextField`'e `visualTransformation` parametresi ekle, bu alanda `PasswordVisualTransformation()` kullan.
- **Bitti:** Compose testi alanın maskeli olduğunu doğrular.

### F0-3 iOS API oturumunda disk önbelleğini kapat · S · ✔ kodda doğrulandı
- **Sorun:** `Services/Platform/URLSessionHTTPClient.swift:72-76` varsayılan `URLCache` ile çalışıyor; kimlik doğrulamalı yanıtlar (e-posta, telefon, ev detayı) diske yazılabilir.
- **Yapılacak:** `makeDefaultSession` içinde `configuration.urlCache = nil`.
- **Bitti:** Mevcut ağ testleri geçer.

### F0-4 iOS çıkışta kalan kişisel veriyi temizle · S · ✔ kodda doğrulandı
- **Sorun:** `Services/AuthService.swift:137-140` yalnızca token ve e-postayı siliyor. Ad/soyad Keychain'de, Apple'dan gelen bekleyen ad `UserDefaults`'ta kalıyor (`Social/AppleCredentialProvider.swift:16-17`). Android her şeyi siliyor.
- **Yapılacak:** `logout()` içinde ad/soyadı da sil; `AuthSessionStore.logout()` Apple bekleyen adını temizlesin.
- **Bitti:** `AuthServiceTests`'e çıkış sonrası dört alanın da boş olduğunu gösteren test eklenir.

### F0-5 iOS Keychain erişilebilirlik sınıfı · S · ✔ kodda doğrulandı
- **Sorun:** `Services/KeychainService.swift` `kSecAttrAccessible` vermiyor; token cihaz yedeğiyle başka cihaza taşınabiliyor. Kayıt "sil + ekle" şeklinde ve ekleme başarısız olursa token sessizce kayboluyor.
- **Yapılacak:** `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`; kayıt önce `SecItemUpdate`, öğe yoksa `SecItemAdd`.
- **Kapsam dışı bırakıldı (15 Kasım 2026):** "Uygulama silinip yeniden kurulunca Keychain'i temizle" kısmı uygulanıp iki inceleme turundan sonra geri çıkarıldı. Güncelleme ile yeni kurulum kesin ayırt edilemiyor; mevcut kullanıcıyı çıkış yaptırma riski faydadan büyük. Yeniden kurulumda otomatik giriş bilinçli olarak sürüyor.
- **Bitti:** Mevcut öğenin kayıtla yeni sınıfa geçtiğini gösteren test.

### F0-6 `mavenLocal()` deposunu daralt · S · ✔ kodda doğrulandı
- **Sorun:** `android/settings.gradle.kts:12` `mavenLocal()`'ı filtresiz ve ilk sırada tanımlıyor; `~/.m2` içindeki herhangi bir paket gerçek bağımlılığın yerine geçebilir.
- **Yapılacak:** `mavenLocal { content { includeGroup("org.swift.swiftkit") } }` ve listenin sonuna taşı.
- **Bitti:** Android build geçer.

### F0-7 Oyun loglarından sunucu metinlerini çıkar · S · ✔ kodda doğrulandı
- **Sorun:** `Services/Games/General/GameOnlineHost.swift:159` ve `:314` `String(describing:)` sonucunu `.public` logluyor; hata enum'unun ilişkili değerleri (sunucu argümanları, mesajlar) kalıcı loglara girebilir. Dosyadaki yorum "payload yok" diyor.
- **Yapılacak:** Yalnızca sabit hata kategorisini (ve gerekiyorsa HTTP durum kodunu) logla.
- **Bitti:** Kategori üreten küçük fonksiyon için birim testi.

### F0-8 Sessizce atlanan testleri gerçek hataya çevir · S · ✔ kodda doğrulandı
- **Sorun:** `shared/Tests` içinde 9 yerde beklenen efekt gelmezse `XCTSkip` atılıyor (`HouseTanksOnlinePlayTests.swift:750,752`, `FausSwitchOnlineEngineTests.swift:149,445,562,567`, `HouseRocketsOnlineEngineTests.swift:640,652`, `HouseTanksOnlineLobbyTests.swift:158`). Durum makinesi bozulsa test yeşil kalır.
- **Yapılacak:** Bu dallarda `XCTFail` + hata fırlat. `FausSwitchSimulationFixtureTests.swift:68`'deki bilinçli atlamaya dokunma.
- **Bitti:** `swift test` geçer; atlanan test sayısı yalnızca fixture üretim testidir.

### F0-9 iOS ölü kodu sil · S
- **Sorun:** Kullanılmayan üyeler var: `AppViewModel` içinde `weeklyLeader`, `sampleUsers`, `sampleChores`, `houseIsLoading`, `setLocalizationLanguage`, `updateLocalizationLanguage`; `ChoreStore.toggleCompletion`; `HouseSessionStore.houseIsLoading`; `Views/Dashboard/Components/ChoreRow.swift`; `ChoreLevelPill`; `TodaysChoresCard` içindeki `pulseAnimation` ve boş `onAppear`.
- **Yapılacak:** Her birinin kullanımını `grep` ile doğrula, sıfır kullanımlı olanı sil. `HouseSessionStore.houseError` için Bölüm 9'daki karar beklenir.
- **Bitti:** iOS build ve testler geçer.

## 5. Faz 1 — Ortam, oturum ve veri doğruluğu

Yayın öncesi yapılması gereken faz. Gerçek kullanıcıyı etkileyen hatalar burada.

### F1-1 Backend adresini tek adrese sadeleştir · S · ✔ kodda doğrulandı
- **Düzeltme (14 Kasım 2026, proje sahibi):** `houseflowapi.fly.dev` tek backend'dir ve production'dır; ayrı bir dev/demo backend yok ve olmayacak. İlk analizdeki "release build demo backend'e gidiyor" bulgusu yanlıştı; koddaki eski adlandırmadan kaynaklandı.
- **Sorun:** `Services/Network/AppEnvironment.swift` `development`/`production` ayrımı, "Demo API" yorumu ve hiç kullanılmayan `api.houseflow.app` yer tutucu adresi taşıyor. Yanıltıcı; biri `.production`'a geçerse istekler sahipliği belirsiz bir alan adına gider.
- **Yapılacak:** Ayrımı ve yer tutucu adresi kaldır; tek `baseURL` kalsın. Çağrı yerlerini güncelle. Android'de (`AndroidHttpAdapter.kt` `LIVE_BASE_URL`) adres zaten tek. Build türüne göre adres seçimi eklenmeyecek.
- **Bitti:** iOS build geçer; kodda `api.houseflow.app` kalmaz.

### F1-2 401'i tek yerde ele al · M · ✔ kodda doğrulandı
- **Sorun:** `Services/Network/NetworkService.swift:199-203` durum kodunu atıp yalnızca mesajı taşıyor; çağıran 401'i ayırt edemiyor. `AppSessionCoordinator.swift:325` token'ı silmeden hata ekranına yönlendiriyor. Android'de `AuthSessionRepository.kt:143-150` ve `HouseSessionRepository.kt:194` aynı durumda.
- **Etki:** Token süresi dolunca kullanıcı her açılışta hata ekranı görür ve elle çıkış yapmak zorunda kalır.
- **Yapılacak:** iOS: `NetworkError.unauthorized` ekle; `NetworkService` ve `SessionRestoreAdapter` 401'i buna eşlesin; koordinatör bu durumda `logout()` çağırsın. Android: istek istisnaları durum kodunu taşısın; oturum geri yüklemede 401 `SignedOut` dönsün. Refresh token eklenmeyecek.
- **Bitti:** `AppSessionCoordinatorTests` ve `AuthSessionRepositoryTest`'te "geçersiz token ile açılış giriş ekranına düşer" testi.

### F1-3 Android: hesap değişiminde eski işleri iptal et · M
- **Sorun:** Üç ayrı yerde aynı desen:
  - `viewmodel/ChoreCatalogViewModel.kt:60,103` + `platform/ChoreCatalogRepository.kt:194`: kaydet/sil sonuçlarında kullanıcı kontrolü yok; token kuyruktaki iş çalışırken okunuyor. A hesabının geç gelen yanıtı B hesabının listesini ezebilir, bekleyen taslak B'nin token'ıyla gönderilebilir.
  - `viewmodel/AuthViewModel.kt:366,383` + `platform/AuthSessionRepository.kt:249`: `refreshProfile()` işi tutulmuyor, çıkışta iptal edilmiyor; temizlenen depoya eski hesabın verisi yeniden yazılabilir.
  - `viewmodel/GameOnlineSession.kt:77,104`: `dispose()` HTTP işlerini iptal etmiyor.
- **Yapılacak:** İşleri bir `Job`'da tut, oturum değişiminde/`dispose()`'da iptal et; sonucu uygulamadan önce oturum neslini kontrol et. iOS'taki flow-ID korumasının karşılığı.
- **Bitti:** Geciktirilmiş yanıt → çıkış → başka hesapla giriş senaryosu için üç ViewModel'de test.

### F1-4 Android: yenileme ve değişiklik yanıtlarının birbirini ezmesini önle · M
- **Sorun:** `viewmodel/HouseViewModel.kt:107,395,463`: `refreshDetails()` paralel çalışabiliyor; değişiklikler istek öncesindeki kopyaya uygulanıp tüm detayı geri yazıyor. `ChoreCatalogViewModel.kt:72,103`'te GET ile PUT arasında aynı yarış var. İki ajan bağımsız olarak aynı sorunu buldu.
- **Etki:** Yeni görev, üye veya duyuru geç gelen eski yanıtla ekrandan kaybolabilir.
- **Yapılacak:** Değişiklik sonucunu `await` sonrasındaki güncel duruma uygula; eski yenileme yanıtlarını basit bir istek sıra numarasıyla ele. Katalogda popup kapanınca PUT'un sürmesi kararı korunur.
- **Bitti:** Ters sırada tamamlanan GET/PUT için ViewModel testleri.

### F1-5 Android: token okuma hatası uygulamayı kapatmasın · S
- **Sorun:** `GameOnlineSession.kt:104,126` ve `AppEventsViewModel.kt:92`'de `token()` çağrısı hata yakalama bloğunun dışında. Keystore hatası yakalanmamış istisnaya dönüşür.
- **Yapılacak:** Çağrıyı aynı hata sınırına al; `CancellationException` yeniden fırlatılsın.
- **Bitti:** Token sağlayıcısının istisna attığı test.

### F1-6 Sunucu snapshot'larını aritmetikten önce doğrula · M
- **Sorun:** `shared/.../HouseTanks/Online/HouseTanksRealtime.swift:37` ve `HouseTanksWorld.swift:850`: yalnızca oyun/harita uyumu denetleniyor; uç değerli `spawnTick` taşmaya yol açar. `FausSwitch/Online/FausSwitchRealtime.swift:29` ve `FausSwitchOnlinePlayMachine.swift:381`'de aynı durum.
- **Etki:** Bozuk sunucu verisi yakalanabilir hata yerine iki platformda da uygulamayı kapatır (Swift taşmada trap eder).
- **Yapılacak:** Mevcut uyumluluk kontrolüne tick aralığı, oyuncu sayısı ve kimlik benzersizliği kontrolü ekle. Yeni katman yok.
- **Bitti:** Fixture'ı bozan testler snapshot'ın reddedildiğini gösterir.

### F1-7 iOS: oyun açıkken sekme çubuğu · S · **Önce kullanıcı doğrular**
- **Sorun:** Yalnızca `RockPaperScissorsView.swift:54` sekme çubuğunu gizliyor; diğer altı oyunda çubuk oyunun üstünde kalıyor. Sekmeye dokunmak oyun view'ını yok edip `onDisappear { model.stop() }` ile online odadan çıkarıyor (`HouseTanksView.swift:92`, `FausSwitchView.swift:75`, `HouseRocketsView.swift:170`).
- **Durum:** Kod okumasına dayanıyor; cihazda görülmedi.
- **Yapılacak:** Kullanıcı sorunu doğrularsa: oyun ekranları ortak bir modifier ile `isOverlayPresented`'ı yönetsin (F3-7 ile birlikte yapılabilir).
- **Bitti:** Kullanıcı online maçta sekme çubuğunun gizlendiğini doğrular.
- **Durum (16 Kasım 2026):** Bu turda yapılmadı; kullanıcının cihazda doğrulaması bekleniyor.

### F1-8 Kullanıcıya ham sunucu metni gösterme · M
- **Sorun:** `shared/.../Ports/HTTPClient.swift:68-75` JSON olmayan gövdeyi olduğu gibi mesaj yapıyor; `NetworkService.swift:12-15` İngilizce teknik metin üretiyor. iOS'ta 35 yerde `error.localizedDescription` doğrudan ekrana gidiyor; bazı koordinatörlerde sabit Türkçe/İngilizce metin var (`AppSessionCoordinator.swift:88,163`, `ProfileCoordinator.swift:51,62`).
- **Yapılacak:** Ham metin yalnızca kısa düz metinse kullanılsın. `LocalizationStore`'a tek `userMessage(for:)` ekle; koordinatörler onu kullansın. View'lardaki çağrılar aşamalı değişir. Doğru örnek: `DashboardCoordinator.loadReviewPhoto:181-197`.
- **Bitti:** `userMessage(for:)` için hata türü başına test.
- **Durum (16 Kasım 2026):** Koordinatör/store katmanı ve `userMessage(for:)` yapıldı. Kalan: view'larda 19 `error.localizedDescription` çağrısı, `AuthSessionStore`'daki login/signup hata metni ve servislerdeki sabit "Not authenticated." metinleri. Altı yeni lokalizasyon anahtarı backend'e eklenmeli (şimdilik kod içi tr/en yedeği kullanılıyor).

## 6. Faz 2 — Performans

Kazançlar koda bakılarak tahmin edildi. Her görevde önce/sonra ölçümü kullanıcı cihazda yapar.

### iOS

### F2-1 `AppViewModel`'in gereksiz yayınlarını kes · S · ✔ kodda doğrulandı
- **Sorun:** `ViewModels/AppViewModel.swift:240-297` sekiz store'un her değişikliğini kendi `objectWillChange`'ine iletiyor. 55 view dosyası `AppViewModel`'i `@EnvironmentObject` olarak gözlemliyor. Toast'u yalnızca `RootView`, overlay'i yalnızca `MainTabView` okuduğu halde her toast tüm ağacı üç kez yeniden çizdiriyor.
- **Yapılacak:** Toast ve overlay iletimini `bindStoreChanges`'tan çıkar; `ToastStore`'u `RootView`'a, `OverlayStore`'u `MainTabView`'a doğrudan ver. `OverlayStore` aynı değeri tekrar yayınlamasın.
- **Değişen dosyalar:** `AppViewModel`, `RootView`, `MainTabView`, `FausCrewApp`.
- **Bitti:** Build ve testler geçer; toast sırasında dashboard satırlarının yeniden çizilmediğini kullanıcı Instruments ile doğrular.

### F2-2 Oyun hedeflerini tembel kur · S · ✔ kodda doğrulandı
- **Sorun:** `Views/Discover/GamesHubView.swift:108` `NavigationLink(destination:)` ile tüm oyun view'larını her çizimde kuruyor. `HouseTanksView.swift:20` demo oturumunu `StateObject` kapanışının dışında yaratıyor; her kurulumda bir SpriteKit sahnesi oluşturulup atılıyor.
- **Yapılacak:** `NavigationLink(value:)` + `.navigationDestination(for:)`. `HouseTanksView`'da ifadeyi tamamen `StateObject(wrappedValue:)` içine al.
- **Ek kontrol:** `RootView.swift:9` ile `GamesHubView.swift:53`'te iç içe `NavigationStack` var; kök olan bir geçişe hizmet etmiyorsa tekilleştir.
- **Bitti:** Build geçer; oyun geçişlerini kullanıcı doğrular.
- **Durum (15 Kasım 2026):** Yapıldı. Kök `NavigationStack` bırakıldı: sekiz kök ekran çubuğu gizlemiyor, kaldırılırsa yerleşim kayar.

### F2-3 Görev detayında fotoğrafı her çizimde çözme · S · ✔ kodda doğrulandı
- **Sorun:** `Views/Dashboard/Components/ChoreDetailPopup.swift:450` 28×28'lik önizleme için 2048 piksellik JPEG'i her `body` çalışmasında çözüyor.
- **Yapılacak:** Fotoğraf hazırlandığında küçük önizlemeyi bir kez üretip `@State`'te tut. `appViewModel` parametresini `@EnvironmentObject` yap (`NewAnnouncementPopup.swift:6` dahil).
- **Bitti:** `ChoreReviewPhotoTests` geçer.

### F2-4 Uzak görsel yükleyiciyi düzelt · S
- **Sorun:** `Views/Shared/CachedRemoteImage.swift:28-33,61,79-81`: önbellekteki görsel için de önce yer tutucu çiziliyor; indirme sınırsız; tam çözünürlüklü görsel 28-42 pt'lik daire için çözülüyor. Android'de 5 MB sınır ve küçültme var.
- **Yapılacak:** Önbellekten eşzamanlı okuyup `State(initialValue:)` ile başlat; 5 MB sınır koy; `byPreparingThumbnail(ofSize:)` ile küçült.
- **Bitti:** Build geçer; sekme değişiminde avatarların yanıp sönmediğini kullanıcı doğrular.

### F2-5 Keychain ve decode işini ana thread'den azalt · S
- **Sorun:** Her istekte token Keychain'den okunuyor (ör. `HouseService.swift:17`); `AuthSessionStore.swift:204-206` her profil yenilemesinde üç öğeyi yeniden yazıyor; `NetworkService.swift:195` decode'u ana thread'de yapıyor.
- **Yapılacak:** `KeychainService` token'ı bellekte tutsun, değişmeyen değeri yazmasın. Decode'u `nonisolated` yardımcıya taşı. `JSONDecoder`'ın her çağrıda kurulmasına dokunma; maliyeti önemsiz.
- **Bitti:** `AuthServiceTests` ve `NetworkServiceTests` geçer.

### F2-6 Dashboard kartlarındaki tekrar eden iş · S
- **Sorun:** `AnnouncementCard.swift:27-29,40-49`: her kurulumda `UserDefaults` okunuyor, sıralama sırasında tarih iki kez ayrıştırılıyor. `TodaysChoresCard.swift:200-222` tüm geçmiş görevleri düz `VStack` ile çiziyor.
- **Yapılacak:** Tarihi bir kez ayrıştır, sıralı listeyi tek değişkende tut, okunmuşları `.task(id:)` ile yükle. Görev listesinde `LazyVStack`.
- **Bitti:** Build ve `DashboardCoordinatorTests` geçer.

### Android

### F2-7 Tek paylaşılan `OkHttpClient` · S
- **Sorun:** `AndroidHttpAdapter.live()` (`:122`) her çağrıda yeni istemci kuruyor ve altı ViewModel'den çağrılıyor; soket fabrikası dört yerde ayrı istemci açıyor; `RemoteImageLoader.kt:19` kendi istemcisini tutuyor. Koddaki yorum "tek havuzlu istemci" diyor.
- **Etki:** Ekranlar arasında bağlantı ve TLS yeniden kullanılmıyor.
- **Yapılacak:** Tek bir temel istemci; adaptör, soket fabrikası ve görsel yükleyici ondan `newBuilder()` ile türesin.
- **Bitti:** Android testleri geçer.

### F2-8 Yükleme zaman aşımı ve soket mesaj sınırı · S · ✔ kodda doğrulandı (zaman aşımı)
- **Sorun:** `AndroidHttpAdapter.kt:123` `callTimeout(30s)` toplam süreyi sınırlıyor; yavaş ağda 3 MB fotoğraf yüklemesi düşebilir (iOS'ta 30 sn boşta kalma süresi). `HouseRocketsOnline.kt:380` gelen soket mesajında boyut sınırı uygulamıyor (iOS'ta 1 MB).
- **Yapılacak:** `connectTimeout(15s)`, `readTimeout(30s)`, `writeTimeout(60s)`. Soket mesajı 1 MB'ı aşarsa bağlantıyı kapat.
- **Bitti:** Android testleri geçer.

### F2-9 Oyun ekranında kare başına yeniden kompozisyonu önle · S · ✔ kodda doğrulandı
- **Sorun:** `ui/games/rockets/HouseRocketsScreen.kt:85,87` ve `tanks/HouseTanksScreen.kt:72` `frameState.value != null` değerini üst composable'da okuyor; her kare tüm ekranı geçersiz kılıyor.
- **Yapılacak:** `remember { derivedStateOf { … } }`.
- **Bitti:** Build geçer; recomposition sayısını kullanıcı Layout Inspector ile karşılaştırır.

### F2-10 Dashboard'u `LazyColumn` yap · M · ✔ kodda doğrulandı
- **Sorun:** `ui/dashboard/DashboardScreen.kt:113` `verticalScroll` kullanıyor; `TodaysChoresCard.kt:119,128` tüm görevleri anahtarsız `forEach` ile oluşturuyor.
- **Yapılacak:** Tek `LazyColumn`, görevler `chore.id` anahtarıyla. Görünüm aynı kalır.
- **Bitti:** Build geçer; giriş animasyonlarını ve kaydırmayı kullanıcı doğrular.
- **Durum (15 Kasım 2026):** Yapıldı, sapmayla: görev satırları `key(chore.id)` ile anahtarlı ama kart tek öğe, satırlar tembel değil. Görev listesi iki platformda da sınırsız (evin tüm geçmişi); karar Bölüm 9 #6'da.

### F2-11 İnceleme fotoğrafları ve görsel indirme · S
- **Sorun:** `ui/dashboard/ChoreDetailPopup.kt:133,185` açılan her turun 2048 piksele kadar bitmap'ini haritada biriktiriyor (bitmap başına ~16 MB). `platform/RemoteImageLoader.kt:29,53` bloklayan `execute()` kullanıyor; coroutine iptali indirmeyi durdurmuyor.
- **Yapılacak:** Yalnızca görüntülenen fotoğrafı tut. İndirmeyi HTTP adaptöründeki iptal edilebilir yaklaşıma geçir.
- **Bitti:** İptal testi geçer.

### Ortak çekirdek

### F2-12 HouseRockets çarpışma geometrisini bir kez hesapla · S · ✔ kodda doğrulandı
- **Sorun:** `shared/.../HouseRockets/Online/HouseRocketsOnlineFlightMachine.swift:219-222` üç geçişin her birinde `gates.flatMap(\.solidPolygons)` çağırıyor; bu özellik dizileri her seferinde yeniden üretiyor.
- **Yapılacak:** Değeri döngüden önce bir kez hesapla.
- **Bitti:** Mevcut çarpışma testleri geçer.

### F2-13 HouseTanks yerel tahminini tekrar etme · M
- **Sorun:** `shared/.../HouseTanks/Online/HouseTanksOnlinePlayMachine.swift:121,220,549`: tahmin snapshot değişmeden de hesaplanıyor; her tahmin dünyayı kopyalayıp 24 tick'e kadar ilerletebiliyor.
- **Yapılacak:** Tahmini yalnızca yeni snapshot geldiğinde hesapla; gerekirse FausSwitch'teki gibi tek sonuç önbelleği.
- **Bitti:** `HouseTanksOnlinePlayTests` aynı sonuçları verir.

### F2-14 Bot planlayıcısında birikmeyi önle · S
- **Sorun:** `shared/.../FausSwitch/FausSwitchBotPlanner.swift:56,66`: geç tamamlanan planlar tüketilmeden maç boyunca tutuluyor.
- **Yapılacak:** Bot başına tüketilmiş tick sınırı tut; geçmiş cevapları saklama.
- **Bitti:** Geciktirilmiş işçi senaryosunda cevap sayısının sınırlı kaldığını gösteren test.

## 7. Faz 3 — Tekrarı azaltma ve okunabilirlik

Davranış değiştirmeyen, bakım maliyetini düşüren görevler. Her biri ayrı PR olmalı.

### F3-1 Görev inceleme kurallarını çekirdeğe taşı · M
- **Sorun:** İnceleme kuralları (kim inceleyebilir, tur sayıları, onay/ret sayımı) iOS'ta `ChoreDetailPopup.swift:79-108,858-882`, Android'de `ui/dashboard/ChoreDetailPopup.kt:120-121,489` içinde ayrı yazılmış. Benzer kurallar zaten çekirdekte (`shared/.../ChoreModels.swift:67-94`).
- **Yapılacak:** Saf fonksiyonları `FausCrewCore`'a taşı, test ekle, iki platform onu kullansın. Ardından iOS popup'ının inceleme bölümünü ayrı dosyaya al.
- **Bitti:** Çekirdek testleri kuralları kapsar; iki platformda yerel kopya kalmaz.
- **Durum (15 Kasım 2026):** Yapıldı. Android, görev başına değil popup açılışında tek köprü çağrısıyla çekirdeğin özetini alıyor (üyeler ve kullanıcı kimliği repository katmanında yok).

### F3-2 Android'de wire alanlarını ikinci kez çözme · M
- **Sorun:** Bridge DTO'yu çözüp doğruluyor, sonra ham gövdeyi döndürüyor (`swift-bridge/.../InviteCodeBridge.swift:145`); Kotlin aynı alan eşlemesini tekrar yapıyor (`platform/HouseSessionRepository.kt:231`) ve iç içe yayıncı kimliğini kaçırıyor.
- **Etki:** Aynı yanıt iki platformda farklı veriye dönüşüyor.
- **Yapılacak:** Bridge çekirdeğin normalize ettiği alanları döndürsün.
- **Bitti:** İç içe yayıncı fixture'ı iki platformda aynı sonucu verir.

### F3-3 Ev adı kuralını tek yerden uygula · S
- **Sorun:** Swift görünen karakteri (`HouseModels.swift:120`), Kotlin UTF-16 birimini (`platform/HouseCreationRules.kt:13`) sayıyor; `CreateHousePopup.kt:129` `take(30)` ile emojiyi ortadan bölebiliyor.
- **Yapılacak:** Android kuralı küçük bir bridge çağrısıyla çekirdekten alsın.
- **Bitti:** Emoji ve birleşik aksan içeren adlar için test.
- **Durum (15 Kasım 2026):** Yapıldı; planda olmayan onboarding `CreateHouseScreen.kt` de düzeltildi.

### F3-4 iOS ortak popup kabuğu · M
- **Sorun:** Arka plan + başlık + kapatma kalıbı 12 popup'ta kopyalanmış; başlık rengi `ThemeSettingsPopup`'ta diğerlerinden farklı. `ProfileView.swift:8-47,421-440` birbirini dışlayan 10 overlay için 10 `Bool` tutuyor.
- **Yapılacak:** Tek `FausPopupShell` view'ı; `ProfileView`'da tek `enum` durumu. Android'de kabuk zaten ortak.
- **Bitti:** Build geçer; popup görünümlerini kullanıcı dört temada doğrular.
- **Durum (15 Kasım 2026):** Yapıldı, görsel tek tipleştirmeyle (onHero rengi, 56pt watermark, 28/44pt kapatma, 12pt tek satır alt başlık). Dokuz popup kabukta; `PhoneManagementPopup` ve yalnızca scrim'li popup'lar yapısı farklı olduğu için dışarıda.

### F3-5 `HouseInfoPopup`'ı sadeleştir · M
- **Sorun:** `Views/Profile/Popups/HouseInfoPopup.swift` (1060 satır): 16 `@State`, ağ çağrıları ve kurallar (`:816-866`) view içinde; ev tipi eşlemesi (`:904-924`) `HouseTypeCard.swift:12-40`'ın kopyası.
- **Yapılacak:** Saf `HouseInfoDraft` yapısı çıkar ve test et; mevcut ev tipi eşlemesini kullan; sahip düzenleyici ve üye bölümünü ayrı dosyalara al.
- **Bitti:** `HouseInfoDraft` testleri geçer.

### F3-6 İki büyük view'ı böl · M
- **`HouseTanksLobbyView.swift` (1019):** Demo (`:215-570`) ve Online (`:572-935`) akışlarını iki view'a ayır.
- **`ChoreTemplateEditorView.swift` (1113):** "When" bölümünü (`:389-633`) alt view'a, `FlowLayout`'u (`:1074`) `Shared`'e taşı.
- **Bitti:** Build geçer; davranış aynı.
- Diğer büyük dosyalar için Bölüm 10'a bakın.

### F3-7 Online oyunlarda ortak yaşam döngüsü · S
- **Sorun:** Oturum açma/kapama blokları üç oyunda (`HouseTanksView.swift:80-95`, `FausSwitchView.swift:63-78`, `HouseRocketsView.swift:148-172`), "ayrıl + 3 sn sonra kapat" kodu iki ViewModel'de kopya.
- **Yapılacak:** Tek `ViewModifier` + `GameOnlineHost.leaveGracefully()`. F1-7 ile birleştirilebilir.
- **Bitti:** Oyun testleri geçer.

### F3-8 Üretimden demo veriyi çıkar · S · ✔ kodda doğrulandı (demo veri mevcut)
- **Sorun:** `ViewModels/Coordinators/DashboardCoordinator.swift:46-83,269-281`: ev detayı yokken dashboard örnek kullanıcı ve görevlerle doluyor; evden çıkış animasyonunda görünebilir.
- **Yapılacak:** Boş dizi döndür. `DashboardCoordinatorTests`'i güncelle.
- **Bitti:** Testler geçer.

### F3-9 Lokalizasyon yardımcılarını birleştir · S
- **Sorun:** `localized(...)` çeşitleri, `social(_:tr:en:)`, `catalogText` ve oyunlarda altı özel `copy()`. Oyun sözlükleri bilinmeyen dilde Türkçe, `social()` İngilizce dönüyor.
- **Yapılacak:** `LocalizationStore`'da tek `localized(_:tr:en:)`; sözlükler dili `APILanguage`'dan alsın.
- **Bitti:** Build ve testler geçer.
- **Durum (15 Kasım 2026):** Yapıldı. Oyun sözlüklerinin dil kuralı çekirdekte iki platform için `tr` → Türkçe, diğer her dil ve boş → İngilizce oldu.

### F3-10 Küçük iOS düzeltmeleri · S
- `LuckySpinView.swift:506-523`, `MidnightCleanupView.swift:329,1032-1047`: indeks tabanlı `ForEach` yerine değer tabanlı; iki üye listesi view'ını birleştir.
- `EmailVerificationView.swift:456-466`, `ForgotPasswordView.swift:462-477`: toast kapatma `Task`'ını sakla ve iptal et.
- `try? await Task.sleep` sonrası durum değiştiren yerlerde iptali yakala (`HouseTanksView.swift:168-172`, `FausSwitchView.swift:149`).
- Preview'lar gerçek ağ/keychain kurmasın: test bağımlılıklı `AppViewModel.preview`.
- `MidnightCleanupView.swift` dosyasını içindeki `VaultRushView` adına göre yeniden adlandır.
- **Durum (15 Kasım 2026):** Yapıldı. VaultRush'taki iki üye listesi farklı şeyler çizdiği için birleştirilmedi.

### F3-11 HouseTanks demo botunu kare hızından bağımsız yap · M
- **Sorun:** `shared/.../HouseTanks/HouseTanksBotMatch.swift:92,105,245`: bot kararları fizik tick'ine değil kare süresine bağlı; aynı seed 30/60/120 FPS'te farklı sonuç veriyor. Dosyadaki "her yerde aynı karar" iddiası sağlanmıyor.
- **Yapılacak:** Karar zamanını fizik tick döngüsüne bağla.
- **Bitti:** Aynı toplam süre üç farklı kare bölünmesiyle aynı dünya durumunu verir.

## 8. Faz 4 — Test ve CI

### F4-1 CI'da iOS build ve test · M · ✔ kodda doğrulandı
- **Sorun:** Tek workflow (`.github/workflows/fauscrew-android-bridge.yml`) Ubuntu'da çalışıyor ve yalnızca `android/**` ile `shared/**` yollarını tetikliyor. iOS kaynakları ve `FausCrewTests` hiç sınanmıyor; geçiş planı (`CROSS_PLATFORM_MIGRATION_PLAN.md:221`) iOS CI'ı zorunlu sayıyor.
- **Yapılacak:** macOS üzerinde mevcut scheme ile iOS test işi; iOS yolları ve `shared/**` tetiklesin.
- **Bitti:** PR'da iOS işi çalışır.
- **Durum:** `.github/workflows/fauscrew-ios.yml` eklendi (`macos-26`, Xcode 26.5, dinamik iPhone simülatörü, `CODE_SIGNING_ALLOWED=NO`). Runner etiketi ve Xcode yolu ilk PR çalışmasında doğrulanmalı.

### F4-2 Fixture bütünlüğünü CI'da gerçekten kontrol et · S · ✔ kodda doğrulandı
- **Sorun:** `shared/Tests/.../HouseTanksParityTests.swift:4,20` SHA-256 kontrolünü `#if canImport(CryptoKit)` içine almış; Linux CI'da test hiçbir şey kontrol etmeden geçiyor olabilir.
- **Yapılacak:** Workflow'a üç fixture için `sha256sum --check` adımı ekle. Yeni paket ekleme.
- **Bitti:** Fixture değişince CI kırılır.

### F4-3 iOS test boşlukları · M
- Öncelik sırasıyla: `AppSessionCoordinator.refreshForAppEvent` ve `leaveRemovedHouse` (`:205-244`); `HouseSessionStore.loadHouseDetails` önbellek ve birleştirme (`:49-76`); `LocalizationStore` dil seçimi (`:171-185`); `DashboardCoordinator.reviewChore/createChore/createAnnouncement`.
- Mevcut `TestSupport` altyapısı yeterli.
- **Durum:** 34 test eklendi. Süre ve cihaz dili için `HouseSessionStore(now:)` ve `LocalizationStore(deviceLanguages:)` varsayılanlı seam'leri eklendi. Testler derlendi, çalıştırılmadı.

### F4-4 Android build doğrulamaları · M
- `swift-bridge/build.gradle:60`: `shared/Package.swift` ve toolchain kimliğini görev girdisi yap; yoksa manifest değişince eski native çıktı kullanılabilir.
- `scripts/check-android-package.sh:17`: beklenen ABI listesini parametre al; tek ABI build'ini reddetmesin.
- Mevcut JNI testlerinin küçük bir bölümünü minify edilmiş release ve API 30 (minSdk) üzerinde çalıştır. Geçiş planındaki Faz 12 kapsamında.
- **Durum:** İlk iki madde yapıldı. Emülatör smoke testi API 30'a alındı. Minify edilmiş release üzerinde JNI testi ertelendi (imza ve keep kuralları gerekiyor; geçiş planı Faz 12). Kırık `check-android-bindings.sh` sürüm 19 / 88 metoda güncellendi.

### F4-5 Belgeleri güncelle · S
- `CROSS_PLATFORM_MIGRATION_PLAN.md:634,661` Switch/Tanks için gerçek durumun gerisinde; `Documents/Games/README.md` güncel. Kayıtları eşitle.

## 9. Kullanıcı kararı bekleyenler

| # | Karar | Önerim |
|---|---|---|
| 1 | ~~Production API alan adı~~ (F1-1) | Kapandı: mevcut fly.dev backend'i production; dev ortamı yok. |
| 2 | `HouseSessionStore.houseError` ekranda gösterilsin mi, silinsin mi? (F0-9) | `HouseErrorView`'da göster; şu an yalnızca yazılıyor. |
| 3 | iOS store'ları `@Observable`'a geçsin mi? | Şimdilik hayır. F2-1 çoğu kazancı küçük eforla sağlıyor; sonra ölçüp karar verin. |
| 4 | SkylineDash oyun döngüsü yeniden yazılsın mı? (`SkylineDashView.swift:542-555`, 60 Hz `Task.sleep` + tüm view yeniden çizimi) | Demo oyunsa bırakın; kalıcıysa `TimelineView`'a geçirin. |
| 5 | F1-7'deki sekme çubuğu sorunu cihazda görülüyor mu? | Online maç sırasında başka sekmeye dokunup deneyin. |
| 6 | ~~Dashboard görev listesi sınırlansın mı?~~ (F2-10) | Kapandı (15 Kasım 2026): sunucu sayfalı ya da yalnızca güncel görevleri döndürecek; arşiv görevler ayrı bir ekrandan açılacak. Bu refactoring planının dışında, ayrıca planlanacak. |

### Backend'e iletilecek notlar

İstemcide değişiklik gerektirmez; bu repoda doğrulanamadı.

- Facebook ve Snapchat açılmadan önce backend token'ın kendi uygulama kimliğimize ait olduğunu doğrulamalı. Şu an bu sağlayıcılar pasif (kimlikler yer tutucu).
- Görev durum geçişleri sunucuda zorlanmalı: inceleme atlanamamalı, kişi kendi görevini onaylayamamalı, `level` sınırlanmalı. İstemci keyfi `status` ve `level` gönderebiliyor.
- Tanks ve Switch mesajlarındaki `clientTick` sunucuda sınırlandırılmalı.
- Kimlik doğrulamalı yanıtlar önbelleğe alınabilir başlık dönmemeli.

## 10. Yapılmayacaklar

Değerlendirildi ve bilerek plan dışı bırakıldı:

- **Certificate pinning, refresh token, istek yeniden deneme katmanı.** Bu ölçekte gerçek bir riski kapatmıyor.
- **Yeni modül, DI framework'ü veya mimari katman.** Tek `FausCrewCore` hedefi ve mevcut composition root yeterli.
- **`FausTheme.swift` (1180) ve `FausThemes.kt` (959) bölmek.** Tamamen veri.
- **`AppViewModel.swift` (622) ve `MainTabView.swift` (624) bölmek.** Sorun boyut değil yayın yapısı; F2-1 çözüyor.
- **`MidnightCleanupView` ve `SkylineDashView`'ı bölmek.** Kendi içinde kapalı demo oyunlar.
- **`ChoreTemplateEditor.kt` (999) ve `AuthViewModel.kt` (780).** Android ajanı uzunluk dışında sorun bulmadı.
- **Swift 6 dil moduna geçiş.** Varsayılan `MainActor` izolasyonuyla risk düşük.
- **Her çağrıda kurulan `JSONDecoder`.** Maliyeti önemsiz.

## 11. Dokunma: iyi durumda olan alanlar

- Android `KeystoreSessionStore` (AES-GCM, alan başına AAD, çıkışta anahtar silme).
- İki platformda loglama (token, e-posta, gövde yok) ve TLS ayarları.
- Sosyal giriş nonce kurulumu (Apple, Google, Facebook Limited Login).
- WebSocket kimlik doğrulaması, yeniden bağlanma ve 401'de çıkış.
- İnceleme fotoğrafı akışı (imzalı URL saklanmıyor, 3 MB sınır, EXIF temizliği, `FLAG_SECURE`).
- iOS `AppSessionCoordinator` / `FausCrewCoordinator` flow-ID korumaları ve testleri; `AppRouter`; `AppDependencies`.
- `HouseSessionStore` istek birleştirme ve 30 sn önbellek.
- Oyun ViewModel'leri ve `GameOnlineHost` yaşam döngüsü; ortak lobi/sonuç makineleri.
- HouseTanks sabit fizik adımı, backend fixture'ları ve parity testleri.
- Swift bridge kayıt kilitleri, JNI sürüm kontrolü, R8 keep kuralları.
- Belgelenmiş katalog kararları ve fotoğraf baytlarının JNI'dan geçmemesi.

## 12. İncelenemeyen alanlar

- Backend davranışı (token ömrü, sosyal token doğrulaması, durum geçişleri).
- Cihaz üzerinde performans, bellek ve FPS; release build'de JNI'ın çalışması.
- iOS: `AuthView`, `OnboardingView`, katalog popup'ları ve üç oyun sahnesinin çizim yolları yalnızca tarandı.
- Android: tüm oyun çizicileri ve görsel kaynaklar satır satır okunmadı; bağımlılıklar için güncel CVE taraması yapılmadı.
- Ortak çekirdek: bot arama algoritmalarının tamamı ve Swift/JNI bellek yaşam döngüsünün tamamı.

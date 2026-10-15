# HouseFlow iOS + Android mimari geçiş planı

## Amaç ve çalışma ilkeleri

Bu plan, mevcut iOS uygulamasını çalışır durumda tutarken platformdan bağımsız iş kurallarını tek bir Swift Package içinde toplar ve Android uygulamasını kademeli olarak ekler. İlk ortak modül `HouseFlowCore` olur; başlangıçta tek üretim target'ı yeterlidir. iOS ve Android kullanıcı arayüzleri kendi yerel araçlarıyla (SwiftUI ve Jetpack Compose) çalışır. Platforma özel kalıcı depolama, HTTP/WebSocket, yaşam döngüsü, yön ve çizim işleri adapter'larda kalır.

Geçiş, davranış eşitliğini koruyan küçük adımlarla ilerler. Bir işlev iki platformda da çalışır hale gelmeden iOS'taki mevcut uygulama yolu kaldırılmaz. Mevcut `Documents/PRODUCT.md`, `Documents/DESIGN.md` ve `Documents/Games/README.md` içindeki ürün, görünüm ve oyun davranışı bu plan boyunca referans kabul edilir.

## Kapsam ve anti-hedefler

**Kapsam**

- Kimlik doğrulama, kullanıcı/ev/iş modeli, doğrulama kuralları, servis sözleşmeleri, use case ve ViewModel durumunun uygun parçalarını ortak Swift koduna taşımak.
- SwiftUI uygulamasını Xcode projesinde tutup `HouseFlowCore`'u bir local Swift Package bağımlılığı yapmak.
- Android uygulamasını Gradle/Compose ile ayrı bir platform katmanı olarak eklemek; ilk adımda yalnızca sınırlı bir dikey dilimi uçtan uca geçirmek.
- HTTP, gerçek zamanlı oyun taşıması, güvenli token deposu, tercihler, yerelleştirme verisi, saat, log, yaşam döngüsü, yön ve navigasyon için açık port/adaptör sınırları koymak.
- House Rockets ve diğer oyunlarda simülasyon/kuralları çizim, kontrol, ses ve platform API'lerinden ayırmak.
- Test, CI, toolchain pinleme, ölçüm, geri alma ve geçiş karar kapıları tanımlamak.

**Anti-hedefler**

- Görünür UI, metin, renk, tipografi, boşluk, animasyon, ekran sırası, gezinme, kontrol, onboarding, yön davranışı veya oyun kurallarını bu mimari geçişin parçası olarak değiştirmek.
- SwiftUI'yı Compose ile ortaklaştırmaya çalışmak ya da Android'de iOS ekranlarını taklit eden bir kabuk üretmek. Platformlar kendi yerel UI'larını gösterir; mevcut ürün davranışının karşılığı korunur.
- Birden fazla Swift Package, mikro-modül, genel amaçlı plugin çerçevesi veya baştan tasarlanmış domain katmanı kurmak. Ayrışma ihtiyacı kanıtlanırsa sonraki kararlaştırılmış aşamada yeni target düşünülür.
- Tüm repo'yu tek seferde taşımak, servisleri yeniden yazmak, backend/API sözleşmesini değiştirmek veya eş zamanlı olarak yeni ürün özelliği eklemek.
- Swift'i Android arayüzü, işletim sistemi entegrasyonu veya tüm ağ yığınının sahibi yapmak. Ortak Swift kodu platform UI'sına JNI üzerinden sahip olmaz.
- Bu belge kapsamında kaynak dosyalarını taşımak veya uygulama koduna değişiklik yapmak. Bu, yalnızca hedef mimari planıdır.

## Mevcut repo: okuma sonucu ve sınıflandırma

Repo bugün kökte Swift kaynakları, bir Xcode projesi, asset catalog'ları ve `Documents/` ürün/tasarım notları içeriyor. `Package.swift`, Gradle projesi, Android kaynak ağacı ya da `scripts/` dizini görünmüyor. `HouseFlowApp.swift` SwiftUI uygulamasını kuruyor; `AppDependencies.live` servis bağımlılıklarını birleştiriyor. Servis protokolleri halihazırda test edilebilir bazı seam'ler sağlıyor. Foundation tabanlı model ve oyun dosyalarının bir kısmı ortaklığa aday; `UIKit`, `Security`, `SwiftUI`, `SpriteKit`, `URLSession` ayrıntıları ise platforma özel sınırda kalmalı.

| Mevcut alan / örnek dosyalar | Bugünkü sorumluluk | Hedef sınıf | Geçiş notu |
|---|---|---|---|
| `Models/Auth/`, `Models/House/`, `Models/Chore/`, `Models/User.swift`, `Models/DateFormatting.swift` | API DTO'ları, iş modeli ve dönüştürme | Çoğunlukla `HouseFlowCore` | JSON kodlama anahtarları, tarih biçimleri, opsiyonel alan ve enum raw value'ları sözleşme olarak test edilir. UI'ya özel biçimlendirme ayrı tutulur. |
| `Services/Protocols/ServiceProtocols.swift` | Servis ve depolama protokolleri | Core portları + gerekli platform tiplerinin arındırılması | `URLQueryItem` gibi FoundationNetworking/Darwin uyum farkı oluşturan tipleri ortak sözleşmeden çıkarmak; URL/data tipleri gerçekten gerekli değilse platform-neutral request/response değerlerine çevirmek. |
| `Services/AuthService.swift`, `UserService.swift`, `HouseService.swift`, `ChoreService.swift`, `LocalizationService.swift` | API use case/iş akışları | Core servis/use case | HTTP yürütmeyi port üzerinden kullanmalı; token okumasını her serviste gizli varsaymak yerine dependency graph'ta açık bağlamalı. Taşıma dosya bazında değil bağımlılıklarıyla yapılır. |
| `Services/Network/NetworkService.swift`, `NetworkHTTPModels.swift` | URL oluşturma, Bearer header, JSON decode, HTTP hata eşleme | İstek sözleşmesi core; iOS/Android transport adapter'ları | Mevcut başarı/hata eşleme davranışı golden fixture ile sabitlenir. URLSession yalnızca iOS adapter'da; Android adaptörü aynı sözleşme ve hata modeli sunar. |
| `Services/Network/GameRealtimeCodec.swift`, `GameRealtimeTransport.swift`, `Models/Games/HouseRockets/*Wire*`, `*Realtime*` | WebSocket protokolü, codec ve oturum mesajı | Codec/protokol doğrulaması Core adayı; socket transport platform adaptörü | Frame türü, byte sınırı, uyumluluk ve hata davranışı korunur. Tek receive tüketicisi ve iptal/generation davranışları kaybolmamalı. |
| `Services/KeychainService.swift`, `Services/AppDependencies.swift` | iOS Keychain ve üretim graph'ı | Keychain adapter + platform composition root | Token/hesap depolama kontratı Core'da; iOS Keychain, Android Keystore destekli şifreli storage ayrı. `AppDependencies` iOS root'a dönüşür; Android'in eşdeğer root'u Kotlin'de kurulur. |
| `Services/LocalizationService.swift`, `Models/Localization/*`, `Views/Shared/LocalizedText.swift`, `ViewModels/Stores/LocalizationStore.swift` | Dil kataloğu, metin fetch/cache, UI sunumu | Dil/payload sözleşmesi ve seçim politikası core adayı; OS metin sunumu platformda | Mevcut dil anahtarları ve sunucu payload'ı aynen korunur. UI string lookup platform yüzeyinde olur; core `Text`, SwiftUI veya Android `Context` bilmez. |
| `ViewModels/AuthenticationViewModel.swift`, `AppViewModel.swift`, `ViewModels/Coordinators/*`, `ViewModels/Stores/*` | Durum akışı ve uygulama orkestrasyonu | İş akışı/state parçaları Core; framework bağlama platformda | Önce tek akışta sınır çizilir. `ObservableObject`, Combine, SwiftUI environment gibi iOS tipleri ortak modele taşınmaz. Aynı state transition'ları iki tarafta karakterizasyon testleriyle korunur. |
| `ViewModels/Navigation/AppRouter.swift`, `HouseFlowApp.swift`, `Views/Core/*` | iOS rotaları, root ve lifecycle bağlama | Route niyetleri/kuralları ortak olabilir; navigation host platforma özgü | Mevcut ekran sırası ve geri davranışı sabit kalır. SwiftUI `NavigationStack` ve Android Navigation Compose ayrı uygulamadır. |
| `Views/Authentication/*`, `Views/House/*`, `Views/Dashboard/*`, `Views/Profile/*`, `Views/Shared/*`, `Views/Discover/GamesHubView.swift` | SwiftUI bileşen ve ekranları | iOS `Views/`; Android Compose `ui/` | Kopyalanmaz veya otomatik çevrilmez. Android'de ürün davranışı eşdeğer yerel bileşenlerle kurulur; UI farkı ancak ürün/tasarım kararıyla yapılabilir. |
| `Models/Games/HouseRockets/HouseRocketsSimulation.swift`, `HouseRocketsCourse.swift`, geometri/physics modelleri | Deterministik dünya ve fizik | Core oyun simülasyonu adayı | SpriteKit/UIKit/SwiftUI bağımlılığı bulunmadığı teyit edilir. Sabit timestep, seed, kurallar ve çıktı iki platformda test edilir. |
| `Models/Games/*` oyun DTO/kuralları; `Services/Games/*Session*`, `*Policy*`, `*Codec*`; `ViewModels/Games/*` | Kurallar, oturum, sıra ve sunum dönüşümü | Saf kurallar/oturum protokolü Core; scheduler/input, UI state bağı Core-adapter | Önce House Rockets çekirdeği ve bir basit oyun pilotu; diğer oyunlar kanıt sonrası taşınır. Demo botları/sunucu otoritesi karıştırılmaz. |
| `Views/Discover/Games/*Scene.swift`, `HouseTanksBotController.swift`, `HouseRocketsArtwork.swift`, yön controller'ı | SpriteKit render, touch, çizim, iOS yön API'si | iOS `Platform/` ve `Views`; Android renderer/input platform implementasyonu | Renderer yalnız render-frame tüketir; oyun sonucunu belirlemez. Kontrol görünürlüğü/sunumu mevcut tasarımla eşleşir. |
| `Documents/PRODUCT.md`, `DESIGN.md`, `Games/README.md`, mevcut multiplayer planı | Ürün, UI ve oyun davranışı | Ortak geçiş guardrail'i / docs | Taşıma sırasında güncel ürün kararı değişmedikçe normatif davranış kaynağıdır. |

## Hedef repo ağacı

İlk aşamada var olan iOS dosyaları yerinde kalır. Core'a alınan her dosya bağımlılıkları çözüldükçe taşınır; hedef düzen tüm dosyaları bir defada taşıma talimatı değildir.

```text
HouseFlow/
├── README.md                              # ürün ve iOS/Android geliştirme giriş noktası
├── HouseFlow.xcodeproj/                 # mevcut iOS uygulaması
├── HouseFlowApp.swift
├── Views/                                # mevcut SwiftUI ekranları, kademeli düzenlenebilir
├── ios/
│   └── Xcode/                            # yeni iOS proje düzeni ihtiyacı doğarsa; mevcut proje ilk etapta korunur
├── shared/
│   ├── Package.swift                     # tek local Swift Package
│   └── Sources/HouseFlowCore/             # başlangıçta tek üretim target'ı
│       ├── Domain/                       # ortak modeller ve kurallar
│       ├── Ports/                        # HTTP, storage, clock, logging vb. kontratlar
│       ├── Services/                     # use case / servis orkestrasyonu
│       └── Games/                        # saf simülasyon ve oyun oturum kuralları
├── android/
│   ├── settings.gradle.kts
│   ├── build.gradle.kts
│   ├── scripts/                        # Android toolchain, JNI ve paket kontrolleri
│   └── app/src/main/kotlin/.../
│       ├── ui/                           # Compose ekranları ve bileşenleri
│       ├── viewmodel/                    # lifecycle-aware state holder'lar
│       ├── navigation/                   # Navigation Compose graph
│       ├── platform/                      # adapters, JNI facade, dependency graph
│       └── MainActivity.kt
├── docs/                                  # mimari kararları, port sözleşmeleri, taşıma kayıtları
└── Documents/                             # ürün/tasarım ve bu plan dahil mevcut belgeler
```

`ios/` altına Xcode projesi taşıma zorunluluğu yoktur. İlk taşıma sırasında mevcut `.xcodeproj` konumu, scheme, signing, asset ve kullanıcı workflow'u çalışır halde bırakılır. Fiziksel repo yeniden düzeni ayrı ve düşük riskli karar kapısıdır.

## Modül sınırları ve bağımlılık kuralları

1. **Başlangıç tek target:** `HouseFlowCore` için tek `Package.swift` ve tek üretim target'ı; doğrulama için test target'ı. Klasörler sorumluluğu anlatır, target sayısını artırmayı gerektirmez.
2. **Core bağımlılıkları:** Foundation'da çalışan, UI ve işletim sistemi framework'lerinden bağımsız Swift. `SwiftUI`, `UIKit`, `SpriteKit`, `Security`, `URLSession`, `UserDefaults`, `UIApplication`, `UIWindowScene` ve Android/JNI sınıfları Core'a giremez.
3. **Bağımlılık yönü:** UI → ViewModel/use case → Core port; platform adapter → Core port implementasyonu. Core platform adapter'larını veya UI'ı import etmez. API DTO'ları/domain modelleri mümkün olduğunca Core'da; HTTP request yürütme platformda.
4. **Tek sözleşme sahibi:** Wire DTO ile domain tipi farklı amaçlara hizmet eder. JSON anahtarı/wire enum'u backend sözleşmesidir; domain state ise iş kavramıdır. Gerekli dönüşüm açık mapper'larla yapılır. Platform UI doğrudan wire model üzerinden iş kuralı üretmez.
5. **Concurrency:** Core actor/async sınırları ve değer tipleriyle açıkça `Sendable` uyumunu hedefler. Main-thread UI güncellemesi adapter/ViewModel host görevidir. JNI'den Swift callback ile ana thread'e atlama ortak mantığın parçası olmaz.
6. **Test erişimi:** Core fonksiyonları sahte clock, seed'li random kaynağı ve fake portlarla deterministik doğrulanır. Platform testleri adapter'ı kontrat testleriyle doğrular.
7. **Target bölme kararı:** Core dosyaları gerçek sahiplik/derleme süresi/dağıtım sorunu çıkarana kadar modül bölünmez. Ayrı `HouseFlowGameCore` gibi bir target ancak iOS ve Android build/test sınırlarının somut faydası ölçülürse ADR ile değerlendirilir.

## Platform portları ve adapter tasarımı

| Port (Core sözleşmesi) | iOS adapter | Android adapter | Eşitlik ve güvenlik notu |
|---|---|---|---|
| Auth/session/token | `Security` Keychain | Android Keystore anahtarı ile korunan şifreli preferences/datastore | Mevcut token, e-posta ve doğrulama bekleyen durum anahtarları envanterlenir. Token plaintext `SharedPreferences`'a yazılmaz. Çıkışta temizleme ve cold-start restore eşitliği test edilir. |
| Preferences | `UserDefaults` adapter | DataStore adapter | `hasSeenOnboarding` ve diğer mevcut kalıcı tercihlerin adı/değeri haritalanır; migration tekrar çalıştırılabilir olur. Gameplay gibi yüksek frekanslı state preferences'ta tutulmaz. |
| HTTP transport | mevcut `URLSession` temelli executor | Android `OkHttp` veya mevcut Gradle stack'inde zaten bulunan HTTP client | Core path, method, query, body, token bağlamı, decode/error semantiğini tarif eder. Adapter timeout, cancellation, TLS, header ve status davranışını aynı kontratta uygular. Yeni ağ kütüphanesi ancak mevcut stack incelendikten sonra seçilir. |
| Realtime transport | mevcut `URLSessionWebSocketTask` adaptörü | OkHttp WebSocket veya seçilen HTTP client'ın WebSocket'i | Connect/send/receive/ping/disconnect; tek receive consumer, text frame politikası, iptal, maksimum byte ve erişim iptali eşlenir. Oda/maç kuralları socket sınıfına gömülmez. |
| Localization | mevcut disk cache + SwiftUI metin çözümü | Core payload cache + Android kaynak/Compose çözümü | API'nin dil kodu ve localization key'leri korunur. Key → görünür metin çözümü UI/platform sınırında kalır; fallback ve cache invalidate davranışı iki tarafta aynı olmalı. |
| Clock / timers | `ContinuousClock` ya da kontrollü Foundation clock | `SystemClock`/monotonic source adapter | İş kuralları duvar saatini değil monotonic süreyi isterse port kullanır. Tarih/timezone formatı platform UI'ında; testte fake clock ilerletilir. |
| Random source | seed'li Swift generator adapter / Core seed | JNI kullanmayan seed/command kontratı; deterministik ortak oyun varsa seed ortak çekirdekte tüketilir | Oyun kuralları gizlice global RNG çağırmaz. Aynı seed'in iOS ve Android'de aynı dizi üretmesi gerekiyorsa PRNG algoritması Core'da sabitlenir ve golden vector ile kilitlenir. |
| Logging / diagnostics | unified logging adapter | Android Log adapter | Core yapılandırılmış olay/alanları iletir; token, kişisel veri, ham auth header veya oyun mesajı gibi hassas payload'lar loglanmaz. |
| Lifecycle | SwiftUI scenePhase/app delegate bridge | Activity/process lifecycle bridge | Core'a `active/background` gibi anlamlı olay verilir. Background'da House-Switch durması ve geri dönüşte sessiz ilerlememe gibi mevcut kurallar korunur; UI framework Core'a sızmaz. |
| Navigation | `AppRouter` + SwiftUI navigation | typed route state + Navigation Compose | Ortak katman route intent/state üretebilir; navigation stack, deep link host, back stack işletim platformunda kalır. Mevcut başlangıç route önceliği ve geri davranışı birebir taşınır. |
| Orientation | `GameOrientationController` / UIKit adapter | Android requested orientation/window adapter | İzin/OS kısıtı başarısızlığı ortak sonuç tipine çevrilir. Oyun görünümü terk edilince mevcut yön geri yükleme kuralı uygulanır. Yön kaynaklı UI değişikliği önermek kapsam dışıdır. |

### HTTP ve API adaptörü ayrıntısı

İlk ortaklaştırılacak parça endpoint davranışının karakterizasyonudur: mevcut HTTP başarı aralığı (200–399), API hata zarfı (`message`/`error`), boş/bozuk body, Bearer header, path/query kodlama ve decoding hataları fixture ile kayda alınır. Core, bu davranışlara göre `HTTPRequest`, `HTTPResponse`, `HTTPClient` ve uygulama hata değerlerini tanımlar. Uygun olmadıkça bütün URLSession API'sini taklit eden genel bir ağ çerçevesi yaratılmaz. iOS adaptörü önce aynı iOS çağrılarını çalıştırır; Android adaptörü aynı kontrat testlerinden geçtikten sonra endpoint endpoint devreye girer.

### Swift Android SDK ve dar swift-java/JNI façade

Swift SDK Android'e Swift package kodunu cross-compile etmeyi hedefler; Android UI yine Kotlin/Compose'dur. Resmi başlangıç akışı, Swift toolchain ile Android Swift SDK'nın sürüm eşleşmesini ve Android NDK gereksinimini vurgular. `swift-java` Swift ↔ Java yönlerinde wrapper/source generation seçenekleri sunar; JNI modu Android gibi JVM/ART ortamları için uyumluluk seçeneğidir ve proje aktif geliştirme aşamasında olduğundan API kararlılığı varsayılmamalıdır ([Swift SDK for Android rehberi](https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html), [`swift-java` proje durumu ve JNI modu](https://github.com/swiftlang/swift-java)).

Uygulanabilir sıra:

1. Önce Core'un Android hedefinde JNI olmadan derlenebilen alt kümesini ve resmi SDK/toolchain uyumunu küçük bir spike ile doğrula. Swift Android SDK, NDK, JDK/Gradle ve Android ABI'leri pinlemeden uygulama akışına bağlama.
2. Ortak çekirdekten Kotlin'e yalnızca sürümlenmiş ve küçük bir API sun: ör. `createSession(configurationDTO)`, `dispatch(commandDTO)`, `currentSnapshotDTO()`, `close()`. Oyun dışı işlerde de aynı ilke geçerlidir: operasyon ve sade DTO değerleri.
3. JNI sınırında `String`, sabit genişlikli integer/bool, byte buffer veya versiyonlu JSON DTO gibi kopyalanabilir tipler kullan. Swift generic'leri, `Codable` reflection'ı, associated type protokoller, arbitrary closure, SwiftUI tipi, `URLRequest`, `URLSession`, Swift `Error` nesnesi ve uzun ömürlü callback graph'ını JNI ile dışarı açma.
4. Android platform adapter'ı Kotlin'de kalır. Tercih edilen üretim erişimi `swift-java jextract --mode=jni` tarafından üretilmiş ince wrapper'lardır. Ham `JNIEnv` kullanımı yalnızca wrapper'ın çözemediği ve code review ile gerekçelendirilmiş minimum glue kodudur.
5. Async işi Kotlin coroutine tarafında sahiplen; çağrıya açık operation ID/cancel ile eşleştir. Swift task/thread affinity ve Kotlin lifecycle scope'unu rastlantısal callback ile bağlama. Core snapshot değer olarak döner; UI kendi lifecycle-aware state akışını kurar.
6. Hata kodu ve DTO sürüm alanı belirle. JNI exception yerine tanımlı hata sonucu dön; her çağrıda sınır doğrulaması/mesaj boyutu üst sınırı uygula. Native belleği sahibinde serbest bırak ve iptal sonrası geç callback'leri düşür.
7. Spike geçmezse UI veya API taşımasını JNI sorunu etrafında yeniden tasarlama: saf ortak iş kuralını JVM/Android uyumlu veri kontratıyla daralt, platform adapter'ında uygulama davranışını koru ve karar kapısında yeniden değerlendir.

`swift-java` gereksinimleri sürümlerle değişebilir. Bu nedenle minSdk seçimi, tüm hedef ABI'ler, Android emulator/device desteği ve JNI yükleme davranışı gerçek pilot ortamında doğrulanır. Araç README'si JDK/Swift gereksinimlerini açıklar; burada sürüm numarası sabitlenmez, repo'nun CI'da doğruladığı sürüm daha sonra tek yerden kilitlenir. Swift Android için resmî Swift CI iş akışı da vardır; CI uyumluluk kanıtı olarak kullanılabilir, ürün cihaz/emulator smoke testinin yerine geçmez ([Swift Android dokümantasyonu](https://docs.swift.org/main/documentation/swiftandroid/)).

## Oyun mimarisi: simülasyon, sunum ve cihaz girdisi

Her oyun dört ayrı sorumluluğa ayrılır:

1. **Simülasyon/kural motoru (Core):** Saf state transition; sabit timestep veya adım tabanlı deterministik ilerleme; fizik, çarpışma, eleme, kazanma, skor ve maç sonucu. Renderer veya ekran boyutu bilmez. `HouseRocketsSimulation` ve `HouseRocketsCourse` bunun mevcut en belirgin pilot adayıdır.
2. **Oturum ve uygulama protokolü (Core + port):** `HouseRocketsGameServicing`, demo/online session, komut sıra numarası, revizyon eskimesi, reconnect policy ve snapshot doğrulaması. Sunucu otoritesi ile demo simülasyonu ayrı implementasyon olarak kalır. Network transport sadece mesaj taşır.
3. **Input adapter (platform):** SwiftUI gesture/joystick ve Compose pointer input, ekran koordinatlarını ortak oyun komutuna dönüştürür. Kontrolün görünür olup olmaması, dead zone, sürükleme eşiği, pause/exit davranışı mevcut kuralla aynı kalır. Ses/haptic gibi yeni feedback önerilmez.
4. **Renderer/audio adapter (platform):** iOS SpriteKit sahnesi ve Android renderer ortak `RenderFrame`/snapshot tüketir; frame'den kural kararı çıkarmaz. `HouseRocketsRenderMapper` saf doğrulama/eşleme ise core'a alınabilir. iOS artwork/SpriteKit node'ları ve Android canvas/Compose/drawable katmanı ayrıdır. Oyun audio'su varsa platform servisidir; ortak simülasyon ses API'si çağırmaz.

Render frame oyun kuralının alternatifi değildir: authoritative simülasyon/server snapshot'ından türetilir; yalnız sunum değerlerini, world-coordinate geometriyi ve fazı taşır. `HouseRocketsPresentationCadence` gibi cadence/scheduler katmanları frame üretim sorumluluğuna göre ayrıştırılır, simülasyonun `advance(by:)` kuralına sızmaz. Pause/background/cancel, render döngüsünü platform yaşam döngüsüyle koordine eder ancak sonucu değiştirmez.

House-Switch, House Tanks, RPS ve Lucky Spin sırayla değerlendirilir. RPS/Lucky Spin gibi saf kuralı küçük oyunlar ek ortaklık kanıtı sağlar; House Rockets deterministik geometri/frame pilotudur. SpriteKit sahnesi taşınmaz. House Tanks bot davranışı simülasyondan ayrıştırılmadan çekirdek adayı sayılmaz.

## Somut taşıma matrisi

| Sıra | Bugünkü kaynak | Hedef | Taşıma/uyarlama işi | iOS uyumluluk koşulu |
|---:|---|---|---|---|
| 1 | `Models/Auth/AuthModels.swift`, `Models/User.swift`, `Models/House/*`, `Models/Chore*` | `shared/Sources/HouseFlowCore/Domain/` | API DTO ve domain tiplerini Core'a al; dışarıdan görünürlüğü yalnız gerekli alanlarda aç; JSON/date/enum fixture testleri ekle. | iOS servis ve view'ları aynı modelleri import ederek derlenir; wire davranışı değişmez. |
| 2 | `Models/DateFormatting.swift`, `InviteCodeRules` (`HouseModels.swift`) | Core policy + platform presentation | Invite code normalization/validasyonunu ortak kural yap. UI tarih/number gösterimi platformda; sadece wire tarih parse politikası gerçekten ortaksa core'da. | Girdi/çıktı ve locale davranışı eski iOS ile aynı. |
| 3 | `Services/Protocols/ServiceProtocols.swift` | `Core/Ports/` | `KeychainStoring`, `NetworkServicing` vb. bağımsız portlara böl; UI/platform tipi ve generics/associated-type bridge zorluğunu azaltan value request contract tasarla. | Eski servislerin çağrılma şekli adapter/facade ile korunur. |
| 4 | `Services/Network/NetworkService.swift`, `NetworkHTTPModels.swift` | Core request contract + `ios/.../URLSessionHTTPAdapter`; Android `platform/AndroidHTTPAdapter` | Mevcut davranıştan fixture çıkar; encoder/decoder ayarlarını ve hata map'ini sabitle. Platform yürütücülerini ayrı uygula. | iOS adapter yeni portu kullanır; endpoint çıktısı/status/hata aynı kalır. |
| 5 | `Services/AuthService.swift`, `UserService.swift`, `HouseService.swift`, `ChoreService.swift` | `Core/Services/` | Servisleri Core'da portla çalışır hale getir; endpoint path/DTO ve domain mapping'i tek kaynaktan tut. | Mevcut iOS API akışları adapter arkasında çalışır ve aynı state transition üretir. |
| 6 | `Services/KeychainService.swift`, `AppDependencies.swift` | iOS `Platform/KeychainAdapter`, `ios composition root`; Android Keystore adapter/root | Portu implemente et, mevcut iOS hesap verisini kaybetmeden başla; Android güvenli depolama ve logout temizliği ekle. | Mevcut cihaz token restore/login/logout davranışı korunur. |
| 7 | `LocalizationService.swift`, `LocalizationModels.swift`, `LocalizationStore.swift`, `LocalizationDiskCache` (AppDependencies) | Core language contracts + platform cache/string adapter | Remote katalog sözleşmesi ve fallback/cache invalidation davranışını tanımla. | iOS localization key ve görüntülenen mevcut dil aynı kalır. |
| 8 | `ViewModels/AuthenticationViewModel.swift`, `AppViewModel.swift`, auth/session stores | Core use case/state + SwiftUI-facing iOS adapter | Önce auth alt kullanım durumunu taşı; `ObservableObject` ve Combine/iOS bindings'i iOS'ta tut veya adapter modeline yansıt. | Auth ekran akışları, hata metni anahtarları, başlangıç route önceliği ve buton sonuçları değişmez. |
| 9 | `ViewModels/Navigation/AppRouter.swift`, coordinators | Core route intent (gerekiyorsa) + iOS Router/Android nav | Route geçiş kurallarını saf fonksiyon halinde ayır; stack uygulamasını platformlara bırak. | Görünen ekran sırası ve geri/iptal davranışı unchanged. |
| 10 | `Models/Games/HouseRockets/*` saf geometri ve `HouseRocketsSimulation.swift` | `Core/Games/HouseRockets/` | Saat/RNG ihtiyacını enjekte et; simülasyondan renderer ve platform tipi bağımlılıklarını çıkar; golden scenario üret. | Mevcut render DTO'ya aynı snapshot/frame girdisi için aynı sonuç. |
| 11 | `Services/Games/HouseRockets/*Session*`, reconnect/policy/acceptance ve `GameRealtimeCodec.swift` | Core session/protocol + `ios/URLSessionRealtimeAdapter` + Android socket adapter | Codec ve policy'yi saflaştır; socket transport portu uygula; online snapshot doğrulamasını ortaklaştır. | Reconnect, stale revision, iptal ve hata sonucu mevcut iOS oyunuyla eşleşir. |
| 12 | `HouseRocketsRenderMapper.swift`, render modelleri, `PresentationCadence.swift` | Mapper/frame contract Core; cadence adapter'a göre | Snapshot→frame dönüşümünü renderer'dan ayır; cadence'i UI render hızına bağlı platform işi tut. | SpriteKit sahnesinin tükettiği frame üretimi ve görünür oyun aynı. |
| 13 | `Views/Discover/Games/HouseRockets/*Scene.swift`, `HouseRocketsArtwork.swift` | iOS `Views/Games/HouseRockets/`; Android renderer `platform/` veya `ui/games/` | Taşıma yalnız iOS klasör düzeni ihtiyacı olduğunda; Android renderer ayrı kurulur. | Aynı alan, parallax, input eşiği, HUD, pause/result ve yön akışı. |
| 14 | `HouseSwitch`, `RPS`, `LuckySpin`, `HouseTanks` model/service/viewmodel/view grupları | Sırasıyla Core policy/sim, UI ve platform adapter | Her oyunu kendi geçme kriteriyle birer dikey dilim olarak ele al; `HouseTanksBotController` çizim ve bot kuralı açısından ayrıştırılmadan taşınmaz. | Oyunun mevcut `Games/README.md` kuralları test oracle olur. |
| 15 | `Services/Games/General/GameOrientationController.swift`, `HouseFlowApp.swift`, app delegate/scene lifecycle | iOS platform adapter; Android platform adapter | Core'a sadece intent/sonuç portu; OS çağrıları platformda. | Landscape gereksinimi, başarısızlık görünümü ve çıkışta geri dönüş değişmez. |
| 16 | `Views/**`, `Views/Shared/DesignSystem.swift`, `LocalizedText.swift` | iOS `Views/`; Android `ui/` | Dosyaları otomatik ortaklaştırma yok; gerekiyorsa iOS grup taşıması ayrı commit/diff ve aynı kaynak dosyalarla. Android karşılığı tasarım sistemine göre inşa edilir. | Guardrail'ler ve görsel/etkileşim baseline'ı sağlanır. |

## Küçük, geri alınabilir geçiş fazları

| Faz | Görevler ve teslimat | Planlanan doğrulama | Çıkış kriteri / geri dönüş noktası |
|---|---|---|---|
| 0. Baseline ve sınır keşfi | Repo/CI/Xcode scheme/API endpoint, toolchain, mevcut test ve cihaz destek envanteri; UI/oyun senaryosu listesi; karar kayıtları. Kod taşınmaz. | Mevcut otomasyonun durumu kaydedilir; kritik akışlar elle gözlenebilir checklist olur. | Her auth/house/dashboard/game akışının beklenen davranışı yazılı; belirsiz backend sözleşmesi açık risk olarak kayıtlı. Devam kararı yoksa yalnız keşifte durulur. |
| 1. Core package iskeleti | `shared/Package.swift`, tek `HouseFlowCore` target + test target, mevcut iOS projesine local package referansı. | Package build/test ve iOS app scheme CI'da çalışır; dosya taşınmadığı için davranış riski yok. | iOS app aynı açılış ve scheme ile çalışır. Package entegrasyonu sorun çıkarırsa referansı kaldırmak yeterli. |
| 2. Saf modeller ve karakterizasyon | User/auth/house/chore wire DTO'ları ve saf validasyonlardan küçük grup; fixture ve serialization/error baseline. | Unit/fixture testleri iOS/macOS host'ta; iOS build pipeline. | API JSON şekli, enum/date ve kurallar aynı; iOS ekranları değişmemiş. Hatalı model grubu eski konumda tutulup faz daraltılır. |
| 3. Port ve iOS adapter geriye uyumlu geçiş | HTTP, secure storage, preferences, localization için Core kontratı; mevcut iOS servislerini adapter'a bağla. | Her port için fake kontrat testi, endpoint fixture ve login/restore/logout smoke checklist. | Mevcut iOS akışları yeni port arkasında aynı; port geçişi tek tek geri alınabilir. |
| 4. Bir dikey iş akışı pilotu | Auth use case/state'in dar kapsamı; SwiftUI view aynı kalır. Core dependency graph ve iOS composition root. | State transition testleri + auth senaryoları (başarılı/başarısız/iptal/offline) doğrulanır. | UI diff'i yok; hata ve başlangıç route davranışı aynıdır; ölçülebilir sahiplik avantajı gösterilir. Aksi halde ortaklığı model/kuralla sınırla. |
| 5. Android toolchain/JNI spike | `android/` Gradle skeleton, Swift SDK cross-compile, ABI library load, minimal JNI ping/value roundtrip. Kullanıcı akışı eklenmez. | CI veya disposable emulator/device üzerinde native library yükleme, çağrı, cancel/lifecycle ve minimum API denemesi; startup/size baz ölçüsü. | Pinlenebilir, tekrarlanabilir build ve desteklenen API/ABI listesi; boyut/startup bütçesi onaylanır. Geçmezse Android'i Kotlin'de tutup JNI kararını daralt/erte. |
| 6. Android platform adaptörleri | Güvenli storage, preferences, HTTP ve localization adapter kontratları. Önce auth gerektirmeyen bir endpoint veya fixture; gizli değerler loglanmaz. | Aynı fixture kontrat testleri, TLS/timeout/cancel, storage reopen/logout testi, düşük ağ smoke. | Eşdeğer HTTP hata ve auth davranışı; token yalnız güvenli adapter'da. Tek adapter başarısızsa o adapter geri alınır. |
| 7. Android ilk UI dikey dilimi | Compose auth veya daha küçük karar verilen ilk gerçek ekran-akışı; `viewmodel/`, typed navigation ve mevcut ürün akışı. | Akış checklist, erişilebilirlik/klavye/sistem back gözlemi, mevcut metin ve geçişlerin tasarım review'u. | İki cihaz boyutunda tamamlanabilir auth akışı, backend ile aynı sonuç; görünür ürün davranışı için onaylı baseline. |
| 8. Küçük saf oyun pilotu | RPS veya Lucky Spin saf kuralları/seed/time portları, Android renderer/UI'dan önce. | İki platformdan aynı vektör/seed ve kural örnekleri; reset/cancel testi. | Aynı sonuç; oyun service contract ve UI dışı olma kanıtı. Başarısızlık tüm oyunları taşımayı durdurur, çekirdek ayrımı tekrar değerlendirilir. |
| 9. House Rockets simülasyon pilotu | Sim/course/mapper/snapshot Core; iOS SpriteKit mevcut frame ile beslenir; Android render yalnız sim snapshot'ı tüketir. | Deterministik senaryo, frame golden, input-to-command ve pause/resume; iki renderer'ın iş kuralı çalıştırmadığı review. | iOS oyun davranışı aynı; Android pilotunda aynı world state ve sonuç. Görsel farklılık baseline dışındaysa port durdurulur. |
| 10. Realtime ve kalan oyunlar | Socket adapter, reconnect/online House Rockets, sonra diğer oyunlar tek tek kanıtla. | Transport contract, reconnect/loss/cancel, offline server-fixture veya fake, oyun bazlı karar testleri. | Hata/reconnect semantiği aynı ve pilot ölçüleri bütçede. Başarısız online adapter tüm oyunu geriye taşımaz; online aşama ertelenir. |
| 11. Düzenleme ve sadeleştirme | Gerekirse Xcode kaynaklarını `ios/` altında düzenle, eski geçici facade ve kopyaları kaldır, docs güncelle. | CI, repo diff review, uygulama smoke ve kaynak sahipliği haritası. | Eski yol artık gereksiz kanıtlı; silinen her parça eşdeğer yol/test ile değişmiş. Son aşama gereksizse uygulanmaz. |

## Pilot geçme / kalma kriterleri

**Geçer:** Android JNI spike tekrarlanabilir biçimde CI'da cross-compile olur; desteklenen ABI'lerde emulator veya cihazda native library yüklenir; DTO roundtrip, hata, cancel ve lifecycle testleri stabil geçer. Saf oyun pilotunda sabit girdiler iki platformda aynı state/result üretir. iOS davranış checklist'i, auth/API hata eşitliği, startup/memory/AAB/JNI/frame pacing bütçeleri kabul edilir. Swift-Java bağımlılığı pinlenebilir ve wrapper code review edilebilir.

**Kalır:** Gerekli minimum Android API/ABI'de native load veya wrapper üretimi tekrarlanamaz; CI'da pinli toolchain elde edilemiyor; JNI async/cancel bellek güvenliği güvenceye alınamıyor; iOS regresyonu veya görünür UX farkı oluşuyor; startup/AAB/memory artışı kararlaştırılan sınırı geçiyor; debug/release davranışı ayrışıyor. Kalma halinde ortaklığı saf model/kural ve DTO'larla sınırla, etkilenen native entegrasyon özelliğini sonraki faza al, iOS'taki doğrulanmış yolu geri getir. Kalma, tüm Android uygulamasını terk etmek anlamına gelmez.

Karar öncesi gerçek başlangıç ölçümü alınır. İlk ölçüm sonrasında geçici bütçe belirle; örnek başlangıç eşikleri: JNI kullanan akışta p95 ilk interaktif hale gelme artışı ≤100 ms, cold-start artışı ≤5%, uygulama boyut artışı ≤8 MB/ABI birleşik dağıtımda hedef bütçe içinde, oyun simülasyonunda p95 frame CPU işi <8 ms 60 Hz cihazında ve bellek artışı <10 MB. Bunlar ürünün mevcut baseline'ı bilinmeden garanti değildir; Faz 0 ölçümüyle ekipçe kabul edilip sabitlenir. AAB dağıtımında ABI split gerçek teslim boyutuyla değerlendirilir.

## Test stratejisi (çalıştırma değil, geçiş tasarımı)

- **Shared unit:** Invite code, domain policy, error mapping, state transition, reconnect policy, DTO mapping ve validation. Saat ve random seed enjekte edilir. Network/OS/renderer yok.
- **Contract/fixture:** Mevcut API request-response body, JSON anahtarları, status sınıfı, empty/malformed body, query/header, websocket text frame ve uyumluluk sürümü. Aynı fixture suite iki platform adapter'ının ortak davranışını sınar.
- **Adapter tests:** Fake HTTP/socket, timeout/cancel/disconnect, status/error mapping, TLS konfigürasyonu; Keychain/Keystore save-load-delete ve logout; preference eski değer migration'ı; localization cache expiry/invalidation.
- **Deterministic game tests:** Seed'li RNG ve fake clock; `HouseRocketsSimulation` sabit command/tick ile golden snapshot; contact, course seam, pause, behind-camera elimination, end tie ve reconnect/stale sequence; aynı vektör iOS ve Android JNI facade'den çağrılır.
- **UI/ViewModel tests:** Başlangıç route önceliği, auth state ve navigation intent. iOS görsel ekranları core testi değildir. Compose ve SwiftUI smoke, etkileşim checklist'ine göre platformda yürütülür.
- **JNI tests:** DTO sürümü/invalid input, max payload, exception/error mapping, cancellation ve tekrar çağrı; debug ve release; process/activity recreate sonrası kaynak sahipliği; desteklenen her ABI/API uçlarında load smoke.
- Testler, platform UI'nın görünüşünü değiştirmenin bahanesi olarak kullanılamaz. Screenshot ve senaryo baseline'ı fark gösterirse önce nedeni belirlenir; ürün/tasarım onayı olmadan uyumsuzluk kodla kabul edilmez.

## Ölçüm planı

| Ölçüm | Nasıl ve nerede | Kayıt / geçiş kapısı |
|---|---|---|
| Startup | iOS cold/warm launch; Android `StartupTimingMetric`/Macrobenchmark veya eşdeğer release ölçümü; native library load süresini ayrı span olarak ölç. Birden çok tekrar, aynı cihaz/build koşulu. | Faz 0 median/p95 baseline; JNI init payı ve toplam cold-start artışı. Geçici bütçeyi pilot öncesi onayla. |
| Bellek | iOS Allocations/MetricKit profili; Android PSS/native heap; idle, login, oyun başlangıcı, oyun sonu ve background/foreground noktaları. | Süreç tepe belleği ve native heap farkı; detach/close sonrası sızıntı eğrisi. Oyun oturumu kapatılınca native session release doğrulanır. |
| AAB / native boyut | release AAB ve ABI başına `bundletool` ile cihaz teslim boyutu; `.so`, JNI wrapper ve Swift runtime payı raporu. | Kurulu cihaz download size ve her ABI için native boyut; split/packaging ayarı karar kapısı. Tek birleşik AAB dosya boyutu kullanıcı yükünü temsil etmeyebilir. |
| JNI overhead | gerçek pilot operasyonlarında çağrı sayısı, kopyalanan byte, p50/p95 ve allocate/free miktarı; mikrobench tek başına yeterli değil. | Çağrı başına küçük granüler API; frame başına JNI çağrısı yok. Renderer 60/120 Hz ise mümkün olduğunca tek snapshot/command batch sınırında kalır. |
| Ağ | aynı test backend/fixture, payload, cihaz ve ağ koşulunda request p50/p95, timeout/cancel, reconnect süreleri ve hata sınıfları. | URLSession ve Android adapter sonuçları request semantic eşitliği; token/header/log sızıntısı olmaması. |
| Recomposition / UI yükü | Android Compose compiler metrics veya Layout Inspector; oyun için `FrameTimingMetric`/Perfetto; iOS Instruments/Hitches. | Snapshot güncellemesinin gereksiz tüm ekran recomposition'ına yol açmaması; oyun world frame ayrı UI state'inden izlenir. UI değişikliği yapmadan state granularity iyileştirilir. |
| Frame pacing | release build, hedef düşük-orta seviye Android cihaz ve referans iPhone; sabit senaryoda frame time p50/p95/p99, jank ve dropped frame. | 60/90/120 Hz cihazlarda eşit sim tick ve stabil çizim; simülasyon render FPS değişince kural sonucu değişmez. |

Her ölçüm raporu cihaz/model/OS, app commit, toolchain, build variant, test senaryosu ve tekrar sayısını taşır. Debug build ölçümü release bütçe kapısı olarak kullanılmaz. Telemetri kişisel veri veya oyun içeriği içermez.

## CI, toolchain pinleme ve repo otomasyonu

- Android'e özgü küçük doğrulama işleri `android/scripts/` altında tutulur: toolchain pin kontrolü, JNI binding ve native paket içeriği. Gelecekte platformlar arası bir yardımcı araç gerekirse ayrı konumlandırılır. Script'ler iş akışını saklamaz; okunur, başarısızlıkta non-zero çıkar.
- `shared/Package.swift` sürüm kuralı net ve reproducible olur. Swift Android SDK'nın beklediği Swift toolchain ile **tam eşleşmesi** gerekir; NDK, JDK, Gradle wrapper, Android Gradle Plugin, Kotlin, Compose BOM ve Android min/target SDK sürümleri dosya/env kaynağında pinlenir. Güncel sürüm seçimi Faz 0'da resmi kaynak/CI uyumlulukla yapılır; bu plan sürüm numarası tayin etmez.
- Android Gradle wrapper checksum'ı ve bağımlılık verification/lock mekanizması açılır. Swift Package resolve pin'i CI tarafından kontrol edilir. Xcode/iOS deployment target ve scheme de mevcut CI koşuluna sabitlenir.
- CI sırası: format/static checks → Core host unit/contract → iOS simulator compile/test pipeline → Android Kotlin/Gradle unit → Swift Android cross-compile (tüm hedef ABI) → JNI instrumentation smoke → release AAB size/native report. Ağ/credential gerektiren backend integration testleri ayrı ve secrets-safe job olur.
- Cache key'leri toolchain/SDK/lock checksum'larını içerir. Cache hit build'i tekrarlanabilirlik doğrulamasının yerine geçmez. PR artifact'ı test raporu, ABI listesi, AAB teslim boyutu ve JNI ölçümünü içerir.
- İlk fazlarda Android toolchain/JNI job'u advisory olabilir; pilot kapısı geçildikten sonra required check yapılır. iOS CI her fazda required kalır. CI kırıldığında son yeşil pilot/artifact saklanır; platform bazında rollback mümkün olur.

## Riskler, geri alma ve karar kapıları

| Risk | Erken sinyal | Azaltma / rollback |
|---|---|---|
| Swift Android SDK / `swift-java` gelişmekte ve sürüme duyarlı | farklı host/CI'da codegen veya runtime farkı | SDK/toolchain/JDK/NDK pinle, küçük JNI spike, generated code check-in/generation politikası belirle; geçmezse native bridge'i sonraya bırak. |
| JNI sınırı gereğinden genişler | çok sayıda küçük callback, generic/callback API, debug edilmesi zor stack | Dar operation + DTO API; UI/network/platform işini Kotlin'e bırak; facade'i tek modülde tut. |
| iOS kullanıcı davranışı kayar | başlangıç route, async hata, back, orientation veya oyun sonucu farkı | karakterizasyon/fixture/smoke baseline; iOS adapter'ını eski yola döndürecek seam; PR başına tek sorumluluk. |
| Token/preferences migration veri kaybı | kullanıcı tekrar giriş ister veya pending verification silinir | iOS depolama biçimine dokunmadan devam et; Android ilk kurulum migration'ı atomik/idempotent; temizleme testleri. Rollback app sürümü destekleyecek kadar eski değerleri koru. |
| Backend davranışı iki client'ta ayrışır | hata zarfı/encoding/query/status farkı | paylaşılan contract fixture; server contract net değilse endpoint geçişini durdur, tahmini düzeltme yapma. |
| Swift ve Kotlin arasında değer kopyalama maliyeti | JNI p95, allocation veya GC/frame spike | frame başına geçiş yapma, batched snapshot/command; ölçüme göre sadece hesap yoğun ve saf fonksiyonu paylaş. |
| Oyun simülasyonu çizim katmanına bağlı kalır | renderer kurala veya sonuç seçimine karar verir | simülasyon test oracle'ı; frame tek yönlü veri; SpriteKit portundan önce iOS karakterizasyonu. |
| Tek target büyür | build/test yavaşlığı veya görünür bağımlılık karmaşası | önce klasör/erişim ve test düzeni; target bölmeyi ölçüm ve ADR ile gerekçelendir. |
| Android UI eşitliği yanlış anlaşılır | piksel piksel iOS kopyası yapılması veya etkileşim farklılaşması | platform-native çizim; eşitliği ürün davranışı, metin, kontrol ve state üzerinden değerlendir; görsel tasarım kararı ayrı. |

**Geri alma ilkesi:** Her fazda platform çağrısı tek composition root üzerinden yeni adapter'a geçer; önceki adapter, aynı portu sağladığı sürece kısa süre tutulabilir. Fazlar ayrı küçük PR/commit'lere ayrılır. Bir Android fazı rollback'i Xcode app'i etkilemez. Bir iOS Core adaptasyonunda regresyon olursa AppDependencies eski iOS servisini seçebilir; ortak model değişiklikleri ancak wire-compatible olduğu doğrulanırsa korunur. Geri alma tamamlanmadan eski yolun kodu silinmez.

**Karar kapıları:** (1) Core'da Android'e uygun yüzey, (2) SDK/JNI spike ve minSdk/ABI desteği, (3) güvenli auth+HTTP adapter kontratı, (4) Android ilk UI dikey dilimi ve UX paritesi, (5) saf oyun deterministik paritesi, (6) House Rockets ölçüm/oyun paritesi, (7) realtime çevrim içi kararlılığı, (8) olası repo/Xcode yeniden düzeni. Her kapıda ürün davranışı, ölçüm raporu, test kanıtı ve açık risk sahibi belirtilir.

## Tahmin (kişi-gün)

Tahminler bir uygulama geliştiricisinin gün başına yaklaşık 6 saat odaklı işe dayalıdır; backend değişikliği, büyük ürün revizyonu veya tasarım kararı içermez. Android UI kapsamı mevcut ekran ve oyun sayısı nedeniyle ana maliyet kalemidir. İlk basit release sonrası tekrar değerlendirilmelidir.

| İş grubu | Tek geliştirici | İki geliştirici takvimi | Not |
|---|---:|---:|---|
| Baseline, ADR, CI/toolchain araştırma | 3–5 gün | 2–4 gün | Bir kişi iOS baseline, diğeri toolchain keşfini paralel yapabilir. |
| Tek Swift Package + modeller/port + iOS adapters | 8–14 gün | 6–10 gün | Geriye uyumlu iOS refactor; test fixture kapsamı belirleyici. |
| Swift Android SDK/JNI spike + CI kararlılığı | 5–10 gün | 4–8 gün | Host CI, ABI/minSdk ve araç kararlılığı belirsizlik payı yüksek. |
| Android platform adapter (auth/storage/http/localization/lifecycle) | 10–18 gün | 7–12 gün | Güvenlik ve API davranışı eşitliği önemli. |
| Android Compose auth/house/dashboard temel dikey dilimleri | 20–35 gün | 14–24 gün | UI çeşitliliğine ve backend edge case'lerine göre. |
| Saf oyun, House Rockets, input/render ve realtime | 20–35 gün | 14–24 gün | İki renderer, pacing, multiplayer reconnect dahil. |
| Kalan oyunlar, release/telemetry/accessibility polish | 12–24 gün | 9–17 gün | Gerekli oyun/ekran kapsamı ürün önceliğiyle sınırlandırılmalı. |
| **Toplam ürün paritesi** | **78–141 gün** | **56–99 takvim günü** | İki geliştiricide ikinci geliştirici uygun Android/UI/API deneyimine sahip ve ortak karar beklemeleri düşük varsayılmıştır. |

İki geliştiricinin aynı Core dosyaları veya aynı oyun üzerinde paralel çalışması çakışma ve review maliyeti üretir. Verimli ayrım: bir geliştirici Core/iOS uyumluluğu, diğeri Android adapter/UI; ortak port sözleşmesi faz öncesi birlikte sabitlenir. Dış beta veya tüm iOS/Android özelliklerinin tam paritesi kapsamdaysa alt sınır hedef plan olarak kullanılmamalıdır. Daha küçük başlangıç için auth + tek ev/dashboard dilimi ve bir saf oyunla release verip kalan oyunları kullanım/veriyle sıraya koymak mantıklıdır.

## UX/UI koruma guardrail'leri

- `Documents/PRODUCT.md`, `Documents/DESIGN.md`, oyun davranışları için `Documents/Games/README.md` ve ilgili mevcut ürün belgeleri ekran içeriği, kurallar, metin, görsel hiyerarşi, kontrol ve motion için başlangıç oracle'ıdır.
- Aynı auth/signup/verification/house/dashboard/profile/discover akışlarının ekran sırası, başlık/gövde metni anahtarları, hata/empty/loading sonuçları, etkileşim, kontrol hit-area'sı, klavye davranışı ve back/cancel akışı değişmeden kalır.
- iOS görünüşü Core taşıma PR'sinde değişmez; Core entegrasyonunda mevcut SwiftUI view ağaçları ve modifier'lar mümkün olduğu kadar aynen kalır. Refactor ile birlikte “iyileştirme” yapılıp regresyon kaynağı belirsizleştirilmez.
- Android kendi platformunun metin ölçekleme, sistem back, klavye, erişilebilirlik ve navigation beklentilerini uygular. Davranış ve içerik eşdeğerliği istenir; iOS piksel ölçülerinin Android'e kopyası istenmez.
- Oyun UI'sında mevcut briefing, kontrol başlangıç alanı/eşiği, joystick görünürlük kuralı, pause, lifecycle, sonuç, portrait/landscape gate, hız alanı/engel fiziği ve kazanma/eleme kuralı değişiklik dışıdır.
- Her ekran/oyun için temel boyut ve kritik state'lerde screenshot/checklist baseline alınır. Renk, font, spacing, motion, localization anahtarı veya görünür metin diff'i mimari taşıma PR'sinde beklenmedik değişiklikse merge edilmez; ürün gerekçesi ve ayrı onaylı değişiklik gerekir.
- Yeni görünür ayar, kullanıcı etkileşimi, özelleştirme veya platforma özel ürün kuralı bu geçişin kapsamına eklenmez. Adaptörler mevcut davranışı sağlar.

## Definition of Done

- iOS uygulaması `HouseFlowCore` local package ile aynı başlangıç ve ekran akışlarını sürdürür; geçişte onaysız görünür UX/UI veya oyun davranışı değişikliği yoktur.
- Tek başlangıç Swift Package/üretim target'ı vardır; her import ve platform portunun sahibi açıkça belgelenmiştir.
- Core'daki iş kuralı/DTO sözleşmeleri fixture ve deterministic testlerle doğrulanır; HTTP, secure storage, localization, lifecycle, navigation, orientation ve clock/log portlarının iOS/Android adapter'ları kontrat testlerine sahiptir.
- Android minSdk, target SDK, ABI, Swift SDK/toolchain, NDK, JDK/Gradle/Kotlin ve iOS deployment target CI tarafından pinned ve raporlanır.
- JNI yüzeyi küçük, versiyonlu ve değer/komut tabanlıdır; native kaynak yaşam döngüsü, hata, cancellation, payload limiti ve güvenli token saklama testlenmiştir.
- Oyun simülasyonu render/input/audio bağımlılığı olmadan deterministic çalışır; online server authority demo kuralından ayrıdır; her iki renderer sadece state sunar.
- Startup, bellek, teslim AAB boyutu, JNI, ağ, recomposition ve frame pacing raporları kabul edilmiş bütçe ile karşılaştırılır.
- Her geçiş fazı geri alınabilir; eski yol yalnız eşdeğer test ve adapter yolu varken kaldırılmıştır.
- CI iOS ve Android test/build katmanlarını, Android Swift cross-compile/JNI smoke ve release size ölçümünü kapsar.
- README/docs repo'nun gerçek build, test ve release girişlerini, platform adapter sınırlarını ve açık kısıtlarını anlatır.

## İlk 13 görevlik backlog

1. Repo içindeki mevcut Xcode scheme, iOS deployment target, API base URL/env, secure storage key'leri, test suites ve CI job envanterini yaz.
2. Auth, onboarding, house selection, dashboard, profile ve her oyun için mevcut UI/interaction/lifecycle checklist'i çıkar; tasarım/ürün belgelerine bağla.
3. HTTP success/error/query/encoding ve localization API örneklerinden fixture seti oluştur; belirsiz backend alanlarını listele.
4. Android destek hedefi (minSdk, ABI, cihaz sınıfı) için ürün varsayımlarını belirle; native SDK desteğine bağlı bu varsayımı Faz 5 kapısında doğrula.
5. Baseline iOS startup, idle/game memory ve House Rockets frame pacing ölçümlerini CI/cihaz build'iyle kaydet; kabul bütçesi taslağını ekipçe belirle.
6. `shared/Package.swift` tek `HouseFlowCore` target + test target olarak ekle; Xcode projeye local package referansı bağla.
7. Auth/user/house/chore model fixture testlerini Core'da kur; ilk küçük DTO grubunu taşı ve iOS call site'larını yeni modüle bağla.
8. `InviteCodeRules` ve uygun saf tarih/wire parse kurallarını platformdan ayır; eski beklenen sonuçları testle.
9. `HTTPClient` request/response ve hata portunu tasarla; generic URLSession API'sini Core'a kopyalamadan mevcut `NetworkService` davranışını fixture ile sabitle.
10. iOS URLSession adapter'ını yeni porta bağla; bir auth endpoint'i üzerinden eski-yeni sonuç eşitliğini doğrula, sonra kalan servisleri endpoint gruplarıyla geçir.
11. Token, preferences ve localization portlarını tanımla; iOS Keychain/UserDefaults/cache implementasyonlarını geriye uyumlu adaptör olarak ekle.
12. Swift Android SDK + NDK + `swift-java` JNI minimal roundtrip için pinlenebilir Gradle sample/spike ve CI job'u oluştur; min API/ABI load, cancel ve AAB boyutunu raporla.
13. Geçme kriterleri sağlanırsa Android güvenli storage/HTTP adapter'ını ve ilk Compose auth dikey dilimini başlat; aksi halde Android UI işini Kotlin adapter seçeneğiyle ilerletip JNI riskini dar karar kaydına al.

## Kaynaklar ve notlar

- [Swift SDK for Android: Getting Started](https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html) — cross-compile bileşenleri ve toolchain/SDK sürüm eşleşmesi.
- [Swift Android Documentation](https://docs.swift.org/main/documentation/swiftandroid/) — build, package portlama ve Android entegrasyon kılavuzları.
- [`swift-java`](https://github.com/swiftlang/swift-java) — Swift/Java source generation, JNI modu, sürüm gereksinimleri ve aktif geliştirme notu. Seçim/entegrasyon tarihinde resmi gereksinimleri tekrar doğrula.

Bu belgede tahmini efor ve performans eşikleri planlama başlangıç değerleridir. Faz 0 baseline'ı ve Android spike kanıtı kararların yerini alır.

---

## Detaylı geliştirme fazları ve takip planı

Bu bölüm, faz planını, kararları, ilerlemeyi ve doğrulama kanıtlarını tek yerde tutan takip kaynağıdır. Fazlara özel ayrı Markdown raporları/checklist'leri oluşturulmayacak; sonuçlar ve açık işler ilgili faz kartına işlenecek. Mevcut ürün davranışı ve UX/UI guardrail'leri aynen geçerlidir. “Dokunulacak” listeleri planlanan sınırı gösterir; her dosyanın tek PR'da taşınması gerekmez. Faz başında kapsam netleştirilir, sonunda kanıt eklenmeden faz `Done` yapılmaz. Test/build burada yalnızca gelecek uygulama işinin doğrulama planıdır; bu belgeyi hazırlarken çalıştırma anlamına gelmez.

### Faz durumları ve takip biçimi

Durum değerleri yalnızca `Not started`, `In progress`, `Blocked`, `Done` olsun. “Blocked” kaydında engel, sahibi, etkisi ve yeniden başlama koşulu yazılır; sessizce “Done” veya sonraki faza taşınmaz.

Her faz kartında şu alanlar tutulur:

| Alan | Kayıt |
|---|---|
| Faz / durum | `Faz N — Not started` (başlangıç değeri) |
| Owner | İsim; tek karar/sorumluluk sahibi. İki geliştiricide işi yapan ve review eden ayrıca yazılır. |
| Başlangıç — bitiş | `YYYY-MM-DD — YYYY-MM-DD`; henüz başlamadıysa boş veya `—`. |
| Karar kaydı | İlgili ADR kimliği/linki; karar yoksa `TBD`, gereken karar ve karar sahibi belirtilir. |
| Kanıt linki | PR, CI run, test/ölçüm raporu veya UX checklist'i; kanıt oluşana kadar `—`. |
| Kalan risk / engel | Kısa açıklama, etki, owner ve kapatma şartı; yoksa `Yok`. |

Haftalık raporda yalnız değişen fazlar güncellenir. Faz sahibinin işi: checkbox'ları PR ile ilişkilendirmek, kanıtı eklemek ve geçiş kapısı kararını kaydetmek. Owner veya tarih belli değilken takvim tahmini taahhüt kabul edilmez.

### Bağımlılık sırası ve paralellik

```text
F0 Baseline
  └─ F1 Package/test altyapısı
      └─ F2 Saf model ve DTO sözleşmeleri
          └─ F3 Portlar + iOS adapter'ları
              └─ F4 Uçtan uca iOS pilotu
                  ├─ F5 Android shell + Swift/JNI spike
                  │   └─ F6 Android adapter'ları
                  │       └─ F7 İlk Android dikey feature
                  │           └─ F8 Kalan ürün feature dalgaları
                  └─ F9 Basit oyun pilotu ─ F10 Oyun motorları / renderer sınırları
                                          └─ F11 Realtime dayanıklılık
F7–F11 ──────────────────────────────────└─ F12 Hardening/release
F12 sonrası karar ────────────────────────── F13 İsteğe bağlı repo düzeni
```

- **Sıkı kritik sıra:** F0 → F1 → F2 → F3 → F4 → F5 → F6 → F7 → F8, ürün Android paritesi için ana kritik yoldur. F5 geçiş kapısı JNI destek kararını verir; F6/F7 bu kanıt olmadan başlamaz.
- **Paralel olabilecek işler:** F0'da biri iOS akış/ölçüm envanteri çıkarırken diğeri Android toolchain gereksinimlerini araştırabilir; tek owner aynı anda kapsam/karar kapısını yönetir. F4'ten sonra, aynı Core dosyalarına dokunmayan geliştiricilerden biri auth/house adapter'ları (F6–F8), diğeri saf oyun test/renderer ayrımı (F9–F10) üzerinde çalışabilir. F11, oyun portu ve transport portları kararlı olunca başlar. F12 release hazırlığını F8/F11'in tamamlanan dilimleriyle kademeli başlatabilir; son kapı ikisi de geçmeden kapanmaz.
- **Paralellik sınırı:** Port sözleşmesi/DTO değişikliği tek owner tarafından koordine edilir. Aynı adapter, `AppDependencies` composition root'u veya oyun simülasyon dosyası iki PR'da eşzamanlı değiştirilmez. Bağımlılık sırf takvimi hızlandırmak için öne çekilmez.
- **F13 bağımsız ve isteğe bağlıdır:** Teknik geçişe bağımlı bir başarı ölçüsü değildir. F12 stabil olduktan ve fiziksel düzenin günlük geliştirme/CI'ya faydası gösterildikten sonra ayrı karar alınır.

### Faz kartları

#### Faz 0 — Baseline ve davranış envanteri

- **Durum / owner / tarih / karar / kanıt:** `In progress — auth referansı sahibi tarafından doğrulandı; cihaz/performance baseline ve Android destek matrisi açık` · Owner: TBD · Başlangıç–bitiş: — · Karar: auth akışlarını simülatörde tekrar etme gerekmiyor; mevcut iOS davranışı referans · Kanıt: uygulama sahibi tüm auth varyasyonlarını fiziksel iPhone'da geliştirici modunda test ettiğini ve beklenen şekilde çalıştığını bildirdi. Ek manuel auth envanteri istenmiyor.
- **Amaç:** Taşınacak davranışı, teknik başlangıç değerlerini ve belirsizlikleri kod değiştirmeden görünür kılmak.
- **Önkoşullar:** Repo ve erişilebilir iOS scheme/CI hakkında bilgi; kritik akışları çalıştırabilecek test cihazı/simülatör veya kayıtlı çıktılar.
- **Kapsam içi:** Akış, API, model, localization, depolama anahtarları, oyun kuralları, CI/toolchain ve ölçüm envanteri.
- **Kapsam dışı:** Kod taşıma, UI yenileme, Android ekran implementasyonu, backend sözleşmesi değiştirme.
- **Görevler:**
  - [ ] `Documents/PRODUCT.md`, `Documents/DESIGN.md`, `Documents/Games/README.md` ve multiplayer planından gözlemlenebilir akış/oyun kuralı checklist'leri çıkar.
  - [x] Auth referansı: uygulama sahibi login ve auth akışlarının tüm varyasyonlarını fiziksel iPhone'da test ettiğini; sorun görmediğini bildirdi. Aynı akışları simülatörde yeniden çalıştırma yok.
  - [ ] House seçimi/oluşturma/katılma, chores, profile, oyunlar ve hata/boş/yükleniyor durumlarının iOS davranış envanterini tamamla.
  - [ ] API path, method, query, JSON, status/error envelope, realtime frame ve localization key örneklerini mevcut dosyalardan/fixture'lardan envanterle; belirsiz olanı tahmin etmeden işaretle.
  - [ ] Keychain/UserDefaults anahtarları, cache yeri/expiry, iOS scheme/deployment target, test suite ve mevcut CI/toolchain listesini kaydet.
  - [x] Localization kaynağı örneği alındı: sağlanan EN payload'ı 415 benzersiz `{key, language, value}` kaydı içeriyor; Android'de `key` tanımlayıcı, EN plaintext `value` olarak kalacak.
  - [ ] iOS cold/warm startup, idle/oyun bellek, House Rockets frame pacing ve app boyutu için cihaz/build/senaryo bilgisini içeren baseline raporu planla/al.
  - [ ] Android minSdk, hedef cihaz/ABI ve desteklenecek release kanallarına dair ürün varsayımını karar sahibiyle kayda geçir.
- **Dokunulacak mevcut dosyalar/dizinler:** Yalnız okuma: `Models/**`, `Services/**`, `ViewModels/**`, `Views/**`, `HouseFlowApp.swift`, `Documents/PRODUCT.md`, `Documents/DESIGN.md`, `Documents/Games/README.md`, `HouseFlow.xcodeproj/**`, CI yapılandırması varsa ilgili dosyalar.
- **Yeni çıktılar:** Envanter, ölçüm, destek matrisi ve karar kayıtları bu belgenin ilgili faz/karar bölümlerinde tutulur; faz başına ayrı Markdown dosyası açılmaz.
- **Küçük PR dilimleri:** (1) davranış envanteri, (2) teknik/toolchain envanteri, (3) ölçüm baseline raporu/karar kaydı. Dokümantasyon dışında kaynak değişikliği yok.
- **Doğrulama:** Her temel akış ürün belgelerine ve gerçek iOS gözlemine bağlanmış olmalı; açık farklar/varsayımlar listelenmeli. Faz içinde app build/test gerekiyorsa bu uygulama işi başlayınca ekipçe yürütülür; bu plan yazılırken çalıştırılmaz.
- **Performans ölçümü:** Ölçüm cihazı, OS, release/debug durumu, tekrar sayısı, p50/p95 ve belirsizlik kaydedilir. Sonraki fazlar aynı senaryoyu tekrar edebilir olmalıdır.
- **Çıkış kriteri:** Davranış envanterinde kritik akış boşluğu yok; Android destek matrisi ve baseline kabul sahibi atanmış; belirsiz backend/API kararlarının owner'ı var.
- **Rollback noktası:** Kod yok; envanterde yanlış bilgi düzeltilir, sonraki faz başlamaz.
- **Tahmini efor:** 3–5 kişi-gün.
- **Sonraki faza geçiş kapısı:** Owner, kritik akış baseline'ını ve Android hedefini onaylar; ölçüm için erişim/araç eksikse eksik yalnız ilgili ölçümde gerekçeli ve sahibi atanmış olur.

#### Faz 1 — Shared Swift Package iskeleti ve test altyapısı

- **Durum / owner / tarih / karar / kanıt:** `Done` · Uygulama owner'ı: Codex; kalıcı proje owner'ı: TBD · Başlangıç–bitiş: 2026-10-10 · Karar: tek local package, tek `HouseFlowCore` production target ve tek test target; sınırlar `shared/README.md` içinde · Kanıt: `swift test --package-path shared` (1 test, 0 hata), `swift package describe --package-path shared` (tools 6.2, 1 library + 1 test target), generic iOS Simulator `xcodebuild` (`BUILD SUCCEEDED`).
- **Amaç:** Mevcut iOS app'i bozmadan `HouseFlowCore` için build ve test sınırı açmak.
- **Önkoşullar:** F0 çıkış kapısı; mevcut Xcode scheme ve desteklenen Swift sürümü biliniyor.
- **Kapsam içi:** Tek Swift Package, tek production target, test target, minimal CI entegrasyonu.
- **Kapsam dışı:** Model/servis taşıma, Android/JNI, target'ları erkenden çoğaltma, Xcode projesini fiziksel taşıma.
- **Görevler:**
  - [x] `shared/Package.swift` eklendi; yalnız `HouseFlowCore` production target'ı ve `HouseFlowCoreTests` test target'ı oluşturuldu.
  - [x] Platform framework sınırları `shared/README.md` içinde kayda geçirildi.
  - [x] Xcode projesine `HouseFlow/shared` local package reference ve app target'a `HouseFlowCore` product dependency eklendi; `shared` file-system-synchronized app üyeliğinden çıkarıldı.
  - [ ] **N/A / beklemede:** Repo içinde CI konfigürasyonu bulunmadığından provider-specific CI üretilmedi. İlk mevcut CI provider'ı seçildiğinde package test ve iOS app build adımları ayrı job/step olarak eklenecek.
  - [x] Manifest `swift-tools-version: 6.2` ile sabitlendi; app target Swift 5 language mode'da bırakıldı. Harici package dependency olmadığı için `Package.resolved` oluşmadı.
- **Dokunulacak mevcut dosyalar/dizinler:** `HouseFlow.xcodeproj/**`, CI dosyaları; mevcut uygulama kaynakları yalnız import/dependency bağlantısı gerekiyorsa.
- **Yeni çıktılar:** `shared/Package.swift`, `shared/.gitignore`, `shared/Sources/HouseFlowCore/HouseFlowCore.swift`, `shared/Tests/HouseFlowCoreTests/HouseFlowCoreSmokeTests.swift`, `shared/README.md`.
- **Küçük PR dilimleri:** (1) boş package + host tests, (2) Xcode local dependency, (3) CI entegrasyonu/pin kontrolü.
- **Doğrulama:** Package smoke testi geçti; package grafiği beklenen iki target'ı gösterdi; generic iOS Simulator app build'i local package ile başarılı oldu. Mevcut model, servis, ViewModel ve UI dosyaları taşınmadı.
- **Performans ölçümü:** Core boş target eklenmesinin iOS build/startup/binary'ye etkisi not edilir; beklenmedik runtime kodu olmamalı.
- **Çıkış kriteri:** Tek Core production target ve tek test target mevcut; Xcode app build'i ve local Core testi yeşil. Repo'da CI olmadığı için CI kapısı N/A/beklemede olarak kaydedildi.
- **Rollback noktası:** Package reference ve CI adımı kaldırılarak mevcut proje eski durumuna dönebilir; henüz taşınmış iş kuralı yoktur.
- **Tahmini efor:** 2–4 kişi-gün.
- **Sonraki faza geçiş kapısı:** Local package graph ve Xcode app build'i doğrulandı; Core sınırı README ile kayıtlı. CI kontrolü, repo bir CI provider'ı edindiğinde zorunlu takip maddesidir.

#### Faz 2 — Saf modeller, kurallar ve DTO contract fixture'ları

- **Durum / owner / tarih / karar / kanıt:** `Done` · Uygulama owner'ı: Codex; kalıcı proje owner'ı: TBD · Başlangıç–bitiş: 2026-10-10 · Karar: auth/user, house/invite ve chore dilimleri mevcut wire adlarıyla Core'a taşındı; locale/current-date tabanlı tarih sunumu ve localization anahtarları iOS'ta bırakıldı · Kanıt: `swift test --package-path shared` (30 test, 0 hata), generic iOS Simulator app build + ayrı derived data ile `build-for-testing` app/test target derlemesi (başarılı), yerel Core boundary ve duplicate/import denetimleri (başarılı).
- **Amaç:** Küçük, framework bağımsız model/validasyon grubunu ortaklaştırmak ve API sözleşmesini testle kilitlemek.
- **Önkoşullar:** F1 tamam; F0 API/model envanteri hazır.
- **Kapsam içi:** Auth/user/house/chore DTO'ları, invite code gibi saf kurallar, serialization/date örnekleri.
- **Kapsam dışı:** HTTP transport, UI, token persistence, büyük çaplı model yeniden adlandırma veya API temizliği.
- **Görevler:**
  - [x] İlk domain grubu olarak auth/user seçildi; mevcut wire adları ve `birthDay`/optional alan sözleşmeleri korundu.
  - [x] Auth/user için request encode, response decode, wire key, optional/null ve malformed fixture testleri tamamlandı.
  - [x] House response/details alanlarının ISO-8601 string ve `{ "time.Time": "..." }` object tarih varyantları gerçek payload yapısına sahip ayrı fixture'larla kilitlendi.
  - [x] Chore komut/response DTO'larının wire key, optional/null, fractional/non-fractional ISO string ve malformed sözleşmeleri fixture'larla; enum raw/unknown davranışı ayrı testlerle kilitlendi.
  - [x] `Models/Auth/AuthModels.swift` tipleri ve `Models/User.swift` içindeki saf `User`, duplicate bırakmadan `HouseFlowCore` içine taşındı; public erişim yalnız mevcut iOS call site'larının init/property ihtiyacına açıldı.
  - [x] `InviteCodeRules` mevcut 8 karakter, uppercase ve ASCII alfasayısal filtre davranışı değiştirilmeden Core'a taşındı. House request/response/info/details DTO'ları ile details payload'ının gerektirdiği nested member, announcement ve chore wire DTO'ları duplicate bırakmadan Core'a alındı.
  - [x] `ChoreLevel`, `ChoreStatus`, chore request/response DTO'ları ve saf `Chore` domain modeli Core'a taşındı; localization key extension'ları, response adapter'ı ve `HouseFlowDateFormatter` iOS presentation katmanında kaldı.
  - [x] Core kaynaklarında yalnız Foundation/pure Swift import'una izin veren ve `URLSession`, `URLRequest`, `UserDefaults` sembollerini reddeden düşük bakım maliyetli yerel boundary testi eklendi. Repo'da CI olmadığından provider config eklenmedi.
  - [x] Taşınan tipleri kullanan Services/ViewModels/Views ve mevcut Xcode test call site'ları açık `import HouseFlowCore` ile tek tipe bağlandı; eski tip tanım dosyaları kaldırıldı.
- **Dokunulacak mevcut dosyalar/dizinler:** `Models/Auth/**`, `Models/User.swift`, `Models/House/**`, `Models/Chore*`, `Models/DateFormatting.swift`, ilgili `Services/**` call site'ları.
- **Yeni çıktılar:** `shared/Sources/HouseFlowCore/AuthModels.swift`, `User.swift`, `HouseModels.swift`, `ChoreModels.swift`; auth/user, house ve chore DTO testleri; `Fixtures/AuthUserFixtures.swift`, `Fixtures/HouseFixtures.swift`, `Fixtures/ChoreFixtures.swift`; `CoreBoundaryTests.swift`.
- **Küçük PR dilimleri:** Auth/user DTO; house DTO + invite rule; chore DTO/date fixture. Her PR tek domain alanı.
- **Doğrulama:** Auth/user, house ve chore request/response encode/decode; wire key; optional/null; malformed zorunlu alan; house string/object tarihleri; chore fractional/non-fractional ISO stringleri; invite-code kuralı; enum raw/unknown ve `Chore` identity/default davranışı test edildi. Core package 30/30 test geçti; iOS app build edildi ve ayrı derived data dizininde `build-for-testing` ile `HouseFlowTests` dahil tüm scheme target'ları derlendi. Görünür UI veya route kodu değiştirilmedi.
- **Performans ölçümü:** Model decode büyük fixture süresi/alloc baseline yalnız taşıma belirgin etkileyebilecekse ölçülür; bu aşamada mikro-optimizasyon yapılmaz.
- **Çıkış kriteri:** Sağlandı: kapsamdaki saf auth/user/house/chore model ve kuralları Core'da tek tanım; wire/date/enum sözleşmeleri fixture testli; Core sınırı temiz; iOS app ve test target'ları yeni modülle derleniyor.
- **Rollback noktası:** Domain grubu başına PR/revert; diğer modeller taşınmadan önceki modül sınırı sürer.
- **Tahmini efor:** 5–9 kişi-gün.
- **Sonraki faza geçiş kapısı:** Faz 2 kapsamı ve kanıtları tamam; HTTP portu ve iOS adapter tasarımı için Faz 3 başlayabilir.

#### Faz 3 — Portlar ve iOS adapter'ları

- **Durum / owner / tarih / karar / kanıt:** `iOS simulator accepted; signed-device Keychain/performance follow-up` · Owner: Codex · Tarih: 2026-10-10 · Karar: sadece Core'da kullanılan minimum `HTTPClient`, `SecureSessionStore`, `PreferencesStore` ve `LocalizationCacheStore` portları eklendi; bu fazda tüketicisi olmadığı için `Clock`/`Logger` portları eklenmedi. HTTP 30 saniye timeout ve 200–399 başarı aralığını korur; hata metni `message` → `error` → varsayılan sırasıyla, JSON olmayan hata gövdesi trim edilmiş metinle eşlenir. Eski Keychain anahtarları, UserDefaults domain/key'leri ve localization cache (`language`, `updatedAt`, `values`) korunur. · Kanıt: Core 32/32; generic iOS Simulator app ve test build başarılı; adapter contract 3 geçti; mevcut NetworkService/AuthService/AppRouter regresyonları 15/15 geçti; kullanıcı manuel simülatör kontrollerinin sorunsuz olduğunu bildirdi. İmzasız test host'unda gerçek Keychain round-trip atlandı; runtime performans karşılaştırması yapılmadı.
- **Amaç:** Core'un bağımlı olacağı minimum portları tanımlayıp mevcut iOS platform servislerini adapter arkasına almak.
- **Önkoşullar:** F2'nin gerekli DTO grupları; F0 token, preference, localization ve HTTP davranışı envanteri.
- **Kapsam içi:** HTTP, secure storage, preferences, localization, clock/logging için gerçekten kullanılan minimum sözleşmeler; iOS implementasyonu.
- **Kapsam dışı:** Android adapter, geniş kapsamlı dependency injection framework, generic ağ abstraction'ı veya ürün akışı değişimi.
- **Görevler:**
  - [x] Her portu kullanan akışı ve platforma bağımlı işlemi eşleştir; kullanılmayan soyutlama ekleme.
  - [x] `HTTPRequest/HTTPResponse/HTTPClient` ve normalize hata tipini mevcut status/error envelope'a göre tanımla.
  - [x] Keychain, preferences ve localization cache için typed, küçük kontratlar oluştur; token/log redaction kuralını belirt.
  - [x] Clock ve logging portlarını yalnız ihtiyaç varsa ekleme kararını kaydet: bu fazda Core tüketicisi yok, port eklenmedi.
  - [x] `URLSession`, `Security`, `UserDefaults`, `UIKit` kullanımlarını iOS sınırında tut; `AppDependencies` üzerinden graph kur.
  - [x] HTTP, preferences ve localization adapter contract testleri ile mevcut servisleri port arkasına geçir; Keychain için test tanımlandı, ancak gerçek round-trip imzalı cihaz kapısında bekliyor.
- **Dokunulacak mevcut dosyalar/dizinler:** `Services/Protocols/ServiceProtocols.swift`, `Services/Network/**`, `Services/KeychainService.swift`, `Services/LocalizationService.swift`, `Services/AppDependencies.swift`, gereken `Services/**` call site'ları.
- **Yeni çıktılar:** `shared/Sources/HouseFlowCore/Ports/**`, iOS `Platform/` veya mevcut `Services/Platform/` altında HTTP/Keychain/preferences/localization adapter'ları, adapter test doubles ve port ADR.
- **Küçük PR dilimleri:** (1) HTTP contract + URLSession adapter, (2) secure storage/preferences, (3) localization/cache, (4) composition root ve endpoint migration. Sözleşme değişirse önce ADR/fixture PR.
- **Doğrulama:** HTTP hata zarfı/status/header/query/encoding, eski preference key'lerinin doğrudan okunması, eski localization JSON'u/fallback'i ve mevcut login/API error/router akışları test edildi. İmzasız simülatörde `Security` erişimi olmadığı için gerçek token load-save-delete testi atlandı; imzalı cihazda tekrar koşulmalı.
- **Performans ölçümü:** URLSession round-trip, JSON decode, localization cache hit/miss; adapter katmanı latency/alloc baseline'ı anlamlı artırmamalı.
- **Çıkış kriteri:** Kod sınırı, iOS regresyonları ve kullanıcı tarafından bildirilen manuel simülatör kontrolleri sağlandı; token plaintext'e aktarılmıyor. İmzalı fiziksel cihaz Keychain testi ve sayısal runtime karşılaştırması release/performance takip maddesidir; kullanıcı Faz 4'e geçişi onayladı.
- **Rollback noktası:** Port başına `AppDependencies` binding eski servise döner; henüz ortak feature state'e toplu geçiş yapılmaz.
- **Tahmini efor:** 7–12 kişi-gün.
- **Sonraki faza geçiş kapısı:** En az bir HTTP, storage ve localization contract iOS'ta uygulanıp kanıtlı; iOS login/restore ve bir API hata akışı aynı.

#### Faz 4 — Tek uçtan uca iOS Core pilotu

- **Durum / owner / tarih / karar / kanıt:** `Implementation done; performance baseline follow-up` · Owner: Codex · Tarih: 2026-10-10 · Karar: açılış/foreground session restore `RestoreSessionUseCase` ile Core'a bağlandı; Core token'ı `SecureSessionStore`'dan alıp tek `GET auth/isAuth` çağrısı yapar. Route ve kullanıcıya gösterilen metin iOS coordinator'da kalır; `sessionRestorer: nil` eski yola geri dönüş noktasıdır. Token yoksa ağ isteği yapılmaz; pending verification doğrulama route'una; başarılı profile göre email verification, birthday setup, house selection veya dashboard'a gider. 401/API mesajı korunur; offline/transport hatasında token kalır ve hata route'u gösterilir. · Kanıt: Core 40/40; generic iOS Simulator app/test build başarılı; coordinator 11/11, önceki coordinator/login/router birleşik koşusu 21/21; Core restore senaryolarında 8 yeni test (401, offline, malformed profile, cancellation ve benzeri). Gerçek kullanıcı auth varyasyonları iPhone'da sorunsuz test ettiğini bildirdi; sayısal latency/cold-start karşılaştırması yok.
- **Amaç:** Bir gerçek iOS akışını View → ViewModel/use case → Core → adapter → backend boyunca ortak sınırdan yürütmek.
- **Önkoşullar:** F3 portları ve iOS adapter'ları; pilot akış için API fixture ve UX baseline.
- **Kapsam içi:** Önerilen auth session restore/login alt akışı veya küçük, az riskli house sorgusu; tek seam.
- **Kapsam dışı:** Tüm ViewModel'ları taşıma, `ObservableObject`/SwiftUI'yı Core'a sokma, ekran davranışını değiştirme.
- **Görevler:**
  - [x] Pilot olarak yalnız token restore + `auth/isAuth` profil doğrulaması seçildi ve karar belgelendi.
  - [x] Core use case geçerli profil değerini, missing-token/invalid-profile durumlarını ve HTTP hata sonucunu açıkça tanımlar.
  - [x] iOS `AuthSessionStore` ve coordinator Core use case'i ince adapter ile çağırır; SwiftUI view ağacı değişmedi.
  - [x] İptal, tekrar çağrı, offline, 401, bozuk/geçersiz profil Core fake port testleriyle doğrulandı.
  - [x] `AppDependencies.live` yalnız açılış restore yolunu Core'a bağlar; `sessionRestorer: nil` eski servise dönüş yoludur.
  - [x] Başlangıç route'u ve 401/geçersiz profil hata metni iOS regresyon testleriyle karşılaştırıldı; gerçek backend/simülatör manuel kabulü bekliyor.
- **Dokunulacak mevcut dosyalar/dizinler:** `ViewModels/AppViewModel.swift`, `ViewModels/AuthenticationViewModel.swift`, `ViewModels/Navigation/AppRouter.swift` veya seçilen dar feature, `Services/AppDependencies.swift`, ilgili `Views/**` yalnız binding gerektikçe.
- **Yeni çıktılar:** `Core/UseCases/**`, pilot unit tests ve bu faz kartındaki karar/kanıt kaydı.
- **Küçük PR dilimleri:** Use case/state test; iOS ViewModel binding; dependency graph switch; davranış karşılaştırma raporu.
- **Doğrulama:** Core 40/40; iOS coordinator 11/11 ve önceki coordinator/login/router 21/21; app ve test hedefi derlendi. Gerçek backend'le açılış/foreground, doğrulanmamış hesap, 401 ve offline manuel simülatör kabulü bekliyor.
- **Performans ölçümü:** Restore/login akış latency, cold-start ve allocations karşılaştırılır; pilotun UI startup'ına ek gecikmesi raporlanır.
- **Çıkış kriteri:** Üretim graph'ında tek tam restore akışı Core sınırından geçiyor; testlerde aynı state/route/hata metni üretiliyor. Manuel gerçek backend kabulü ve karşılaştırmalı cihaz performansı henüz tamamlanmadı.
- **Rollback noktası:** Tek composition binding/feature flag eski iOS use case'e döner; ortak DTO/contract fixture kalabilir.
- **Tahmini efor:** 4–7 kişi-gün.
- **Sonraki faza geçiş kapısı:** Pilot iki farklı auth/session senaryosunda doğrulandı; iOS davranışı aynı; F5 için Android Core yüzeyi/Swift type kısıtları yazılı.

#### Faz 5 — Android Gradle shell ve Swift SDK/JNI roundtrip

- **Durum / owner / tarih / karar / kanıt:** `Closed — yerel spike; release kapıları ertelendi` · Owner: Codex · Tarih: 2026-10-11 · Geçici pinler: Swift 6.4.0 / `swift-6.4.0-RELEASE_android`, NDK r30 (`30.0.16248370`), swift-java 0.6.0, Gradle 8.13 / AGP 8.13.2, Kotlin 2.0.21, Gradle JDK 17+ (yerelde 21), SwiftKitCore publish için JDK 25; build minSdk 31, compile/target 36, arm64-v8a + x86_64. Bu pinler deneme yapılandırmasıdır, ürün destek matrisi onayı değildir. İki ABI cross-compile/package, API 36.1 arm64 JNI smoke ve kullanıcının çalıştırdığı 14/14 instrumentation testi geçti; boş Android Activity açıldı. Tek yerel tanısal ölçüm: debug cold start 842 ms / PSS 61,934 KB; release denemesi 606 ms / 34,837 KB. Bunlar tek emülatör ölçümü, kontrollü kıyas veya kabul edilmiş performans bütçesi değildir.
- **Amaç:** Android host iskeletini ve en küçük Swift çağrısını üretim UI akışından bağımsız doğrulamak.
- **Önkoşullar:** F4 Core API pilotu; Android destek matrisi taslak/onay; toolchain araştırması.
- **Kapsam içi:** Gradle shell, NDK/Swift SDK/JDK pinleme, native library packaging, bir input/output JNI façade ve smoke.
- **Kapsam dışı:** Auth/UI, tüm Core'u bridge etme, frame başına native çağrı, genel Swift/Kotlin binding generator yazma.
- **Görevler:**
  - [x] Swift Android resmi SDK/toolchain eşleşmesi, NDK, JDK, Gradle wrapper/AGP/Kotlin ve SwiftJava gereksinimini araştırıp geçici spike pin kararını al (cihaz destek matrisi onayı açık).
  - [x] `android/` minimal app + Gradle wrapper ve Kotlin package kur; gereksiz product screen ekleme; debug/release build'i doğrula.
  - [x] Bir Core saf fonksiyonunu seç; Swift SDK ile hedeflenen Android ABI'ler için cross-compile et.
  - [x] `swift-java` JNI generation kullanarak versioned primitive alanla deterministic test-vector çağrısı yap.
  - [x] API 36.1 arm64-v8a emülatöründe native load, null/invalid input ve payload sınırını doğrula. Bu senkron/stateless spike'da coroutine cancellation ve lifecycle close uygulanamaz; gelecekteki async/IO bridge için sahiplik sözleşmesi ayrıca tanımlanmalı.
  - [ ] Min API ve ABI matrisi üzerinde emulator/cihaz smoke çalıştır; debug/release paketlemeyi kıyasla.
  - [x] CI'da pin kontrolü, cross-compile ve wrapper/codegen contract kontrolü ekle (workflow yazıldı; clean CI sonucu bekleniyor).
- **Dokunulacak mevcut dosyalar/dizinler:** `shared/Package.swift` / Core public API (yalnız gerekli tip), CI/pin dosyaları; mevcut iOS ekranları değişmez.
- **Yeni çıktılar:** `android/settings.gradle.kts`, root/app Gradle dosyaları, wrapper, `android/app/src/main/**`, `android/app/src/test/**`, JNI façade/generated binding policy, Swift SDK/NDK pin manifest, Android scripts. Spike kararı/kanıtı bu faz kartında tutulur.
- **Küçük PR dilimleri:** (1) Gradle empty shell, (2) pinned Swift cross-compile CI, (3) JNI ping/value DTO, (4) API/ABI/device smoke ve size report.
- **Doğrulama:** Cross-compile, .so load, roundtrip, release shrink/package ve desteklenen API/ABI; generated code tekrar üretimi aynı sonuçta.
- **Performans ölçümü:** Startup'a native load etkisi, JNI çağrı latency/allocation, birleşik ve ABI split AAB teslim boyutu, native memory.
- **Çıkış kriteri:** Clean CI'da pinli toolchain; desteklenen tüm hedef ABI'de load/call ve hata sınırı; senkron/stateless çağrı için cancellation/close gerekmemesi belgeli; p95/startup/AAB bütçeleri F0'da kabul edilmiş sınırda.
- **Rollback noktası:** `android/` shell ve native dependency ayrı revert edilebilir; iOS app ve Core host testleri etkilenmez. JNI kapısı geçmezse sonraki Android entegrasyon işi durur, Kotlin uygulama kararı ayrıca ele alınır.
- **Tahmini efor:** 5–10 kişi-gün (belirsizlik payı yüksek).
- **Sonraki faza geçiş kapısı:** Ürün sahibi desteklenecek min API/ABI'yi kabul eder; CI ve gerçek runtime spike geçer; JNI error/cancel/lifecycle ownership belgeli.

#### Faz 6 — Android platform adapter'ları

- **Durum / owner / tarih / karar / kanıt:** `Closed — adapter baseline; Core auth entegrasyonu F7'de` · Owner: Codex · Tarih: 2026-10-11 · Adapter'lar: Keystore AES-256-GCM secure session store (backup/device-transfer dışı; bozuk/kayıp key reauthentication gerektirir; IO `Dispatchers.IO`); yalnız hassas olmayan `hasSeenOnboarding`/`chosenHouse` DataStore; 30 saniye timeout/coroutine cancel/HTTPS kurallı HTTP adapter; atomic localization cache, offline son cache ve missing-key fallback; lifecycle event bridge ve sabit kodlu, PII içermeyen log olayları. Kanıt: 8/8 JVM unit testi, API 36.1 arm64 emülatöründe 14/14 instrumentation testi (3 JNI, 6 Keystore, 1 DataStore, 4 localization), iOS contract testleri ve kabuk launch'ı kullanıcı tarafından doğrulandı. Kullanıcı talebiyle mevcut adapter kapsamı kapatıldı; Core auth/JNI çağrı sahipliği henüz entegre değil.
- **Amaç:** Core portlarını Android platform API'leriyle güvenli ve aynı sözleşmede çalıştırmak.
- **Önkoşullar:** F3 port kontratları; F5 JNI ve Android shell kapısı.
- **Kapsam içi:** Keystore destekli secure storage, DataStore preferences, HTTP, remote localization/cache, lifecycle ve log adapter'ları.
- **Kapsam dışı:** Görünür UI, yeni auth davranışı, API endpoint/schema değişikliği, generic Android platform framework.
- **Görevler:**
  - [x] Token ve hassas değer için Keystore-backed encryption/key invalidation ve logout silme politikasını tanımla; tek emülatörde adapter testini çalıştır.
  - [x] DataStore'a onboarding ve seçili ev tercihlerini idempotent eşle; hassas token DataStore/plain preferences'a yazılmasın.
  - [x] HTTP adapter'da URL/query/header/body/ham status, timeout, cancellation ve HTTPS konfigürasyonunu iOS contract ile eşleştir.
  - [x] Localization endpoint/cache key, atomic refresh, offline fallback ve dil verisini mevcut sözleşmeyle uygula.
  - [ ] Lifecycle active/background sinyali Activity'den adapter'a aktarılıyor; Core session/use case bağlantısı F7'deki async JNI sınırı seçilince doğrulanacak.
  - [x] Sabit olay kodlu log ekle; serbest metin alanı olmadığı için token, auth header, e-posta/PII ve oyun payload'ı loglanamaz.
  - [ ] Ortak HTTP fixture iOS/Android'de mevcut; Android cihazda storage reopen geçti. iOS fixture testi, gerçek process-death ve min API güvenlik/offline kabulü tamamlanacak.
- **Dokunulacak mevcut dosyalar/dizinler:** Core `Ports/**`, Android `platform/**`; iOS `Services/Network/**`, `KeychainService.swift`, `LocalizationService.swift` yalnız port kontratı güncellemesi gerekirse.
- **Yeni çıktılar:** Kotlin `SecureTokenStore`, `PreferencesStore`, `HTTPAdapter`, `LocalizationRepository`, `LifecycleBridge`, `AppLogger`; unit/instrumentation/contract tests; güvenlik sınırları bu faz kartında tutulur.
- **Küçük PR dilimleri:** Secure storage; HTTP + error map; preferences; localization; lifecycle/logging. Bir PR bir port.
- **Doğrulama:** Shared fixture contract, TLS/timeout/cancel, key invalidation/logout, encrypted-at-rest review, offline/cache/fallback, log scan.
- **Performans ölçümü:** HTTP request overhead, secure-store read/write latency, localization cold/hot cache, background wake-up ve heap.
- **Çıkış kriteri:** Her port contract testli; token güvenli; iOS/Android aynı domain sonucu; log privacy review tamam.
- **Rollback noktası:** Adapter binding tek tek önceki Kotlin/platform implementasyonuna döner; veri migration'ı kayıpsız ve tekrar çalışabilir olmalı. Token migration rollback'i kullanıcı verisini temizlememeli.
- **Tahmini efor:** 8–14 kişi-gün.
- **Sonraki faza geçiş kapısı:** Auth için gerekli token, HTTP, preferences ve lifecycle adapter'ları desteklenen min API'de kanıtlı; güvenlik ve offline hata semantiği review edilmiş.

##### Faz 5–6 release öncesi açık kontroller

Bu maddeler Faz 5/6'nın kapatılmasını geri almaz; release readiness ve sonraki Android auth entegrasyonu için açık kalır:

- GitHub Actions `HouseFlow Android bridge` temiz `workflow_dispatch` koşusu; workflow içindeki API 31 x86_64 runtime testi.
- Ürün sahibi minSdk/ABI destek matrisini açıkça onaylamalı; API 31/x86_64 veya fiziksel arm64 doğrulaması gerekirse o hedefte smoke yapılmalı.
- Gerçek process-death sonrası oturumun korunması, logout sonrası geri gelmemesi ve Keystore key kaybında reauthentication doğrulanmalı. API 36.1 adapter testi depolamayı yeniden açar ama gerçek OS process-death testi değildir.
- Gerçek backend HTTPS sertifika zinciri ve offline davranış cihaz/emülatörde doğrulanmalı.
- Kabul edilen performans/boyut bütçesi belirlenip cold start, native ilk yükleme, PSS/RSS, HTTP/cache latency ve ABI'ye göre indirilen boyut ölçülmeli. Yaklaşık 63 MB AAB ve 203 MB imzasız universal release APK, split teslim boyutu değildir; 16 KB APK hizası doğrulandı.

#### Faz 7 — İlk Android dikey feature

- **Durum / owner / tarih / karar / kanıt:** `Implementation ve yerel manuel kabul tamam — release matrisi açık` · Owner: Codex · Tarih: 2026-10-11 · Karar: ilk dikey dilim iOS AuthView ile aynı görünümde Android sign-in, session restore, logout ve sonraki route kararının aktarılmasıdır. Core `AuthWireContract` login/profile wire ve route önceliğini sahiplenir; Swift/JNI v2 yalnız kaba JSON çağrılarını taşır; Android HTTP/Keystore/Compose state'i platformda kalır. F8'e ait signup/verification/forgot-password ve auth sonrası gerçek ürün ekranları burada açılmadı. Kanıt: Core 43/43, bridge host 2/2, Android JVM 14/14 ve API 36.1 arm64 emülatör instrumentation 16/16 geçti; JNI v2 binding kontrolü geçti. Ürün sahibi 2026-10-11'de iletilen manuel testlerin başarılı olduğunu bildirdi. Tek debug cold-start `am start -W` ölçümü 1084 ms; karşılaştırmalı bütçe henüz yok.
- **Amaç:** Bir kullanıcı akışını Compose → ViewModel → Core → Android adapter → API hattında tamamlamak.
- **Önkoşullar:** F5/6 geçilmiş; F0 UX baseline; F4 iOS pilot.
- **Kapsam içi:** Auth login/session restore veya kararlaştırılmış en küçük tam auth dilimi; state, route ve mevcut metin/validation.
- **Kapsam dışı:** Yeni onboarding, görünür tercih, redesign, signup/email verification/forgot-password'ın gerçek ekranları ve auth sonrası dashboard/house ekranları (F8). Mevcut iOS AuthView görsel hiyerarşisi korunur.
- **Görevler:**
  - [x] Android sign-in alan, boş-alan validation, API hata, loading ve route state'i iOS AuthView/AuthSessionCoordinator kaynağından eşlendi; Compose ekranında yeni ürün kontrolü eklenmedi.
  - [x] Compose ViewModel → Swift Core JNI façade → Android HTTP/Keystore adapter zinciri kuruldu; ağ/depolama `Dispatchers.IO`, UI `StateFlow`, iş iptali coroutine ile yönetilir.
  - [x] Navigation Compose auth/status graph ve pending verification → token restore → profile route önceliği eklendi; 15 dakika arka plan sonrası yeniden doğrulama iOS eşik değeriyle eşlendi.
  - [x] Auth ekranındaki mevcut localization key'leri ve loading/error state'i kullanıldı; SwiftUI'nin açık renk tercihi Android'de korundu.
  - [x] Localization wire formatı `{ key, language, value }` olarak kaldı; `key` tanımlayıcı, plaintext `value` olarak kullanılır. EN örneği 415 key içerir.
  - [x] İlk açılışta cache hızlı gösterim, sonra desteklenen cihaz dili tam/base eşleşme → sunucu varsayılanı → ilk aktif dil; login sonrası profil dili uygulanır.
  - [x] Seçili dil ve dil başına cache kalır; yeni değerler `StateFlow` ile ekrana yansır; offline cache/key fallback UI'ı bloke etmez. Profil dilini sunucuya yazan ayarlar akışı F8'deki gerçek localization ekranına bağlıdır.
  - [x] Klavye Done ile submit, boş formda disabled submit, TalkBack alan etiketleri ve Android back davranışı uygulandı; ürün sahibi iletilen manuel testlerin başarılı olduğunu bildirdi, cihaz/OS ayrıntısı kaydedilmedi.
  - [x] Fixture'la login başarı/başarısızlık, restore, pending verification önceliği ve logout JVM/JNI testleriyle doğrulandı; ürün sahibi manuel testlerin başarılı olduğunu bildirdi.
- **Dokunulacak mevcut dosyalar/dizinler:** Core auth use case/port; iOS `Views/Authentication/**`, `ViewModels/AuthenticationViewModel.swift`, `AppRouter.swift` yalnız baseline karşılaştırması için okunur.
- **Yeni çıktılar:** Android `ui/auth/**`, `viewmodel/AuthViewModel.kt`, `platform/AuthSessionRepository.kt`, `platform/AndroidLocalizationState.kt`, Compose/JNI/JVM testleri; sonuçlar yalnız bu faz kartında izlenir.
- **Uygulama paketi:** Kullanıcının isteğiyle F7 tek çalışma kapsamında tamamlandı; faza özel yeni Markdown dosyası oluşturulmadı.
- **Doğrulama:** Core 43/43; bridge host 2/2; Android JVM 14/14; emülatör instrumentation 16/16; generated JNI 5 method v2. Mevcut AVD'de System UI ANR bir kez çıktı; Wait sonrası HouseFlow auth ekranı normal açıldı. iOS tam uygulama test hedefi tekrar koşulmadı: `simctl` kullanılabilir iOS cihazı göstermedi; değişen iOS çağrı yolunun Core unit testleri geçti. Ürün sahibi iletilen manuel testlerin başarılı olduğunu bildirdi; cihaz/OS ve tekil senaryo sonuçları ayrıca kaydedilmedi.
- **Performans ölçümü:** API 36.1 arm64 emülatörde tek debug cold start 1084 ms; JNI genel roundtrip testinde p50 2.3 µs/p95 5.5 µs. Auth request latency, ilk etkileşim, recomposition ve destek matrisi için kontrollü baseline henüz yok; F0/release gate ile kıyaslanacak.
- **Çıkış kriteri:** İlk sign-in/restore dilimi ve route kararı hazır; yerel manuel kabul ürün sahibi tarafından başarılı bildirildi. İkinci API/cihaz ve ölçüm bütçesi sürüm kabulünde hâlâ doğrulanmalı; bu kanıtlar olmadan Faz 7'nin release kapısı kapalı sayılmaz. F8 ürün ekranları tamamlanana kadar başarılı auth mevcut iOS loading görünümündeki handoff durumunda kalır.
- **Rollback noktası:** Auth route Android'de önceki placeholder/native fallback'e döner; Core port/adapter testleri kalabilir. iOS route etkilenmez.
- **Tahmini efor:** 6–10 kişi-gün.
- **Sonraki faza geçiş kapısı:** Yerel auth pilotu manuel olarak kabul edildiği için F8 geliştirmesi başlayabilir. Ürün sürümü öncesinde iki cihaz/API düzeyinde auth checklist, copy/state paritesi, erişilebilirlik ve performans bütçesi ayrıca doğrulanır.

#### Faz 8 — Kalan auth, house, chore, profile ve localization dalgaları

- **Durum / owner / tarih / karar / kanıt:** `Geliştirme sürüyor — beşinci dilim kodu ve otomatik testleri geçti; cihaz/gerçek API/görsel kabul açık` · Owner: Codex · Tarih: 2026-10-12 · Karar: F7'de kabul edilen auth pilotunu gerçek ürün rotalarına bağlayıp iOS'taki oyun dışı akışları görünür tasarım/etkileşim değiştirmeden Android'e taşımak. Kanıt: iOS `RootView`, `MainTabView`, coordinator/store ve servis akışları Android ile eşlendi. İlk üç dilimin önceki test kayıtları aşağıdadır. Beşinci dilimde Core 51 XCTest + 2 Swift Testing, bridge host 6/6, Android JVM 30/30, Android debug ve instrumentation APK derlemesi, JNI v6 binding kontrolü ve iOS Simulator hedefli uygulama derlemesi geçti; bağlı Android cihaz bulunmadığından yeni Compose instrumentation koşulmadı.
- **Amaç:** İlk açılıştan auth, ev ve ana ekran üzerinden profil/dil değişimine kadar iOS'ta mevcut olan oyun dışı kullanıcı yolculuklarının Android'de çalışması; Swift Core'un iş/DTO kararlarını, Android'in HTTP/Keystore/Compose sorumluluklarını koruması.
- **Önkoşullar:** F7 yerel auth pilotu kabul edildi. F7'den kalan ikinci API/cihaz ve karşılaştırmalı performans ölçümleri sürüm kapısıdır; F8 kodlamasını bloke etmez.
- **Kapsam içi:** iOS'taki üç sayfalı ilk açılış onboarding'i; signup, e-posta doğrulama, şifre sıfırlama, doğum günü tamamlama; ev seçimi/oluşturma/katılma/değiştirme/ayrılma; dashboard duyuru/görev/üye görünümü ve mevcut görev/duyuru eylemleri; profil, ev bilgileri/daveti/üyelik işlemleri, avatar seçimi, dil ayarları ve logout. Loading, error, empty, popup ve geri dönüş durumları da aynı kapsamda.
- **Kapsam dışı:** Yeni ekran/akış/kontrol, yeni house selector, UX redesign, sırf Android için API değişikliği, oyunların kendisi (F9+). iOS'ta yalnız entegrasyon-bekliyor bildirimi veren telefon yönetimi ve gerçek social sign-in Android'de de çalışan backend özelliği gibi sunulmaz; mevcut iOS durumuyla eşlenir. Oyun sekmesi/oyun hub'ının tam etkileşimi F9+ oyun kapsamına bağlıdır: F8, var olmayan oyunu çalışıyormuş gibi göstererek genel parity iddiasında bulunmaz.
- **Mimari uygulama kuralı:** Mevcut `HouseFlowCore` auth/house/chore/user DTO'ları ve `InviteCodeRules` yeniden kullanılır; ortak doğrulama, wire decoding ve route/iş kararları yalnız gerçekten iki platformda paylaşıldığında küçük use case/facade'lere çıkarılır. JNI sınırı ekran öğesi veya liste satırı başına değil, login gibi kaba iş operasyonu başına geçilir; büyük house payload'ları tek seferde ayrıştırılır. Android'de ekran state'i/lifecycle `StateFlow` + ViewModel, HTTP/Keystore/cache ve görsel asset/image yükleme platform adapter'ındadır. iOS servis/coordinator davranışı referanstır; Core'a taşınan mantık iOS'ta regression testiyle korunur. Genel amaçlı yeni repository/DI/UI framework'ü kurulmaz.
- **Uygulama sırası ve teslimler:** Aşağıdaki dalgalar tek Faz 8 kapsamının uygulanabilir dikey dilimleridir; ayrı faz Markdown dosyaları açılmaz.
  1. **Envanter ve parity zemini (2–3 kişi-gün):** `RootView`/`MainTabView` ve ilgili SwiftUI component'lerden route, overlay, alan, validasyon, copy key, görsel token/asset ve endpoint→DTO→error matrisini bu faz kartına işle. Aynı ekran boyutu, font ölçeği ve dil için iOS referans görüntülerini karşılaştırma kanıtı olarak kullan; eksik backend yeteneğini tahminle doldurma. `auth/isAuth`, `house/details`, `chore`, `user/profile` dahil gerçek sözleşmeleri fixture ile sabitle.
  2. **Auth tamamlaması (5–8 kişi-gün):** Android'de ilk kurulum onboarding kararını mevcut tercih deposuna bağla; AuthView'deki sign-up modu, email verification/OTP/resend süresi, forgot/reset password ve birthday setup ekranlarını aynı görünüm/geri dönüşle ekle. `auth/signup`, `auth/forget`, `auth/reset`, `auth/validate-email`, `user/profile/{id}` sözleşmeleri ve F7 pending verification/token önceliği birlikte test edilir. Hatalı OTP, süresi dolmuş kod, tekrar gönderme, yarım akış sonrası process death ve logout temizliği ayrı state'lerdir.
  3. **Ev oturumu ve gerçek rota (6–9 kişi-gün):** F7'nin auth-sonrası handoff'u kaldır; 0 ev → `HouseSelectionView`, ev varsa saklı `chosenHouse` geçerliyse o/aksi halde ilk ev → `house/details` → dashboard sırasını uygula. `house/create`, `house/join`, `house/details`, `house/infos`, `house/inviteCode`, `house/exit` ve mevcut ev profil/üyelik eylemlerini ihtiyaç duyulan ekran diliminde bağla. Oluştur/katıl için detay yüklenmeden dashboard'a gitme; switch/leave sırasında eski evin cevaplarının yeni eve yazılmasını generation/cancel kontrolüyle önle. Ev değiştirme, iOS'taki Home sekmesine uzun basma davranışından sapmaz.
  4. **Ana ekran ve görev/duyuru (7–11 kişi-gün):** iOS `MainTabView` görsel/overlay davranışını ve Home/Profile rotalarını kur; `HouseDashboardView` hiyerarşisindeki header, duyuru, bugünkü görevler, üyeler, FAB ve popupları aynı içerik/eylemle uygula. `house/details` tek başlangıç kaynağıdır; `chore` create/update, `chore/status`, `chore/review`, `house/announcement` başarılıysa yalnız aktif evin state'ini güncelle. Recurring, status/review, boş liste, owner/üye yetkisi ve hata sonrası geri dönüş fixture'larla doğrulanır. iOS'taki demo fallback gerçek ev verisi yerine geçirilmez.
  5. **Profil, üyelik ve localization (7–11 kişi-gün):** `ProfileView` kartları ve mevcut edit/avatar/house info/invite/join/language/about/logout popup'larını taşı; ekranda kullanılan `user/getImages`, `user/profile/{id}`, `house/profile`, `house/exit`, `house/inviteCode` sonuçlarını doğru aktif kullanıcı/ev state'ine işle. iOS'ta tanımlı ancak bu ekranda çağrılmayan `user/getImage` uç noktası, gerçek kullanım çıkana kadar Android'e sırf kapsam doldurmak için eklenmez. Dil seçiminde önce profil güncellemesi, sonra mevcut `AndroidLocalizationState` cache/remote yenilemesi ve iOS'taki yeniden giriş gereksinimi uygulanır. Sağlanan 415-key `en` payload'ı test fixture/referanstır; `key` plaintext değildir, remote değerler sabit EN kaynaklarına dönüştürülmez. Yeni cihaz, tekrar açılış, profil dili, manuel değişim, offline cache ve hızlı art arda dil seçimi test edilir.
  6. **Bütünleşik kabul ve iyileştirme (4–7 kişi-gün):** Sign-up→verify→birthday→house create/join→dashboard→chore/announcement→profile/language→logout ve mevcut hesapla restore/switch/leave zincirlerini uçtan uca geçir. iOS karşılaştırmasında bulunan yalnız parity/performance kusurlarını düzelt; kapsam genişletme kararı ayrıca alınır.
- **Uygulama kaydı (2026-10-11, ilk dilim):** Android'de iOS `OnboardingView` kaynaklı üç sayfa, swipe, mevcut localization key'leri, son sayfada etkinleşen Get Started ve kalıcı `hasSeenOnboarding` tercihi eklendi. Token/session restore önceliği korunur; signed-out ilk açılış onboarding'e, daha önce tamamlanmış açılış sign-in'e gider. Double submit engeli ve ilk açılışta auth/onboarding'e uygun status-bar görünümü eklendi. JVM 16/16; emülatör instrumentation 18/18. Emülatörde ilk sayfa görseli incelendi; System UI ANR uyarısı bir kez çıktı, Wait sonrası ekran normal çizildi. iOS ile yan yana görsel kabul henüz yapılmadı.
- **Uygulama kaydı (2026-10-11, ikinci dilim):** Android sign-up modu, `auth/signup` token/pending verification; doğrulama maili GET, altı karakterli OTP POST ve üç dakikalık resend; `auth/forget`/`auth/reset` ve altı rakamlı reset kodu; `user/profile/{id}?userId=...` doğum günü PUT ile auth sonrası profil rotası eklendi. Mevcut iOS metin anahtarları, ekran akışı, form/geri davranışı ve görsel düzeni referans alındı; yeni ürün kontrolü tasarlanmadı. Core typed wire kontratları ve JNI v3 kaba JSON çağrılarıyla DTO/yanıt kararı Swift'te, HTTP/Keystore/Compose Android'de kaldı. Signup ve doğrulanmamış login pending durumu process restart'ta saklanır; doğrulama yalnız güncel profil e-postayı doğrulanmış gösterince temizlenir. Android emülatörde auth/sign-up ekran görüntüsü kontrol edildi; System UI ANR açılışta yeniden görüldü, Wait sonrası toparlandı. Son JNI runtime değişikliğiyle Gradle runner ANR yüzünden başlamayınca aynı yüklü test APK'sı üzerinden `adb shell am instrument -w` çalıştırıldı; 21/21 test ve JNI v3 roundtrip 4/4 geçti. Ürün sahibi ikinci dilim manuel testlerinin başarılı olduğunu bildirdi; tekil senaryo/cihaz ve iOS yan yana görsel kanıtı ayrıca kaydedilmedi.
- **Uygulama kaydı (2026-10-11, üçüncü dilim):** `auth/isAuth` JNI profil özeti ev listesini Android'e verir. Android ev oturumu, 0 evde seçim; çok evde geçerli `chosenHouse`, değilse ilk ev; ardından `house/details` doğrulaması başarılıysa dashboard rotası kuralını uygular. Create/join formları, iOS summary popup, loading/error ve geri davranışı bağlandı. Swift Core `HouseWireContract` mevcut house DTO'larıyla create/join/details/info/invite/exit/profile yanıtlarını doğrular; Android HTTP/Keystore/DataStore ve tek aktif ev state'ini yönetir. Nesil + iptal kontrolü switch/logout/leave sırasında eski ev cevabını atar, create/join ayrıntı yüklemesi hatasında tekrar gönderimde ikinci create/join yerine bekleyen evin ayrıntısı denenir. `house/infos`, `house/inviteCode`, `house/exit` ve `house/profile` repository/ViewModel sınırına bağlandı; bunların iOS Profile popup'ındaki görünür üyelik/edit/leave yüzeyleri profil diliminde yapılacak. Dashboard rotası açılıyor fakat şu an yalnız ev başlığı/veri özeti ve iOS Home uzun basma switch davranışını taşıyan geçici giriş; tam kart/eylem/tab paritesi bir sonraki dashboard diliminde açık. Gerçek backend ve yan yana görsel kabul yapılmadan bu dilim/parite `Tamam` değildir.
- **Uygulama kaydı (2026-10-12, dördüncü dilim):** Geçici dashboard özeti `ui/dashboard/**` altında gerçek `house/details` üyeleri, görevleri, aktif duyuruları, iOS'taki iki aşamalı FAB, duyuru ve görev popup'larıyla değiştirildi. `DashboardWireContract`/JNI v5 create/update/status/review/announcement istek ve cevaplarını mevcut Core DTO'larıyla doğrular; Android repository ağ/JSON işini IO'da yapar, seçili ev dışında yanıt birleştirmez ve iptal/nesil kapısı geç eski sonucu atar. Yerel duyuru okundu bilgisi kullanıcı+ev bazında, üye avatarları sınırlandırılmış indirme ve bellek önbelleğiyle tutulur. Core 50 XCTest + 2 Swift Testing, bridge host 5, Android JVM 28/28, Android debug/test APK derlemesi, JNI binding kontrolü, iOS Simulator build geçti. Ürün sahibi Faz 8'de bu noktaya kadar yapılan manuel testlerin başarılı olduğunu bildirdi; cihaz ve iOS yan yana görsel kanıtı ayrıca kaydedilmedi.
- **Uygulama kaydı (2026-10-12, beşinci dilim kodlandı; manuel kabul açık):** Android Profile tabı, iOS kart sırası ve edit/avatar/house info/invite/join/language/about/logout popup akışları eklendi. Telefon yönetimi iOS'taki gibi backend-bekliyor bildirimi ve görünür kontrollerle sınırlıdır. `auth/isAuth` profil alanları JNI v6'da taşınır; `AuthWireContract` mevcut `UpdateProfileRequest`/`UpdateProfileResponse` ve `GetImagesResponse` DTO'larını doğrular. Android `ProfileRepository` HTTP/Keystore ile çalışır; `AuthViewModel` profil ve dil durumunu, `HouseViewModel` aktif ev ve üyelik durumunu yönetir. Ev bilgisi istekleri geç gelen başka ev yanıtını atar; görseller sınırlandırılmış IO indirme ve bellek önbelleği kullanır. Dil kaydı sırası profil PUT → cache/remote yenileme → yeniden giriş; metinler mevcut localization key'lerinden alınır. Core 51 XCTest + 2 Swift Testing, bridge host 6, Android JVM 30/30, JNI v6 binding kontrolü, debug ve instrumentation APK derlemesi ile iOS Simulator hedefli uygulama derlemesi geçti. ARM64 debug APK yaklaşık 136 MiB. Cihaz bağlı olmadığı için yeni Compose instrumentation, gerçek backend uçtan uca akış ve iOS yan yana görsel parite henüz geçmedi; bu dilim `Tamam` sayılmaz.
- **Android 11/API 30 uyumluluk pilotu (2026-10-12; cihaz kabulü açık):** Redmi Note 8 Pro / Android 11 cihazında önceki API 31 APK'sı kurulamadığı için Android uygulaması ve Swift köprüsü `minSdk 30`a, Swift native hedef üçlüleri `android30`a hizalandı. Swift SDK API 30 hedefini sağlıyor; Gradle ARM64 + x86_64 Swift derlemeleri, Android JVM testleri ve debug/instrumentation APK derlemeleri geçti. ARM64 APK manifesti API 30, paketlenen yerel kütüphanelerin Android ELF hedef notları en fazla API 30; imza, ZIP bütünlüğü ve hizalama doğrulandı. Bu yalnız derleme/paketleme kanıtıdır: Redmi cihazda kurulum, JNI açılışı, gerçek API akışları ve performans kabulü bekleniyor. F0 ürün destek matrisi bu pilotla otomatik onaylanmış sayılmaz.
- **Uygulama kaydı (2026-10-12, Android görsel parite dilimi; cihaz kabulü açık):** Ürün sahibinin yan yana iOS/Android ekran görüntülerinde (yükleme, Home, Profile, New Chore, görev detayı) görünür farklar tespit edildi ve Android UI iOS bileşen ağacına göre yeniden kuruldu. `ui/theme/**` iOS `AppDesign`/`HouseJourneyTheme` tokenlarını, SF Symbol→Material ikon eşlemesini (`material-icons-extended`, release'de R8 ile budanır), renkli/ofsetli gölgeyi ve kart giriş animasyonunu taşır; `ui/components/**` `MainScreenBackground`, `BrandHeroCardBackground`, `BrandPopupHeaderBackground`, popup kabuğu/alanları, toast ve `UserAvatar`/`CachedRemoteImage` karşılıklarını içerir. `ui/main/MainTabScreen` iOS `MainTabView`/`CustomTabBar` gibi tek kabukta kayan seçim kapsülü, popup açıkken gizlenen yüzen bar ve Home uzun basma ev değiştirici popover'ını sunar; Dashboard/Profile artık bu kabuğun sekmeleridir. Dashboard kartları, FAB, New Chore/Chore Detail/New Announcement popup'ları, Profile kartları, çıkış onayı ve HouseLoading iOS'taki ölçü, renk, ikon ve animasyonlarla eşlendi; eksik payload anahtarları iOS fallback metinleriyle (`LocalizedText.get(key, fallback)`) çözülür, API tarihleri cihaz saat diliminde gösterilir. Uzak görsel indirme `platform/RemoteImageLoader`'a taşındı. Android JVM 30/30, debug ve instrumentation APK derlemesi geçti; ekranlar Robolectric ile yerelde render edilip iOS görüntüleriyle karşılaştırıldı (kalıcı test eklenmedi). Games sekmesi F9'a kadar görünür ama etkisizdir; profil popup'larının iç alanları yalnız ortak kabuk/buton stiliyle güncellendi. Gerçek cihazda kabul bekleniyor.
- **Uygulama kaydı (2026-10-15, Android görsel parite ikinci dilimi + klavye politikası; cihaz kabulü açık):** Ürün sahibinin yeni yan yana görüntüleri üzerine ev seçimi, ev oluşturma (tür kartı, "tren rayı" kişi sayısı seçici, özet popup'ı), ev katılma, ev hata ekranı, doğum günü, Profil Düzenle, Ev Bilgisi (sahip/üye görünümü, üye çıkarma, davet kodu bölümü) ve kalan profil popup'ları (avatar, dil, telefon, eve katıl, hakkında) iOS bileşen ağacına göre yeniden kuruldu; `ui/house/**` iOS `Views/House/**` gibi ekran başına dosyalara bölündü. iOS `.graphical`/`.compact` DatePicker karşılığı ortak `GraphicalCalendar`/`CompactDatePicker` bileşeni doğum günü, Profil Düzenle ve Yeni Görev'de kullanılır. Açılıştaki ikinci (eski) yükleme ekranı kaldırıldı: oturum geri yükleme `HouseLoadingPhase.CHECKING_AUTH` fazıyla aynı `HouseLoadingScreen` hedefinde gösterilir, geri yükleme hatası iOS `HouseErrorView` karşılığını kullanır. Klavye: Android tüm API seviyelerinde Android 15+ ile aynı edge-to-edge inset modelini kullanır (`WindowCompat.setDecorFitsSystemWindows(false)` + `adjustResize`); IME kökte bir kez `imePadding` ile tüketilir, odaktaki alan kaydırılabilir içerikte görünür alana gelir, boş alana dokunma `dismissKeyboardOnTap` ile activity kökünde ve her popup penceresinde odağı/klavyeyi kapatır. Dashboard header metni ve duyuru butonu dikeyde ortalandı. Android JVM testleri, debug ve instrumentation APK derlemesi geçti; yeni `KeyboardDismissTest` instrumentation testi eklendi (JVM'de touch mode zorlanarak doğrulandı; cihazda koşulmadı). Ekranlar yerelde Robolectric ile render edilip iOS görüntüleriyle karşılaştırıldı. Gerçek cihazda klavye ve görsel kabul bekleniyor.
- **Parite takip matrisi (F8):** `Tamam` yalnız otomatik test ve gerekli manuel karşılaştırma geçince yazılır.

| Akış | iOS referansı | Android karşılığı | Durum |
| --- | --- | --- | --- |
| İlk açılış/onboarding | `OnboardingView`, `AppRouter` | `OnboardingScreen`, `AuthViewModel`, `DataStore` | Kod + otomatik test geçti; manuel iOS görsel parite açık |
| Kalan auth ve doğum günü | `AuthView`, `EmailVerificationView`, `ForgotPasswordView`, `BirthdaySetupView` | `AuthWireContract` + JNI v3 + `AuthSessionRepository` + `AuthViewModel` + `ui/auth/**` | Kod + otomatik test geçti; gerçek API/cihaz ve iOS yan yana görsel kabul açık |
| Ev seçimi/oluşturma/katılma/değiştirme | `Views/House/**`, `HouseFlowCoordinator` | `HouseWireContract` + JNI v4 + `HouseSessionRepository` + `HouseViewModel` + `ui/house/**` | Kod/otomatik test geçti; gerçek backend, iOS yan yana görsel ve üyelik popup kabulü açık |
| Dashboard/görev/duyuru | `HouseDashboardView`, `DashboardCoordinator` | `DashboardWireContract` + JNI v5 + `DashboardRepository` + `HouseViewModel` + `ui/dashboard/**` | Kod/JVM/Core/bridge testi geçti; ürün sahibi önceki manuel testlerin başarılı olduğunu bildirdi; iOS yan yana görsel kayıt ve F8 bütünleşik kabul açık |
| Profil/ev yönetimi/logout | `ProfileView`, `ProfileCoordinator` | `ui/profile/**` + `ProfileRepository` + `HouseViewModel` + JNI v6 | Kod, sözleşme/JVM testi ve APK derlemesi geçti; cihaz instrumentation, gerçek API ve görsel kabul açık |
| Dil seçimi/cache/yeniden giriş | `LanguageSettingsPopup`, `LocalizationStore` | `AndroidLocalizationState` + profil UI + `AuthViewModel` | Kayıt/yenileme/yeniden giriş akışı kodlandı; gerçek cihazda hızlı seçim, offline/cache ve iOS paritesi açık |
| Oyun hub/oyun etkileşimi | `GamesHubView` ve oyun ekranları | F9+ | F8 kapsamı dışında |
- **Parite kaydı:** Her dilimde bu kartta `iOS kaynak ekran/aksiyon → Core kural/DTO → Android route/state/ekran → otomatik test → manuel görsel kabul` eşlemesi güncellenir. Özellikle onboarding, auth edge, house, dashboard, chore/announcement, profile/localization ve logout satırları kapatılmadan F8 tamamlanmış sayılmaz; oyun satırı F9+ olarak açıkça işaretlenir.
- **Dokunulacak mevcut dosyalar/dizinler:** iOS `Views/Core/**`, `Views/Authentication/**`, `Views/House/**`, `Views/Dashboard/**`, `Views/Profile/**`, ilgili `Services/**`, `ViewModels/Coordinators/**` ve `ViewModels/Stores/**` baseline/regression için; Core `AuthModels.swift`, `HouseModels.swift`, `ChoreModels.swift`, `UseCases/**`; Android `MainActivity.kt`, `platform/**`, `viewmodel/**`, `ui/**`, `swift-bridge/**`. iOS dizinlerini yeniden taşıma bu fazın önkoşulu değildir.
- **Yeni çıktılar:** Gerekli küçük Core wire/use-case testleri; Android `ui/onboarding/**`, `ui/auth/**`, `ui/house/**`, `ui/dashboard/**`, `ui/profile/**`, bunlara karşılık gelen ViewModel/platform adapter ve JVM/Compose instrumentation testleri. Parity/karar/test kayıtları yalnız bu dosyada tutulur.
- **Doğrulama:** Her dilimde Core fixture/golden contract ve bridge host testleri; Android JVM ViewModel/repository/state testleri, API 36.1 arm64 Compose/route testleri ve gerçek backend hesabıyla manuel akış. iOS'ta Core değişirse ilgili iOS regression/simülatör smoke da koşulur. JSON bozuk/eksik alan, 401/token kaybı, offline/time-out, çift submit, process recreation, geri tuşu, klavye ve TalkBack/font ölçeği kapsanır. Kullanıcıya manuel test adımları geliştirme sonunda sohbetten verilir; ayrı dosya açılmaz.
- **Performans/bellek kuralı:** F7 cold-start ölçümü referans kaydıdır, F8 bütçesi değildir. Aynı AVD ve release/profile build'de ilk etkileşim, auth→dashboard süresi, `house/details` payload/parse ve ilk çizim, dashboard scroll/frame, image cache hit/memory, dil yenileme ve ABI teslim boyutu ölçülür; iOS eş senaryosu ve F0'da kabul edilen bütçe ile karşılaştırılır. Ağ/JSON/JNI işi ana thread'de yapılmaz; ev detayı istekleri ev ID'si bazında dedupe edilir, stale response atılır; liste yeniden hesaplama ve resim indirme ekrana görünür ihtiyaçla sınırlanır. Kanıt olmadan rastgele sayısal hedef veya ön optimizasyon eklenmez.
- **Çıkış kriteri:** Kapsamdaki oyun dışı iOS yolculuklarının Android karşılığı gerçek API ile çalışır; onaysız görünür fark yoktur; Core/iOS/Android otomatik testleri ve ürün sahibinin manuel parite kabulü geçer. Her eksik akış veya yalnız iOS'ta backend-bekliyor durumu matriste açıkça belirtilir. F7/F0 release matrisi ve F12 sertleştirmesi ayrıca açık kalabilir; bunlar geçmiş gibi yazılmaz.
- **Rollback noktası:** Android'de route/feature bazında son çalışan ekrana geri dönülür; önceki auth/session sözleşmesi ve iOS davranışı korunur. Backend değişikliği gerektiren akışta sahte workaround üretilmez, açık karar kaydıyla durulur.
- **Tahmini efor:** 31–49 kişi-gün (dalgaların toplamı); mevcut ekran sayısı, backend fixture erişimi ve görsel parite doğruluğuna göre envanterden sonra güncellenir. Tek kişilik geliştirmede bu takvim günü değildir. Uygulama davranışı zaten iOS'ta varsa genel mimari soyutlama yerine mevcut küçük contract'ları genişletmek tercih edilir.
- **Sonraki faza geçiş kapısı:** Oyun dışı yolculuk matrisi tamamlanmış veya ürün sahibinin açıkça ertelediği satırlar işaretlenmiş; oyun hub/oyun etkileşimi F9+ bağımlılığı olarak görünür; sürüm kapısındaki cihaz/API ve performans borçları ayrıca takip edilir.

#### Faz 9 — Basit oyun pilotu ve deterministik testler

- **Durum / owner / tarih / karar / kanıt:** `Not started` · Owner: TBD · Tarih: — · ADR: oyun pilotu (RPS/Lucky Spin) · Kanıt: shared vectors + Android UI test.
- **Amaç:** Küçük saf oyun kuralını iki platformda aynı state/result üretecek biçimde Core'da kullanmak.
- **Önkoşullar:** F2 DTO/kural yaklaşımı; F5 JNI call path; Android ViewModel altyapısı.
- **Kapsam içi:** İlk önce RPS veya Lucky Spin gibi az çizim/fizik bağımlı oyun; seed/clock/protocol ve sonuç kuralı.
- **Kapsam dışı:** House Rockets realtime, yeni game mechanic, demo bot zorluğu değiştirme, renderer redesign.
- **Görevler:**
  - [ ] RPS/Lucky Spin arasından en az port maliyetli ve saf kurala sahip pilotu seç; nedenini ADR'de yaz.
  - [ ] Game command/state/revision ve seed/RNG contract'ını belirle; mevcut demo/sunucu yetkisini ayır.
  - [ ] Saf kuralları `HouseFlowCore/Games/<Pilot>`'a taşı; global clock/RNG erişimini enjekte et.
  - [ ] Edge case, reset, stale revision, replay ve seed golden vector testleri oluştur.
  - [ ] iOS mevcut ViewModel/service'i Core command/state'e bağla; Android JNI çağrısını oyun hamlesi başına kullan, frame başına değil.
  - [ ] Android mevcut UI akışı ve ekran sonucunu aynı sıra ve metinle gösterir; görünür kontrol veya kural ekleme.
- **Dokunulacak mevcut dosyalar/dizinler:** `Models/Games/RockPaperScissors/**`, `Models/Games/LuckySpin/**`, `Services/Games/RockPaperScissors/**`, `ViewModels/Games/**`, `Views/Discover/Games/**`.
- **Yeni çıktılar:** Core game rules/test vectors; Android `ui/games/<pilot>/**`, ViewModel/JNI facade method, deterministic test fixture.
- **Küçük PR dilimleri:** Kural/seed test; iOS binding; Android state binding; UI parity/smoke.
- **Doğrulama:** Her iki platform aynı seed+command sequence için aynı result/revision; cancellation/reset; screen sequence/feedback checklist.
- **Performans ölçümü:** Komut-to-state JNI p50/p95, allocation, game screen frame time; oyun turu başına çağrı sayısı.
- **Çıkış kriteri:** Golden testler aynı; Core rule dışında renderer/UI karar üretmiyor; JNI maliyeti kullanıcı input'una görünür gecikme yapmıyor.
- **Rollback noktası:** Pilot oyunun Android route'u geri çekilir; ortak pure rule testleri ve iOS wrapper ayrı ayrı kalabilir.
- **Tahmini efor:** 5–9 kişi-gün.
- **Sonraki faza geçiş kapısı:** Deterministic vectors iOS/Android'de tutarlı; F10 için snapshot batch taslağı ve ölçüm metodu kabul edilmiş.

#### Faz 10 — House Rockets, House Tanks ve House Switch: simulation/renderer ayrımı

- **Durum / owner / tarih / karar / kanıt:** `Not started` · Owner: TBD · Tarih: — · ADR: oyun motoru ve JNI batch API · Kanıt: golden simulation, renderer parity checklist, frame profile.
- **Amaç:** Oyun kuralı/physics authority'sini ortak simülasyonda, input ve çizimi platformlarda tutmak; yüksek frekanslı JNI boundary'yi batch snapshot'a indirgemek.
- **Önkoşullar:** F9 sim command/state kalıbı; F5 JNI; oyun dokümantasyonu baseline; multiplayer authoritative sınırı biliniyor.
- **Kapsam içi:** House Rockets önce; ardından House Switch/Tanks için bağımsız feasibility; world simulation, render DTO, input command, cadence, audio port.
- **Kapsam dışı:** SpriteKit'i JNI ile ortaklaştırma, game rules/physics değiştirme, frame başına object/callback JNI, yeni görsel efekt/control.
- **Görevler:**
  - [ ] Her oyun için rule authority, simulation tick, render frame, input coordinate, audio, lifecycle ve network sorumluluk matrisi çıkar.
  - [ ] House Rockets `Course/Simulation/RenderModels/RenderMapper` içinden UIKit/SpriteKit/Combine bağımsız saf sınırı doğrula.
  - [ ] Fixed tick, capped delta, course seed, collision, turn, elimination ve simultaneous tie için deterministic vectors oluştur.
  - [ ] Swift sim API'sini `advance(commandsBatch, elapsedTicks) -> snapshotDTO` benzeri toplu sınırda sun; çağrı başına dönen nesne sayısını düşük tut.
  - [ ] JNI DTO byte/element limitini, ownership, copy cost ve version'ı sabitle; frame provider'a closure export etme.
  - [ ] iOS SpriteKit scene yalnız snapshot/frame çizsin; `HouseRocketsScene.update` physics/sonuç kararı üretmesin; mevcut iOS görüntü/kurallar korunur.
  - [ ] Android render/input adapter'ı aynı snapshot ve command contract kullanır; renderer tek başına bot, collision veya winner kararı vermez.
  - [ ] House Switch ve Tanks için ayrı küçük assessment; simulation gerçekten platformdan bağımsız değilse zorla Core'a taşımak yerine yalnız saf policy'yi ayır.
  - [ ] Audio varsa sound event ID/value listesiyle platforma ver; Core audio session/device route bilmez.
- **Dokunulacak mevcut dosyalar/dizinler:** `Models/Games/HouseRockets/**`, `Models/Games/HouseSwitch/**`, `Models/Games/HouseTanks/**`, `Services/Games/HouseRockets/**`, `ViewModels/Games/**`, `Views/Discover/Games/HouseRockets/**`, `HouseSwitch/**`, `HouseTanks/**`, `HouseFlowApp.swift` orientation/lifecycle binding.
- **Yeni çıktılar:** Core `Games/HouseRockets/**`; render/input DTO contract; JNI `GameCoreFacade`; Android `platform/games/**` renderer/input/clock/orientation; sim golden scenarios; game architecture ADR.
- **Küçük PR dilimleri:** House Rockets simulation port + tests; iOS frame source binding; JNI batch facade; Android renderer snapshot smoke; House Switch assessment; Tanks assessment/port PR'ı (yalnız geçerse).
- **Doğrulama:** Seed/tick golden snapshots, geometry/collision edge tests, input-to-command, pause/resume/background, result tie, JNI invalid/oversize batch; iOS/Android renderer visually/behaviorally review edilir.
- **Performans ölçümü:** 60/90/120 Hz render'da JNI çağrı/frame ve snapshot byte count; p50/p95 crossing/copy time; Swift simulation p95; Compose recomposition, SpriteKit/Android frame time, dropped frames, native heap ve GC.
- **Çıkış kriteri:** Core deterministic; renderer kural sahibi değil; input mapping eşdeğer; batch JNI p95 kabul bütçesinde; iOS screenshot/behavior baseline korunmuş; oyun başına açık karar.
- **Rollback noktası:** Renderer başına eski local presentation bridge kullanılabilir; Core snapshot API korunurken JNI batch binding geri alınır. Physics değişikliği varsa bu fazda geri alınır, platform parity bozulmadan migrate edilmez.
- **Tahmini efor:** 14–24 kişi-gün (House Rockets); House Tanks/Switch kapsamına göre ilave 8–16 gün.
- **Sonraki faza geçiş kapısı:** House Rockets simulation, input, renderer, JNI batch ve lifecycle profile kabul edildi; diğer oyunların port/skip kararı ADR'de kayıtlı.

#### Faz 11 — Realtime multiplayer, reconnect ve lifecycle dayanıklılığı

- **Durum / owner / tarih / karar / kanıt:** `Not started` · Owner: TBD · Tarih: — · ADR: transport/reconnect authority · Kanıt: chaos/fault test report.
- **Amaç:** Online House Rockets session'ı Android transport'ta mevcut server authority, revision ve reconnect davranışıyla çalıştırmak.
- **Önkoşullar:** F3 transport contract, F6 Android socket adapter, F10 snapshot/input boundary.
- **Kapsam içi:** WebSocket connect/send/receive/ping/disconnect, codec validation, lobby/flight/result, reconnect/cancel ve background/foreground.
- **Kapsam dışı:** Sunucu protokolü/oyun otoritesi değiştirme, reconnect UX redesign, yeni notification/voice/audio etkileşimi.
- **Görevler:**
  - [ ] Mesaj/frame byte cap, text frame, session/token bağlama, error/status, heartbeat ve close semantics'i F0 fixture ile eşle.
  - [ ] Android socket transport'u tek receive consumer, cancellation ve generation/stale connection protection ile uygula.
  - [ ] Codec/compatibility validation ve online snapshot→render mapper'ı Core'da saf test et.
  - [ ] App background/foreground, activity recreation, network loss, server close, auth revoked ve reconnect sırasında pause/resume/session state'ini doğrula.
  - [ ] Demo/local session ile online server authority'yi açıkça ayır; local renderer sonucu server'a yazmasın.
  - [ ] iOS ve Android aynı protocol fixture/fault sequence ile davranış raporu verir.
- **Dokunulacak mevcut dosyalar/dizinler:** `Services/Network/GameRealtimeTransport.swift`, `GameRealtimeCodec.swift`, `NetworkHTTPModels.swift`, `Services/Games/HouseRockets/**`, `Models/Games/HouseRockets/*Realtime*/*Wire*`, `ViewModels/Games/HouseRockets/**`.
- **Yeni çıktılar:** Android realtime adapter, Core reconnect/session contract tests, fault fixture/chaos harness, lifecycle instrumentation, runbook.
- **Küçük PR dilimleri:** codec contract; Android socket transport; lobby session; flight input/snapshot; reconnect/background matrix; server staging run.
- **Doğrulama:** Network interruption/duplicate/out-of-order/stale revision, cancel during receive/send, token revocation, payload cap, resume without unintended time advance; backend staging only if approved/configured.
- **Performans ölçümü:** ping RTT, receive/decode/apply p50/p95, reconnect recovery, message bytes/rate, JNI batch overhead and game frame pacing under network load.
- **Çıkış kriteri:** Server remains sole multiplayer authority; Android reconnect result/error same contract as iOS; backgrounding never advances game unexpectedly; no stale native session leak.
- **Rollback noktası:** Android online route can be withheld while offline/demo and iOS paths stay; Android socket adapter independent revert; avoid backend rollback unless server change was separately authorized.
- **Tahmini efor:** 10–18 kişi-gün.
- **Sonraki faza geçiş kapısı:** Fault matrix complete on supported API/device; security and protocol review clear; recovery and frame budgets pass.

#### Faz 12 — Performans hardening, accessibility parity, security ve release hazırlığı

- **Durum / owner / tarih / karar / kanıt:** `Not started` · Owner: TBD · Tarih: — · ADR: release budget/supported matrix · Kanıt: signed release candidate report.
- **Amaç:** Ölçülmüş darboğazları ve release risklerini düzeltmek; işlev eşitliği ve güvenli platform entegrasyonunu release kriterine bağlamak.
- **Önkoşullar:** Release scope içindeki F7/F8 akışları ile ilgili oyun/realtime fazları tamam; kabul edilmiş F0 bütçeleri.
- **Kapsam içi:** Startup, memory, AAB/ABI, JNI, network, Compose recomposition, frame pacing, accessibility checks, secret/storage/security, CI/release notes.
- **Kapsam dışı:** Kullanıcıya görünen tasarım veya feature polish, yeni setting/customization, ürün davranışı iyileştirmesi.
- **Görevler:**
  - [ ] Release cihaz/OS matrisi, API seviyeleri, ABI, iOS deployment target ve test kapsamını freeze et.
  - [ ] Cold/warm startup, idle/peak/native heap, AAB device-delivery, JNI p50/p95, network, recomposition ve frame pacing baseline-vs-release raporu al.
  - [ ] Ölçümle doğrulanan darboğazları tek tek düzelt; her düzeltme için regression test/measurement linki ekle.
  - [ ] iOS/Android metin ölçekleme, screen reader semantics, focus, contrast/system setting ve keyboard/system back parity checklist'ini ürün davranışını değiştirmeden kapat.
  - [ ] Token at rest, TLS, log redaction, JNI input bounds, native memory ownership, dependency/pin/license/security scan review tamamla.
  - [ ] Release/debug configuration, crash reporting privacy, signing, CI required checks, rollback artifact ve release runbook doğrula.
  - [ ] Release candidate akışları için golden UX/behavior screenshots/checklists karşılaştır; onaysız UI farkı varsa release'i blokla.
- **Dokunulacak mevcut dosyalar/dizinler:** CI, pin manifests, `android/scripts/**`, iOS/Android platform adapters, only measured Core hot paths; `Documents/DESIGN.md`/product docs değişmez unless separately approved.
- **Yeni çıktılar:** Bu belgedeki release checklist/ölçüm kayıtları, ABI/AAB manifesti, rollback/runbook ve release notes; faza özgü yeni Markdown dosyası açılmaz.
- **Küçük PR dilimleri:** Tek ölçüm kategorisi veya güvenlik açığı başına PR; release wiring ve runbook ayrı.
- **Doğrulama:** Release build test matrix, device smoke, security/privacy review, contract suite, accessibility audit, rollback rehearsal (non-production).
- **Performans ölçümü:** Tüm F0 budget metrikleri aynı cihaz/senaryoda; outlier ve regression trendi açıklanır. Bütçe aşılırsa UI/behavior'ı sadeleştirme önerilmez; ölçüm sahibi ve teknik seçenek karara sunulur.
- **Çıkış kriteri:** Tüm release blocking testleri geçer; budget sahipleri onaylar; güvenlik/privacy ve accessibility parity açık bulgusuz; rollback runbook denenmiş.
- **Rollback noktası:** RC önceki stabil Android/iOS artifact'ına döner; server compatibility korunur. Native binary ve core package sürümü eşleşmiş artifact olarak geri alınır.
- **Tahmini efor:** 8–14 kişi-gün.
- **Sonraki faza geçiş kapısı:** Android release sign-off tamam; F13 için fayda/riski ayrıca değerlendirecek kadar stabil iş akışı ve yeşil CI geçmişi mevcut. F13 yapılmadan da Definition of Done sağlanabilir.

#### Faz 13 — İsteğe bağlı nihai repo fiziksel düzenlemesi

- **Durum / owner / tarih / karar / kanıt:** `Not started` · Owner: TBD · Tarih: — · ADR: repo layout move (go/no-go) · Kanıt: dry-run diff + CI + reviewer approval.
- **Amaç:** Yalnız stabil sistemde, repo fiziksel yerleşimini (`ios/`, `shared/`, `android/`, `docs/`) ekip/CI kullanımını ölçülebilir biçimde kolaylaştırıyorsa düzenlemek.
- **Önkoşullar:** F12 stabil release; package, schemes, Android Gradle ve CI pinleri oturmuş; move faydası belgeli.
- **Kapsam içi:** Klasör taşıma, Xcode group/source path, CI path, README/docs link ve ownership update.
- **Kapsam dışı:** Bu planın başında büyük repo taşıması, kaynak davranış/refactor, package bölme, API/UI değişikliği veya sırf estetik düzenleme.
- **Görevler:**
  - [ ] Mevcut layout'un somut maliyetini (CI path karmaşası, navigation, ownership) ve hedef faydayı yaz; fayda yoksa fazı `Not started` bırakıp kapat.
  - [ ] Xcode project references, synchronized groups, assets, tests, schemes, signing, Gradle paths ve CI scripts için move map çıkar.
  - [ ] Rename-aware diff ile dry run; file history/link risklerini gözden geçir.
  - [ ] Taşımayı kaynak değişikliklerinden ayrı, küçük ve otomatik rename olarak yap; aynı PR'da kod düzenleme yok.
  - [ ] Xcode/Gradle/CI/README/docs tüm path'lerini clean checkout'ta doğrula.
- **Dokunulacak mevcut dosyalar/dizinler:** Repo kökündeki Xcode app/source/assets/docs/CI paths; `shared/` ve `android/`. Sadece kararlaştırılmış path move.
- **Yeni çıktılar:** `ios/` altında taşınmış mevcut iOS proje/source (yalnız onayla), güncel link/path belgeleri ve move map.
- **Küçük PR dilimleri:** CI/path hazırlığı; iOS Xcode move; docs/root cleanup. Tek büyük rename PR yalnız git rename detection ve clean diff sağlanırsa.
- **Doğrulama:** Tam clean checkout'ta iOS/Android build-test CI; resources, generated JNI, app signing, package resolution, scripts ve local developer instructions kontrolü.
- **Performans ölçümü:** Move beklenen runtime performans değiştirmez; CI setup/checkout/build duration değişimi karşılaştırılır.
- **Çıkış kriteri:** Path değişikliği günlük çalışma veya CI'da net fayda sağlar; hiçbir runtime/source behavior değişmez; tüm path referansları güncel.
- **Rollback noktası:** Pure move PR revert edilir; release branch ve package path eski konuma döner.
- **Tahmini efor:** 2–5 kişi-gün. Fayda gösterilmezse efor 0; yapılmaması başarı kabul edilir.
- **Sonraki faza geçiş kapısı:** Takip eden faz yok. Karar “yapıldı” veya “gerek görülmedi” olarak ADR'de kapanır; repo düzeni migration DoD'sinin zorunlu koşulu değildir.

### Milestone'lar (M0–M6)

| Milestone | İçerik | Kanıt ve kabul sahibi |
|---|---|---|
| M0 — Baseline kabul | F0 davranış envanteri, Android hedef matrisi, cihaz/build ölçümleri ve karar owner'ları. | Ürün + teknik owner checklist'i kabul eder. |
| M1 — Shared core bootstrapped | F1 tek package/target ve CI; ilk F2 DTO fixture'ları. | iOS scheme + package CI run. |
| M2 — iOS core pilot stable | F2 gerekli modelleri, F3 iOS port/adapters, F4 tam pilot. | Golden contract/state ve iOS parity raporu. |
| M3 — Android native feasibility | F5 Gradle shell, pinli Swift SDK/NDK/JNI roundtrip ve ABI/API kanıtı. | Android teknik karar kapısı: pass/limit/defer. |
| M4 — Android platform + first feature | F6 adapters, F7 ilk Compose dikey akışı. | Security/contract/UI flow parity ve ölçüm raporu. |
| M5 — Feature/game parity scope | F8 release scope features; F9–F11 seçilmiş games/realtime. | Feature matrisi, deterministic vectors, multiplayer fault report. |
| M6 — Release ready | F12 hardening, security, accessibility, performance ve release runbook. | Release owner sign-off; F13 ayrı opsiyonel karar. |

### Kritik yol ve ilk dört haftalık örnek plan

Takvim bir örnektir; ekip kapasitesi, CI erişimi ve F0 ölçümleriyle güncellenir. Faz geçiş kapısı geçmeden sonraki milestone tarihi taahhüt edilmez.

| Hafta | Ana odak | Paralel iş | Hafta sonu kanıtı / kapı |
|---|---|---|---|
| 1 | F0: akış, wire model/API, iOS test/CI ve depolama envanteri | Diğer geliştirici Android minSdk/ABI/Swift SDK-JNI resmi gereksinimlerini araştırır; ürün kararı bekler. | M0 checklist, owner/tarih/ADR, baseline cihaz ve ölçüm senaryosu; UI davranışı kayıtlı. |
| 2 | F1: tek Swift Package + iOS local dependency + CI; test altyapısı | F0'dan gelen DTO fixture'larını hazırlama, kod taşımadan. | Package ve app clean CI; F2 küçük ilk DTO PR'ı açılabilir. |
| 3 | F2: auth/user DTO ve house/invite rule fixture; ilk Core testleri | Network contract örnekleri/Android toolchain pin taslağı ayrı çalışma. | M1; wire contract fixture ve iOS aynı JSON mapping. |
| 4 | F2 son dilimler, F3 HTTP port taslağı/iOS URLSession adapter ilk endpoint | Secure storage/localization port taslağı; F5 kapsamı hâlâ yalnız spike planlama olabilir. | F2 çıkış kanıtı; iOS pilot için port contract PR; plan/tahmin güncellenmiş. |

Örnek kritik yol sonraki haftalarda F3 → F4 → F5 → F6 → F7 olarak sürer. F9 oyun pilotu F4/F5 sonrası, auth/house feature işini bloke etmeyen ayrı dikey hat olarak başlayabilir. Ekip iki kişiyse ortak port adları ve DTO contract'ları için kısa design sync yapılır; eşzamanlı Core kodlaması yerine ayrı sahiplik seçilir.

### Haftalık ilerleme raporu şablonu

```markdown
## Hafta: YYYY-MM-DD – YYYY-MM-DD

### Genel durum
- Milestone: Mx / hedef tarih:
- Kritik yol durumu: On track | At risk | Blocked
- Bu hafta kapanan kararlar:

### Faz güncellemeleri
| Faz | Durum | Owner | Tamamlanan iş / PR | Kanıt | Kalan iş / ETA |
|---|---|---|---|---|---|
| F# | Not started / In progress / Blocked / Done | İsim | ... | ... | ... |

### Davranış ve UX/UI guardrail
- Baseline checklist farkı (yoksa “yok”):
- Onaysız görünür veya iş kuralı farkı: (varsa release blocker, owner ve düzeltme PR'ı)

### Ölçüm ve kalite
- Startup / memory / AAB / JNI / network / recomposition / frame pacing:
- CI kırığı ve flaky test:
- Security/accessibility bulguları:

### Risk ve karar ihtiyacı
| Risk/karar | Etki | Owner | Gerekli tarih | Sonraki eylem |
|---|---|---|---|---|

### Gelecek hafta
- En fazla üç hedef:
- Bekleyen bağımlılık veya kapasite:
```

### İlk geliştirme fazını başlatma kontrol listesi

F0 başlangıcında tamamlanacaklar:

- [ ] Bir teknik sorumlu ve bir ürün/tasarım karar sahibi belirle; karar sahibi UX/UI parity onayını verir.
- [ ] İşin kapsamını “iş mantığını ve platform kodunu ayırma; iki native uygulama” olarak kaydet.
- [ ] Auth, house, chore, profile, localization ve oyun için mevcut iOS akışlarının owner'ını belirle.
- [ ] Xcode scheme, deployment target, app launch, tests/CI ve repository layout bilgisini linkle.
- [ ] Mevcut backend DTO/error/localization/realtime sözleşmesinin hangi fixture veya dosyadan doğrulandığını yaz; bilinmeyeni soru/owner olarak aç.
- [ ] Baseline ölçümü için aynı iOS cihazı/simülatör ve release build koşulunu belirle; Android için minSdk/ABI kararını araştırma maddesi yap.
- [ ] Token/preferences migration hassasiyetini ve mevcut kullanıcı datası riskini kayda geçir.
- [ ] İlk sprint için sadece envanter ve karar çıktısı seç; kod taşıma hedefi ekleme.
- [ ] Her faz sahibi için durum, tarih, karar kaydı ve kanıt linki alanlarını doldur.
- [ ] F0 geçiş kapısında owner onayı olmadan Package/Xcode düzenlemesine başlama.

#### İlk aşamada yapılmayacaklar

- SwiftUI ekranını Compose ile ortaklaştırmak ya da iOS görünümünü yeniden tasarlamak.
- Yeni kullanıcı etkileşimi, ayar, görünür özelleştirme, metin/renk/animasyon veya ürün davranışı önermek.
- Tüm repo'yu taşıma; `.xcodeproj`'u `ios/` altına almayı F1/F2 önkoşulu yapmak.
- Başlangıçta birden fazla Swift Package/production target, geniş DI/container, generik plugin sistemi veya ortak UI framework kurmak.
- Ölçmeden Swift Android/JNI'ı tüm servis ve oyunlara yaymak; her frame için JNI callback kullanmak.
- API/backend sözleşmesini varsayımla değiştirmek veya Core içine UIKit/SpriteKit/URLSession/Security tipleri almak.
- Build/test/benchmark sonuçlarını baseline olmadan başarı diye raporlamak; test verisi içinde token/PII loglamak.
- Faz kapılarını atlamak, owner/karar/kanıt olmadan `Done` yazmak veya F13 repo düzenini ürün paritesi şartı yapmak.

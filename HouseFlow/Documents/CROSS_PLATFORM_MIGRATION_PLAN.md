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
│   └── app/src/main/kotlin/.../
│       ├── ui/                           # Compose ekranları ve bileşenleri
│       ├── viewmodel/                    # lifecycle-aware state holder'lar
│       ├── navigation/                   # Navigation Compose graph
│       ├── platform/                      # adapters, JNI facade, dependency graph
│       └── MainActivity.kt
├── scripts/                               # pin kontrolü, metadata/asset ve CI yardımcıları
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

- `scripts/` altında yalnız tekrar kullanılabilir küçük işler: pin tutarlılığı doğrulama, Swift Android package cross-compile, JNI facade generation check, fixture doğrulama ve ölçüm artifact toplama. Script'ler iş akışını saklamaz; okunur, başarısızlıkta non-zero çıkar.
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

Bu ek, yukarıdaki özet fazları uygulanabilir iş paketlerine açar. Mevcut ürün davranışı ve UX/UI guardrail'leri aynen geçerlidir. “Dokunulacak” listeleri planlanan sınırı gösterir; her dosyanın tek PR'da taşınması gerekmez. Faz başında kapsam netleştirilir, sonunda kanıt eklenmeden faz `Done` yapılmaz. Test/build burada yalnızca gelecek uygulama işinin doğrulama planıdır; bu belgeyi hazırlarken çalıştırma anlamına gelmez.

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

- **Durum / owner / tarih / karar / kanıt:** `Not started` · Owner: TBD · Başlangıç–bitiş: — · ADR: Android destek matrisi ve baseline bütçesi · Kanıt: checklist + ölçüm raporu linkleri.
- **Amaç:** Taşınacak davranışı, teknik başlangıç değerlerini ve belirsizlikleri kod değiştirmeden görünür kılmak.
- **Önkoşullar:** Repo ve erişilebilir iOS scheme/CI hakkında bilgi; kritik akışları çalıştırabilecek test cihazı/simülatör veya kayıtlı çıktılar.
- **Kapsam içi:** Akış, API, model, localization, depolama anahtarları, oyun kuralları, CI/toolchain ve ölçüm envanteri.
- **Kapsam dışı:** Kod taşıma, UI yenileme, Android ekran implementasyonu, backend sözleşmesi değiştirme.
- **Görevler:**
  - [ ] `Documents/PRODUCT.md`, `Documents/DESIGN.md`, `Documents/Games/README.md` ve multiplayer planından gözlemlenebilir akış/oyun kuralı checklist'leri çıkar.
  - [ ] Login, signup, doğrulama, otomatik login, house seçimi/oluşturma/katılma, chores, profile, localization, logout ve hata/boş/yükleniyor durumlarının mevcut ekran sırası ile sonuçlarını kaydet.
  - [ ] API path, method, query, JSON, status/error envelope, realtime frame ve localization key örneklerini mevcut dosyalardan/fixture'lardan envanterle; belirsiz olanı tahmin etmeden işaretle.
  - [ ] Keychain/UserDefaults anahtarları, cache yeri/expiry, iOS scheme/deployment target, test suite ve mevcut CI/toolchain listesini kaydet.
  - [ ] iOS cold/warm startup, idle/oyun bellek, House Rockets frame pacing ve app boyutu için cihaz/build/senaryo bilgisini içeren baseline raporu planla/al.
  - [ ] Android minSdk, hedef cihaz/ABI ve desteklenecek release kanallarına dair ürün varsayımını karar sahibiyle kayda geçir.
- **Dokunulacak mevcut dosyalar/dizinler:** Yalnız okuma: `Models/**`, `Services/**`, `ViewModels/**`, `Views/**`, `HouseFlowApp.swift`, `Documents/PRODUCT.md`, `Documents/DESIGN.md`, `Documents/Games/README.md`, `HouseFlow.xcodeproj/**`, CI yapılandırması varsa ilgili dosyalar.
- **Yeni çıktılar:** Öneri: `docs/migration/behavior-inventory.md`, `docs/migration/baseline.md`, `docs/adr/0001-android-support-matrix.md`. Dosya adları repo doküman düzenine göre uyarlanabilir; mevcut `Documents/` yapısı korunabilir.
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

- **Durum / owner / tarih / karar / kanıt:** `Not started` · Owner: TBD · Tarih: — · ADR: port API ve error mapping · Kanıt: adapter contract CI.
- **Amaç:** Core'un bağımlı olacağı minimum portları tanımlayıp mevcut iOS platform servislerini adapter arkasına almak.
- **Önkoşullar:** F2'nin gerekli DTO grupları; F0 token, preference, localization ve HTTP davranışı envanteri.
- **Kapsam içi:** HTTP, secure storage, preferences, localization, clock/logging için gerçekten kullanılan minimum sözleşmeler; iOS implementasyonu.
- **Kapsam dışı:** Android adapter, geniş kapsamlı dependency injection framework, generic ağ abstraction'ı veya ürün akışı değişimi.
- **Görevler:**
  - [ ] Her portu kullanan use case'i ve platforma bağımlı işlemi eşleştir; kullanılmayan soyutlama ekleme.
  - [ ] `HTTPRequest/HTTPResponse/HTTPClient` ve normalize hata tipini mevcut status/error envelope'a göre tanımla.
  - [ ] Keychain, preferences ve localization cache için typed, küçük kontratlar oluştur; token/log redaction kuralını belirt.
  - [ ] Clock ve logging portlarını yalnız determinism/diagnostic ihtiyacı olan Core use case'lerine ekle.
  - [ ] `URLSession`, `Security`, `UserDefaults`, `UIKit` kullanımlarını iOS adapter'da tut; `AppDependencies` üzerinden graph kur.
  - [ ] Her adapter için fake/contract test yaz; mevcut iOS servisini port arkasına tek tek geçir.
- **Dokunulacak mevcut dosyalar/dizinler:** `Services/Protocols/ServiceProtocols.swift`, `Services/Network/**`, `Services/KeychainService.swift`, `Services/LocalizationService.swift`, `Services/AppDependencies.swift`, gereken `Services/**` call site'ları.
- **Yeni çıktılar:** `shared/Sources/HouseFlowCore/Ports/**`, iOS `Platform/` veya mevcut `Services/Platform/` altında HTTP/Keychain/preferences/localization adapter'ları, adapter test doubles ve port ADR.
- **Küçük PR dilimleri:** (1) HTTP contract + URLSession adapter, (2) secure storage/preferences, (3) localization/cache, (4) composition root ve endpoint migration. Sözleşme değişirse önce ADR/fixture PR.
- **Doğrulama:** Hata zarfı/status/header/query/encoding contract; token load-save-delete; old preference migration; localization fallback/cache; iOS akışları eski sonuçları üretir.
- **Performans ölçümü:** URLSession round-trip, JSON decode, localization cache hit/miss; adapter katmanı latency/alloc baseline'ı anlamlı artırmamalı.
- **Çıkış kriteri:** iOS üretim graph'ı tüm taşınmış portları adapter ile sağlar; hiçbir token platformlar arası plaintext'e düşmez; iOS golden akışları geçer.
- **Rollback noktası:** Port başına `AppDependencies` binding eski servise döner; henüz ortak feature state'e toplu geçiş yapılmaz.
- **Tahmini efor:** 7–12 kişi-gün.
- **Sonraki faza geçiş kapısı:** En az bir HTTP, storage ve localization contract iOS'ta uygulanıp kanıtlı; iOS login/restore ve bir API hata akışı aynı.

#### Faz 4 — Tek uçtan uca iOS Core pilotu

- **Durum / owner / tarih / karar / kanıt:** `Not started` · Owner: TBD · Tarih: — · ADR: ilk Core use case seçimi · Kanıt: iOS pilot PR + senaryo raporu.
- **Amaç:** Bir gerçek iOS akışını View → ViewModel/use case → Core → adapter → backend boyunca ortak sınırdan yürütmek.
- **Önkoşullar:** F3 portları ve iOS adapter'ları; pilot akış için API fixture ve UX baseline.
- **Kapsam içi:** Önerilen auth session restore/login alt akışı veya küçük, az riskli house sorgusu; tek seam.
- **Kapsam dışı:** Tüm ViewModel'ları taşıma, `ObservableObject`/SwiftUI'yı Core'a sokma, ekran davranışını değiştirme.
- **Görevler:**
  - [ ] Küçük ve ölçülebilir pilot seçimini (tercihen token restore + isAuth route) ADR'de açıkla.
  - [ ] Core use case giriş/çıkış state'lerini değer tipleriyle tanımla.
  - [ ] iOS ViewModel/Coordinator'u Core use case'i çağıran ince bağlayıcı yap; SwiftUI view ağacını değiştirme.
  - [ ] İptal, tekrar çağrı, offline, 401 ve restore başarısızlığını fake portla test et.
  - [ ] Üretim AppDependencies graph'ında tek pilot yolu aç; eski yol fallback/revert olanağı sürsün.
  - [ ] Aynı girişlerde önceki başlangıç route'u ve hata metni anahtarı sonuçlarını karşılaştır.
- **Dokunulacak mevcut dosyalar/dizinler:** `ViewModels/AppViewModel.swift`, `ViewModels/AuthenticationViewModel.swift`, `ViewModels/Navigation/AppRouter.swift` veya seçilen dar feature, `Services/AppDependencies.swift`, ilgili `Views/**` yalnız binding gerektikçe.
- **Yeni çıktılar:** `Core/UseCases/**`, pilot `Core/State/**` ve unit tests; `docs/migration/ios-pilot.md`.
- **Küçük PR dilimleri:** Use case/state test; iOS ViewModel binding; dependency graph switch; davranış karşılaştırma raporu.
- **Doğrulama:** Unit + adapter contract + iOS simulator/device senaryo; baseline route/ekran/voiceover label değil mevcut UI değerleri karşılaştırması. Fark olursa feature merge edilmez.
- **Performans ölçümü:** Restore/login akış latency, cold-start ve allocations karşılaştırılır; pilotun UI startup'ına ek gecikmesi raporlanır.
- **Çıkış kriteri:** Bir tam akış Core sınırından geçiyor, aynı state ve görünür sonuç çıkıyor; kod sahipliği anlaşılır ve iOS'a özgü binding Core'dan ayrıdır.
- **Rollback noktası:** Tek composition binding/feature flag eski iOS use case'e döner; ortak DTO/contract fixture kalabilir.
- **Tahmini efor:** 4–7 kişi-gün.
- **Sonraki faza geçiş kapısı:** Pilot iki farklı auth/session senaryosunda doğrulandı; iOS davranışı aynı; F5 için Android Core yüzeyi/Swift type kısıtları yazılı.

#### Faz 5 — Android Gradle shell ve Swift SDK/JNI roundtrip

- **Durum / owner / tarih / karar / kanıt:** `Not started` · Owner: TBD · Tarih: — · ADR: minSdk/ABI/JNI · Kanıt: pinned shell, CI cross-compile ve device/emulator JNI raporu.
- **Amaç:** Android host iskeletini ve en küçük Swift çağrısını üretim UI akışından bağımsız doğrulamak.
- **Önkoşullar:** F4 Core API pilotu; Android destek matrisi taslak/onay; toolchain araştırması.
- **Kapsam içi:** Gradle shell, NDK/Swift SDK/JDK pinleme, native library packaging, bir input/output JNI façade ve smoke.
- **Kapsam dışı:** Auth/UI, tüm Core'u bridge etme, frame başına native çağrı, genel Swift/Kotlin binding generator yazma.
- **Görevler:**
  - [ ] Swift Android resmi SDK/toolchain eşleşmesi, NDK, JDK, Gradle wrapper/AGP/Kotlin ve SwiftJava gereksinimini araştırıp pin kararını al.
  - [ ] `android/` minimal app + Gradle wrapper ve Kotlin package kur; gereksiz product screen ekleme.
  - [ ] Bir Core saf fonksiyonunu seç; Swift SDK ile hedeflenen Android ABI'ler için cross-compile et.
  - [ ] `swift-java` JNI generation kullanarak versioned DTO/primitive alanla `ping` veya deterministic test-vector çağrısı yap.
  - [ ] Native load, null/invalid input, hata dönüşü, payload sınırı, Kotlin coroutine cancellation ve lifecycle close'u sınırla.
  - [ ] Min API ve ABI matrisi üzerinde emulator/cihaz smoke çalıştır; debug/release paketlemeyi kıyasla.
  - [ ] CI'da pin kontrolü, cross-compile ve wrapper/codegen drift kontrolü ekle.
- **Dokunulacak mevcut dosyalar/dizinler:** `shared/Package.swift` / Core public API (yalnız gerekli tip), CI/pin dosyaları; mevcut iOS ekranları değişmez.
- **Yeni çıktılar:** `android/settings.gradle.kts`, root/app Gradle dosyaları, wrapper, `android/app/src/main/**`, `android/app/src/test/**`, JNI façade/generated binding policy, Swift SDK/NDK pin manifest, `scripts/check-android-toolchain.sh` benzeri doğrulama script'i, spike raporu.
- **Küçük PR dilimleri:** (1) Gradle empty shell, (2) pinned Swift cross-compile CI, (3) JNI ping/value DTO, (4) API/ABI/device smoke ve size report.
- **Doğrulama:** Cross-compile, .so load, roundtrip, release shrink/package ve desteklenen API/ABI; generated code tekrar üretimi aynı sonuçta.
- **Performans ölçümü:** Startup'a native load etkisi, JNI çağrı latency/allocation, birleşik ve ABI split AAB teslim boyutu, native memory.
- **Çıkış kriteri:** Clean CI'da pinli toolchain; desteklenen tüm hedef ABI'de load/call/cancel; p95/startup/AAB bütçeleri F0'da kabul edilmiş sınırda.
- **Rollback noktası:** `android/` shell ve native dependency ayrı revert edilebilir; iOS app ve Core host testleri etkilenmez. JNI kapısı geçmezse sonraki Android entegrasyon işi durur, Kotlin uygulama kararı ayrıca ele alınır.
- **Tahmini efor:** 5–10 kişi-gün (belirsizlik payı yüksek).
- **Sonraki faza geçiş kapısı:** Ürün sahibi desteklenecek min API/ABI'yi kabul eder; CI ve gerçek runtime spike geçer; JNI error/cancel/lifecycle ownership belgeli.

#### Faz 6 — Android platform adapter'ları

- **Durum / owner / tarih / karar / kanıt:** `Not started` · Owner: TBD · Tarih: — · ADR: Android storage/network adapter seçimi · Kanıt: contract test ve security review.
- **Amaç:** Core portlarını Android platform API'leriyle güvenli ve aynı sözleşmede çalıştırmak.
- **Önkoşullar:** F3 port kontratları; F5 JNI ve Android shell kapısı.
- **Kapsam içi:** Keystore destekli secure storage, DataStore preferences, HTTP, remote localization/cache, lifecycle ve log adapter'ları.
- **Kapsam dışı:** Görünür UI, yeni auth davranışı, API endpoint/schema değişikliği, generic Android platform framework.
- **Görevler:**
  - [ ] Token ve hassas değer için Keystore-backed encryption/key invalidation ve logout silme politikasını tanımla.
  - [ ] DataStore'a onboarding/session preference eşlemesini idempotent yap; hassas token DataStore/plain preferences'a yazılmasın.
  - [ ] HTTP adapter'da URL/query/header/body/error envelope, timeout, cancellation ve TLS konfigürasyonunu iOS contract ile eşleştir.
  - [ ] Localization endpoint/cache key, invalidation, fallback ve dil seçimi verisini mevcut sözleşmeyle uygula.
  - [ ] Lifecycle event'lerini yalnız Core session/use case'e gerekli active/background sinyali olarak aktar.
  - [ ] Structured log ekle; token, auth header, e-posta/PII ve oyun payload'ını redakte et.
  - [ ] Adapter contract testlerini aynı fixture ile çalıştır; cihaz üzerinde storage reopen ve process death senaryosunu doğrula.
- **Dokunulacak mevcut dosyalar/dizinler:** Core `Ports/**`, Android `platform/**`; iOS `Services/Network/**`, `KeychainService.swift`, `LocalizationService.swift` yalnız port kontratı güncellemesi gerekirse.
- **Yeni çıktılar:** Kotlin `SecureTokenStore`, `PreferencesStore`, `HTTPAdapter`, `LocalizationRepository`, `LifecycleBridge`, `AppLogger`; unit/instrumentation/contract tests; security notes.
- **Küçük PR dilimleri:** Secure storage; HTTP + error map; preferences; localization; lifecycle/logging. Bir PR bir port.
- **Doğrulama:** Shared fixture contract, TLS/timeout/cancel, key invalidation/logout, encrypted-at-rest review, offline/cache/fallback, log scan.
- **Performans ölçümü:** HTTP request overhead, secure-store read/write latency, localization cold/hot cache, background wake-up ve heap.
- **Çıkış kriteri:** Her port contract testli; token güvenli; iOS/Android aynı domain sonucu; log privacy review tamam.
- **Rollback noktası:** Adapter binding tek tek önceki Kotlin/platform implementasyonuna döner; veri migration'ı kayıpsız ve tekrar çalışabilir olmalı. Token migration rollback'i kullanıcı verisini temizlememeli.
- **Tahmini efor:** 8–14 kişi-gün.
- **Sonraki faza geçiş kapısı:** Auth için gerekli token, HTTP, preferences ve lifecycle adapter'ları desteklenen min API'de kanıtlı; güvenlik ve offline hata semantiği review edilmiş.

#### Faz 7 — İlk Android dikey feature

- **Durum / owner / tarih / karar / kanıt:** `Not started` · Owner: TBD · Tarih: — · ADR: ilk Android feature kapsamı · Kanıt: Compose akış testi + baseline checklist.
- **Amaç:** Bir kullanıcı akışını Compose → ViewModel → Core → Android adapter → API hattında tamamlamak.
- **Önkoşullar:** F5/6 geçilmiş; F0 UX baseline; F4 iOS pilot.
- **Kapsam içi:** Auth login/session restore veya kararlaştırılmış en küçük tam auth dilimi; state, route ve mevcut metin/validation.
- **Kapsam dışı:** Yeni onboarding, görünür tercih, redesign, iOS ekranını piksel kopyalama, tüm auth edge-case'leri aynı PR'da.
- **Görevler:**
  - [ ] Android auth ekranı ve state geçişini mevcut iOS/ürün baseline'ından tanımla: alan, mevcut validation, hata/başarı ve route.
  - [ ] Compose ViewModel'i Core state/use case'e bağla; coroutine lifecycle/cancel kurallarını belirle.
  - [ ] Navigation Compose graph'ta yalnız ilgili route/back dönüşünü uygula; başlangıç route önceliğini koru.
  - [ ] Mevcut metin/localization key ve loading/error state eşlemesini yap; yeni kullanıcıya görünen seçenek ekleme.
  - [ ] TalkBack, sistem font ölçeği, klavye submit/back ve Android system back'i aynı akışın semantiğine göre kontrol et.
  - [ ] Aynı backend fixture ve iOS senaryosuyla login başarı/başarısızlık, restore ve logout testini tamamla.
- **Dokunulacak mevcut dosyalar/dizinler:** Core auth use case/port; iOS `Views/Authentication/**`, `ViewModels/AuthenticationViewModel.swift`, `AppRouter.swift` yalnız baseline karşılaştırması için okunur.
- **Yeni çıktılar:** Android `ui/auth/**`, `viewmodel/AuthViewModel.kt`, `navigation/**`, Compose UI/instrumentation tests; Android feature parity checklist.
- **Küçük PR dilimleri:** (1) state/use case binding, (2) Compose screens, (3) navigation + keyboard/back, (4) auth contract/smoke parity.
- **Doğrulama:** State test, Compose semantics/instrumentation, min API/cihaz smoke, UX checklist; visible copy/layout difference review edilir ama iOS'u yeniden tasarlamaya dönüştürülmez.
- **Performans ölçümü:** Android cold start, auth screen first interactive, recomposition count/duration, native library first call ve auth request latency.
- **Çıkış kriteri:** Android'de aynı iş akışı ve sonuç; sistem erişilebilirlik davranışı; hata/route parity; performans sınırı içinde.
- **Rollback noktası:** Auth route Android'de önceki placeholder/native fallback'e döner; Core port/adapter testleri kalabilir. iOS route etkilenmez.
- **Tahmini efor:** 6–10 kişi-gün.
- **Sonraki faza geçiş kapısı:** İki cihaz/API düzeyinde auth checklist geçer; ürün copy/state farkı yok; platform back/keyboard erişilebilirlik bulguları kapalı.

#### Faz 8 — Kalan auth, house, chore, profile ve localization dalgaları

- **Durum / owner / tarih / karar / kanıt:** `Not started` · Owner: TBD · Tarih: — · ADR: feature dalga sırası · Kanıt: feature PR/checklist indeksleri.
- **Amaç:** Kalan uygulama akışlarını dikey, küçük ve geri alınabilir dilimlerle Android'e taşımak.
- **Önkoşullar:** F7 auth pilotu; F2/3 model ve adapter contract'ları; ürün akış envanteri.
- **Kapsam içi:** Signup/email verification/forgot-password, house selection/create/join, dashboard chores/announcements, profile, localization; her akış mevcut kapsam kadar.
- **Kapsam dışı:** Yeni rol, ekran, filtre, kullanıcı etkileşimi, workflow veya görünür özelleştirme; API'yi sırf Android için değiştirme.
- **Görevler:**
  - [ ] Dalga sırasını bağımlılığa göre belirle: auth edge flow → house membership → dashboard/chore → profile/localization cache.
  - [ ] Her dalga için mevcut endpoint/DTO/route/state/error ve empty/loading checklist'i çıkar.
  - [ ] Feature başına ViewModel/use case/Compose screen değişikliklerini ayrı PR'lara böl; API contract testleri ortak kalır.
  - [ ] House seçimi ve membership state'ini auth session lifecycle ile eşle; token invalid/house absent gibi kenarları fixture ile test et.
  - [ ] Chore recurring/status/review, announcements ve profile update semantiğini mevcut Swift servisleriyle karşılaştır.
  - [ ] Localization remote/fallback/cache ve locale değişiminde mevcut ekran metinlerinin yenilenmesini doğrula.
  - [ ] Her akışta sistem back, process recreation, offline/error ve erişilebilirlik checklist'ini tamamla.
- **Dokunulacak mevcut dosyalar/dizinler:** Core `Domain/Services/Ports/**`; iOS `Services/AuthService.swift`, `HouseService.swift`, `ChoreService.swift`, `UserService.swift`, ilgili `ViewModels/**` ve `Views/**` baseline için.
- **Yeni çıktılar:** Android `ui/house/**`, `ui/dashboard/**`, `ui/profile/**`, `viewmodel/**`, feature tests, localization adapter/resources; `docs/migration/parity/**` indeks.
- **Küçük PR dilimleri:** Signup/verif; house choose/create; join/invite; dashboard read; chore update/review; announcements; profile update; localization/cache. Her slice tek user journey.
- **Doğrulama:** Shared contract fixtures + ViewModel state tests + Compose semantics/UI smoke; backend staging varsa contract integration; iOS reference checklist.
- **Performans ölçümü:** Dashboard data load, image/cache davranışı mevcut platform beklentisine göre; list recomposition/scroll frame time; profile image fetch; localization refresh latency.
- **Çıkış kriteri:** Kapsamdaki her mevcut akışın Android karşılığı var ve davranış parity checklist'i geçti; backend/API hataları aynı domain state'e çevriliyor.
- **Rollback noktası:** Feature/route bazında Android eski ekrana/placeholder'a dönebilir; diğer dilimler bağımsız kalır. Backend değişikliği gerektiren akış durdurulur, tahmini workaround eklenmez.
- **Tahmini efor:** 20–35 kişi-gün; kapsamlı iOS paritesi için daha yüksek olabilir.
- **Sonraki faza geçiş kapısı:** Planlanan non-game flow listesi açıkça tamamlandı veya ürün sahibinin onayladığı release scope'ta ertelendi; UX/UI farkı onaysız değil.

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
- **Dokunulacak mevcut dosyalar/dizinler:** CI, pin manifests, `scripts/**`, iOS/Android platform adapters, only measured Core hot paths; `Documents/DESIGN.md`/product docs değişmez unless separately approved.
- **Yeni çıktılar:** `docs/release/android-release-checklist.md`, perf/security report, ABI/AAB manifest, rollback/runbook ve release notes.
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

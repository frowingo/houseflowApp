# Görev: HouseFlow → FausCrew yeniden adlandırması (iOS + Android + shared Swift)

Sen bu repoda (`/Users/frowing/Projects/houseflowApp`) çalışan bir kodlama ajanısın. Uygulamanın adı **HouseFlow**'dan **FausCrew**'e değişiyor. Marka varlıkları (ikon, splash, `Theme.FausCrew`, `FausMark`, `FausHero`, `FausSplash`, `FacebookDisplayName`) zaten FausCrew; senin işin kalan her şeyi tutarlı biçimde taşımak.

## Sabit kararlar (tartışma, uygula)

- Uygulama **henüz hiçbir mağazada yayında değil** → bundle ID, applicationId ve cihazda saklanan anahtarlar migration yazmadan değiştirilebilir.
- Kapsam **tam**: görünen ad, kimlikler, kod içi tip/modül/paket adları, klasör/dosya adları, CI, dokümanlar.
- Yazım kuralları:
  | Eski | Yeni |
  |---|---|
  | `HouseFlow` (PascalCase) | `FausCrew` |
  | `houseFlow` (camelCase) | `fausCrew` |
  | `houseflow` (küçük harf, paket/scheme/anahtar) | `fauscrew` |
  | `HOUSEFLOW` | `FAUSCREW` |
  | `house_flow` / `house-flow` (varsa) | `faus_crew` / `faus-crew` |
- Kullanıcıya görünen ad tam olarak **`FausCrew`** (boşluksuz, F ve C büyük).

## Kesinlikle DOKUNMA

1. **Ev/hane domain terimi "House"**: `House`, `HouseService`, `HouseRockets*`, `HouseTanks*`, `HouseSwitch*`, `HouseMembersCard`, `HouseInfoPopup`, `houseRocketsProtocol.json`, `FausHouseIcon` vb. Bunlar uygulama adı değil, "ev" kavramı. Sadece `HouseFlow` / `houseflow` token'ı değişir. Toplu `sed` ile `House` → `Faus` gibi bir şey yapma.
2. **Backend URL'leri**: `https://houseflowapi.fly.dev/api/v1` (`HouseFlow/Services/Network/AppEnvironment.swift`, `AndroidHttpAdapter.kt` → `LIVE_BASE_URL`) ve `https://api.houseflow.app/api/v1`. Sunucu tarafı taşınmadan değişirse uygulama çalışmaz. Olduğu gibi bırak, final raporda "takip işi" olarak listele.
3. **Sosyal giriş gizli/harici değerleri**: `GIDClientID`, `com.googleusercontent.apps.323555794723-…` URL scheme, Facebook/Snap placeholder'ları. Yeni değer uydurma; final raporda listele.
4. Repo kök klasör adı (`houseflowApp`) ve GitHub remote (`frowingo/HouseFlowApp`): dokunma, raporda belirt.
5. `FAUSCREW_RENAME_AGENT_PROMPT.md` (bu dosya): dokunma, commit'leme.
6. Üçüncü taraf paketler, `Package.resolved` içindeki dış bağımlılık kayıtları.

## Ön hazırlık

1. `git status` temiz olmalı. Değilse (ör. `HouseTanksBotController.swift` değişikliği) **dur ve kullanıcıya sor**; onun değişikliklerini commit'leme veya geri alma.
2. `dev` dalından `rename/fauscrew` dalını aç.
3. Envanter çıkar: `git grep -nI -iE 'house[_-]?flow'` çıktısını kaydet (başlangıçta ~256 dosya). İşin sonunda bununla karşılaştıracaksın.
4. Taşımalarda daima `git mv` kullan (geçmiş korunsun). Build çıktılarını (`HouseFlow/android/build`, `HouseFlow/android/app/build`, `swift-bridge/build`, `swift-bridge/.build`, `shared/.build`, DerivedData) taşımadan önce sil; bunlar git'te değil.

## Aşama 1 — iOS kimliği ve görünen ad

Dosyalar: `HouseFlow.xcodeproj/project.pbxproj`, `HouseFlowInfo.plist`, `HouseFlowDebugInfo.plist`, `HouseFlow.entitlements`, `HouseFlow.xcodeproj/xcshareddata/xcschemes/HouseFlow.xcscheme`.

- `PRODUCT_BUNDLE_IDENTIFIER`: `Iworf.HouseFlow` → `Iworf.FausCrew`, `Iworf.HouseFlowTests` → `Iworf.FausCrewTests` (Debug + Release, 4 yer). `Iworf.` önekini koru.
- App target build ayarlarına (Debug + Release) `INFOPLIST_KEY_CFBundleDisplayName = FausCrew;` ekle. Şu an display name yok, ana ekranda `PRODUCT_NAME` görünüyor.
- Target'ları yeniden adlandır: `HouseFlow` → `FausCrew`, `HouseFlowTests` → `FausCrewTests` (PBXNativeTarget `name`, `productName`, ürün referansları `FausCrew.app` / `FausCrewTests.xctest`, `TEST_HOST = "$(BUILT_PRODUCTS_DIR)/FausCrew.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/FausCrew"`, tüm `/* HouseFlow… */` yorumları, build configuration list adları).
- Plist anahtarları: `HouseFlowSocialProviders` → `FausCrewSocialProviders`, `HouseFlowAppleSignInEnabled` → `FausCrewAppleSignInEnabled` (her iki plist'te) ve okuyan kodda: `HouseFlow/Services/Social/SocialCredentialProviding.swift:54,59`. Test fixture'larında aynı anahtarlar geçiyorsa onları da güncelle.
- Snap URL scheme: `houseflow` → `fauscrew`, `SCSDKRedirectUrl` → `fauscrew://snap-kit/oauth2` (iki plist).
- Paylaşılan scheme: dosyayı `FausCrew.xcscheme` olarak taşı; `BuildableName`, `BlueprintName`, `ReferencedContainer = "container:FausCrew.xcodeproj"` değerlerini güncelle.
- `HouseFlow.xcodeproj/xcuserdata/` git'te takip ediliyor: kullanıcıya özel; içindeki breakpoint yolunu yeni klasöre göre güncelle (silme).

## Aşama 2 — Klasör/dosya taşımaları (iOS)

Proje Xcode 16 **file-system synchronized groups** kullanıyor (`PBXFileSystemSynchronizedRootGroup`), yani klasör taşıması + pbxproj'deki `path =` güncellemesi yeterli; tek tek dosya referansı yok.

| Eski | Yeni |
|---|---|
| `HouseFlow.xcodeproj/` | `FausCrew.xcodeproj/` |
| `HouseFlow/` (kaynak kökü; içinde `android/`, `shared/` de var) | `FausCrew/` |
| `HouseFlow/HouseFlowApp.swift` (`struct HouseFlowApp`) | `FausCrew/FausCrewApp.swift` (`struct FausCrewApp`) |
| `HouseFlowTests/` | `FausCrewTests/` |
| `HouseFlowTests/HouseFlowCoordinatorTests.swift` | `FausCrewTests/FausCrewCoordinatorTests.swift` |
| `HouseFlowInfo.plist`, `HouseFlowDebugInfo.plist` | `FausCrewInfo.plist`, `FausCrewDebugInfo.plist` |
| `HouseFlow.entitlements` | `FausCrew.entitlements` |

pbxproj'de `path = HouseFlow;`, `path = HouseFlowTests;`, `INFOPLIST_FILE`, `CODE_SIGN_ENTITLEMENTS`, local Swift package `relativePath = HouseFlow/shared;` → `FausCrew/shared` güncellenmeli. `@testable import HouseFlow` (23 yer) → `@testable import FausCrew` (modül adı target adından gelir).

pbxproj'yi metin olarak düzenle; ID'leri değiştirme. Her düzenlemeden sonra `plutil -lint FausCrew.xcodeproj/project.pbxproj` ile doğrula.

## Aşama 3 — Shared Swift paketi ve Android Swift bridge

- `FausCrew/shared/Package.swift`: paket `HouseFlowShared` → `FausCrewShared`, ürün/target `HouseFlowCore` → `FausCrewCore`, test target `HouseFlowCoreTests` → `FausCrewCoreTests`. Klasörleri `Sources/FausCrewCore`, `Tests/FausCrewCoreTests` olarak taşı. `import HouseFlowCore` (~96 yer) ve `@testable import HouseFlowCore` → `FausCrewCore`. `CoreBoundaryTests.swift` içindeki `"Sources/HouseFlowCore"` yolunu güncelle. pbxproj'deki `productName = HouseFlowCore` (2 yer) güncelle.
- `FausCrew/android/swift-bridge/`: `HouseFlowAndroidBridge` → `FausCrewAndroidBridge` (Package.swift adı, ürün, target, `Sources/` ve `Tests/` klasörleri, `HouseFlowAndroidBridgeTests`), `swift-java.config` içinde `"javaPackage": "com.fauscrew.androidbridge"`, `build.gradle` → `namespace 'com.fauscrew.androidbridge'`, generated java srcDir yolu, `libFausCrewAndroidBridge.so`. Swift tarafındaki `HouseFlowAndroidBridge` tipi/enum'u da `FausCrewAndroidBridge` olur. Kotlin'de `System.loadLibrary("HouseFlowAndroidBridge")` benzeri çağrıyı bul ve güncelle.
- `FausCrew/android/scripts/check-android-bindings.sh` ve `check-android-package.sh`: yollar, `package com.fauscrew.androidbridge;`, kütüphane adı.
- `Package.resolved` dosyalarını elle düzenleme; gerekirse `swift package resolve` ile yenile ve dış bağımlılık sürümlerinin değişmediğini `git diff` ile kontrol et.

## Aşama 4 — Android uygulaması

- `settings.gradle.kts`: `rootProject.name = "FausCrewAndroid"`.
- `app/build.gradle.kts`: `namespace = "com.fauscrew"`, `applicationId = "com.fauscrew"`, Gradle property `houseflowAbi` → `fauscrewAbi` (yorum dahil; README/dokümanlarda geçen `-PhouseflowAbi` kullanımlarını da güncelle).
- Kotlin paketleri: `app/src/{main,test,androidTest}/java/com/houseflow/**` → `java/com/fauscrew/**` (`git mv`), tüm `package com.houseflow…` / `import com.houseflow…` → `com.fauscrew…`.
- Tip/dosya adları: `HouseFlowTheme.kt`, `HouseFlowColors`, `HouseFlowType`, `HouseFlowIcons`, `HouseFlowPopup(.kt)`, `HouseFlowToast(.kt)` vb. → `FausCrew…`. iOS tarafındaki karşılıkları (`HouseFlowColors`, `HouseFlowType`, … Swift'te) için de aynısı; dosya adını tip adıyla birlikte değiştir.
- `AndroidManifest.xml`: `android:label="HouseFlow"` yerine `res/values/strings.xml` oluşturup `<string name="app_name">FausCrew</string>` ekle ve `android:label="@string/app_name"` kullan. Snap intent-filter `android:scheme="fauscrew"`.
- `res/values/social.xml`: `houseflow_social_providers` → `fauscrew_social_providers` (okuyan Kotlin kodunu güncelle), `snap_redirect_url` → `fauscrew://snap-kit/oauth2`.

## Aşama 5 — Cihazda saklanan anahtarlar, log subsystem'leri, metinler

Yayında olmadığı için doğrudan yeniden adlandır (migration yok):

- iOS `KeychainService` varsayılan servis: `com.houseflow.app` → `com.fauscrew.app`.
- iOS `AnnouncementCard.swift` `keyPrefix = "houseflow.read-announcements"` → `fauscrew.read-announcements`; Android `AnnouncementCard.kt` SharedPreferences adı aynı şekilde.
- `Logger(subsystem: "com.houseflow" | "HouseFlow")` → `"com.fauscrew"` (tümünü `com.fauscrew` olarak birleştir); Android `Log.i("HouseFlow", …)` tag'i → `"FausCrew"`.
- Android `AndroidPreferencesStore.kt` DataStore adı `houseflow_preferences` → `fauscrew_preferences` (property adı `houseflowPreferences` → `fauscrewPreferences`).
- Android `KeystoreSessionStore.kt`: `PREFERENCE_NAME = "fauscrew_secure_session_v1"`, `KEY_ALIAS = "com.fauscrew.session.v1"`. **Aynı adla** `res/xml/data_extraction_rules.xml` içindeki iki `exclude` satırını güncelle; uyuşmazsa şifreli oturum yedeğe sızar.
- Test dosyalarındaki geçici adlar (`houseflow-pref-test-…`, `houseflow_secure_session_test_…`, `com.houseflow.session.test…`, `HouseFlowTests-…`, `HouseFlowCoordinatorTests-…`, `HouseFlowBridgePerf`).
- Kullanıcıya görünen yedek metinler: `"Join {house_name} on HouseFlow with invite code {invite_code}."` (iOS `HouseInviteCodeSection.swift`, Android `HouseInfoPopup.kt`) → `on FausCrew`. `InviteCodeBridge.kt` hata mesajı → `"Incompatible FausCrew Swift bridge"`. Android test `AuthScreenTest.kt` `"app_name" to "FausCrew"`.
- `accessibilityLabel` / `contentDescription` zaten FausCrew; kontrol et.

## Aşama 6 — CI ve dokümanlar

- `.github/workflows/houseflow-android-bridge.yml` → `fauscrew-android-bridge.yml`; `name:`, `paths:` (`FausCrew/android/**`, `FausCrew/shared/**`, workflow dosyasının kendisi), `working-directory: FausCrew` ve tüm `HouseFlow…` referansları.
- `.claude/settings.local.json`: içinde eski yollar varsa güncelle.
- Markdown/JSON dokümanlar (`PRODUCT.md`, `DESIGN.md`, `Documents/**`, `shared/README.md`, `.impeccable/**`): ürün adı olarak geçen "HouseFlow" → "FausCrew", yollar/tip adları yeni haline. Geçmiş kayıt niteliğindeki plan dosyalarında da yolları güncelle ki ölü link kalmasın. `.impeccable/surfaces/` dosya adlarında eski yol parçası varsa olduğu gibi bırakabilirsin.

## Aşama 7 — Doğrulama (hepsi geçmeden bitmiş sayma)

1. Kalıntı taraması: `git grep -nI -iE 'house[_-]?flow'` çıktısı **yalnızca** şunları içermeli: backend URL'leri (`houseflowapi.fly.dev`, `api.houseflow.app`), GitHub repo URL'si/`houseflowApp` yolu, bu prompt dosyası. Başka her satır ya düzeltilmeli ya da raporda gerekçelendirilmeli. Ayrıca `git ls-files | grep -i houseflow` boş olmalı (bu dosya hariç).
2. `plutil -lint` tüm plist'ler ve pbxproj.
3. `swift test --package-path FausCrew/shared`
4. `swift test --package-path FausCrew/android/swift-bridge` ve `sh FausCrew/android/scripts/check-android-bindings.sh` (toolchain yoksa atla ve raporda söyle).
5. iOS: `xcodebuild -project FausCrew.xcodeproj -scheme FausCrew -destination 'platform=iOS Simulator,name=<mevcut bir iPhone>' build test`. Simülatörde açıp ana ekranda adın **FausCrew** göründüğünü ve oturum açma ekranının geldiğini kontrol et.
6. Android: `FausCrew/android` içinde `./gradlew :app:assembleDebug :app:testDebugUnitTest` (cihaz/emülatör varsa `connectedDebugAndroidTest`). Üretilen APK'da `aapt dump badging` ile `package: name='com.fauscrew'` ve `application-label:'FausCrew'` doğrula.
7. Önceki/sonraki test sayıları aynı olmalı; düşüş varsa nedenini bul.

## Commit düzeni

Mantıksal adımlar halinde, her biri derlenebilir olacak şekilde commit at (ör. 1: iOS kimlik + görünen ad, 2: klasör/target taşıma, 3: shared + bridge, 4: Android paket/kimlik, 5: anahtarlar + metinler, 6: CI + dokümanlar). Repo'nun commit mesajı stiline uy (`git log` bak). **Push etme, PR açma**; kullanıcı onaylayacak.

## Final rapor (kullanıcıya)

Kısa bir özet + şu **manuel/harici yapılacaklar** listesi (bunları sen yapamazsın, açıkça yaz):

1. **Apple Developer**: `Iworf.FausCrew` App ID oluştur, *Sign in with Apple* yeteneğini aç; provisioning profilleri yenile.
2. **App Store Connect**: "FausCrew" adıyla yeni uygulama kaydı aç (ad ancak bu kayıtla rezerve edilir).
3. **Google Play Console**: "FausCrew" uygulaması oluştur; `com.fauscrew` paketi ilk yüklemeyle kalıcı olarak alınır. Upload/app signing anahtarı.
4. **Google Cloud OAuth**: yeni bundle ID için iOS client → yeni `GIDClientID` ve ters client-ID URL scheme'i plist'e girilmeli; `com.fauscrew` + SHA-1 için Android client. Bu yapılana kadar Google ile giriş çalışmaz.
5. **Facebook / Snap Kit portalleri**: bundle ID / paket adı ve redirect `fauscrew://snap-kit/oauth2`.
6. **Backend**: Apple/Google token doğrulamasında `aud` (bundle ID / client ID) kontrolü varsa yeni değerleri ekle; uzaktan gelen `app_name` lokalizasyonunu "FausCrew" yap; ileride API domain'i (`houseflowapi.fly.dev`, `api.houseflow.app`) taşınacaksa ayrı iş.
7. İsteğe bağlı: GitHub repo ve yerel kök klasör adının değiştirilmesi.

Ayrıca: grep'te kalan ve bilerek bırakılan satırların listesi, çalıştırılamayan doğrulama adımları ve nedenleri.

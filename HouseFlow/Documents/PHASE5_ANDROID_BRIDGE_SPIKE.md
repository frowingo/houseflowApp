# Faz 5 — Android Swift köprü denemesi

Durum (11 Ekim 2026): **Faz 5 kullanıcı kararıyla kapatıldı; teknik spike yerel emülatörde doğrulandı.** İki ABI cross-compile ve paketleme, API 36.1 / arm64-v8a JNI testleri, kullanıcı tarafından sonradan çalıştırılan 14/14 Android instrumentation testi ve kabuk açılışı geçti. Temiz GitHub CI, API 31 x86_64 runtime, fiziksel cihaz ve kabul edilmiş performans bütçesi sürüm öncesi kontrolüne ertelendi. Geçici minSdk/ABI ayarları bu hedeflerin ürün desteği olarak kabul edildiğini göstermez. Android tarafı yalnız boş bir `Activity` ve JNI test yüzeyi içerir; ürün arayüzü değildir. Sonraki Faz 6 adapter'ları eklendi; bu belge JNI spike kararını kaydeder.

## Mimari karar

`HouseFlowCore` Swift/Android bağımlılığı almıyor. Android'e özel `android/swift-bridge` dinamik Swift paketi Core'a yerel paket bağımlılığı kuruyor ve yalnız iki üst seviye fonksiyon dışarı açıyor: `bridgeVersion()` ve `normalizeInviteCode(_:)`. Kotlin `InviteCodeBridge` girişi null ve 64 UTF-16 kod biriminden uzun input'u yerel çağrıdan önce reddediyor. Sürüm kontrolü yalnız ilk geçerli çağrıda yapılır; her normalleştirmeye ek JNI çağrısı yüklenmez. Swift tarafı mevcut `InviteCodeRules.normalized` kuralını çağırıyor. JNI üretilen kodun sahibi `swift-java` `JExtractSwiftPlugin`; üretilen dosyalar repoya eklenmiyor.

Bu fonksiyon kasıtlı olarak eşzamanlı, kısa ve state tutmuyor. Dolayısıyla bu denemede coroutine cancellation veya lifecycle close için gerçek bir kaynak yok; sonraki async/IO sınırı seçilene kadar sahte cancellation API'sı eklememek daha doğru. Başarısız native load şimdilik testte ve boş kabuk başlangıcında görünür hata üretir; üretim UI'sı buna bağlanmayacak.

## Geçici destek ve sürüm matrisi

| Bileşen | Deneme pini / karar | Durum |
| --- | --- | --- |
| Swift host + Android SDK | 6.4.0 ve `swift-6.4.0-RELEASE_android` | Kuruldu; iki ABI'de debug/release cross-compile geçti |
| Android NDK | r30 / `30.0.16248370` | Kuruldu; Swift SDK sysroot bağlantısı yapıldı |
| swift-java | 0.6.0, JNI modu | Host codegen/test ve cihaz JNI roundtrip geçti |
| Gradle / AGP | 8.13 / 8.13.2 | Debug/release APK, AAB ve unit test geçti; CI henüz çalışmadı |
| Kotlin / JDK | 2.0.21 / Gradle için 17+ | Android Gradle JDK 21 ile geçti; SwiftKitCore JDK 25 ile Maven Local'a yayımlandı |
| SDK seviyesi | min 31, compile/target 36 | Derleme için API 36 tutuldu; kullanıcının tek emülatör tercihiyle API 31 cihaz testi ertelendi |
| ABI | arm64-v8a, x86_64 | İkisi derlendi/paketlendi; çalışma testi yalnız arm64-v8a emülatöründe yapıldı |

minSdk 31 seçimi muhafazakârdır: swift-java'nın API 28–30 JNI VM erişimiyle ilgili bilinen sorunu vardır. Sorun kapatılmış olsa bile alt API'ler ayrı cihaz testi geçmeden destek sözü verilmez. Bu seçim ürünün nihai Android destek politikası değildir.

## Kurulum ve doğrulama sırası

1. Resmî Swift kılavuzundaki eşleşen open-source Swift 6.4.0, Android SDK bundle ve NDK r30'u kur. `ANDROID_NDK_HOME` ve `SWIFT_ANDROID_SDK_BUNDLE` ortam değişkenlerini **tam dizinlere** ayarla. SDK bundle komutu/kontrol toplamı için aşağıdaki resmî Swift bağlantısını kullan; bunları yerel script ile indirmiyoruz.
2. Swift SDK'nın NDK sysroot bağlantısını kur: `ANDROID_NDK_HOME=... SWIFT_ANDROID_NDK_LINK=1 bash "$SWIFT_ANDROID_SDK_BUNDLE/swift-android/scripts/setup-android-sdk.sh"`. Ardından repo kökünden `sh android/scripts/check-android-toolchain.sh` ile pin ön kontrolünü çalıştır. Bu yalnız yol/sürüm kontrolüdür, compile başarısı değildir.
3. `android/swift-bridge` içinde `swift package resolve` yap; `Package.resolved` artık kaynakta yer alır ve sürüm/revizyon değişirse diff incelenir. `swift-java` 0.6.0 checkout'unda JDK 25 ile `:SwiftKitCore:publishToMavenLocal -PswiftkitVersion=0.6.0` çalıştır. Maven Local'da `org.swift.swiftkit:swiftkit-core:0.6.0` artefaktını doğrula.
4. `android/` içinde `./gradlew --version` ile Gradle 8.13 dağıtımını ilk kez indirip doğrula. Wrapper JAR resmî Gradle `v8.13.0` deposundan alındı (SHA-256: `81a82aaea5abcc8ff68b3dfcb58b3c3c429378efd98e7433460610fecd7ae45f`). Başlatıcılar minimal tutuldu; Gradle'ın standart wrapper scriptleriyle değiştirmek istenirse aynı JAR ve dağıtım pini korunmalı.
5. `./gradlew :swift-bridge:assembleDebug :swift-bridge:assembleRelease :app:assembleDebug :app:assembleRelease :app:bundleRelease :app:testDebugUnitTest` çalıştır. Gradle debug/release Swift derlemelerini ayrı üretir. Repo kökünden `sh android/scripts/check-android-bindings.sh` ve `sh android/scripts/check-android-package.sh <apk|aab|aar>` ile üretilen API ve iki ABI'deki native kütüphaneleri denetle; APK'larda build-tools 36 `zipalign -c -P 16 4` ile 16 KB hizalamayı kontrol et. Release R8 açıktır; köprü modülü JNI wrapper için consumer keep kuralını taşır.
6. Güncel API emülatöründe `./gradlew :app:connectedDebugAndroidTest` çalıştır. Minimum API ve fiziksel arm64-v8a cihaz testleri destek matrisi genişletilmeden önce ayrıca yapılmalı. `BridgeRoundtripTest` Core test vektörünü JNI üzerinden çalıştırır ve 1.000 çağrılık tanısal p50/p95/native-heap verisini `HouseFlowBridgePerf` etiketiyle loglar. Bu mikro ölçüm tek başına ürün performans bütçesi değildir.
7. Debug APK'yı `adb install -r android/app/build/outputs/apk/debug/app-debug.apk` ile kur; `adb shell am force-stop com.houseflow` ardından `adb shell am start -W -n com.houseflow/.MainActivity` ile cold-start süresini al. `adb logcat -d -s HouseFlowBridgePerf:I AndroidRuntime:E` ve `adb shell dumpsys meminfo com.houseflow` çıktılarını kaydet. Release APK imzasız üretildiğinden doğrudan kurulamaz; yalnız test için imzalayıp aynı smoke'u tekrarla, debug anahtarını üretim imzası olarak kullanma. Native roundtrip başarısızsa boş kabuk başlangıcında hata görülür. Debug/release cold start, native load, APK/AAB boyutu ve bellek karşılaştırmasını aynı cihazda kaydet. CI build'i ve cihaz çıkış kriteri **henüz karşılanmış sayılmaz**.

## Bu oturumda yapılan kontroller

- Dosya yapısı ve pinler yazıldı. `sh -n` kontrolleri ve SwiftPM manifest parse başarılı; `swift test --package-path shared` 40/40 geçti. `swift test --disable-sandbox --package-path android/swift-bridge` macOS host'ta tekrar geçti (1/1) ve Java JNI wrapper'ı üretti. `swift build --configuration release --package-path android/swift-bridge` de macOS host'ta geçti (ilk optimize derleme yaklaşık 6 dakika). `check-android-bindings.sh` üretilen iki public metodu doğruladı. İlk host testinde macOS platform alt sınırı uyuşmazlığı görüldü ve yalnız köprü paketinde 13.0'a yükseltilerek düzeltildi. `--disable-sandbox` burada Codex dosya sandbox'ı altında SwiftPM'in iç sandbox kurma hatasını aşmak içindi; CI komutu standart `swift test` olarak kalır.
- Swift 6.4 ve Android SDK/NDK kuruldu; SDK'nın NDK sysroot bağlantısı yapıldı ve `check-android-toolchain.sh` geçti. Swift 6.4 Android ürün çıktısı `.build/out/Products/{Debug,Release}-android-{aarch64,x86_64}` düzeninde olduğundan Gradle görevleri bu konuma eşleştirildi.
- `:app:assembleDebug`, `:app:assembleRelease`, `:app:bundleRelease` ve `:app:testDebugUnitTest` geçti. R8, SwiftKitCore'un Android'de bulunmayan `jdk.jfr.Description` ve `jdk.jfr.Label` metaverisini raporladı; köprü consumer kurallarına yalnız bu iki tip için `dontwarn` eklendi. JNI sınıfı için `keep` kuralı korunuyor.
- İlk cihaz testinde `libSwiftJava.so` yüklenemedi: ELF bağımlılığı `libswiftObservation.so` APK'da eksikti. Her iki ABI için Swift runtime paket listesine eklendi ve içerik kontrolü bunu zorunlu sayıyor. Sonraki API 36.1 / arm64-v8a / 16 KB sayfa emülatör testinde 3/3 test geçti. Test vektörü, Unicode ve geçersiz girdi sınırlarını kapsıyor.
- Debug/release AAR, debug APK, imzasız release APK ve AAB'de iki ABI için 40'ar `.so` girdisi doğrulandı. Her iki APK `zipalign -c -P 16 4` kontrolünden geçti. Son boyutlar yaklaşık 63 MB debug/release AAR, 218 MB debug APK, 203 MB release APK ve 63 MB AAB. İki ABI ve Swift runtime'ı birlikte paketlemek belirgin dağıtım maliyeti doğuruyor; boyut bütçesi henüz belirlenmedi.
- Debug APK normal açılışta `842 ms` cold start, `61.934 KB` toplam PSS gösterdi. 1.000 JNI çağrısının tanısal p50/p95 değeri `2.208/2.292 µs`, native heap değişimi `160 bayt` olarak loglandı. Yerel test anahtarıyla geçici imzalanan release APK da R8 sonrası açıldı (`606 ms`, `34.837 KB` PSS). Bu tekil emülatör ölçümleri doğrudan performans karşılaştırması veya ürün bütçesi değildir; geçici release APK temizlendi ve emülatöre debug APK geri yüklendi.
- Kullanıcının tek emülatör tercihiyle API 31 sistem imajı, AVD'si ve SDK platformu kaldırıldı; Android Studio da kaldırıldı. API 36.1 emülatörü ve CLI derleme araçları korunuyor. Repo kökündeki `.github/workflows/houseflow-android-bridge.yml` SDK/NDK bağlantı adımıyla güncellendi; workflow GitHub'da henüz çalışmadı.

## Kapatma kararı ve sürüm öncesi kontroller

- Wrapper, `Package.resolved`, host JNI codegen, iki ABI cross-compile ve yerel debug/release paketlemesi doğrulandı. Kullanıcının çalıştırdığı API 36.1 / arm64-v8a emülatör instrumentation testleri 14/14 geçti; uygulama kabuğu COLD launch durumuyla açıldı.
- Kullanıcı talebiyle Faz 5, bu yerel teknik kapsamda kapatıldı. Temiz GitHub CI, API 31 minimum sürüm, x86_64 runtime ve fiziksel arm64 cihaz çalışması doğrulanmadı; bunlar sürüm öncesi kontrol maddeleridir, test edilmiş gibi raporlanmamalıdır.
- Cold start için native çağrı açık/kapalı kontrollü ölçüm, ilk native load süresi, gerçek cihaz RSS ve ABI başına indirme boyutu henüz yok. Tanısal emülatör metrikleri F0 bütçeleriyle kıyaslanmadan ve dağıtım boyutu değerlendirilmeden 'performanslı' denmeyecek.
- Ürün sahibi minSdk/ABI matrisini onaylamadan kapsam genişletilmeyecek. JNI girişleri gerçek auth/IO use case'lerine bu kapı geçmeden bağlanmayacak.
- Sürüm öncesi GitHub'da ilgili dalın `Actions → HouseFlow Android bridge → Run workflow` koşumu ve API 31 x86_64 adımı yeşil olmalı. Workflow henüz gönderilmediği için CI koşumu yoktur. Yerel tek API 36.1 imajı korunur; ikinci yerel imaj gerekmez.
- Faz 6 bağımlılıklarından sonra release AAB yaklaşık 63 MB, imzasız release APK yaklaşık 203 MB'dir; iki ABI için paket kontrolünde 42'şer native `.so` girdisi ve 16 KB APK hizası geçti. Bunlar teslim edilen ABI split boyutunu ve ürün bütçesini kanıtlamaz.

## Kaynaklar

- [Swift SDK for Android başlangıç kılavuzu](https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html)
- [swiftlang Android `hello-swift-java` örneği](https://github.com/swiftlang/swift-android-examples/tree/main/hello-swift-java)
- [swift-java JNI açıklaması](https://github.com/swiftlang/swift-java)
- [swift-java API 28–30 JNI sorunu](https://github.com/swiftlang/swift-java/issues/419)
- [Android Gradle Plugin 8.13 uyumluluğu](https://developer.android.com/build/releases/agp-8-13-0-release-notes)

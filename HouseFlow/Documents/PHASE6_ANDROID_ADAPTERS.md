# Faz 6 — Android platform adapter'ları

Durum (11 Ekim 2026): **Faz 6 kullanıcı kararıyla mevcut adapter kapsamıyla kapatıldı.** Android 8/8 JVM, 14/14 API 36.1 arm64 instrumentation testi, iOS contract testleri ve Android kabuk açılışı doğrulandı. Android ürün ekranı, Core port API'leri ve sunucu sözleşmesi değiştirilmedi. Adapter'lar henüz Core auth/JNI kullanım senaryosuna bağlanmıyor; bu ilk tam dikey özelliğin (Faz 7) işi. API 31/x86_64, gerçek process-death ve performans/boyut kabulü sürüm öncesi takip işidir.

## Uygulanan sınırlar

| Adapter | Sorumluluk / sınır | Otomatik kanıt |
| --- | --- | --- |
| `KeystoreSessionStore` | Core'daki beş güvenli alanın karşılığı; Android Keystore AES-256-GCM, alan adına bağlı doğrulama, kayıp/bozuk anahtarda yeniden giriş, logout silme. Senkron disk işi ana thread'de reddedilir. | API 36.1 arm64 emülatöründe 6 cihaz testi |
| `AndroidPreferencesStore` | Yalnız `hasSeenOnboarding` ve `chosenHouse` DataStore anahtarları; token veya başka hassas değer içermez. | 1 cihaz testi; tekrar yazma ve silme |
| `AndroidHttpAdapter` | Ham HTTP isteği/yanıtı, URL/query/header/body/status, 30 saniye toplam timeout, coroutine iptalinde `Call.cancel()`, üretimde HTTPS. API hata yorumunu üst katmana bırakır. | 4 JVM testi; loopback istek, iptal, timeout, cleartext reddi |
| `AndroidLocalizationRepository` / `AndroidLocalizationCache` | Mevcut endpoint ve JSON alanları, dil anahtarı doğrulaması, atomic dosya yazımı, cache-first/explicit refresh, offline son cache ve eksik anahtar fallback. | 4 cihaz testi |
| `AndroidLifecycleBridge` / `AppLogger` | `MainActivity` yalnız active/background bildirir. Log API'si serbest metin yerine sabit olay kodları alır; token/PII/payload parametresi yoktur. | 1 JVM lifecycle testi; log API statik inceleme |

Şifreli oturum dosyası `data_extraction_rules.xml` ile cloud backup ve cihaz taşımasından dışlanır; Keystore anahtarı başka cihaza taşınmaz. Kayıt varken anahtar kaybolması veya ciphertext doğrulama hatası kalan alanları silip `ReauthenticationRequired` döndürür; eksik kayıt `Missing` döndürür. Geçici Keystore/IO hatası sessizce oturum yok sonucuna çevrilmez. Anahtar biyometrik doğrulama istemez; donanım destekli anahtar her cihazda garanti edilmez. Çağıran kod disk/Keystore işini `Dispatchers.IO` üzerinde yapmalıdır. Logların sabit kodlu olması, ileride yeni parametre eklenirse ayrıca gizlilik incelemesi gereksinimini ortadan kaldırmaz.

## Doğrulama

- Yerel Android `:app:testDebugUnitTest`: **8/8 geçti**. HTTP fixture `shared/Fixtures/platform_http_contract.txt` içinden yüklenir; aynı vektör iOS `PlatformPortContractTests` tarafından okunur.
- API 36.1 arm64-v8a emülatöründe `:app:connectedDebugAndroidTest`: **14/14 geçti** (3 JNI, 6 Keystore, 1 DataStore, 4 localization). Depolamayı yeni adapter örneğiyle yeniden açma kapsanır; gerçek OS process-death kapsanmaz.
- Debug/release APK ve release AAB derlendi; her iki ABI için native içerik ve APK'larda 16 KB zip hizası kontrol edildi. Bu sonuç API 31/x86_64 cihaz çalışma kanıtı değildir.
- iOS Xcode hedefi artık yalnız iOS kaynak dizinlerini ve asset'leri izler; Android Gradle çıktılarının uygulamaya kaynak olarak kopyalanması engellendi. `xcodebuild build` iOS Simulator hedefiyle geçti. Ortak iOS HTTP fixture testi için simülatör koşumu ayrıca tamamlanmalıdır.

## Faz kapandıktan sonra izlenecek işler

1. Sürüm öncesi GitHub'da `.github/workflows/houseflow-android-bridge.yml` için temiz `workflow_dispatch` koşumu yeşil olmalı. Bu koşum API 31 x86_64 cihaz testini de içerir. Yerelde ikinci sistem imajı indirmek gerekmez.
2. Ürün destek matrisi yazılı karara bağlanmalı; API 31 x86_64 ve gerekiyorsa fiziksel arm64 cihazda bridge + adapter smoke, logout/reopen ve offline/cache kontrolü yapılmalı.
3. Gerçek process-death ardından oturum ciphertext'inin korunması, logout ardından geri gelmemesi ve anahtar kaybında yeniden giriş davranışı Faz 7 auth akışıyla test edilmeli. Mevcut boş kabukta auth UI olmadığı için bu elle kontrol edilemiyor.
4. Gerçek backend sertifika zinciri cihazda doğrulanmalı; mevcut otomatik testlerde cleartext reddi, timeout ve iptal kontrol edildi.
5. Faz 0 performans bütçesi cold start, native yükleme, AAB/ABI teslim boyutu, bellek ve HTTP/cache gecikmesi ölçülerek belirlenmeli. Tek emülatör ölçümü ürün bütçesinin yerine geçmez.

Bu maddeler Faz 6 kod kapsamını yeniden açmaz; release readiness ve Faz 7 auth entegrasyonu sırasında ele alınır. Core'a JNI üzerinden auth/IO bağlanırken async/cancellation sahipliği ayrıca kanıtlanmalıdır.

Kaynaklar: [Android Keystore AES-GCM](https://developer.android.com/reference/android/security/keystore/KeyGenParameterSpec), [AndroidX Security sürüm notları](https://developer.android.com/jetpack/androidx/releases/security), [Android Auto Backup](https://developer.android.com/identity/data/autobackup), [DataStore sürüm notları](https://developer.android.com/jetpack/androidx/releases/datastore).

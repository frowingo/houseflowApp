# Faz 3 — Port ve iOS adaptör kararları

Tarih: 2026-10-10. Kapsam: mevcut iOS davranışını koruyarak Android'e taşınabilecek iş mantığı için minimum platform sınırı. Bu belge yeni bir ürün akışı veya Android implementasyonu tanımlamaz.

## Sahiplik ve bağımlılık yönü

| Core sözleşmesi | Bugünkü iOS sahibi | Bugün kullanan akış |
|---|---|---|
| `HTTPRequest`, `HTTPResponse`, `HTTPClient`, `HTTPStatusFailure` | `URLSessionHTTPClient`; JSON encode/decode ve mevcut `NetworkError` eşlemesi `NetworkService` | Auth, user, house, chore, localization HTTP istekleri |
| `SecureSessionStore` | `KeychainService` (`Security`), mevcut Keychain service/account anahtarları | Login, restore, doğrulama, authenticated istekler |
| `PreferencesStore` | `UserDefaults` uyarlaması, mevcut app domain ve key'ler | `hasSeenOnboarding`, `chosenHouse` |
| `LocalizationCacheStore` | `LocalizationDiskCache`, mevcut Application Support `Localization/plaintext_<dil>.json` biçimi | Dil cache restore, yenileme ve offline fallback |

Portlar `HouseFlowCore` içinde yalnız veri ve işlem sözleşmesidir. `URLSession`, `URLRequest`, `Security`, `UserDefaults`, `Combine`, `UIKit` ve `SwiftUI` Core'a girmedi. `AppDependencies.live` iOS üretim graph'ını kuruyor. Game realtime transport'un ham `URLRequest` yolu mevcut iOS adaptörde bırakıldı; WebSocket protokolünü HTTP portuna zorlamıyoruz.

`Clock` ve `Logger` portları eklenmedi: Faz 3'te Core içinde onları tüketen bir use case yok. Gerekirse ilgili use case ile birlikte küçük sözleşme olarak eklenmeli. UI ve oyunlara özgü `UserDefaults` kullanımları da bu fazda taşınmadı.

## Davranış ve güvenlik sözleşmesi

- HTTP path ve query, önceki `baseURL.appendingPathComponent` + `URLComponents` biçimiyle; `Authorization`/`Content-Type` ve 30 saniyelik request timeout korunur. 200–399 başarı decode edilir. Hata gövdesinde `message`, ardından `error`, sonra varsayılan metin; JSON değilse trim edilmiş ham metin, boşsa status kodu kullanılır. Başarılı body decode hatası önceki `NetworkError.decodingError` olarak kalır.
- `SecureSessionStore` string değerlerinde `nil` yazımı silmedir. Token, HTTP request veya Authorization header Core hata değerinde ya da logda saklanmaz. Token `UserDefaults` veya localization cache'e yazılmaz. Mevcut Keychain service/account anahtarları değişmedi; hesap/tokene migration gerekmez.
- `PreferencesStore` mevcut `hasSeenOnboarding` ve `chosenHouse` anahtarlarını aynı UserDefaults domain'inden okur/yazar. Bu fazda veri kopyalama yok; eski tercihlerin okunması doğrudan test edilir.
- Localization cache aynı dosya adı ve JSON alanları (`language`, `updatedAt`, `values`) ile okunur/yazılır. Sunucu başarısızsa mevcut cache veya iOS'taki oyun metni/anahtar fallback'i korunur. Disk yazımı best-effort ve atomiktir.

## Concurrency ve maliyet

Mevcut `NetworkService`, Keychain ve ViewModel çağrıları zaten main actor üzerinde; portlar bu fazda aynı actor sınırını izler. `URLSession.data(for:)` asenkron I/O yapar; main thread'de beklemeye geçilmez. Bu karar yeni bir Core use case'i ağır decode veya CPU işi eklerse yeniden gözden geçirilir; şimdilik aktörler arası ek geçiş ve DI framework maliyeti getirmemek daha uygundur. Ayrı Android/JNI bağlama ve performans bütçesi sonraki fazın kararıdır.

## Kanıt ve açık kapı

- Core package testleri HTTP hata zarfı, raw text/boş body ve platform import sınırını doğrular.
- iOS adapter testleri URL/method/query/header/body/status, eski preference key'leri, eski localization cache JSON'u ve fallback'i doğrular. Mevcut NetworkService/AuthService/AppRouter regresyon testleri login ve API hata akışını korur.
- İmzasız simülatör test host'u gerçek Keychain'e erişemediğinde Keychain round-trip testi açıkça atlanır. Bu yüzden gerçek `Security` persist/reopen/delete döngüsü imzalı iOS cihazında doğrulanmadan güvenlik kapısı tam geçilmiş sayılmaz.
- Bu fazda önce/sonra runtime latency ve allocation baseline'ı alınmadı; yalnız derleme ve davranış eşitliği doğrulandı. Android spike öncesinde HTTP p95, cache hit/miss ve cold-start ölçümleri gerekir.

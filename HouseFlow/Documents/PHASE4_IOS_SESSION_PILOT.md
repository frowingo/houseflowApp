# Faz 4 — iOS oturum geri yükleme pilotu

Tarih: 2026-10-10. Pilot: uygulama açılışı veya yeterince uzun arka plan dönüşünde mevcut token ile `GET auth/isAuth` çağrısı. Kayıt olma, giriş, e-posta doğrulama, ev seçimi ve SwiftUI ekranları mevcut iOS akışlarında kalır.

## Karar ve akış

`AppSessionCoordinator.performAutoLogin()` aynı önceliği uygular: token yoksa giriş/onboarding, doğrulama bekleyen e-posta varsa doğrulama ekranı, zaten doğrulanmış oturum varsa işlem yok. Doğrulama gerektiğinde aynı yükleme rotaları gösterilir. Profil isteğini artık `AuthSessionStore.restoreAuthenticatedUser` üzerinden `RestoreSessionUseCase` yapar.

```text
AppSessionCoordinator → AuthSessionStore → SessionRestoreAdapter
    → HouseFlowCore.RestoreSessionUseCase → HouseFlowCore.HTTPClient
    → iOS NetworkService / URLSessionHTTPClient → auth/isAuth
```

Core use case `SecureSessionStore` içinden token okur, tek GET isteği gönderir, mevcut 200–399 başarı aralığını ve `IsAuthResponse` DTO'sunu kullanır. Başarılı ve verili profili değer tipi olarak döndürür. Missing token, bozuk/geçersiz profil, HTTP durum hatası, decode ve ağ hatası birbirinden ayrılır. Token Core hata tiplerine veya loglara eklenmez. iOS adapter bu sonuçları önceki `NetworkError` biçimine çevirir; rota ve kullanıcıya gösterilen metin kararları iOS koordinatöründe kalır.

Bu pilot için ayrı state machine, DI framework, feature flag veya yeni ekran eklenmedi. `AppDependencies.live` tek üretim binding'ini verir. Geri alma noktası `sessionRestorer: nil` binding'idir: `AuthSessionStore` o durumda mevcut `AuthService.isAuth()` yoluna döner. Aynı fallback iOS testlerinde kullanılmaktadır.

## Davranış eşitliği

| Girdi/sonuç | Önceki iOS davranışı | Pilot davranışı |
|---|---|---|
| Token yok | Onboarding veya giriş | Aynı; ağ isteği yok |
| E-posta doğrulaması bekliyor | Doğrulama rotası | Aynı |
| Geçerli profil, ev yok | Ev seçimi | Aynı |
| Geçerli profil, seçili ev var | Ev yükleme ardından dashboard | Aynı koordinatör yolu |
| `401` ve API `message` | Sunucu metniyle ev hata rotası | Aynı metin ve rota |
| `success: false` veya `data: null` | “Oturumunuz sona ermiş...” hata metni | Aynı metin |
| Çevrimdışı/transport hata | Ev hata rotası; token kalır | Aynı |
| Çıkış sırasında geç gelen yanıt | Akış kimliği eski yanıtı reddeder | Aynı akış kimliği korunur |

## Kanıt ve açık kontroller

- Core kullanım senaryosu: 8 yeni test; kayıtlı token ve tek GET, token yokluğu, 401, offline, geçersiz/malformed payload, tekrar çağrı, istek öncesi iptal ve geç yanıtın reddi. Tüm package: 40/40.
- iOS testleri: Core üzerinden gerçek `NetworkService`/URLSession adapter yolunu kullanan başlangıç rotası, doğrulanmamış profil, 401 hata metni, geçersiz profil ve offline senaryoları; mevcut coordinator/login/router regresyonları. Son coordinator simülatör koşusu: 11/11; önceki birleşik coordinator/login/router koşusu: 21/21.
- Generic iOS Simulator app ve test hedefi `build-for-testing` ile derlendi.
- Gerçek backend ile uygulama açılışı ve arka plan dönüşü henüz bu pilot koduyla manuel denenmedi. Kabul için doğrulanmış hesapla soğuk açılışın dashboard/ev seçimine gitmesi, doğrulanmamış hesabın doğrulama rotasına gitmesi ve 401/çevrimdışı hatanın eski metin/rotayı göstermesi gerekir.
- Önceki build'e ait aynı koşullu latency/cold-start/allocation baseline'ı yok; sayısal performans iyileşmesi iddia edilmez. Yeni yolda yine bir GET ve bir JSON decode vardır, ek disk erişimi veya bekleme süresi eklenmedi. Cihaz üzerinde ölçüm Faz 5 öncesi performans kapısında yapılmalı.

Android sınırı için bu pilot, Swift tarafında yalnız `HTTPRequest`, `HTTPResponse`, `IsAuthUserData`, `SessionRestoreError` ve kullanım senaryosu API'sını gerektirir. Kotlin/Swift köprüsünde bu Swift tiplerini otomatik olarak doğrudan açmak yerine Faz 5'te dar, sürümlü bir giriş/sonuç yüzeyi denenir. `@MainActor` port sınırı da Android toolchain denemesinde tekrar değerlendirilir.

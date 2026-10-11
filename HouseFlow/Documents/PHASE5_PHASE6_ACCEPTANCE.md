# Faz 5–6 kapanış ve sürüm öncesi kontrol kaydı

11 Ekim 2026: kullanıcı kararıyla Faz 5 ve Faz 6 mevcut teknik kapsamlarıyla kapatıldı. Android API 36.1 arm64 emülatöründe 14/14 instrumentation testi geçti; debug uygulaması emülatöre kuruldu ve `MainActivity` COLD launch ile açıldı. Android ekranının boş beyaz görünmesi beklenir; Compose ürün ekranı henüz yok. iOS simülatör testlerinin kullanıcı tarafından tamamlandığı bildirildi. Aşağıdakiler faz kapatma koşulu olmaktan çıkarıldı ve sürüm öncesi kontroller olarak ertelendi.

## Sürüm öncesi takip

1. **Temiz CI ve API 31 x86_64:** değişiklikler GitHub'a aktarıldıktan sonra **Actions → HouseFlow Android bridge → Run workflow** seç. `bridge` job yeşil bitmeli. Workflow API 31 x86_64 emülatöründe `:app:connectedDebugAndroidTest` de çalıştırır; yerelde ikinci imaj gerekmez.
2. **Destek matrisi:** `minSdk=31`, `arm64-v8a` ve `x86_64` ürün desteği olarak yazılı karara bağlanmalı. Gerekiyorsa API 31 veya üzeri fiziksel arm64 cihazda testler ve açılış smoke'u tekrarlanmalı.
3. **Performans:** Faz 0 bütçesi için cold start, native yükleme, bellek, AAB/ABI teslim boyutu ve HTTP/cache gecikmesi cihaz ve build varyantıyla ölçülmeli. Mevcut yaklaşık 63 MB AAB, ABI split teslim boyutunu veya ürün bütçesini tek başına göstermez.
4. **Oturum yaşam döngüsü:** gerçek process-death sonrasında oturumun korunması, logout sonrasında silinmesi ve Keystore anahtar kaybında yeniden giriş davranışı Faz 7 auth akışıyla test edilmeli. Boş Android shell'de auth UI yoktur.
5. **Gerçek backend bağlantısı:** Android cihaz/emülatör üzerinde HTTPS sertifika zinciri ve offline davranışı doğrulanmalı. Otomatik testler HTTP kontratı, timeout, coroutine iptali ve cleartext reddini kapsar.

Bu takip maddeleri Faz 5–6'nın kapatılmasını geri almaz; release readiness ve Faz 7 entegrasyonu için açık riskler olarak kalır.

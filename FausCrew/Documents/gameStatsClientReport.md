# Oyun istatistikleri — istemci uygulama raporu

**Tarih:** 28 Kasım 2026 · **Dal:** `dev` · **Plan:** [gameStatsClientPlan.md](gameStatsClientPlan.md) · **Sözleşme:** [gameStatsBackendContract.md](gameStatsBackendContract.md) · **Durum:** Kod tamam, commit edilmedi.

## Ne yapıldı

| Görev | İçerik |
|---|---|
| G1 Core | `GameRoute.stats(houseId:)` (`GET game/stats?houseId=`), `GameStatsWireContract` (istek, kayıplı çözme, hata türleri), `GameStatsBoard` (bilinen oyunlar ve güncel üyeler süzülür, lider işaretlenir, 2+ oyunda "Genel" toplamı: galibiyet ↓ → maç ↓ → üyelik sırası). `notYourTurn` / `invalidMove` kodları kaldırıldı. |
| G2 Eşleme | `OnlineGameVisual` (iOS + Android): oyun anahtarı → başlık anahtarı ve oyunun kendi görseli (Faus robotu, roket, tank). Oyunlar ekranı başlıkları da buradan okur. |
| G3 iOS | `GameStatsService`, `GameStatsStore` (dönem bazlı eski cevap düşürme, 429'da tek tekrar, 403/404'te bağlam başına tek profil yenileme), `AppDependencies` / `AppViewModel` bağlantısı. |
| G4 Android | `GameStatsBridge` (köprü sürümü 22 → 23), `GameStatsRepository`, `GameStatsViewModel` (üye değişince istek atmadan pano yeniden kurulur), `MainActivity` bağlantısı. |
| G5 Arayüz | İlerleme kartı satırın 1/3'üne indi (halka + başlık + sayı, seviye rozeti sağ üstte). Yeni `GameStatsCard` 2/3: başlıkta oyun adı ya da "Genel", liderin adı taçla; zirve çizgisi (düğüm yüksekliği = galibiyet, kendi düğümün teal halka + "Sen"); 5+ üyede aynı alanda yatay kaydırma ve kenar solması; altta yazısız görselli kareler; en solda "Genel" (anket simgesi), sonra olive Faus robotu, roket, tank. Başlıkta küçük "Oyun istatistikleri:" etiketi ve yanında oyunun adı; lider alt satırın sağında küçük puntoyla. İlerleme kartında turuncu seviye rozeti kaldırıldı, halka ve metin birlikte kartın tam ortasında, alt metin kesilmeden tam gösterilir (gerekirse küçülür). Satır yüksekliği 184. |
| Temizlik | Hiç yapılmamış TicTacToe'nun tüm izleri istemci ve dokümanlardan silindi. |

Yenileme: kart açıldığında ve ev değiştiğinde (Android'de kullanıcı değişince de). Polling yok. Maçtan dashboard'a dönüş kartı yeniden açtığı için yeniler.

## Test sonuçları

| Hedef | Sonuç |
|---|---|
| `shared` `swift test` | 507 test, 0 hata (1 atlanan, önceden de vardı) |
| `swift-bridge` `swift test` | 81 test, 0 hata (yeni `GameStatsBridgeTests` 5 test) |
| Android `:app:testDebugUnitTest` | 323 test; yeni `GameStatsRepositoryTest` 5/5, `GameStatsViewModelTest` 11/11 geçti. Tam takımda `NotificationViewModelTest`'ten 2 test zaman aşımına düştü; tek başına çalıştırınca geçiyor ve bu iş o dosyalara dokunmadı (zamanlamaya bağlı kararsız test). |
| iOS | Uygulama ve test hedefleri derlendi (`TEST BUILD SUCCEEDED`). Makinede simülatör olmadığı için `GameStatsServiceTests` ve `GameStatsStoreTests` **çalıştırılmadı**. |

## Bilinen noktalar

- İstemci, backend `game/stats` yayına girdikten sonra çıkmalı; öncesinde uç 404 döner. Bağlam başına tek profil yenileme döngüyü engeller ama kart hata gösterir.
- Backend `builtin.go` TicTacToe'yu hâlâ kaydediyorsa orada silinmeli; istemci bilinmeyen anahtarı zaten göstermez.
- Kart metinleri sunucu çevirisi yoksa yerleşik tr/en yedeklerini kullanır (`game_stats_*` anahtarları). Sunucu çeviri tablosuna eklenmeleri önerilir.

## Elle kontrol listesi (iOS ve Android)

1. Dashboard: ilerleme kartı solda dar, oyun kartı sağda geniş, ikisi aynı boyda. İlerleme kartında turuncu rozet yok, halka ve metin birlikte dikeyde ve yatayda ortada, alt metin "…" ile kesilmiyor.
2. Hiç maç oynanmamış ev: "Henüz tamamlanmış oyun yok" mesajı, kare yok.
3. Tek oyun oynanmış: tek kare, "Genel" karesi yok; başlık oyunun adı.
4. Birden çok oyun: en solda anket karesi ("Genel", açılışta seçili), sonra oyun kareleri; başlıkta küçük "OYUN İSTATİSTİKLERİ:" ve yanında seçili oyunun adı.
5. Kareye dokununca görsel hareket eder (robot zıplar, roket kalkar, tank döner, çubuklar büyür); düğümler yeni yerlerine kayar.
6. Lider düğümü turuncu halkalı, alt satırın sağında küçük taç + ad; kendi düğümün teal halka + "Sen".
7. Hiç oynamamış üye soluk, sayısı "—"; düğüme dokununca altta "Ad · X galibiyet / Y maç" ya da "oynamadı".
8. 5+ üyeli ev: grafik yatay kayar, kenarlar solar, sekme değişince başa sonra kendi düğümüne kayar.
9. Bir maç bitirip dashboard'a dön: sayılar güncellenir.
10. İnternet yokken ilk açılış: hata mesajı + "Tekrar dene"; veri varken hata olursa eski veri kalır.
11. Ev değiştir: kart yeni evin verisiyle yüklenir.
12. Erişilebilirlik: sıralama tek cümle olarak okunur; kareler seçili durumu bildirir; hareket azaltma açıkken animasyon yok.

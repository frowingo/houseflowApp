# Chore Arşivi — Uygulama Raporu

**Tarih:** 24 Kasım 2026 · **Dal:** `dev` · **Plan:** [choreArchiveClientPlan.md](choreArchiveClientPlan.md) · **Sözleşme:** [choreArchiveBackendContract.md](choreArchiveBackendContract.md)

## Özet

Planın tüm görevleri uygulandı: A1, A2, B1, B2, C1, C2, C3 ve D1. Hiçbir şey commit edilmedi.

Çalışma düzeni şöyleydi:
- Claude yönetti.
- **Yazar 1:** Core ve iOS. Sonnet.
- **Yazar 2:** Android ve köprü. Sonnet.
- **İnceleyici:** ayrı bir Sonnet ajanı.

Claude her diff'i okudu. İnceleyicinin ve Claude'un bulguları aynı yazarlara geri gönderildi ve düzeltildi.

## Doğrulama

| Katman | Sonuç | Başlangıç |
|---|---|---|
| Ortak çekirdek (`swift test`) | 493 test, 0 hata, 1 atlandı (bilinçli fixture testi) | 470 |
| Swift köprüsü (`swift test`) | 76 test, 0 hata | 69 |
| Android (`:app:testDebugUnitTest :app:assembleDebug`) | 307 test, 0 hata; derleme başarılı | 287 |
| iOS (`xcodebuild build-for-testing`, `generic/platform=iOS Simulator`) | TEST BUILD SUCCEEDED | — |

**Açık:** iOS testleri çalıştırılmadı, çünkü makinede simülatör yok. Yeni iOS testleri yalnızca derlendi: `ChoreArchiveStoreTests`, `ChoreArchiveServiceTests` ve `URLSessionHTTPClientTests`. Android `androidTest` (UI testleri) de çalıştırılmadı.

## Ne değişti

| Katman | Değişiklik |
|---|---|
| Core | Yeni `ChoreArchiveWireContract` dosyası: ilk sayfa isteği (tarihler UTC `Z` ile), `nextUrl` doğrulaması (önek, göreli path, RFC 3986 query, geçerli `%XX`; `'` reddedilir), sayfa yanıtı ve `ChoreArchiveFailure`.<br>`HTTPRequest.percentEncodedQuery` eklendi.<br>`ChoreFailureReason.reviewRejected` eklendi. Neden artık `completedAt` ile belirleniyor; statusHistories kuralı yalnızca eski önbellek için yedek.<br>`Chore` modeline `completedAt` ve `completedBy` eklendi. |
| iOS | `URLSessionHTTPClient` hazır kodlanmış query'yi olduğu gibi kullanıyor.<br>Yeni `ChoreArchiveService` (`NotificationService` kalıbında).<br>Yeni `ChoreArchiveStore` (`NotificationStore` kalıbında: epoch ile eski yanıt atma, tekrar eleme, 403'te ev erişimi akışı).<br>`DashboardStore.chore(from:)` mapping'i dışarı açıldı ve arşivle paylaşılıyor.<br>Yeni `ChoreArchivePopup`; detay popup'ın içinde açılıyor.<br>Chore kartına "Tüm geçmiş" satırı eklendi; `ModernChoreRow`'a isteğe bağlı detay satırı eklendi. |
| Köprü | Yeni `ChoreArchiveBridge` (`choreArchiveRequest`, `choreArchiveResponse`). JWT köprüden geçmiyor.<br>`choreObject` artık `completedAt` ve `completedBy` da taşıyor.<br>Köprü sürümü 21'den 22'ye çıktı. |
| Android | `PlatformHttpRequest.encodedQuery` eklendi.<br>Yeni `ChoreArchiveRepository` (`NotificationRepository` kalıbında) ve `ChoreArchiveViewModel` (`NotificationViewModel` kalıbında: generation sayacı, Job iptali, effects).<br>`HouseChore` modeline `completedAt` ve `completedBy`, `ChoreFailureReason` enum'una `REVIEW_REJECTED` eklendi.<br>Yeni `ChoreArchivePopup` (pull-to-refresh ile) ve `DashboardPopup.Archive`. |

## Plandan sapmalar ve kararlar

- **Yer tutucular:** iki platform da `%@`/`%s` değil, uygulamanın mevcut `{date}` ve `{name}` kuralını kullanıyor. Plandaki D1 tablosu buna göre düzeltildi. Backend bu anahtarları katalogda yayınlarsa değerler `Kapandı: {date}` ve `Tamamlayan: {name}` biçiminde olmalı.
- **Yeniden yüklemede liste korunur:** pull-to-refresh ya da aynı ayın yeniden yüklenmesi, iki platformda da listeyi ekranda tutuyor. Başarısız olursa liste kalıyor ve hata gösterilmiyor; bu, bildirim listesiyle aynı davranış.
- **Android geri tuşu:** ayrı bir `BackHandler` yok. Arşiv ve detay iç içe Dialog olduğu için geri tuşu önce en üstteki Dialog'u kapatıyor.
- **İkon farkı:** popup ikonu iOS'ta `archivebox.fill`. Android ikon setinde karşılığı olmadığı için `clockFill` kullanıldı.
- **Değişmeyenler:** `dueDate` kodu, push yönlendirmesi ve dashboard'daki 48 saatlik liste bu fazda değişmedi (plan Bölüm 2 ve 8).

## İnceleme bulguları ve sonuçları

| Bulgu | Sonuç |
|---|---|
| Core `'` karakterini kabul ediyordu; Android'de OkHttp onu `%27` yapıyor. | `'` reddediliyor; test eklendi. |
| iOS store `Calendar.current`'ı açılışta sabitliyordu. | Artık `.autoupdatingCurrent` kullanılıyor. |
| iOS ilk sayfada tekrar eden id elenmiyordu. | Eleniyor; test eklendi. |
| Android yeniden yüklemede listeyi silip hata gösteriyordu. | iOS ile eşitlendi; testler eklendi. |
| Satır detayı iki platformda farklıydı. Android'de iki ayrı "tekrar dene" vardı. İleri okun kaynağı iki yerdeydi. | Hepsi düzeltildi. |
| İki istek aynı anda 403 alırsa profil yenileme iki kez tetiklenebilir. | Kabul edildi: en kötü durumda gereksiz bir yenileme. |

## Kullanıcının ekranda kontrol etmesi gerekenler (iOS ve Android)

1. Ana ekranda Geçmiş bölümünde yalnızca son 48 saatte kapanan chore'lar var ve kartın altında "Tüm geçmiş" satırı görünüyor; liste boşken de.
2. Arşiv bu ayla açılıyor ve dün kapanan chore da listede.
3. 10'dan fazla kapanmış chore olan bir ayda "Daha fazla göster" listeyi sona ekliyor, tekrar yok; son sayfada buton kayboluyor.
4. Yüklenirken ay değiştirince eski ayın chore'ları yeni listeye karışmıyor. İleri ok bu ayda kapalı.
5. Süresi dolan chore "Son teslim tarihi geçtiği için başarısız oldu.", üçüncü turda reddedilen chore "İncelemede üç kez reddedildi." gösteriyor. Hiçbir yerde "system" yazmıyor. Completed satırında "Tamamlayan: …" var; evden ayrılan üye için "Eski üye" yazıyor.
6. Arşivdeki bir chore'a dokununca detay salt okunur açılıyor ve kapatınca arşive dönülüyor. Review fotoğrafı görüntüleniyor.
7. Boş bir ayda boş durum, uçak modunda hata ve yeniden deneme görünüyor. Pull-to-refresh listeyi silmeden yeniliyor.
8. Arşiv açıkken gelen bir push'a dokununca arşiv kapanıyor ve push akışı çalışıyor.
9. Android'de geri tuşu önce detayı, sonra arşivi kapatıyor.

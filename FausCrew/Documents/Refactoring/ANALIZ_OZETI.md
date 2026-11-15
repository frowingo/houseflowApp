# FausCrew Kod Tabanı Analizi: Özet

## Ne istendi, ne yapıldı, sonuç ne

FausCrew kod tabanı (iOS SwiftUI, Android Compose ve ortak Swift çekirdeği; yaklaşık 112 bin satır) performans, okunabilirlik, mimari ve güvenlik açısından incelendi. Kodda hiçbir değişiklik yapılmadı; build ya da test çalıştırılmadı. Dört salt-okunur ajan 62 ham bulgu üretti, tekrarlar birleştirilince 47 görevlik bir plan çıktı. Sonuç: kod tabanı genel olarak sağlam ve büyük bir yeniden yazım gerekmiyor. Yayından önce öne çıkan iş: süresi dolmuş token'ın kullanıcıyı hata ekranında bırakması (`F1-2`). Not: ilk sürümdeki "release build demo sunucusuna gidiyor" bulgusu yanlıştı; mevcut backend production'dır ve `F1-1` yalnızca koddaki yanıltıcı adlandırmayı temizler.

## Kim ne yaptı

| Alan | Model | Bulgu |
|---|---|---|
| iOS uygulama katmanı | Opus 5.5 (High) | 21 |
| Güvenlik ve ağ/oturum | Opus 5.5 (High) | 15 |
| Android ve swift-bridge | Sol 6.1 (High) | 14 |
| Ortak çekirdek ve CI | Sol 6.1 (High) | 12 |

Yönetici oturum (Fable 5.2) bulgulardan 20 tanesinin kanıt satırını kodda tek tek kontrol etti; hepsi doğru çıktı.

## Önce bunlara bakın

- `F1-1`: Koddaki `development`/`production` ayrımı yanıltıcı; tek backend var ve production. Yalnızca adlandırma temizliği.
- `F1-2`: Süresi dolmuş token'da uygulama kullanıcıyı her açılışta hata ekranına düşürüyor; çıkışı elle yapmak zorunda kalıyor.
- `F1-3`: Android'de hesap değişiminde eski isteklerin yanıtları yeni hesabın verisinin üzerine yazabiliyor.
- `F0-4`: iOS çıkışta ad ve soyadı silmiyor; Android ise her şeyi siliyor.
- `F2-1`: iOS'ta küçük bir toast bile tüm ekran ağacını yeniden çizdiriyor. En büyük performans kazancı bu; cihazda ölçülmedi.

## Sizden beklenen kararlar

1. Production API alan adı (`F1-1`): kapandı; mevcut backend production.
2. `HouseSessionStore.houseError` ekranda mı gösterilsin, silinsin mi (`F0-9`)? Öneri: gösterilsin.
3. iOS store'ları `@Observable`'a geçsin mi? Öneri: şimdilik hayır.
4. SkylineDash oyun döngüsü yeniden yazılsın mı? Öneri: demo ise bırakılsın.
5. Sekme çubuğu sorunu (`F1-7`) cihazda görülüyor mu? Öneri: online maç sırasında başka sekmeye dokunup deneyin.

## Neye güvenebilirsiniz, neye güvenemezsiniz

Planda "kodda doğrulandı" ile işaretli 20 bulgu elle kontrol edildi ve hepsi doğru çıktı. Kalan görevler ajan raporlarına dayanıyor; uygulayan kişi önce kanıt satırını kendisi okumalı. Hiçbir build, test ya da cihaz ölçümü yapılmadı; performans kazançları koda bakılarak tahmin edildi, backend davranışı ve Android oyun çizicileri tam incelenmedi.

## Dosyalar

- Ayrıntılı plan (asıl kaynak): [GELISTIRME_PLANI.md](GELISTIRME_PLANI.md)
- Faz raporları: [FAZ_RAPORLARI.md](FAZ_RAPORLARI.md)

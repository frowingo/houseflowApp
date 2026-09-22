# Taş–Kağıt–Makas demo akışı

- `RockPaperScissorsModels`: kimlikli oyuncu, maç, tur; Codable komut ve tam durum görüntüsü.
- `RPSGameServicing`: asenkron komut gönderimi ve `AsyncStream` üzerinden durum akışı.
- `DemoRPSGameService`: eşleştirme, kura, bot hamleleri, geri sayım ve sonuçların tek otoritesi.
- `RockPaperScissorsViewModel`: lobi girdileri, servis enjeksiyonu ve ekran durumu. Aynı oturumdaki eski/tekrarlanan revizyonları eler.
- SwiftUI ekranları: durumun sunumu, animasyonlar ve kullanıcı niyetleri. Kazanan hesaplamaz.

## Kurallar

2–8 oyuncu; ilk oyuncu kullanıcı, diğerleri demo botlarıdır. Her turun başında kalan oyuncular Fisher–Yates ile karıştırılır. Sayı tekse karıştırılmış listenin son oyuncusu maç yapmadan üst tura çıkar; o turdaki herkes eşit olasılıkla seçilebilir. Önceki turda kura alan oyuncu sonraki turda da seçilebilir.

Maç tek galibiyetle biter. Beraberlikte aynı maç kimliği korunur, el numarası artar ve hamleler temizlenir. Tüm maçlar bitince kazananlar ve kura alan oyuncu bir sonraki turu oluşturur. Tek oyuncu kaldığında turnuva tamamlanır. Elenen kullanıcı kalan maçları izleyebilir.

## WebSocket geçiş noktası

Gerçek bağlantı henüz eklenmedi. Gelecek adaptör `RPSGameServicing` protokolünü uygulayarak ekranın `service` parametresinden verilebilir; üretim servisi hazır olduğunda uygulamanın bağımlılık grafiğine taşınmalıdır. Codable modeller uygulama sözleşmesidir; sunucu mesaj formatı henüz belirlenmiş değildir.

Sunucu oyuncu kimliğini oturumdan doğrulamalı; istemcinin gönderdiği oyuncu listesini veya kimliği yetki olarak kabul etmemelidir. Kura, eşleşmeler, süreler ve sonuçlar sunucuda belirlenmelidir. Her oyuncu yalnızca kendi hamlesini göndermeli, iki hamle de kesinleşmeden rakibin hamlesi yayınlanmamalıdır. Demodaki boş hamle ile bot maçını ilerletme ve manuel tur ilerletme yalnızca simülasyon kontrolleridir.

Komutlar oturum kimliği, beklenen revizyon, maç kimliği ve el numarası taşır. Adaptör komut onaylarını/hatalarını eşlemeli, eski oturumlardan gelen mesajları düşürmeli ve yeniden bağlantıda güncel tam durumu almalıdır. Sunucu tarafında ayrıca benzersiz komut kimliğiyle tekrar önleme, oda yetkileri, hazır olma, seçim süresi, bağlantı kopması ve hükmen sonuç politikaları tanımlanmalıdır. Bu ağ davranışları demo kapsamında uygulanmış değildir.

Ekrandan çıkışta demo görevi iptal edilir ve akış kapatılır. Yeni turnuva yeni oturum kimliği alır; eski geri sayım sonucu yeni turnuvaya yazılamaz.

## Doğrulama

`HouseFlowTests/RockPaperScissorsTests.swift` dokuz hamle kombinasyonunu, 2–8 oyuncuyla 140 turnuvayı, kura uygunluğunu, giriş sınırlarını, eski/geçersiz komutları ve yeniden başlatma iptalini kapsar. Temel servis Foundation, ViewModel Combine kullanır; kurallar SwiftUI veya simülatör gerektirmeden test edilebilir.

---

# House-Switch ilk oynanabilir sürüm

- `HouseSwitchView`: hazırlık, oyun HUD'ı, duraklatma ve sonuç akışını sunar.
- `HouseSwitchViewModel`: oyun fazını, ilerlemeyi, süreyi, yerçekimi değişim sayısını ve yerel en iyi süreyi yönetir.
- `HouseSwitchScene`: SpriteKit fizik döngüsü, kamera, platform, lazer ve bitiş temaslarının tek otoritesidir.
- `HouseSwitchLevel`: ekrandan bağımsız parkur verisini taşır; dikey ölçüler farklı cihaz boylarına oranlanır.

## Ekran yönü ve kontrol kuralı

Lobi, koşudan önce yatay ekran zorunluluğunu açıklar. Başlat eylemi sahneyi yataya kilitler; yatay ölçü oluşmadan oyun döngüsü başlamaz. Yerçekimi yalnızca evin tabanı mevcut çekim yönündeki katı bir yüzeye basarken değiştirilebilir. Havadaki dokunuşlar fizik durumunu değiştirmez.

## Çarpışma ve akış kuralı

Katı platformlar oyuncuyla fiziksel olarak çarpışır ancak doğrudan ölüm üretmez. Bu kural ön ve yan yüzeyler için de geçerlidir. Kamera oyuncudan bağımsız ve sabit hızla sağa ilerler; engele takılan oyuncu ekranda geriye düşer ve gövdesi sol kenardan tamamen çıktığında elenir. Aktif lazer teması ve oyun alanının dikey sınırlarının dışına çıkmak da koşuyu bitirir.

Parkur uzunluğu 8.840 birimdir. Alt ve üst raylarda ikişer fiziksel boşluk bulunur. Boşluğa yerçekimi yönünde giren oyuncu ray desteğini kaybeder ve ekran dışına düşer. Beş küçük oklu hız şeridi yalnızca üzerinde koşulunca bir kez çalışır; kısa süreli hız farkı oyuncuya kameraya göre yaklaşık 70 birim sağ mesafe kazandırır.

## Kapsam

İlk sürüm solo ve bitişli tek bir parkurdur. Endless ve multiplayer bu çekirdeğin oynanış dengesi doğrulandıktan sonra ayrı aşamalar olarak ele alınmalıdır. En iyi süre cihazda `UserDefaults` ile tutulur; sunucu skor tablosu henüz yoktur.

## Doğrulama

`HouseFlowTests/HouseSwitchTests.swift` güvenli platform kuralını, ölümcül temas politikasını, yerçekimi geçişini, taban temas probunu, sol kenardan tamamen çıkma sınırını, ilerleme sınırlarını ve parkurun ölçeklenmesini kapsar.

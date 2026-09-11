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

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

---

# House Rockets demo akışı

- `HouseRocketsView`: hazırlık, tek insan oyuncunun 360° joystick kontrolü, HUD, duraklatma ve sonuç ekranı.
- `HouseRocketsViewModel`: kullanıcı niyetlerini sıra numaralı komutlara dönüştürür; yalnızca yeni maç revizyonlarını kabul eder.
- `HouseRocketsGameServicing`: demo ile gelecekteki çevrim içi oturumun ortak komut/durum sınırı.
- `DemoHouseRocketsSession`: 1 insan + 1–3 bot, geri sayım, bot kararları ve maç yaşam döngüsü.
- `HouseRocketsCourse`: daralan, genişleyen, yükselen/alçalan, kum saati ve kısa dar geçitlerin ortak geometri kaynağı; çizim ve fizik aynı çokgenleri kullanır.
- `HouseRocketsSimulation`: ekran boyutundan bağımsız dünya koordinatlarında hareket, katı yüzey teması, lider takibi ve arka sınırdan elenme kuralları.
- `HouseRocketsScene`: SpriteKit döngüsünde simülasyonu ilerletir; dünyayı eşit eksen ölçeğiyle ekrana yansıtır. Oyun kuralları çizim kodunda hesaplanmaz.

## Kontrol ve kazanma kuralları

Joystick yalnızca yönü belirler. Güvenli oyun alanının sağ ve sol %30’luk şeritlerinde başlayan sürüklemeler yön verir; sabit kontrol görünmez. İlk dokunma noktası merkezdir; 5 puanı geçen sürüklemede %55 opaklıkla görünür ve parmak bırakılınca veya hareket iptal edilince kaybolur. Sürükleme kenar alanından ekranın içine taşabilir. Duraklatma düğmesi kontrol katmanının üzerinde kalır. Başlangıç yönü sağdır; bırakıldığında son yön korunur. İnsan ve bot gemileri sürekli itkiyle, 300 dünya birimi/saniye temel hızla hareket eder; çubuğun merkezden uzaklığı hızı değiştirmez. Bütün yönler, geri uçuş dahil, kullanılabilir. Temas durumunda yüzeyin engellediği hareket bileşeni durur; eğimli yüzeyler gerçek yüzey normaliyle çözülür, gemi yüzey boyunca kayabilir ve yön değiştirerek kurtulabilir. Alt/üst platform veya engel teması doğrudan elemez.

Parkur koordinatlarında X ilerleme, Y enine konumdur; koridor 360 birim genişliğindedir. Yatay bölümde 1.200, dikey bölümde 600 birim ilerisi görünür; iki eksen aynı ölçekle çizilir. Gemi çarpışma yarıçapı 10 birim; gövde çizimi önceki sürümün yarı ölçeğindedir. Engellerin dünya konumu sabittir. Kamera, hayattaki en öndeki geminin gerçek konumuna göre ileri kayar; kendiliğinden ilerlemez ve geri gitmez. Herkes engelde takılırsa kamera da durur. Bir geminin çarpışma gövdesi arka sınırdan (yatayda sol, dikeyde alt kenar) tamamen çıktığında elenir. Bir gemi kaldığında maç biter; süre sınırı veya mesafeye göre kazanan seçimi yoktur. Eşzamanlı olarak tüm gemilerin çıkması savunmacı bir beraberlik sonucudur.

Oyun sürdükçe her 25 saniyede bir yatay/dikey geçiş başlar: 25. saniyede yukarı, 50. saniyede sağa, 75. saniyede tekrar yukarı döner. Her geçiş 3 saniye sürer; yön uyarısı geçişten 3 saniye önce görünür ve geçiş boyunca kalır. Cihaz yatay kalır. Joystick komutları ve HUD yönü ekran koordinatlarındadır; simülasyon bunları parkur koordinatlarına çevirir. Dönüş mevcut roketleri, engelleri ve hız alanlarını birlikte taşır; yeni yön girişi olmadığında parkura göre yön korunur. Kamera mesafesi ve liderin 420 birimlik arka payı değişmediğinden dönüş tek başına eleme yaratmaz.

Duraklatma hareketi, dönüşü ve geçen süreyi durdurur. Elenen insan kalan botları izleyebilir. Ekrandan çıkışta oturum görevleri iptal edilir; yeniden başlatma yeni oyuncu/maç kimlikleri ve temiz simülasyon oluşturur.

Bilgi yazıları yatay parkurda üst/alt boşluklarda, dikey parkurda iki yan boşluğun en üst kısmındadır. Üç saniyelik dönüş boyunca bilgiler tamamen gizlenir; duraklatma düğmesi kullanılabilir kalır. Dönüş öncesi bildirim iki tarafta da yön oku ve `Turn` olarak görünür; süre ve kalan oyuncu sayısı simge/sayıyla, izleme durumu kısa bir etiketle verilir. Bilgi katmanı joystick dokunuşlarını engellemez; yalnızca duraklatma düğmesi dokunma alır. Sahne ve bilgi katmanı aynı güvenli ekran alanını kullanır.

## Görsel dil

`HouseRocketsArtwork.swift` referans roketin yuvarlak gövdesini, dairesel penceresini, kanatlarını ve arka bileziğini oyun sahnesi, lobi ve Games kartı için ortak vektör yollarıyla çizer; Games kartının düzeni diğer kartlarla aynıdır. Palet: #780000, #C1121F, #FDF0D5, #003049, #669BBC, #A9D6E5. Koyu lacivert parkur, farklı tonda mavi dış alan, krem yazılar/sınırlar ve bordo engeller kullanılır. Düşük kontrastlı mavi, bordo, kırmızı ve krem topografik konturlar dış alanda sabittir; boyut değişiminde yeniden üretilir. Engel yüzeylerindeki daha belirgin konturlar siluete kırpılır. Kamera yakınlaştırması roketleri, engelleri ve tokenleri aynı oranda büyütür; dünya fiziği değişmez. Parkur yatayda ekranın sağ/sol, dikeyde üst/alt fiziksel kenarına uzanır; bilgi alanları parkurun dışında kalır. Oyuncuların mevcut serileştirilmiş renk kimlikleri korunur, görsel renkleri yeni palete eşlenir.

## Hareketli hız alanları

Engeller arasında ilerleme konumu sabit, parkurun enine ekseninde maç süresine bağlı sinüs hareketi yapan alanlar vardır. Yatay parkurda yukarı/aşağı, dikey parkurda sağa/sola hareket ederler. Görsel ve temas yarıçapı 15,4 birimdir (ilk boyuttan %30 küçük). Salınım hızı %20 artırılmıştır: periyotlar hızlanma için 3,0 saniye, yavaşlama için yaklaşık 3,67 saniyedir. Her beş yerleşimden biri atlanır; iki türün uzun vadeli dağılımı dengelidir. Mavi çift ok 1,3 saniye boyunca ×1,45 (435 birim/s), kırmızı fren 1,4 saniye boyunca ×0,65 (195 birim/s) uygular. Alanlar katı değildir ve gemileri elemez. Aynı alan her gemiyi bağımsız olarak bir kez etkiler; alan diğer yarışçılar için kaybolmaz. Etkiler çarpılmaz; son temas önceki etkiyi değiştirir, süre bitince temel hıza dönülür. Duraklatmada alan hareketi ve etki süresi de donar. Yeniden başlatmada etkiler ve temas geçmişi temizlenir. Kamera gerisinde kalan alanlar/temas kayıtları silinir.

Hız durumu roket çevresindeki halka, itki alevi ve insan oyuncunun HUD etiketiyle gösterilir. Alanların çift ok/fren sembolleri renk ayrımını destekler. Botlar geçidin giriş merkezine ek olarak eğimli geçidin ilerideki merkezini izler; insanla aynı hız ve temas kurallarına tabidir.

## Çevrim içi geçiş noktası

`HouseRocketsSessionFactory` ekran başına yerel bot veya çevrim içi oturum kurar. `GameSessionService` uygulamanın mevcut HTTP/keychain bağımlılıklarını paylaşır; `OnlineHouseRocketsSession` v2 wire sözleşmesini ve native WebSocket bağlantısını yönetir. Yerel bot simülasyonu çevrim içi maçta çalıştırılmaz.

- `HouseRocketsOnlineLobby`: welcome/sync, gerektiğinde join, açık ready/leave/cancel niyetleri ve heartbeat. Komut kabulü uygulama kanıtı değildir; session version/durumuyla doğrulanır. İptal yetkisi oturumun kurucusu veya ev sahibine aittir; son kararı backend verir.
- `HouseRocketsOnlineFlight`: sınırlı input/ACK/prediction tamponları, snapshot interpolation ve sunucu elenme bildirimleri. `HouseRocketsRenderMapper` sunucu geometrisini render modeline çevirir; `HouseRocketsScene` yalnız çizim yapar.
- `HouseRocketsOnlineResult`: maç kimliğini sabitler, finalizing sırasında kalıcı kaydı bekler; sonuç event’i kaybolursa aynı eski session ID’siyle HTTP sorgular. En çok 5 deneme ve toplam 20 saniye bütçe vardır; Retry-After korunur. 401/403 ve geçersiz sözleşme otomatik tekrar edilmez. HTTP okuyucusu socket kapansa da çalışır; ekran/context kapanınca eski yanıtlar düşürülür.
- `HouseRocketsOnlineResultView`: completed, beraberlik ve iptali sunar. Sıra doğrudan kalıcı result’tan gelir; eşit sıralar korunur. Mesafe sıralama üretmez. Başlamadan iptal edilen lobby/countdown için 404 sonuç kaydı bulunmadığı anlamına gelebilir; oynanmış maçtaki 404 aynı şekilde yorumlanmaz.

Rematch eski oturumu yerelde resetlemez. Eski bağlantı/input/sonuç işleri kapanır; PUT yeni veya başkasının açtığı aktif oturumu bulur, oyuncu yalnız eksikse join olur ve tekrar açıkça hazır olur. Terminal oturuma socket retry yoktur. Reconnect aynı maç kimliğiyle çalışır; yeni aktif oturum açmak yalnız rematch akışına aittir.

M4 doğrulaması (5 Ekim 2026): Foundation servis/fixture testlerinde toplam 87 test geçti (18 yeni M4 testi); iOS kaynak tip kontrolü geçti. Önceki iki denemede realtime handshake HTTP 503 aldı. Backend fix’i sonrasındaki canlı iki istemcili doğrulamada WebSocket/welcome/join, ready=false/true, countdown, playing, steering ACK ve sunucu elenmesi geçti. A kalıcı result event’ini aldı; B’de event kasıtlı düşürülerek aynı eski session ID’sinden HTTP ile birebir aynı result doğrulandı. Rematch yeni ortak lobiye bağlandı, oyuncular yeniden açıkça hazır oldu; yetkili lobi iptali session durumuyla doğrulandı ve sonuç kaydı bulunmayan iptal kazanan/sıra üretmeden işlendi. Test bağlantıları kapatıldı. Bu doğrulama Foundation/native socket servis akışıdır; gerçek cihaz sonuç ekranı/yön değişimi kabulü henüz yapılmadı.

## M5 bağlantı ve context yaşam döngüsü

- `HouseRocketsReconnectPolicy` hata sınıflandırmasını ve jitter/backoff süresini belirler. En çok 5 otomatik deneme; ilk bağlantıda 20 saniye, uçuşta welcome içindeki reconnect grace ile sınırlı bütçe vardır. Hızlı kopma/bağlanma bütçeyi sıfırlamaz; başarılı bağlantının kararlı kalması gerekir. HTTP `Retry-After` asgari beklemedir. 401/403, sözleşme hatası ve terminal conflict otomatik retry üretmez.
- `OnlineHouseRocketsSession` geçici socket kapatmayı kalıcı context cleanup'tan ayırır. Oturum kimliği ve kritik event observer'ları korunur; reconnect güncel token ile aynı session'a socket açar, PUT/join/ready veya eski steering tekrar etmez. Nonce taşıyan tam playing sync cevabı, periyodik snapshot coalescing tamponundan ayrı kritik akışta tutulur.
- `HouseRocketsOnlineLobby` her bağlantı girişimini ayrı generation ile sınırlar. Foreground'da hem korelasyonlu session hem oyun sync'i gerekir. Kontrol yeniden gelen grant ve oyuncunun snapshot generation'ı eşleşmeden açılmaz; aynı socket resync'i grant generation'ını koruyabilir. Yeni epoch doğrudan playing gelse de kabul edilir; eski epoch/sequence düşürülür, ilan edilmiş elenme yeni frame ile diriltilmez.
- `HouseRocketsOnlineFlight` bağlantı/foreground sınırında input, ACK, prediction ve in-flight write'ı temizler; son sunucu geometrisini korur ve bağlantı yokken tahmini uçuşu dondurur. Elenmiş oyuncu izleyici kalır; reconnect geçmiş elenmelerin haptic bildirimini yeniden oynatmaz. İkinci cihaz kontrolü aldığında eski cihaz otomatik resync/bind yarışına girmez; kontrolü geri almak açık kullanıcı niyetidir.
- Background input ve uygulama heartbeat'ini durdurur; online maç sunucuda ilerler. Yerel bot pause davranışı korunur. Açık Exit iki saniyeyle sınırlı business leave'tir; ulaşılamayan sunucuda leave uygulanmış varsayılmaz, server grace devreye girer. Logout/house/mode değişimi/disappear eski task'ları idempotent kapatır; 401 mevcut uygulama logout akışına bağlanır.
- `HouseRocketsOnlineConnectionView` yalnız bağlantı/kurtarma/kontrol devri durumunu sunar; retry ve kontrolü geri al niyetlerini ViewModel'e iletir. Mevcut oyun paleti ve panel bileşenleri kullanılır; kısa yatay ekranda veya büyük yazıda içerik kaydırılabilir.

M5 doğrulaması (5 Ekim 2026): `HouseRocketsReconnectTests.swift` içinde 24 yeni test; kopma/grace, Retry-After/503 bütçesi, auth/yetki kaybı, foreground tam sync, ikinci cihaz kontrolü, spectator, epoch/grant sıraları ve geç gelen eski context cevaplarını kapsar. Toplam 111 Foundation testi ve tüm iOS Swift kaynaklarının tip kontrolü geçti. Native socket canlı testinde background/foreground, aynı ID'ye PUT olmadan reconnect ve ikinci cihaz kontrol devri/açık reclaim doğrulandı. Ardından kalıcı result event/HTTP fallback, rematch, yeni ready ve yetkili lobi iptali regresyonları da geçti; test bağlantıları kapatıldı. Bu test servis yaşam döngüsü çağrılarını kullanır; iOS'un gerçek background suspension davranışı ve görsel ekran kabulü ayrıca cihazda yapılmalıdır. Owner process kaybı testi backend ile koordineli staging bilgisi bekliyor; üretimde owner/process veya secret değiştirilmedi.

## Doğrulama

`HouseFlowTests/HouseRocketsTests.swift` içindeki 27 test; tam daire yönlendirme ve sabit hız, bırakılan yönün korunması, lider takibi, engellerin sabit konumu, ölümcül olmayan platform/engel teması, yüzeyde kayarak kurtulma, engelin arka yüzü, tam arka sınır çıkışı, eşzamanlı elenmeler, süre sınırının olmaması, 30/120 FPS tutarlılığı, bot geçişleri ve komut serileştirmesini kapsar. Yeni kapsam; farklı geçit profillerini, eğimli yüzeylerin normalini, hız alanlarının yalnızca dikey hareketini, hızlanma/yavaşlama temasını, tek seferlik etkiyi, temel hıza dönüşü ve tüm parkur deseninin botlarla geçişini de doğrular. Tekrarlanan yatay/dikey dönüşlerin zamanlaması ve yön uyarıları, dönüşlerde kameranın ve takılmış roketlerin korunması, ekran yönünde kontrol, alt sınırdan eleme, iPhone/iPad boyutlarında parkurun ekrana sığması ve bilgi alanlarının dönüşte gizlenmesi ve dikey konumda üstte yeniden görünmesi da test edilir. Foundation tabanlı model ve simülasyon, simülatörden bağımsız olarak da test edilebilir.

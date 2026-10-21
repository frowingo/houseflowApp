# House of Tanks — harita, ölçek ve multiplayer hazırlık planı

Tarih: 19 Ekim 2026

Durum: Faz 1–3'ün ilk uygulaması tamamlandı; Faz 4 cihaz üstü level tuning ve
görsel kabul bekliyor. Faz 5 multiplayer öncesi simulation/render ayrımı henüz
başlamadı.

20 Ekim 2026 kapsam güncellemesi:

- Kullanıcı isteğiyle tahta kasalar itilebilir ve tek füze isabetinde kırılabilir oldu;
  diğer engeller sabit. Kasa konumları ve kırılma durumu her yeni turda sıfırlanır.
- Haritalar v2: sıcak ahşap Salon, mavi zikzak Koridorlar, kiremit tonlu raflı Depo,
  yeşil dört girişli halka Avlu. Sabit duvar parçaları labirent düzeni oluşturur.
- Jokerler 7–11 oyun saniyesi aralıklarla, aynı anda en çok bir tane olacak şekilde
  güvenli rastgele konumlarda doğar. Yerde 8 saniye kalır; temasta veya sürede silinir.
  Başlangıç noktalarından en az 80 pt (büyük arenalarda daha fazla), canlı tanklardan
  50 pt ve mevcut engel sınırlarından 26 pt uzaklık aranır; uygun yer yoksa doğma ertelenir.
- Her tank aynı anda tek güç taşır; yenisi eskisinin yerini alır. Güç süresi 6 saniye:
  1.55x hız, basılı tutarken 0.16 saniye aralıklı tarama, her basışta beşli yelpaze atışı
  veya süre boyunca hasarı önleyen kalkan. Normal atış aralığı 0.58 saniyedir.
- Joker ve güç süreleri pause sırasında ilerlemez; elenme/tur/maç geçişleri temizlenir.
  Sembol ve süre yayı tankın üzerinde, aktif gücün adı ve saniyesi HUD'da gösterilir.
- Botlar mevcut kasa/duvar sınırlarına göre küçük bir yerel ızgarada yol bulur;
  yakındaki jokerleri hedefleyebilir. Yeni bir navigasyon framework'ü eklenmez.
- Kullanıcı manuel testleri kendi telefonunda yapar. Açık izin olmadan simülatör
  oluşturulmaz, yüklenmez veya çalıştırılmaz. Bu geliştirmede simülatör kullanılmadı.

20 Ekim doğrulama sonucu:

- Saf Swift kuralları üzerinde 169 kontrol geçti: token tek alıcısı, token/güç son
  kullanım sınırları, güç değiştirme, sıfır zaman adımında süre korunması, güvenli
  doğma adayları, dört ekran ölçüsünde spawn/engel açıklığı ve rota bağlantısı.
- Bot rota adımları engel köşelerinde tank açıklığıyla kontrol edildi; küçük ekran
  köşe kesme sorunu giderildi ve kalıcı XCTest regresyon senaryosu eklendi.
- Oyun modeli, katalog, joker kuralları, navigasyon, SpriteKit sahnesi ve demo servisi
  mevcut iPhoneOS SDK ile `swiftc -typecheck` kontrolünden hatasız geçti. SwiftUI,
  localization ve XCTest dosyalarının syntax kontrolü geçti.
- Tam uygulama build'i, XCTest runner ve görsel/fiziksel cihaz testi bu turda
  çalıştırılmadı. Aşağıdaki manuel senaryolar kullanıcının telefonu için bekliyor.
- Doğrulama için oluşturulan geçici derleyici önbelleği ve kontrol çalıştırıcısı
  temizlendi; yeni paket, runtime veya simülatör kurulmadı.

19 Ekim 2026 teslim notu:

- Version'lı dört harita kataloğu, normalize spawn/engel/dekorasyon tanımları eklendi.
- Salon, Koridorlar, Depo ve Avlu lobby üzerinden seçilebilir hale getirildi.
- Tank, mermi, engel ve mekânsal efekt ölçüleri yarıya indirildi; hareket, dönüş,
  mermi hızı ve cooldown değerleri korunuyor.
- Map ID/version demo snapshot'ına taşındı ve sonraki turlarda korunuyor.
- Harita sınırı, spawn clearance ve yarı ölçek için otomatik kontroller eklendi.
- iOS Simulator build'i başarılı; House-Tanks testleri 11/11 geçti.
- Simulator görsel kabul akışı uygulamanın giriş ekranında durdu; test hesabı
  kullanılmadan House-Tanks lobby/gameplay ekranlarına ulaşılamadı.

## 1. Amaç

House of Tanks'ın çalışan yerel bot demosunu koruyarak:

- tankları, mermileri ve statik engelleri ekranda yaklaşık yarı ölçekte göstermek,
- dört farklı ve tekrar oynanabilir harita sunmak,
- mevcut tek dokunuş kontrolünü değiştirmemek,
- level geliştirmesini daha sonra yapılacak authoritative multiplayer entegrasyonuna
  uygun veri ve servis sınırlarıyla yapmak.

Bu aşamada online bağlantı, backend sözleşmesi veya gerçek oyunculu lobi yapılmaz.
Online seçeneği mevcut ekranda “yakında” olarak kalır; yerel bot modu ürünün çalışan
referans davranışıdır.

## 2. Korunacak mevcut davranış

İlk kabul baseline'ı aşağıdaki davranışlardır:

- Üç oyuncu: bir insan ve iki bot.
- Dokunmaya başlayınca tank mevcut baktığı yöne ateş eder ve ilerler.
- Dokunma bırakılınca ilerleme durur, tank dönmeye devam eder ve dönüş yönü değişir.
- Üç zorluk seviyesi, beş zırh, 60 saniyelik tur ve üç tur galibiyeti korunur.
- Geri sayım, pause/resume, round sonucu, match sonucu, haptic feedback ve
  reduce-motion davranışları korunur.
- Bot demo ve gelecekteki online servis aynı command/snapshot kenarından beslenmeye
  devam eder.

Mevcut yapı bu hedef için tamamen baştan yazılmamalıdır. Halihazırda
`HouseTanksGameServicing`, `HouseTanksCommand` ve `HouseTanksSnapshot` sınırları
bulunuyor. En büyük teknik borç, `HouseTanksScene` sınıfının çizimle birlikte
fizik, çarpışma, bot gözlemi ve arena tanımının da sahibi olmasıdır.

## 3. Ürün kararları

### 3.1. Harita seçimi

Önerilen ilk davranış: kullanıcı lobi ekranında dört haritadan birini seçer ve bu
harita maçın bütün turlarında sabit kalır. Varsayılan harita, mevcut arena düzeninin
yeni veri modeline taşınmış hali olur.

İlk teslimde rastgele harita veya her tur otomatik harita değiştirme eklenmez.
Böylece oyuncu maç boyunca öğrendiği cover ve görüş koridorlarını kullanabilir;
gelecekte server yalnız bir `mapID + mapVersion` seçerek bütün istemcileri aynı
geometriye bağlayabilir.

### 3.2. Ölçek

Tek bir `gameplayScale = 0.5` kavramı kullanılmalıdır. Yalnız artwork küçültmek
yerine aşağıdaki parçalar birlikte ölçeklenir:

- tank artwork'ü ve tank physics body,
- mermi artwork'ü ve physics body,
- namlu çıkış mesafesi ve muzzle flash,
- statik engellerin artwork'ü ve physics body,
- patlama ve vurulma efektlerinin mekânsal boyutu.

Arena ve kamera küçültülmez; amaç aynı ekranda daha fazla kullanılabilir oyun alanı
oluşturmaktır. İlk geçişte hareket hızı, dönüş hızı, mermi hızı ve ateş cooldown'ı
değiştirilmez. Böylece kontrol zamanlaması korunur. Küçük gövdeler nedeniyle algılanan
hız artarsa bu değerler ancak cihaz playtest'i sonrasında ayrı tuning olarak ele alınır.

Mevcut sayılara göre ilk teknik hedefler:

| Parça | Mevcut | İlk hedef |
| --- | ---: | ---: |
| Tank physics body | 40 × 28 | 20 × 14 |
| Tank visual scale | 0.76 | 0.38 |
| Mermi | 18 × 7 | 9 × 3.5 |
| Engel scale | 0.72 | 0.36 |

Bu değerler kabul ölçüsü değil başlangıç değeridir. Görsel ve fizik gövdelerinin
birbirini örtmesi zorunlu kabul kriteridir.

### 3.3. Engel kapsamı

20 Ekim isteği önceki statik-engel sınırını günceller: tahta kasalar dinamik ve tek
isabette yıkılabilir, kanepe/ayırıcı/masa/kitaplık/kolon/bitki sabittir. Aynı haritada
iki tür birlikte kullanılır. Online aşamasında kasa konumu, yıkılma, token doğumu ve
güç süresi sunucu otoritesine taşınmalıdır; mevcut rastgelelik yerel demo içindir.

## 4. Harita seti

Harita koordinatları ekran pikseliyle değil 0...1 normalize arena koordinatlarıyla
tanımlanır. Her harita kendi spawn noktalarını, engellerini ve dekoratif zemin çizgilerini
taşır.

### 4.1. Salon — dengeli başlangıç haritası

Mevcut haritanın davranışını koruyan referans haritadır. Orta ayırıcı, iki kanepe,
masa ve sandık düzeni veri modeline taşınır; küçülen ölçekte boş kalan alanlara
iki küçük cover eklenebilir.

- Amaç: mevcut demo için regresyon referansı.
- Oyun karakteri: açık görüş ile cover arasında dengeli.
- Hedef engel sayısı: 7–9.

### 4.2. Koridorlar — yön ve kaçış haritası

Kısa ayırıcılar dört bağlantılı koridor oluşturur; çıkmaz sokak kullanılmaz.

- Amaç: tek dokunuşla ileri gitme zamanlamasını öne çıkarmak.
- Oyun karakteri: orta menzil, keskin görüş kesilmeleri.
- Hedef engel sayısı: 10–12.

### 4.3. Depo — yoğun cover haritası

Küçük sandık ve kitaplık kümeleri, aralarında en az iki alternatif geçiş bırakacak
şekilde yerleştirilir.

- Amaç: küçük ölçekte daha fazla engel vaadini görünür kılmak.
- Oyun karakteri: kısa menzil ve sık pozisyon değiştirme.
- Hedef engel sayısı: 12–16.

### 4.4. Avlu — merkez kontrol haritası

Ortada büyük ama geçilebilir çevre boşluğu olan yuvarlak masa/ada, çevrede küçük
kolonlar bulunur. Spawn'lar merkeze doğrudan ateş hattında olmaz.

- Amaç: dairesel dolaşım ve flank rotaları sunmak.
- Oyun karakteri: uzun çevre rotası ile riskli merkez geçişi.
- Hedef engel sayısı: 8–12.

### 4.5. Ortak level kuralları

Her harita aşağıdaki kontrolleri geçmelidir:

- Bütün spawn noktaları arena sınırında ve engellerden güvenli uzaklıktadır.
- Hiçbir oyuncu başlangıçta başka bir oyuncuya doğrudan ateş hattında değildir.
- Her spawn'dan diğer alanlara en az iki rota vardır; erişilemeyen bölge yoktur.
- En dar oynanabilir geçit hedef tank genişliğinin en az 1.75 katıdır.
- Spawn-to-center mesafeleri ve ilk güvenli cover erişimi yaklaşık dengelidir.
- Dekoratif node physics body üretmez; fizik geometriyle görsel geometri ayrışmaz.
- Desteklenen landscape boyutlarında engeller üst üste binmez veya arena dışına çıkmaz.

## 5. Minimum veri modeli

Yeni bir genel oyun framework'ü kurmak yerine House of Tanks'a özel küçük bir model
yeterlidir:

```swift
enum HouseTanksMapID: String, CaseIterable, Codable, Sendable {
    case livingRoom
    case corridors
    case warehouse
    case courtyard
}

struct HouseTanksMapDefinition: Sendable {
    let id: HouseTanksMapID
    let version: Int
    let spawnPoints: [NormalizedPoint]
    let obstacles: [HouseTanksObstacleDefinition]
    let decorations: [HouseTanksDecorationDefinition]
}
```

`HouseTanksMatchConfiguration` seçilen `mapID` değerini taşır. Snapshot da en az
`mapID` ve `mapVersion` taşımalıdır. Demo session haritayı config'den alır; ileride
online session bu alanları server snapshot'ından alır. Wire DTO'lar ortaya çıktığında
domain enum'ları doğrudan network sözleşmesi olarak kullanılmamalıdır.

Harita tanımları immutable ve deterministik olmalıdır. Scene içinde rastgele engel
üretimi yapılmaz. İleride procedural varyasyon istenirse server tarafından verilen
ayrı bir seed/version sözleşmesiyle eklenir.

## 6. Geliştirme fazları

### Faz 0 — Baseline'ı kilitle (1–2 kişi-gün)

- Mevcut arena, tank ölçüleri, spawn'lar, kontrol akışı ve round kurallarını
  davranış/screenshot baseline'ı olarak kaydet.
- `HouseTanksMatchRules`, eski sequence reddi, round reset ve disconnect iptalini
  unit testlerle güvenceye al.
- Mevcut haritayı değiştirmeden kabul senaryosu hazırla.

Çıkış: Çalışan demoyu sonraki fazlarda yanlışlıkla değiştirdiğimizi gösterecek test ve
görsel referanslar bulunur.

### Faz 1 — Harita verisini Scene'den ayır (2–3 kişi-gün)

- Map ID, version, normalize nokta, obstacle ve decoration tanımlarını ekle.
- Mevcut arena değerlerini `livingRoom` tanımına bire bir taşı.
- `HouseTanksScene` yalnız verilen tanımdan node üretir; harita seçmez.
- Lobby'ye dört harita seçimi için sade kart/chip alanı ekle, ancak yalnız hazır
  haritaları etkinleştir.

Çıkış: Varsayılan Salon seçiliyken mevcut demonun kontrolü ve maç akışı değişmez.

### Faz 2 — Yarı ölçeğe geç (1–2 kişi-gün)

- Ortak gameplay scale'i görsel ve physics ölçülerine birlikte uygula.
- Spawn güvenlik yarıçapı, namlu çıkışı, efekt boyutu ve bot mesafe hesabını gözden geçir.
- Hareket/dönüş/ateş hızlarını ilk etapta sabit tut.
- En küçük ve en büyük desteklenen landscape ölçülerinde görsel-physics eşleşmesini
  kullanıcının fiziksel cihazında doğrula; simülatör için ayrıca açık izin gerekir.

Çıkış: Tanklar ve engeller mevcut ekrandaki boyutlarının yaklaşık yarısıdır; kontrol
hareketi aynı jest ve zamanlama modeliyle çalışır.

### Faz 3 — Dört haritayı üret (4–6 kişi-gün)

- Salon'u kabul et, ardından Koridorlar, Depo ve Avlu tanımlarını ekle.
- Gerekli yeni obstacle artwork türlerini mevcut shape tabanlı çizim diliyle oluştur.
- Harita başına spawn/engel sınırı/geçit testleri ekle.
- Her haritada easy/normal/hard botlarla tam maç smoke senaryosu çalıştır.

Çıkış: Dört harita lobiden seçilebilir; her biri aynı match/round kurallarıyla
tamamlanabilir ve bir haritada yapılan seçim başka maça sızmaz.

### Faz 4 — Level tuning ve demo kabulü (2–3 kişi-gün)

- Spawn güvenliği, doğrudan ilk atış, sıkışma noktası, kör alan ve bot takılması
  gözlemlerini kaydet.
- Harita başına maç süresi, ilk isabet süresi ve bot galibiyet dağılımını karşılaştır.
- Yalnız kanıtlanan sorunlar için engel/spawn düzeni veya hız tuning'i yap.
- Accessibility, reduce motion, pause/resume, orientation ve düşük FPS davranışını
  tekrar doğrula.

Çıkış: Dört harita “oynanabilir içerik” kabulünü geçer. Bu nokta level geliştirmesinin
ilk yayınlanabilir demo sınırıdır.

### Faz 5 — Multiplayer öncesi simulation/render ayrımı (6–10 kişi-gün)

Bu faz dört haritanın oynanabilir hale gelmesini bloke etmemeli; online çalışmaya
başlamadan önce tamamlanmalıdır.

- Fizik state'i ve sonuç otoritesini `HouseTanksScene` dışındaki deterministik simulation
  katmanına taşı.
- Scene'e `apply(renderFrame:)` benzeri salt render girişi ver; Scene winner, armor veya
  authoritative hit kararı üretmesin.
- Demo service aynı command'leri local simulation'a uygulasın ve snapshot yayınlasın.
- Bot observation doğrudan Scene node'larından değil simulation state'inden üretilsin.
- Fixed tick, enjekte edilebilir clock ve seed'li RNG kullan; dört map definition aynı
  simulation tarafından tüketilsin.
- Aynı input + map version + seed'in aynı state sonucunu verdiğini golden testlerle
  doğrula.

Çıkış: Yerel demo görünür biçimde aynı kalır; gelecekteki online adapter server
snapshot'ını aynı render sınırına map edebilir. Client online modda hit/winner üretmez.

### Faz 6 — Daha sonraki online entegrasyon

Bu planın uygulama kapsamı değildir. Başlamadan önce backend ile wire contract,
session/lobby/ready, server tick, map version, reconnect, input ownership, hit/result
otoritesi ve kapasite sınırları birlikte kararlaştırılır. House Rockets'taki gibi
local demo ayrı tutulur; online servis factory üzerinden enjekte edilir.

## 7. Dosya bazlı değişiklik yönü

| Alan | Beklenen yön |
| --- | --- |
| `Models/Games/HouseTanks/HouseTanksModels.swift` | Map ID/version ve configuration/snapshot alanları |
| Yeni `Models/Games/HouseTanks/HouseTanksMapModels.swift` | Normalize ve immutable level tanımları |
| Yeni `Services/Games/HouseTanks/HouseTanksMapCatalog.swift` | Dört statik harita kataloğu; global framework değil |
| `Views/Discover/Games/HouseTanks/HouseTanksScene.swift` | Hard-coded arena kaldırma, definition'dan node üretme, ortak scale |
| `Services/Games/HouseTanks/DemoHouseTanksGameSession.swift` | Config map seçimi ve round hazırlığı |
| `ViewModels/Games/HouseTanks/HouseTanksViewModel.swift` | Seçili harita state'i ve config'e aktarım |
| `Views/Discover/Games/HouseTanks/HouseTanksView.swift` | Dört haritalı sade seçim UI'ı |
| Yeni House Tanks testleri | Kurallar, map validation, lifecycle ve daha sonra determinism |

Faz 5'e gelmeden `AppDependencies` içine online House Tanks bağımlılığı eklemek gerekmez.
Demo service'in doğrudan view init'inde oluşturulması level fazlarında korunabilir;
online başlarken House Rockets benzeri per-screen session factory'ye taşınır.

## 8. Test ve kabul matrisi

### Otomatik

- Dört map ID benzersiz, version pozitif ve katalogda eksiksizdir.
- Her haritada en az üç spawn vardır; noktalar 0...1 aralığındadır.
- Obstacle bounds arena içindedir; spawn clearance ihlali yoktur.
- Aynı config yeni round'da aynı map/version ile devam eder.
- Eski command sequence reddedilir; yeni maç eski task/hit sonucunu kabul etmez.
- Scale uygulandığında görsel temel ölçü ile physics ölçüsü aynı katsayıyı kullanır.
- Faz 5 sonrasında aynı seed/input dizisi aynı simulation snapshot'ını üretir.

### Manuel cihaz kabulü

- Dört haritada tank, mermi ve engel yaklaşık yarı boyutta görünür.
- Dokun-basılı tut-bırak kontrolü mevcut demo ile aynı davranır.
- Tank dar geçitlerde sıkışmadan ilerler, engel içine doğmaz ve ekran dışına çıkmaz.
- Mermi küçük cover'ın görsel olarak dışından geçip physics body'ye görünmez biçimde
  çarpmaz.
- HUD küçük oyun elemanları nedeniyle gereksiz büyütülmez; okunabilirliği korunur.
- Pause/background/foreground sonrasında basılı input takılı kalmaz.
- iPhone ve iPad landscape oranlarında dört harita oynanabilir kalır.
- Kasayı tankla it; diğer kasalara, sabit engellere ve arena kenarına çarptığında
  içerilerinden geçmemeli. Tek füze kasayı silmeli; yeni tur kasaları geri getirmeli.
- Her jokeri hem oyuncu hem bot alabilmeli; token tek kişiye verilmeli, süresi dolan
  token kaybolmalı. Yeni güç eski gücü değiştirmeli; kalkan zırhı azaltmamalı.
- Taramalı ateş yalnız basılı tutarken sürmeli; çoklu atış beş mermiyi tek tetikte
  yelpaze biçiminde çıkarmalı. Güç bitince normal kontrol ve hız geri gelmeli.
- Joker varken ve güç aktifken pause/background/foreground dene; kalan oyun süreleri
  korunmalı. Tur geçişinde eski token veya güç kalmamalı.

## 9. Riskler ve önlemler

| Risk | Önlem |
| --- | --- |
| Yalnız artwork küçülür, hitbox büyük kalır | Tek scale kaynağı ve debug physics overlay kabulü |
| Küçük tank aynı hızda fazla hızlı hissedilir | Hızları peşinen değiştirme; Faz 4 ölçümüyle tune et |
| Çok engel botları kilitler | Bağlantılı rotalar, minimum geçit ve bot smoke senaryosu |
| Map verisi Scene/online/backend arasında kopyalanır | `mapID + mapVersion`; tek immutable mobil katalog, sonra ortak fixture |
| Dört harita için gereksiz oyun motoru geliştirilir | House Tanks'a özel küçük katalog; procedural editor/ECS yok |
| Level işi sırasında çalışan demo bozulur | Önce mevcut haritayı veri modeline bire bir taşı, sonra scale ve yeni haritaları ayrı fazla aç |
| Client authoritative yapı online'a aynen taşınır | Online başlamadan Faz 5 gate'i; Scene yalnız render eder |

## 10. Önerilen teslim sırası ve maliyet dengesi

İlk görünür ve yayınlanabilir hedef Faz 0–4'tür: yaklaşık **10–16 kişi-gün**.
Multiplayer teknik hazırlık gate'i olan Faz 5 ayrıca yaklaşık **6–10 kişi-gün**dür.
Gerçek online entegrasyon backend kapsamı ve sözleşmesi görülmeden bu tahmine dahil
edilmemelidir.

En mantıklı sıra:

1. Baseline ve mevcut Salon haritasını veri modeline kayıpsız taşıma.
2. Tek ölçek kaynağıyla yarı boyuta geçiş.
3. Üç yeni harita ve sınırlı yeni statik artwork.
4. Cihaz üstünde level tuning.
5. Ancak haritalar kabul edildikten ve online işi gerçekten başlayacakken deterministik
   simulation/render ayrımı.

Bu sıra, içerik sonucunu erken gösterir; buna karşılık harita tanımlarını baştan
version'lı ve deterministik tuttuğu için multiplayer aşamasında level'ların yeniden
yazılmasını önler.

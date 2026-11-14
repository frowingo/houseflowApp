# Faus Switch online — backend brifingi

Tarih: 6 Kasım 2026 (robot çarpışması, start platformları, yerçekimi 2900, havadaki hız şeritleri; dikey tırmanış, sola akan son kısım, adil dönüşler (dönüş payı, robotlar arası temas yönü), lazerler yerine portallar, yavaşlatma şeritleri, 28 yüksekliğinde şeritler ve daha uzun portal atlayışları; 4'ten fazla robotlu yarışta %75 boy robotlar ve snapshot'ta `runnerScale`: `courseVersion` 7) · Hazırlayan: mobil (istemci) tarafı · Hedef: `houseflowApi` backend agent'ı

Durum: **İstemci tarafı hazır, backend geliştirmesi bekleniyor.** iOS demo modu oynanabilir;
online mod bu belgedeki sözleşmeyle konuşan bir sunucu bekliyor. Katalogda `fausSwitch`
yokken uygulama online kartını "bu evde kapalı" olarak gösterir.

Bu belge Faus Switch'in (eski adı House-Switch, kod adı `fausSwitch`) online çok oyunculu
modu için backend'de yapılacakları anlatır. Oyun: robotlar sağa doğru akan bir parkurda
koşar; oyuncu bir yüzeye basarken dokunarak yerçekimini zemin ↔ tavan arasında çevirir.

## 1. Özet

- Ortak çok oyunculu çekirdek (oturum, lobi, hazır penceresi, geri sayım, gateway, kontrol
  yetkisi, Redis koordinasyonu, kalıcılık, kurtarma) **olduğu gibi kullanılır**.
- Yeni iş: House Rockets / FauseTanks gibi bir **tick oyun modülü**:
  `internal/application/game/games/fausSwitch`. Sunucu otoriterdir: flip, çarpışma,
  elenme, bitiş sırası ve kazanan sunucudadır.
- Referans motor Swift'te hazır:
  `houseflowApp/FausCrew/shared/Sources/FausCrewCore/Games/FausSwitch/`
  - `FausSwitchModels.swift` (sabitler), `FausSwitchCourse.swift` (parkur verisi),
    `FausSwitchPhysics.swift` (adım fonksiyonu ve sıralama).
  - `Online/FausSwitchWireModels.swift` ve `Online/FausSwitchRealtime.swift` (wire sözleşmesi).
  - Bot kodu (`FausSwitchBotBrain`, `FausSwitchBotMatch`) yalnız demo içindir; online'da bot yok.
- Sözleşme örnekleri: `shared/Fixtures/fausSwitchProtocol.json` (contract `fausSwitch.v1`).
  İstemci testleri bu dosyayı okur; backend de aynı dosyayla eşitlik testi yazmalı.
- Yeni oyun anahtarı `fausSwitch`; katalog kaydı ev bazında açılır, yayına kadar kapalı başlar.

## 2. Mevcut altyapının karşıladıkları

| İhtiyaç | Durum |
|---|---|
| En az 2, en çok min(ev üyesi, 8) oyuncu | Var (`MinimumPlayers = 2`, `MaximumPlayers = 8`). Bot ile doldurma yok. |
| 2 kişi hazır → 30 sn pencere → 3 sn geri sayım → yarış | Var: `readyWindow` → `countdown` → `running`. |
| WebSocket zarfı, `controlGranted`, sıra numaraları, yeniden bağlanma, kayıt noktası | Var (House Rockets ile aynı). |
| Kalıcı sonuç | Var: modül kendi `ResultCodec`'ini tanımlar. |

## 3. Modülde yeni olanlar

1. **Lobi niyeti `fausSwitch.selectColor`.** Kontrol yetkisi gerektirmez, yalnız oturum
   `lobby` veya `readyWindow` iken ve oyuncu katılmışken kabul edilir. İstemci tarafında bu
   niyet için ortak lobi makinesine `sendLobbyIntent` eklendi; backend'de de ortak çekirdeğin
   lobi aşamasında oyun modülüne niyet iletmesi gerekebilir (karar §9).
2. **Geri sarmalı flip.** Flip, istemcinin ekranda gördüğü tick'te (`clientTick`) uygulanır;
   en fazla 250 ms (30 tick) geriye sarılır.
3. **Robotlar birbirine katıdır.** Biri diğerinin başında koşabilir, zıt yerçekimli iki robot
   tabanları birbirine değerek ilerler, arkadaki hızlı robot öndekinin arkasında kalır. Bu yüzden
   bir flip'in geri sarılması **bütün dünyayı** (tüm robotları) geri sarar ve yeniden simüle eder (§6).
4. **Start platformları.** Her robot aynı x'te kendi platformundan başlar; platformlar oyuncu
   sayısına göre parkura eklenir (§4.2, §4.3).
5. **Kalabalık yarışta küçük robotlar (v7).** Yarış 4'ten fazla robotla başlarsa bütün robotlar
   yarış boyunca %75 boydadır (§4.2.2); sunucu bunu her snapshot'ta `runnerScale` ile yollar.

## 4. Oyun kuralları (Swift referansıyla birebir)

### 4.1. Sabitler (`FausSwitchMetrics`)

| Ad | Değer |
|---|---|
| Fizik frekansı | 120 Hz sabit adım (`dt = 1/120`) |
| Dünya | yükseklik 390, görüş genişliği 844 (kamera sol kenarı) |
| Ray kalınlığı | 27,3 → zemin yüzeyi y = 27,3, tavan yüzeyi y = 362,7 |
| Robot kutusu | 27,2 × 33,6 (merkez x, y); 4'ten fazla robotlu yarışta × 0,75 = 20,4 × 25,2 (§4.2.2) |
| Başlangıç x | 380 |
| Koşu hızı | 225 birim/sn |
| Yerçekimi | 2900 birim/sn² (çekim yönüne) |
| Flip hızı | 270; mevcut dikey hızın 0,34 katı daha büyükse o (`max(270, 0,34·|vy|)`), yeni yöne |
| Boost | +110 birim/sn, 78 tick (0,65 sn); her pad oyuncu başına bir kez |
| Boşluk çıkış hızı | 312 birim/sn (ekran dışına) |
| Dikey sınır payı | 80 |
| Geri sayım | 3 sn |
| Azami yarış | 120 sn = 14.400 tick |
| Kamera | §4.2.1: `cameraTrail(tick)` (geride kalma çizgisi) |

### 4.2. Parkur (`FausSwitchCourse.race(runnerCount:)`, `courseVersion = 7`)

**Tüm kurallar parkur koordinatlarındadır:** `x` parkur boyunca alınan yol, `y` bant içindeki
yükseklik (zemin rayı altta, tavan rayı üstte). Parkur ekranda önce sağa akar, x = 9100'de
çeyrek dönüşle yukarı kıvrılır ve dikey tırmanışla devam eder; tırmanışta zemin rayı sağ duvar,
tavan rayı sol duvar olur (robotlar sağa/sola switch eder). x = 15.450'de ikinci bir sola
çeyrek dönüşle yeniden yataya geçer ve bu kez **sola** akar; bu kısımda zemin rayı üstte,
tavan rayı altta görünür (bant 180° dönmüştür). Bu bükülme (`FausSwitchTrack`)
**yalnız çizim ve kameradır**; fizik, çarpışma, boşluk, portal, boost, yavaşlatma, bitiş ve sıralama
hesapları düz bir parkurdaymış gibi aynı kalır. Sunucunun dünya koordinatı tutmasına gerek yok.

Uzunluk 20.400, bitiş çizgisi x = 20.280. Raylar boşluk yerlerinde bölünmüş katı parçalardır.
Engeller 2'li / 3'lü gruplardır (ekranı geçitlere böler). Tüm koordinatları Swift dosyasından
**aynen** alın; değerleri burada tekrar yazmıyoruz ki tek kaynak kalsın. Özet:

- Yatay kısım 12 engel grubu (x ≈ 1000 … 8840); 1. dönüş 9100 … 9720,46 boştur (engel,
  boşluk, portal, şerit yok); tırmanış 9 engel grubu (x ≈ 10.100 … 15.130); 2. dönüş
  15.450 … 16.070,46 aynı şekilde boştur; sola akan kısım 8 engel grubu (x ≈ 16.470 … 20.030).
- Boşluklar: zemin 3820–4010, tavan 4580–4770, zemin 6520–6710, tavan 7800–7990,
  zemin 12.000–12.190, tavan 13.420–13.610, zemin 17.480–17.670, tavan 19.040–19.230.
  Sensör, boşluğun iki yanından `robotWidth + 10` içeride başlar.
- Lazer yok (v6'da kaldırıldı). Yerlerinde **portallar** var (x, ray, çıkış x):
  2190 zemin → 1970; 3330 tavan → 3110; 5150 zemin → 4930; 7260 tavan → 7040;
  11.450 zemin → 11.350; 14.200 tavan → 14.100; 18.220 zemin → 18.000; 19.830 tavan → 19.610
  (yatay kısımlarda 220, tırmanışta 100 geri).
  Portal açıklığı: x ± 4, zemin portalında y = 27,3 … 67,3, tavan portalında 322,7 … 362,7
  (yükseklik 40: robot 33,6 sığar). Robot kutusu açıklıkla kesişirse karşı rayda çıkar
  (§4.4 adım 5). Çıkış x'i ile portal x'i arasında karşı ray her yerde boştur (yavaşlatma şeridi de yok).
- **Yavaşlatma şeritleri** (48 × 28; merkez x, y): raya yapışık olanlar zeminde y = 41,3,
  tavanda y = 348,7; diğerleri havada. Zemin: 1200, 4100, 7380, 12.270, 14.320, 17.750;
  tavan: 2330, 4880, 8080, 13.690, 19.310; havada: (6170, 205), (13.310, 195), (19.700, 200).
  Kimlikler bu sırayla değil, Swift'teki listeye göre (0…13) verilir; dosyadan alın.
- Hız şeritleri raylara bitişik değildir, bantta havada durur (merkez x, y; 48 × 28):
  (1660, 150), (2720, 230), (5170, 190), (6300, 140), (8520, 250), (12.900, 200), (14.850, 150), (16.700, 200), (18.670, 230). Raydan koşan robot değmez;
  genelde flip sırasında içinden geçilir.
- Start platformları: yarıştaki robot sayısı `n` (1…8) için `FausSwitchStartGrid.lanes(count: n)`
  koltuk başına bir katı ekler (tür `platform`; katı listesine `standard`'ın katılarından sonra,
  koltuk sırasıyla eklenir). Her platform x = 340 … 500 (start çizgisinin 40 gerisinden 120
  ilerisine), kalınlık 6. Hesap **onda bir birim cinsinden tam sayılarla** yapılır (taban
  bölme), sonra 10'a bölünür:
  - `floor = 273`, `band = 3354`, `height = 336`, `thickness = 60`, `halfBlock = 198`.
  - Koltuk `s`: çiftse `gravity = down`, `lane = s / 2`; tekse `gravity = up`,
    `lane = n − 1 − s / 2` (alttan yukarı 0, 2, 4, 6, sonra 7, 5, 3, 1).
  - `center = floor + band · (2·lane + 1) / (2·n)`.
  - `down`: `bottom = center − 198`, robot merkezi `bottom + 60 + 168`.
    `up`: `bottom = center + 198 − 60`, robot merkezi `bottom − 168`.
  - Platform `minY = bottom / 10`, `maxY = (bottom + 60) / 10`; robot `y = merkez / 10`.
  - Örnek n = 2: platformlar 91,3–97,3 ve 292,6–298,6; robotlar y = 114,1 (zemin tarafı)
    ve 275,8 (tavan tarafı). Swift testleri 1…8 için tüm değerleri kontrol eder.
  - n > 4 iken `height = round(33,6 · runnerScale · 10) = 252`, `halfBlock = 156` (§4.2.2);
    robot merkezi `bottom + 60 + 126` / `bottom − 126`.

#### 4.2.2. Kalabalık yarış: robot boyu (`FausSwitchStartGrid.runnerScale`, v7)

8 robotta start bandı koltuk başına yalnız 41,9 yüksekliğindedir; tam boy robot (33,6) ile
platformu (6) ancak sığar. Bu yüzden:

- `n` = yarış başlarken (geri sayıma girerken) yarıştaki robot sayısı;
  `runnerScale = n > 4 ? 0,75 : 1`. Yarış boyunca sabittir (çıkan/elenen olsa da), bütün
  robotlar aynı ölçektedir. Snapshot'ta `runnerScale` alanı olarak her zaman yazılır.
- Ölçeklenen: robot kutusu (`27,2·s × 33,6·s`, merkez x, y), destek probu (`width = 27,2·s`,
  `inset = min(7, 0,2·width)`, ayak kenarı `y ± 33,6·s/2`) ve start platformları (§4.2).
- Ölçeklenmeyen: portal çıkışı (`exitY` yüzeyden ± 16,8; küçük robot 4,2 havada çıkıp düşer),
  `landingX` içindeki 13,6, boşluk sensörü payı (`27,2 + 10`), hız, yerçekimi, kamera, sınırlar.
- Go'da ölçekli boyut **çalışma anında** `float64` çarpımıyla hesaplanmalı (`width := w * s`).
  Untyped sabit katlama (`27.2 * 0.75`) Swift'ten 1 ulp farklı olabilir: `33,6 · 0,75`
  çalışma anında `25.200000000000003`'tür.
- Kontrol değerleri (n = 8, s = 0,75; koltuk 0…7 doğuş y): 51,2 · 338,7 · 93,1 · 296,8 ·
  135,1 · 254,8 · 177,0 · 212,9. Fixture'da `crowdedCountdown` örneği bu yarışın tick 0
  snapshot'ıdır; Swift testi `testCrowdedStartsMatchTheBackendTables` n = 5 ve 8'i kontrol eder.

#### 4.2.1. Kamera ve geride kalma çizgisi (`FausSwitchCamera`)

Kamera, start çizgisinden koşu hızıyla ilerleyen bir odak noktasını izler; geride kalma
çizgisi odağın belli bir mesafe gerisidir. Yatayda (sağa da sola da) görüş odağın 380
gerisinden başlar; tırmanışta ekran yatay olduğu için kamera 0,75'e uzaklaşır ve görüş odağın
yalnız 140 gerisinden başlar. Her dönüşte bu mesafe yumuşakça bir değerden diğerine geçer:

- `focus(tick) = min(380 + 225 · tick / 120, length − 464)`; son kısım yatay olduğu için
  `464 = 844 − 380` (odağın önündeki görüş; bitiş çizgisi ekranda kalır). Standart parkurda
  üst sınır 19.936.
- Dönüş `i` için (`start₁ = 9100`, `start₂ = 15.450`): `uᵢ = clamp((focus − startᵢ) / L, 0, 1)`,
  `L = 395 · π / 2 ≈ 620,4646` (dönüşün merkez hattı uzunluğu), `blendᵢ = uᵢ · uᵢ · (3 − 2uᵢ)`.
- `behind = 380`, sonra sırayla `behind += (140 − behind) · blend₁` ve
  `behind += (380 − behind) · blend₂`.
- `cameraTrail(tick) = focus(tick) − behind`.

Yani yatay kısımlarda `cameraTrail = focus − 380` (ilk kısımda `225 · tick / 120`, eskisiyle
aynı), tırmanışta `focus − 140`. Çizgi hiç geri gitmez: 1. dönüşte kısa süre koşu hızından
hızlı ilerler, 2. dönüşte yavaşlar. Değerleri Swift'teki `FausSwitchCamera.focus/behind/ahead`
ile birebir aynı sırada hesaplayın (testler `FausSwitchTrackTests`).

**Dönüş payı (adillik, `FausSwitchCamera.turnCarry`).** Pay dönüşte daraldığı için, yatayda
bol payı olan robot yalnız dönüş yüzünden elenmesin diye her robot dönüşte kullandığı pay
oranını korur. `ahead` de `behind` gibi harmanlanır: yatay 464, dikey `390 / 0,75 − 140 = 380`
(`ahead = 464`, sonra `ahead += (380 − ahead) · blend₁`, `ahead += (464 − ahead) · blend₂`).
Bir adımda (`tick → tick + 1`), robotun adım öncesi kutusuyla:

- `f₀ = focus(tick)`, `f₁ = focus(tick + 1)`, `g = f₀ − body.maxX`.
- `g > 0` ise `carry = g · (1 − behind(f₁) / behind(f₀))`, değilse
  `carry = g · (1 − ahead(f₁) / ahead(f₀))`.

Düz kısımlarda iki oran tam 1'dir, `carry` tam 0 olur. 1. dönüşte geride kalan robot biraz
hızlanır (380'in 300'ü gerideyse tırmanışa 140'ın 110,5'i geride girer), 2. dönüşte aynı
oranda geri kalır; iki dönüşün toplam etkisi sıfırdır. Odağın önündeki robot (boost sonrası)
görüş payının oranını korur. Dönüşte ve dönüş kenarlarında engel olmadığından robot yalnız
başka bir robota takılabilir.

**Kamera (yalnız çizim).** Görüş her an bandın izden `viewAhead`'e kadar olan kısmını içine
alır (sığdıracak kadar uzaklaşır, kısmın zoom'undan fazla yakınlaşmaz; boş ekran koşu yönünün
önüne verilir). Dönüşlerde `viewAhead` 200'e iner. Böylece yarışta olan her robot ekrandadır.
Dönüşte iz çizgisi ekranı çapraz keser; gerisi istemcide karartılır. Sunucu kamerayı
hesaplamaz.

### 4.3. Başlangıç

Koltuk sırası oturumdaki katılım sırasıdır ve yarış boyunca değişmez. Her robot x = 380'de
kendi platformunda doğar (§4.2): çift koltuklar platformun üstünde `down`, tek koltuklar
altında `up`; `velocityY = 0` (fixture'daki A ve B: y = 114,1 ve 275,8). Snapshot'taki
`runners[]` **koltuk sırasıyla** yazılmalıdır; istemci platformları ve adım sırasını buradan
çıkarır.

### 4.4. Adım sırası (`FausSwitchPhysics.step(_ runners:tick:course:)`)

Her tick önce o tick'in flip'leri uygulanır, sonra robotlar **koltuk sırasıyla tek tek**
adımlanır. Her robot adımlanırken diğer koşan robotlar o anki yerlerindedir (kendisinden
önceki koltuklar bu tick'te zaten hareket etmiş, sonrakiler henüz etmemiş). Bitiren veya
elenen robot çarpışmaya katılmaz (adımı içinde bitiren/elenen robot o andan itibaren de).

`tick → next = tick + 1`; zaman `t = next / 120`.

1. Hız: `speed = 225 + (tick < boostedUntilTick ? 110 : 0) − (tick < slowedUntilTick ? 100 : 0)`.
2. Yerçekimi: `vy += gravity.sign · 2900 · dt` (`down` için sign = −1, `up` için +1).
3. Hareket: `x += speed · dt + carry`, `y += vy · dt` (`carry` §4.2.1, adım öncesi kutuyla;
   önce `carry` hesaplanır, sonra `vy` güncellenir).
4. Temas çözümü (en fazla 4 tur; bir turda hiçbir itme olmazsa biter). Her turda önce diğer
   koşan robotların kutuları (koltuk sırasıyla), sonra parkur katıları: robot kesiştiği her
   kutudan **en az nüfuz eksenine** göre dışarı itilir (eşitlikte dikey; kesişme kesindir,
   1e-9'dan küçük nüfuz yok sayılır). **Başka bir robota karşı** önce geldiği yön bakılır:
   adım öncesi kutu (`before`, 3. adımdan önceki kutu) o robotun kutusundan dikeyde ayrıysa
   (`before.maxY ≤ other.minY + 1e-9` veya `before.minY ≥ other.maxY − 1e-9`) ve yatayda
   ayrı değilse itme dikeydir; yatayda ayrı, dikeyde ayrı değilse yataydır; ikisi de aynıysa
   en az nüfuz kuralı geçerlidir. Parkur katılarında yalnız en az nüfuz kuralı vardır. Dikey itme harekete karşıysa `vy = 0`; yatay itme
   yalnız ilerlemeyi keser. Yalnız adımlanan robot itilir, diğerine dokunulmaz (itme/momentum
   aktarımı yok). Ön/yan temas öldürmez.
4b. Portal: robot kutusu bir portalın açıklığıyla kesişiyorsa (kimlik sırasıyla ilk olan)
   `x = min(max(exitX, cameraTrail(next) + 13,6 + 24), portal.x − 4 − 13,6 − 1)`,
   `y` = karşı rayın yüzeyi ± 16,8, `gravity` = karşı yön, `vy = 0`; ardından temas çözümü
   (4. adım) yeni kutuyla, `before` = yeni kutu olarak bir kez daha çalışır. Portal tek başına
   eleme yapmaz: çıkış izin gerisindeyse robot izin hemen önüne konur.
5. `supported` = destek probu bir katıya **veya başka bir koşan robotun kutusuna** değiyor mu
   (çözümden sonra).
6. Boşluk: desteksizse ve çekim yönündeki raydaki bir boşluğun sensörüyle kesişiyorsa
   `vy = gravity.sign · max(|vy|, 312)` (robot ekran dışına düşer; 8. adımda elenir).
7. Boost: robot kutusu kullanılmamış bir pad ile kesişiyorsa (destek ya da yerçekimi yönü
   aranmaz) pad kullanılmış sayılır ve `boostedUntilTick = max(boostedUntilTick, next + 78)`.
8. Yavaşlatma: robot kutusu kullanılmamış bir yavaşlatma şeridiyle kesişiyorsa şerit kullanılmış
   sayılır ve `slowedUntilTick = max(slowedUntilTick, next + 96)`.
9. Bitiş: `body.maxX ≥ finishX − 8` → `finished`, `finishedAtTick = next`, `vy = 0`.
10. Dikey sınır: `y < −80` veya `y > 470` → `boundary`.
11. Geride kalma: `body.maxX ≤ cameraTrail(next)` → `leftBehind` (§4.2.1).

Destek probu: robotun (ölçekli, §4.2.2) ayak kenarının ±0,5 dışında, yatayda `min(7, 0,2·genişlik)` içeriden
ince bir kutu; bir katıyla ya da başka bir koşan robotla kesişiyorsa robot desteklidir
(başka bir robotun başında duran ya da tabanı başka bir robotun tabanına değen robot da flip
yapabilir). **Flip yalnız destekliyken** kabul edilir; değilse sessizce yok sayılır (istemci zaten yalnız destekliyken gönderir, ama
gecikme yüzünden sunucuda desteksiz düşebilir — bu durumda hata değil, no-op).

### 4.5. Sıralama (`FausSwitchRanking.ranks`)

1. Bitirenler: `finishedAtTick` küçük olan önde.
2. Koşmaya devam edenler: x büyük olan önde.
3. Elenenler: daha geç elenen önde.
Eşitler aynı sırayı paylaşır. `winnerId` = 1. sıradaki tek bitiren; kimse bitirmediyse `null`.

### 4.6. Bitiş koşulları

- `raceComplete`: koşan robot kalmadı.
- `timeLimit`: 14.400 tick doldu.
- Diğerleri ortak çekirdekten: `insufficientPlayers`, `cancelledByUser`, `sessionExpired`,
  `recoveryFailed`, `coordinationUnavailable`, `runtimeOverloaded`.

### 4.7. Bağlantı kopması

Bağlantısı kopan robot **girdisiz koşmaya devam eder** (`connected = false`); yeniden bağlanma
payı 10 sn. Oyuncu yarıştan açıkça çıkarsa robot `forfeit`, üyeliği düşerse
`membershipRevoked` ile elenir. Eleme nedenleri yalnız `boundary`, `leftBehind`, `forfeit`,
`membershipRevoked`'dır; `laser` v6'da kaldırıldı (istemci artık çözmez).

## 5. Renk seçimi

- Renkler: `plum, forest, ocean, lavender, olive, bronze, graphite, berry`.
- `fausSwitch.selectColor { color }` lobide alınır. Her renk için **ilk talep** kazanır;
  sonraki talepler `accepted` alır ama rengi değiştirmez.
- Yarış başlarken renk talep etmemiş ya da çakışan oyunculara koltuk sırasına göre ilk boş
  renk atanır. Snapshot'taki `color` her zaman nihai renktir; istemci onu çizer.
- Yarış başladıktan sonra `selectColor` → `fausSwitch.error.not_in_lobby`.

## 6. Sözleşme: `fausSwitch.v1`

Tam örnekler fixture'da. Protokol sürümü 2 (ortak).

### İstemciden

| Tip | Payload | Not |
|---|---|---|
| `realtime.join` / `realtime.ready` / `realtime.resync` / `realtime.ping` | ortak | |
| `fausSwitch.selectColor` | `{ color }` | kontrol yetkisi yok, yalnız lobi |
| `fausSwitch.flip` | `{ controlGeneration, inputSequence, clientTick }` | `inputSequence` oyuncu başına 1'den artar; yeniden gönderimde aynı `messageId` ve aynı sıra |

Flip kuralları:
- `controlGeneration` geçerli değilse → `fausSwitch.error.stale_control` (istemci kontrolü bırakır).
- `inputSequence ≤ lastProcessedInputSequence` → yinelenen; tekrar uygulanmaz, yine `accepted`.
- `clientTick` şu anki tick'ten > 30 eskiyse `now − 30`'a kırpılır; gelecekteyse `now`'a.
- Uygulama: **tüm dünya** (bütün robotlar) `clientTick`'teki kayıtlı durumuna geri sarılır,
  bu flip ve o aralıkta kabul edilmiş diğer tüm flip'ler kendi tick'lerinde yeniden uygulanarak
  şu anki tick'e kadar §4.4'e göre yeniden simüle edilir. Robotlar birbirini etkilediği için
  bir oyuncunun geç gelen flip'i başkalarının konumunu da değiştirebilir. Bunun için son 30
  tick'in dünya durumu ve tick'e göre kabul edilmiş flip listesi tutulmalı. Destek kontrolü
  geri sarılmış dünyada yapılır.
- Bitiren/elenen robot → `fausSwitch.error.runner_finished`; yarış yoksa `not_running`.
- Girdi hızı en fazla 20/sn; fazlası `realtime.error.rate_limited`.

### Sunucudan

| Tip | Ne zaman |
|---|---|
| `realtime.welcome` | `settings` (fixture), `courseVersion: 7` |
| `realtime.sessionSnapshot` | lobi değişince (ortak) |
| `fausSwitch.controlGranted` | ortak kontrol mekanizması |
| `fausSwitch.snapshot` | 20 Hz; geri sayımda da (tick 0) |
| `realtime.accepted` / `realtime.rejected` | her komut için |
| `fausSwitch.result` | kalıcı sonuç yazılınca |

Snapshot alanları: `sessionId, gameKey, runtimeEpoch, stateSequence, tick, elapsedSeconds,
phase, courseVersion, runnerScale, countdownEndsAt, winnerId, runners[]`. `runnerScale` 1 ya da
0,75'tir (§4.2.2); başka değer istemcide `invalidResponse` olur. Her runner:
`playerId, displayName, color, x, y, velocityY, gravity, boostedUntilTick, usedBoosts,
slowedUntilTick, usedSlows, status, finishedAtTick, eliminatedAtTick, eliminationReason, connected,
lastProcessedInputSequence, controlGeneration`. Boş değerler `null` olarak **yazılmalı**
(istemci alan yokluğunu hata sayar). `controlGeneration` yalnız izleyen bağlantının kendi
robotunda dolu.

İstemci tahmini: istemci tüm robotları son snapshot'tan şu anki tick'e kadar aynı fizikle
birlikte ilerletir (koltuk sırası = `runners[]` sırası); kendi onaylanmamış flip'lerini üzerine
uygular. Diğer oyuncuların flip'leri yalnız sonraki snapshot'la gelir. Bu yüzden snapshot'taki fizik
alanları (`velocityY`, `boostedUntilTick`, `usedBoosts`, `slowedUntilTick`, `usedSlows`) eksiksiz ve tutarlı olmalı.

### HTTP

- `PUT /api/v1/game/fausSwitch/session` `{ houseId }` → oturum (ortak şema).
- Sonuç okuma: ortak sonuç uç noktası, `gameKey = fausSwitch` (fixture `http.result`).
- Katalog kaydı `settings` alanını taşımalı (fixture `settings`); `settings` yoksa istemci
  oyunu katalogda görmez.

### Hata kodları

`fausSwitch.error.invalid_input`, `control_unavailable`, `stale_control`, `runner_finished`,
`not_running`, `not_in_lobby`, `result_not_found` ve ortak `realtime.error.*`.

## 7. Kalıcı sonuç

`fausSwitch.result`: `sessionId, houseId, gameKey, protocolVersion, courseVersion, status
(completed | cancelled), endReason, winnerId, startedAt, endedAt, durationSeconds, players[]`.
Her oyuncu: `playerId, rank, finishedAtTick, eliminatedAtTick, eliminationReason, distance`
(`distance` = robotun son **dünya x'i**, başlangıç çizgisinden çıkarılmadan; fixture'daki gibi). `completed` ise
`startedAt` dolu ve `endReason ∈ {raceComplete, timeLimit}`; `cancelled` ise bu ikisi dışında.

## 8. Test ve eşitlik beklentileri

- Go fizik adımı Swift ile aynı sırada ve aynı sabitlerle; parkur verisi birebir.
- Eşitlik fixture'ı: `shared/Fixtures/fausSwitchSimulation.json` (Swift motorundan, courseVersion 7).
  Senaryolar `duel` (2), `four` (4), `crowdedFive` (5, ölçek 0,75) ve `crowdedEight` (8, ölçek 0,75);
  her biri bütün robotlar durana kadar süren tam bir yarış. Biçim:
  `{"courseVersion", "scenarios": [{"name", "runnerCount", "flips": [{"tick", "seat"}],
  "checkpoints": [{"tick", "runners": [{"x", "y", "velocityY", "gravity", "status",
  "finishedAtTick", "eliminatedAtTick", "eliminationReason"}]}]}]}`; opsiyoneller `null`,
  `Double`'lar kısaltmasız, anahtarlar sıralı. `finishedAtTick` yalnız `finished`, eleme alanları
  yalnız `crashed` robotta dolu. Senaryo `lanes(count:runnerScale:)` ile başlar; her tick'te o
  tick'in flip'leri liste sırasıyla uygulanır, sonra adım atılır. Tick `T`'deki checkpoint, `T`'ye
  ulaştıran adımdan sonraki ve `T`'nin flip'lerinden önceki durumdur. Flip'ler denemedir:
  havadayken yapılan (desteksiz) flip listede durur ve hiçbir şeyi değiştirmez. Checkpoint'ler
  tick 0'da, her 30 tick'te ve bir robotun durumu değiştiği her tick'te. Her senaryoda en az bir
  portal fırlatması, bir desteksiz flip, bir robotun başka robot üstünde durması, bir bitiş ve bir
  eleme var; dosyanın tamamında `boundary` ve `leftBehind` elemeleri ikisi de geçiyor.
  İstemci testi: `FausSwitchSimulationFixtureTests`.
- Protokol fixture'ı (`fausSwitchProtocol.json`) üzerinden encode/decode testleri.
- Geri sarma: 250 ms gecikmeli flip'in, gecikmesiz flip ile aynı sonuca vardığı test
  (iki robot üst üste dururken alttakinin geç flip'i dahil).
- Çarpışma: üst üste duran, tabanları birbirine değen ve arka arkaya koşan robot senaryoları;
  hiçbir tick'te iki koşan robotun kutusunun iç içe geçmediği tam yarış testi
  (Swift karşılığı `FausSwitchCollisionTests`).
- Start platformları: n = 1…8 için platform ve doğuş değerlerinin Swift ile birebir aynı olduğu test
  (n > 4'te ölçek 0,75; `crowdedCountdown` fixture'ı).
- Ölçek: 4 kişilik yarış 1, 5 kişilik 0,75 ile başlar; geri sayımda biri çıksa da ölçek değişmez.
- 8 robotlu tam yarışta hiçbir tick'te kutular iç içe geçmez; 8 oyunculu geri sarma benchmark'ı.
- Aynı `inputSequence` ile yeniden gönderilen flip'in iki kez uygulanmadığı test.

## 9. Backend agent'ın karar vereceği noktalar

- Lobi niyetinin (`selectColor`) ortak çekirdekte nasıl yönlendirileceği.
- Renk taleplerinin oturum dokümanında mı, oyun modülünün lobi durumunda mı tutulacağı
  (lobi `sessionSnapshot`'ına renk eklemek isterseniz istemci kolayca okuyabilir; şu an
  istemci başkalarının rengini ilk yarış snapshot'ında görür).
- Simülasyon eşitlik fixture'ının kim tarafından üretileceği.
- Snapshot boyutu: 8 robotta ~2 KB; gerekirse delta, ama ilk sürümde tam snapshot yeterli.

## 10. İstemci tarafında yapılanlar

- FausCrewCore: deterministik fizik, parkur, demo botları, online motor
  (`FausSwitchOnlineEngine`), wire modelleri, copy anahtarları ve testleri.
- iOS: demo/online mod seçimi, renk seçimi, robot karakter, yeni açık palet ve doku,
  online oda / yarış / sonuç / rövanş ekranları, `GameOnlineHost` bağlantısı.
- Android: henüz yok; aynı Core motoru köprüyle kullanılabilir.

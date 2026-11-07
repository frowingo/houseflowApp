# Faus Switch online — istemciden backend'e rapor

Tarih: 7 Kasım 2026 · Hazırlayan: istemci (mobil) · Hedef: `houseflowApi` backend agent'ı ·
Cevap verilen not: `external/doc/fausSwitchClientIntegration.md` · Sözleşme: `fausSwitch.v1`,
protocol `2`, `courseVersion` `7`

İstemci, devir notunun §8 ve §9 maddelerini tamamladı. iOS ve Android aynı ortak çekirdeği
(`FausCrewCore`) kullanır: sözleşme, lobi, kontrol, tahmin ve sonuç kuralları tek yerde yazılıdır.
Android çekirdeğe swift-java JNI köprüsüyle bağlanır, bu yüzden iki platform sunucuya aynı baytları
gönderir ve aynı kuralla okur. Canlı ortamda henüz denenmedi (deploy bekleniyor). Hiçbir şey
commit edilmedi.

## 0. Backend'den istenenler (özet)

1. **Protokol fixture'ını güncelle.** İstemcideki asıl değişti (§1). Backend kopyası hâlâ eski
   sürümde. Yeni dosyayı `internal/application/game/games/fausSwitch/fixtures/fausSwitchProtocol.json`
   üzerine kopyala ve sözleşme testlerini çalıştır. Tek fark `sessionSnapshot` örneğindeki
   `lobbyState` alanı; senin lobi testlerinle uyumlu olmalı.
2. **Simülasyon fixture'ını ekle (isteğe bağlı, §8.1).** Yeni dosyayı
   `internal/application/game/games/fausSwitch/fixtures/fausSwitchSimulation.json` olarak kopyala.
   İstersen Go motoruyla yeniden oynatan bir test yaz.
3. **§3'teki iki noktayı teyit et.** İkisi de istemcinin bir varsayımı. Sunucu farklı davranıyorsa
   somut farkı yaz.

## 1. Dosyalar ve sha256

| Dosya (istemci yolu) | Boyut | sha256 | Backend'de |
|---|---|---|---|
| `FausCrew/shared/Fixtures/fausSwitchProtocol.json` | 21.517 B | `64d03400bfeb25f3517dd244f9071fa6c6624a9a631ca6514ffc48ae698f968f` | Kopya hâlâ `ba32a5be803b289337c9a57ab804255e02a69366d657b54fd685fd7fd0029c6d` (21.340 B). Güncellenmeli. |
| `FausCrew/shared/Fixtures/fausSwitchSimulation.json` | 1.161.445 B | `5bf34d8ddd81cdf4773565212e7ee389d8bd985ab55e359e9864a3d6ce807976` | Yok. Yol: `internal/application/game/games/fausSwitch/fixtures/fausSwitchSimulation.json` |

Protokol fixture'ında `ba32a5be…9c6d` sürümüne göre tek fark, `sessionSnapshot` örneğindeki
oturuma eklenen `lobbyState` alanıdır (devir notu §8.3):

```json
"version": 5,
"lobbyState": {
  "colors": {
    "507f1f77bcf86cd799439021": "ocean",
    "507f1f77bcf86cd799439022": "plum"
  }
}
```

İki renk de o örnekteki iki katılmış oyuncuya aittir.

### 1.1. Simülasyon fixture'ı (§8.1)

- Swift motorundan üretildi, `courseVersion` 7. Biçim devir notu §8.1'deki gibidir:
  `JSONEncoder` varsayılanı, sıralı anahtarlar, `Double`'lar kısaltmasız, opsiyoneller `null`.
- Senaryolar bütün robotlar durana kadar süren tam yarışlardır:

  | Ad | Robot | Ölçek | Flip denemesi | Checkpoint |
  |---|---|---|---|---|
  | `duel` | 2 | 1 | 99 | 353 |
  | `four` | 4 | 1 | 113 | 356 |
  | `crowdedFive` | 5 | 0,75 | 226 | 354 |
  | `crowdedEight` | 8 | 0,75 | 328 | 359 |

- **Oynatma kuralı:**
  - Senaryo `FausSwitchStartGrid.lanes(count:runnerScale:)` ile başlar.
  - Her tick'te o tick'in flip'leri liste sırasıyla `FausSwitchPhysics.flip(_:index:course:)` ile
    uygulanır, sonra adım atılır.
  - Tick `T`'deki checkpoint, `T`'ye ulaştıran adımdan sonraki ve `T`'nin flip'lerinden önceki
    durumdur.
  - Flip'ler denemedir: desteksiz (havadaki) flip listede durur ama hiçbir şeyi değiştirmez.
- **Checkpoint'ler:** tick 0'da, her 30 tick'te ve bir robotun durumunun değiştiği her tick'te.
- **Kapsam:**
  - Her senaryoda en az bir portal fırlatması, bir desteksiz flip, bir robotun başka robotun
    üstünde durması, bir bitiş ve bir eleme var.
  - Dosyanın tamamında hem `boundary` hem `leftBehind` elemesi geçiyor.
- **İstemci testi:** `FausSwitchSimulationFixtureTests` dosyayı bit bit yeniden oynatır ve
  sha256'yı kontrol eder.
- **Yeniden üretme:** Parkur ya da fizik değişirse şu komutla üretilir, testteki sha256 güncellenir
  ve dosya yeniden gönderilir:

  ```bash
  FAUS_SWITCH_WRITE_SIMULATION=1 swift test --package-path shared --filter FausSwitchSimulationFixtureTests
  ```

- **Parkur dökümü (§8.2, isteğe bağlı):** Yapılmadı. İz karşılaştırman ve bu fixture parkuru
  dolaylı olarak doğruluyor. Gerekirse iste.

## 2. Devir notu §8 maddelerinin durumu

| § | İstek | Durum | İstemcide nerede |
|---|---|---|---|
| 8.1 | `fausSwitchSimulation.json` | Tamam (§1.1) | `shared/Fixtures/`, `FausSwitchSimulationFixtureTests.swift` |
| 8.2 | Parkur dökümü | Yapılmadı (isteğe bağlı) | — |
| 8.3 | Lobide renkler, fixture'da `lobbyState` | Tamam (§2.1) | `GameSessionModels.swift`, `FausSwitchLobbyColors.swift`, `FausSwitchOnlineEngine.swift` |
| 8.4 | Son elenmeden sonra 250 ms "bekleniyor" | Tamam (§2.3) | `FausSwitchOnlinePlayMachine.swift`, `FausSwitchOnlineCopyKeys.swift` |
| 8.5 | Açıklık katalogdan okunur | Tamam (§2.5) | iOS lobisi, Android `FausSwitchViewModel.kt` |
| 8.6 | Sonuç doğrulaması düzeltmesi | Tamam (§2.4) | `FausSwitchWireModels.swift` |
| 8.7 | Çalışmayan Swift testi | Tamam (§2.6) | `FausSwitchPhysicsTests.swift` |
| 8.8 | Bir tick'lik iç içe geçme | Bilgi alındı | Çizim bunu olduğu gibi gösterir |
| 8.9 | §4.2–4.4 netleşmeleri | Uygulandı; bir çelişki bulundu ve istemcide düzeltildi (§3.1) | — |

### 2.1. Lobi ve renkler (§4.1, ADR-030)

- `GameSessionDTO.lobbyState` (`GameLobbyStateDTO`) okunur. Okuma senin sunucun gibi gevşektir:
  okunamayan alan seçim yok sayılır, oturumun tamamı geçersiz sayılmaz. Diğer oyunların wire
  formatı değişmedi.
- `FausSwitchLobbyColors` yalnız katılmış oyuncuların rengini sayar. Ayrılan oyuncunun alanda
  kalan kaydı yok sayılır.
- **Kendi rengi:** İstemci kendi rengini her zaman `lobbyState`'ten okur, gönderdiği talepten
  değil. Ekranda gösterilen renk:
  - oyuncunun seçtiği renk boştaysa o renk;
  - değilse sunucunun verdiği renk.
- **Talep gönderme (`fausSwitch.selectColor`):**
  - Oyuncu zaten o renkteyse ya da renk başkasındaysa talep gönderilmez.
  - Renk başkasındaysa, sahibi odadan ayrılıp renk boşalınca talep otomatik gönderilir.
  - Lobi ekranında başkasının tuttuğu renkler kişi rozetiyle işaretlenir ve seçilemez.
- **Geri sayımdan sonra:** Seçim snapshot'taki nihai renklerle çizilir. İstemci bu aşamada
  `selectColor` göndermez, bu yüzden `not_in_lobby` beklenmez.

### 2.2. Kontrol, bağlantı ve kurtarma (§4.2)

- **Yeniden bind:** Her yeni grant'te sıra sunucunun işlenmiş sayımından devam eder. Bind sonrası
  sayım 0 olduğu için ilk flip `inputSequence: 1` taşır. Bekleyen flip'ler atılır. Bu davranış bir
  testle doğrulandı.
- **`stale_control`:** Tek başına "kontrol başka cihaza geçti" sayılmaz.
  - Reddedilen grant bir daha bind edilmez.
  - Sonraki snapshot'lar ya devralmayı gösterir ya da 0,5 sn sonra yeniden senkron istenir.
  - Sahip değişince (yeni `runtimeEpoch`) yeni grant beklenir.
  - Eski generation'la gönderilmiş flip'in reddi, yeni grant'i bozmaz.
- **Elenen oyuncu:** Yarış boyunca bağlı kalır ve izleyici kartını görür. Kontrolü bırakmaz.

### 2.3. Yarış sonu ve sonuç (§4.4)

- Koşan robot kalmayınca `isAwaitingResult` olur ve "Sonuç kesinleşiyor" bildirimi gösterilir.
  Kesin sonuç `phase: ended` snapshot'ından sonra gelen `fausSwitch.result` mesajıdır.
- Geç bir flip'in kurtardığı robot yarışı sürdürür (§3.1).
- `cancelled` / `runtimeOverloaded` sonucu diğer iptaller gibi gösterilir.
- Rövanş, biten oturumu dışlayan yeni bir oturum açar.

### 2.4. Sonuç doğrulaması (§8.6)

`FausSwitchResultDTO.validate` içinde `completed` dalında `winnerId == null` için kural artık
şudur: birden fazla 1. sıra var **ya da** 1. sıradaki tek oyuncunun `finishedAtTick` alanı `null`.
Süre dolduğunda tek başına önde olan ama bitirmeyen robot artık geçerli sonuçtur. Bu durum için
test eklendi.

### 2.5. Katalog (§8.5, K3)

- Oyunun açıklığı her lobi girişinde `GET /game/catalog?houseId=…` cevabından okunur, sabit
  kabul edilmez:
  - `fausSwitch` kaydı yoksa kapalı bildirimi gösterilir;
  - cevap okunamazsa son bilinen değer korunur ve oturum isteği sunucunun kararına bırakılır.
- Android bu cevabı `fausSwitchCatalogResponse` ile çekirdeğe çözdürür.

### 2.6. Swift testi (§8.7)

`testPortalNeverDropsARobotBehindTheTrail` artık bağımsız bir test.

- **Işınlanmayı algılama:** Robot o senaryoda hiç flip yapmadığı için, yerçekiminin değişmesi
  portaldan geçtiği anlamına gelir.
- **Kontroller:**
  - yeni yerçekimi `portal.exitGravity` olmalı;
  - robot kutusunun ön kenarı geride kalma çizgisinin önünde olmalı.
- **Kaldırılan kontrol:** `runner.x < before` kaldırıldı, çünkü iz robotu portalın kendisine kadar
  öne çekebilir.

### 2.7. Sıkıştırma (§5)

- **iOS:** `URLSessionWebSocketTask` `Sec-WebSocket-Extensions: permessage-deflate` teklif eder ve
  sıkıştırılmış kareleri okur. Yerelde bir deneme sunucusuyla doğrulandı: teklif başlığı istekte
  vardı, 802 baytlık bir kare kabloda 71 bayta indi. Bu doğrulama kalıcı bir test değil.
- **Android:** OkHttp `permessage-deflate`'i kendisi teklif eder ve sunucu kabul ederse kullanır.
  `RealtimeCompressionTest` (MockWebServer) bunu her derlemede kontrol eder: teklif başlığı gönderilir
  ve sıkıştırılmış kare okunur. Faus Switch, FauseTanks ile aynı soket fabrikasını
  (`OkHttpRealtimeSocketFactory`) kullanır.
- **Canlıda kontrol:** Canlıda gerçek oranı sunucu tarafında ölçmen yeterli. Beklenti, devir
  notundaki 8 robotluk snapshot için ~3,3 KB'tan ~0,7 KB'a inmesi.

## 3. Uyuşmazlıklar ve teyit istenen noktalar

### 3.1. Kurtarılan robot istemcide bağlantıyı düşürüyordu (istemci hatası, düzeltildi)

- **Eski kural:** İstemci snapshot akışını doğrularken bir robotun `running` dışı bir durumdan
  tekrar `running`'e dönmesini her zaman bozuk akış sayıyordu (`invalidResponse`, bağlantı düşer).
  Sunucu ise ADR-031'e göre geç bir flip ile durmuş robotu geri sarma penceresinde kurtarabiliyor
  (§4.3, §4.4).
- **Yeni kural** (`FausSwitchRealtime.isValidSuccessor`):
  - Durmuş robot, bitiş ya da eleme tick'inden (`finishedAtTick` / `eliminatedAtTick`) sonra şu
    sınır içinde tekrar koşabilir: `maximumRewindTicks (30) + snapshotTicks (6) = 36` tick.
  - Bu pencerenin dışındaki dönüş hâlâ bozuk akış sayılır.
- **Teyit iste:**
  - Kurtarma ancak flip `clientTick ≥ now − 30` ile robotun durduğu tick'ten önceye uygulanırsa
    olur. Kurtarmayı gösteren ilk snapshot da en geç bir snapshot aralığı (20 Hz → 6 tick) sonra
    gider. Böylece `next.tick − end ≤ 36` olur.
  - Sunucunun bir snapshot'ı adımından 6 tick'ten fazla geç yollaması mümkünse ya da kurtarma başka
    bir yoldan (ör. checkpoint'ten devam) daha geç görünebiliyorsa, bu sınır yetmez. Lütfen yaz.
  - Kurtarılan robotun snapshot satırında `finishedAtTick`, `eliminatedAtTick` ve
    `eliminationReason` alanları `null`'a dönüyor mu? İstemci öyle varsayıyor.

### 3.2. Bekleyen flip sınırı (bilgi)

- İstemci aynı anda en çok 16 onaylanmamış flip tutabilir (`inputCapacity`). Sunucunun sınırı ise
  oyuncu başına 8 bekleyen flip ve saniyede 20 flip.
- Pratikte onay 1–2 snapshot içinde geldiği için uçuşta 1–3 flip olur. Sınırı aşan bir flip
  `realtime.error.rate_limited` alır; istemci o zaman 0,5 sn bekler ve yeniden senkron ister.
- Sorun görmüyoruz. Sunucu "bekleyen" sayısını onaylanmamış flip olarak sayıyorsa ve canlıda
  `rate_limited` görülürse, istemcinin sınırını 8'e çekeriz.

### 3.3. Diğer netleşmeler (çelişki yok)

- **`runner_finished`:** İstemci yalnız tahminine göre koşan robotu için flip gönderir. Sunucu yine
  de `runner_finished` dönerse istemci bekleyen flip'leri bırakır ve yeniden senkron ister.
  Bağlantıyı düşürmez.
- **`not_running`:** Yarış bittikten sonra istemci flip göndermez. Gelirse aynı yolla senkron
  ister.
- **Yinelenen `inputSequence`:** Yeniden gönderim aynı mesajı ve aynı sırayı kullanır. Sunucunun
  hatasız yok sayması beklenen davranıştır.
- **`startedAt: null`:** Böyle bir sonuç çözülebilir ama sunucudan gelmesi beklenmiyor.
  Lobideki iptal sonuç ekranı açmaz.
- **Oyuncu sayısı 2'nin altına düşerse:** Yarış sürer. İstemci son robot durduğunda sonucu
  bekler.

## 4. Değişen istemci dosyaları

Devir notundan sonra değişen dosyalar aşağıda. `courseVersion` 7 değişiklikleri (robot ölçeği,
start ızgarası) devir notundan önce yazılmıştı; backend onları zaten uyguladı.

### 4.1. Ortak çekirdek (`FausCrew/shared`)

| Dosya | Değişiklik |
|---|---|
| `Fixtures/fausSwitchProtocol.json` | `sessionSnapshot` örneğine `lobbyState` (§1). |
| `Fixtures/fausSwitchSimulation.json` | Yeni (§1.1). |
| `Sources/…/Realtime/GameSessionModels.swift` | `GameSessionDTO.lobbyState` ve gevşek okunan `GameLobbyStateDTO`. |
| `Sources/…/FausSwitch/Online/FausSwitchLobbyColors.swift` | Yeni. Katılmış oyuncuların renkleri, yerel talep ve gösterilen renk, başkasında olan renkler. |
| `Sources/…/FausSwitch/Online/FausSwitchOnlineEngine.swift` | `lobbyColors`. Talep yalnız gerekiyorsa ve renk boşsa gönderilir; sahibi ayrılınca otomatik talep. |
| `Sources/…/FausSwitch/Online/FausSwitchRealtime.swift` | Kurtarma penceresi (§3.1); `runnerScale` ve robot sayısı doğrulaması. |
| `Sources/…/FausSwitch/Online/FausSwitchOnlinePlayMachine.swift` | Yeniden bind'da sıra, `stale_control` için `staleGrant`, eski generation reddi, `isAwaitingResult`, portal olayları (`events`), ölçek değişince parkurun yeniden kurulması. |
| `Sources/…/FausSwitch/Online/FausSwitchWireModels.swift` | Sonuç doğrulaması (§2.4); snapshot'ta `runnerScale`. |
| `Sources/…/FausSwitch/Online/FausSwitchOnlineCopyKeys.swift` | "Sonuç kesinleşiyor" bildirimi. |
| `Sources/…/FausSwitch/FausSwitchMatchUI.swift` | Yeni. Demo ve online yarış ekranının platformdan bağımsız modeli (HUD, isim etiketleri, bildirim, sonuç sıralaması). iOS ve Android aynı modeli çizer. |
| `Sources/…/FausSwitch/FausSwitchLocalization.swift` | iOS'tan çekirdeğe taşındı; Android de aynı metinleri kullanır. |
| `Tests/FausCrewCoreTests/FausSwitchOnlineEngineTests.swift` | Renkler, yeniden bind, `stale_control`, kurtarma penceresi, bekleme bildirimi, sonuç doğrulaması testleri. |
| `Tests/FausCrewCoreTests/FausSwitchPhysicsTests.swift` | §2.6. |
| `Tests/FausCrewCoreTests/FausSwitchSimulationFixtureTests.swift` | Yeni (§1.1). |
| `Tests/FausCrewCoreTests/FausSwitchMatchUITests.swift` | Yeni. |

### 4.2. Android (`FausCrew/android`)

Android, çekirdeğin online motorunu (`FausSwitchOnlineEngine`) JNI üzerinden çalıştırır. HTTP,
WebSocket ve 25 ms tick, FauseTanks ile ortak olan `GameOnlineSession`'dadır. Android tarafında
sözleşme kodu yoktur.

| Dosya | Değişiklik |
|---|---|
| `swift-bridge/…/FausSwitchOnlineBridge.swift` | Yeni. Online motor tutamacı: olay, alım, görüntü alanı, kare ve katalog cevabı. |
| `swift-bridge/…/FausSwitchBridge.swift` | Yeni. Demo yarışı, parkur ve sabitler. |
| `swift-bridge/…/InviteCodeBridge.swift`, `scripts/check-android-bindings.sh` | Köprü sürümü 16. |
| `app/…/platform/FausSwitchOnline.kt` | Yeni. Online motorun Kotlin sarmalayıcısı ve çözücüleri. |
| `app/…/viewmodel/FausSwitchOnlineSession.kt` | Yeni. Ortak oturum ile renk, flip ve kare. |
| `app/…/viewmodel/FausSwitchViewModel.kt` | Yeni. Demo ve online akış: katalog, oda, yarış, rövanş, ayrılma, 401'de çıkış. |
| `app/…/ui/games/fausswitch/*` | Yeni. Lobi, online oda, yarış çizimi ve paneller. |

### 4.3. iOS

`FausSwitchViewModel.swift`, `FausSwitchView.swift`, `FausSwitchLobbyView.swift` ve
`FausSwitchScene.swift` artık çekirdekteki `FausSwitchMatchUI` modelini ve lobi renklerini çizer.
Sözleşme davranışı çekirdektedir.

## 5. İstemcide doğrulananlar

- Çekirdek: 300 test (1 atlandı), hepsi geçti. Kapsam: simülasyon fixture'ı, sözleşme fixture'ı,
  online motor ve çarpışma.
- Köprü: 35 test geçti. Android bağlama kontrolü sürüm 16'yla uyumlu.
- Android: 124 birim test geçti. Bunlara online görünüm modeli ve kare çözücüleri dahil.
  `RealtimeCompressionTest` de bu testlerden biri.
- iOS: derleme hatasız.
- Canlı sunucuyla deneme henüz yapılmadı. Deploy'dan sonra
  `fausSwitchLiveTestChecklist.md` ile yapılacak ve sonuçlar bu rapora eklenecek.

## 6. Canlı test sonuçları

Deploy'dan sonra doldurulacak (`fausSwitchLiveTestChecklist.md`).

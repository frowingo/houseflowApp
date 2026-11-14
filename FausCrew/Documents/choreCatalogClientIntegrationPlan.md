# Görev Kataloğu ve Görev Kategorisi — istemci entegrasyon planı

Tarih: 12 Kasım 2026 · Hazırlayan: mobil (istemci) · Dayanak: `choreCatalogBackendContract.md`
(backend; henüz master'a merge ve deploy edilmedi)

Bu belge, backend sözleşmesine göre iOS ve Android'de yapılacak işleri, mimari kararları ve
sırayı tanımlar. Wire sözleşmesi backend belgesindeki gibidir; burada tekrar edilmez.

**Hedef:** Master deploy edildiği anda uygulama ek değişiklik olmadan çalışsın. Deploy'dan önce
de mevcut görev akışları bozulmasın.

## Durum (13 Kasım 2026)

- **F0–F5 tamam** (commit edilmedi). Otomatik doğrulamalar geçiyor: Core 333 test, swift-bridge 44 test, Android unit testleri, iOS `build-for-testing`.
- **Kalan:** §7'deki eksikler ve deploy'dan sonra F6 canlı testi.
- Aşağıdaki §0, entegrasyondan **önceki** durumdur.

## 0. Başlangıçtaki durum (kısa)

- **Katalog popup'ı** (iOS ve Android, commit edilmedi):
  - 9 kategori rafı ve 62 sistem şablonu uygulamaya gömülü. Metinler iki dilli (tr/en); her şablonun ikonu ve dakika tahmini var.
  - Taslaklar sekmesi cihazda (`ChoreDraftStore`, UserDefaults/SharedPreferences) kullanıcı başına tutuluyor.
  - `sourceTemplateId`, sistem şablonuyla kaydedilen taslak arasındaki bağı tutuyor.
- **Görev oluşturma:** `POST chore`, kategori göndermiyor.
- **Görev güncelleme:** `PUT chore/{id}` için Core'da body, iOS'ta servis, Android'de ViewModel fonksiyonu var. **Hiçbir ekran bunu çağırmıyor.**
- **Katmanlar:**
  - **Core** (`shared/Sources/FausCrewCore`): wire DTO'ları ve kuralları tutar. iOS doğrudan kullanır.
  - **Android:** Core'u `swift-bridge` üzerinden kullanır (istek gövdesi + yanıt doğrulama, istek başına tek geçiş). JSON'u Kotlin'de parse eder (`toHouseChore`).
- **Hata zarfı:** `HTTPStatusFailure` `message` ya da `error` alanını zaten okuyor. Backend'in iki hata zarfı da (`{"error"}` ve `{"success":false,"error"}`) ek iş gerektirmeden çalışır.
- **Rol bilgisi:** Kullanıcı modelinde rol yok. Bu yüzden "rol 2" istemcide bilinmiyor; herkes normal kullanıcı sayılır (bkz. K4).

## 1. Önce karar verilmesi gerekenler

| # | Konu | Neden önemli | Öneri |
|---|---|---|---|
| K1 | **Kategori raflarındaki sistem şablonları nereden gelecek?** | Sözleşme "tek bilgi kaynağı sunucudur" diyor ve sistem kayıtlarını GET ile veriyor. Sunucu modelinde ikon, dakika ve ikinci dil yok; tek bir `title`/`description` var. | **Raflar sunucudaki `isSystem: true` kayıtlarından dolar.** Uygulamada yalnızca kategori görünümü kalır: 9 kategorinin adı, rengi, ikonu ve sloganı (kategori yerelleştirmesi zaten istemcinin işi). Şablon ikonu kategori ikonundan gelir; dakika etiketi gösterilmez. Gömülü 62 şablon, backend'in sistem kayıtlarını seed etmesi için `choreCatalogSeed.json` olarak teslim edilir (bkz. K3). |
| K2 | **Sistem şablonu ile kullanıcının kopyası arasında bağ** — **Karar (12 Kasım 2026): bağ tutulmaz** | Kullanıcının kopyası ayrı bir kayıttır; sistem şablonuna istemciden hiçbir güncelleme gitmez (backend zaten yalnızca rol 2'ye izin verir). | Sistem şablonunda buton her zaman **"Taslak olarak kaydet"**tir ve her basış `id`'siz, `isSystem: false` yeni bir kayıt oluşturur. **"Taslağı güncelle"** yalnızca kullanıcının kendi kaydında (Taslaklar sekmesinden açılan) çıkar ve o kaydın `id`'siyle PUT gönderir. Cihazda bağ haritası ve `sourceTemplateId` yok. |
| K3 | **Sistem kayıtları sunucuda hazır mı, hangi dilde?** — **Karar (13 Kasım 2026)** | Sunucuda seed yoksa raflar boş açılır. Seed tek dilliyse İngilizce kullanıcı Türkçe başlık görür. | Sistem kayıtlarını backend ekler; `choreCatalogSeed.json`'a bakarak (tr/en metinler dosyada). **Backend, sistem kayıtlarını kullanıcının `language` değerine göre yerelleştirilmiş döner.** İstemci başlık ve açıklamayı olduğu gibi gösterir; istemcide key eşleme yok. Dil değişince kullanıcı yeniden giriş yapar ve popup açılışında liste yeniden çekilir. İstemci her durumda boş raf için mesaj gösterir. |
| K4 | **Rol 2 (yetkili) kullanıcılar sistem kaydını uygulamadan düzenleyebilsin mi?** | Kullanıcı modelinde rol yok. Eklemek için `auth/isAuth` yanıtında rol alanı gerekir; sözleşmede bu yok. | **Bu iş kapsam dışı.** Uygulamada sistem kayıtları herkes için salt okunur. Yönetim backend tarafında yapılır. |
| K5 | **Kaydet/güncelle iyimser mi?** | Yeni kaydın `id`'si yanıtla gelir. Taslaklar'daki kart ve sonraki güncelleme bu `id`'ye dayanır. | **Kaydet/güncelle:** buton yanıt gelene kadar dönen gösterge ile bekler; başarılı yanıtla liste patch'lenir. **Silme:** iyimserdir; kart hemen kalkar, hata olursa yerine geri konur. Böylece "iyimser değişikliği geri al" kriteri sadece silmede devreye girer. |

## 1.1. Mevcut tasarımı koruma ilkesi (karar, 12 Kasım 2026)

Entegrasyon, `dev` dalında **commit edilmemiş** katalog çalışmasının üzerine yapılır. Bu
çalışma atılmaz, sıfırdan yazılmaz; yeni katman mevcut ekranların altına bağlanır.

- **Korunan tasarım (iOS ve Android, birebir):**
  - Today's tasks kartının köşesindeki mozaik buton.
  - Ortada açılan büyük popup ve tema renkli sabit yükseklikteki başlığı.
  - Taslaklar sekmesi, kategori çipleri ve arama.
  - Şablon kartları (`ChoreTemplateTile`): "TASLAK · {kategori}" etiketi ve sağ üstteki silme butonu.
  - Taslaklar boş kartı.
  - Silme onay penceresi.
  - Bildirim bandı ("oluşturuldu", "taslak kaydedildi", "taslak güncellendi").
  - Editör: düzenlenebilir başlık ve not, kategori seçici, zorluk kartı ve altındaki kesikli "Taslak olarak kaydet" / "Taslağı güncelle" butonu, tekrar stepper'ı, bitiş saati seçici.
- **Değişen yalnızca veri kaynağı:**
  - Raflar ve Taslaklar, gömülü liste ve cihaz deposu yerine sunucu kayıtlarından dolar.
  - Ekranlar aynı presentation modelini (`ChoreTemplate`) kullanmaya devam eder; sunucu kaydı bu modele çevrilir.
- **Veri farkından doğan küçük görünüm farkları:**
  - Sistem kartında şablon ikonu yerine kategori ikonu görünür.
  - Dakika etiketi gizlenir. Kart bunu bugün de destekliyor: taslak kartlarında süre 0 olduğunda etiket zaten çıkmıyor.
- **Yeni öğeler mevcut tasarım dilinde yapılır:** aynı kart, köşe yarıçapı, renk ve yazı tipleriyle. Bunlar:
  - Sistem kartlarındaki kilit rozeti.
  - Yükleniyor iskelet kartları.
  - Hata ve "Tekrar dene" kartı (Taslaklar boş kartının biçiminde).
  - Boş raf mesajı.
  - Kaydet butonundaki dönen gösterge.
  - Görev satırı ve detayındaki kategori etiketi (katalog kategori renkleriyle).
- **Kaldırılan yalnızca veri katmanıdır:**
  - Gömülü 62 şablon, `ChoreDraftStore`, `sourceTemplateId` ve ilgili fixture/testler.
  - Görünüm dosyaları (`ChoreCatalogPopup`, `ChoreTemplateEditor(View)`, `ChoreCatalogComponents`, `TodaysChoresCard`) kalır ve yalnızca yeni veri kaynağına bağlanacak kadar değişir.

## 2. Mimari hedef

```
FausCrewCore (Swift, iOS + Android ortak)
  ChoreCategoryKind          int enum 0…9, bilinmeyen → .uncategorized
  Create/UpdateChoreRequest  + category: Int?   (nil → alan hiç gönderilmez)
  ChoreResponse / HouseChoreDTO / Chore  + category (decodeIfPresent ?? 0)
  ChoreCatalogRecord         ChoreCatalogModel DTO (Codable)
  ChoreCatalogRules          title 3–200, description ≤1000, interval 0–365,
                             level 10/20/30, category 1–9, 1–100 eleman,
                             isDeleted ⇒ id zorunlu, isSystem asla true gönderilmez
  ChoreCatalogPatch          yerel liste + gönderilen dizi + yanıt → yeni liste (index eşleme)
  ChoreCatalogWireContract   PUT gövdesi, GET/PUT yanıt doğrulama, hata sınıfı
                             (validation 400 / forbidden 403 / notFound 404 / unauthorized 401)

iOS                                   Android
  ChoreCatalogService (URLSession)      ChoreCatalogRepository (platform/, AndroidHttpAdapter)
  ChoreCatalogStore (ViewModels/Stores) ChoreCatalogViewModel (viewmodel/)
  ChoreCatalogPopup + Editor            ChoreCatalogPopup + Editor
                                        swift-bridge: choreCatalogRequestBody,
                                        choreCatalogResponse (+ patch), bridgeVersion 17 → 18
```

- **Kural, patch ve hata sınıflandırması tek yerde, Core'da.** Android köprüyü istek başına bir kez geçer: gövdeyi üretir; yanıtı doğrular ve patch'lenmiş listeyi tek JSON olarak alır.
- **Kategori int'i ↔ raf eşlemesi** uygulamadaki kategori görünümünde durur ve iki platformda aynıdır: `kitchen=1, bath_laundry=2, toilet=3, rooms=4, floors=5, pets=6, trash=7, plants=8, shopping=9`. Sıra bugünkü raf sırasıyla birebir aynı.
- **İstek sırası:** Store, PUT isteklerini sırayla gönderir; aynı anda ikinci bir PUT gitmez. Böylece index eşlemesi her zaman tek bir istekle yanıtı arasında kalır.

## 3. Fazlar

### F0 — Sözleşme ve fixture'lar
- Backend belgesi `Documents/choreCatalogBackendContract.md` olarak saklandı.
- `shared/Fixtures/choreCatalogApi.json` eklenir. İçinde:
  - GET yanıtı: sistem ve kullanıcı kayıtları; `description` boş ve null örnekleri.
  - Karma bir PUT isteği ve yanıtı: ekleme, güncelleme ve silme aynı istekte.
  - 400, 403 ve 404 hata gövdeleri.
  - `category: 0` ve tanınmayan değer (ör. 42) taşıyan görev örnekleri.
- Bu dosya backend'in örneklerinden türetilir. Deploy sonrası gerçek yanıtla karşılaştırılıp gerekirse düzeltilir (F6).

### F1 — Core (`swift test --package-path shared`)
1. **`ChoreCategoryKind`:**
   - `init(apiValue:)`: 0 ve tanınmayan değerler `.uncategorized` olur.
   - `isAssignable` sadece 1–9 için doğrudur.
2. **Görev istekleri:** `CreateChoreRequest` ve `UpdateChoreRequest`'e `category: Int?` eklenir.
   - `nil` ise anahtar JSON'a hiç yazılmaz.
   - Test: güncellemede kategori verilmezse gövdede `category` anahtarı yok (kabul kriteri 2).
3. **Görev yanıtları:** `ChoreResponse`, `HouseChoreDTO` ve `Chore`'a `category` eklenir.
   - `decodeIfPresent ?? 0` ile okunur. Bu sayede deploy'dan önceki backend yanıtları da çözülür.
4. **`DashboardWireContract`:** `choreBody` ve `updateChoreBody` `category` parametresi alır.
5. **`ChoreCatalogRecord`:**
   - `id` boş string → nil.
   - `description` null → "".
   - Tarihler string olarak taşınır.
6. **`ChoreCatalogRules.validate([ChoreCatalogRecord])`:** sunucu kurallarının birebir aynısı.
   - Sözleşmede "karakter" deniyor. Uzunluk Swift `Character` sayısıyla ölçülür. S3 yanıtı farklı çıkarsa güncellenir.
   - Başlık kırpılmış (trim) haliyle ölçülür ve öyle gönderilir.
7. **`ChoreCatalogPatch.apply(local:sent:response:)`:**
   - Yanıt boyu gönderilen diziyle aynı değilse hata.
   - `isDeleted: true` dönen kayıt listeden çıkar.
   - Var olan `id` üzerine yazılır.
   - Yeni kayıt (gönderilende `id` yok), index sırasıyla yanıttaki `id` ile listeye eklenir.
8. **`ChoreCatalogWireContract`:**
   - `putBody(records)`: önce doğrular, sonra kodlar.
   - `validateList` (GET) ve `validateUpsert` (PUT).
   - `failureKind(statusCode)`: validation, forbidden, notFound, unauthorized ya da other. Yanında sunucunun mesajı.
9. **Testler:** fixture'dan GET çözümü, karma PUT patch'i, her kural için sınır değerleri (2/3/200/201 karakter, 365/366 gün, 100/101 eleman), hata sınıfları.

### F2 — Görev kategorisi (iki platform; katalogdan bağımsız, deploy'dan önce de güvenli)
- **iOS:** `ChoreService.createChore` ve `updateChore` `category: ChoreCategoryKind?` alır. Response → `Chore` adaptörü `category` taşır.
- **Android:**
  - `ChoreInput`'a `category: Int? = null` eklenir.
  - `DashboardWire.body` ve köprüdeki `dashboardRequestBody` `category` alır.
  - `toHouseChore` `optInt("category", 0)` okur.
  - `HouseChore.category` eklenir.
- **Liste ve detay:**
  - Gösterilecek yerler:
    - iOS: `ModernChoreRow`, `ChoreRow` ve `ChoreDetailPopup`.
    - Android: `ModernChoreRow` ve `ChoreDetailPopup`.
  - Her birinde küçük bir kategori etiketi (kategori ikonu + adı, kategori rengi) gösterilir.
  - `0` ya da tanınmayan değerde nötr renkli "Kategorisiz"/"Uncategorized" yazar (yeni anahtar `chore_category_none`).
- **Oluşturma:** Editörden gönderilen her yeni görev, seçili rafın int'ini gönderir. Katalogdan açılan görevde bu şablonun kategorisidir; sıfırdan görevde seçilen kategoridir (varsayılan Kitchen = 1).
- **Deploy'dan önce:** Eski backend `category` alanını görmezden gelir ve yanıtta göndermez. Bu durumda uygulama her görevi "Kategorisiz" gösterir, akış bozulmaz.
  - S4: Eski backend bilinmeyen alanı reddediyor mu? Teyit edilmeli.

### F3 — iOS katalog
1. **Servis ve store:**
   - `ChoreCatalogService` (`Services/`) ve protokolü (`ServiceProtocols.swift`).
   - `ChoreCatalogStore` (`ViewModels/Stores/`) şunları yayınlar: `records`, `phase` (idle/loading/loaded/failed) ve `pendingIds`.
2. **Tazeleme:** Popup açılınca GET yapılır. Popup açıkken uygulama ön plana gelirse (`scenePhase == .active`) yine GET.
   - Önceki liste varsa ekranda kalır. Yenileme arka planda yapılır.
3. **Popup:**
   - Raflar `records.filter(\.isSystem)` kayıtlarını kategoriye göre gruplar.
   - Sistem kartında kilit rozeti var; silme ve düzenleme aksiyonu yok.
   - Taslaklar sekmesi `!isSystem` kayıtlarını gösterir. Sıralama `updatedOn`'a göre yeniden eskiye (bugünkü "yeni en üstte" davranışı).
   - Yükleniyor için iskelet kartlar gösterilir. Hata durumunda mesaj ve "Tekrar dene" kartı çıkar. Boş raf için mesaj gösterilir.
   - Arama sunucu başlıklarında yapılır; bugünkü Türkçe karakter katlama aynen kalır.
4. **Editör:**
   - **Sistem kaydı (raftan açılan):**
     - Form doldurulur ve görev oluşturulabilir.
     - Buton her zaman "Taslak olarak kaydet"tir; her basış `id`'siz ve `isSystem: false` yeni bir kayıt gönderir (K2).
     - Sistem kaydına hiçbir zaman PUT gitmez.
   - **Kullanıcı kaydı (Taslaklar'dan açılan):** kategori seçici, "Taslağı güncelle" (`id`'li PUT) ve silme.
   - **Sıfırdan iş:** "Taslak olarak kaydet" yeni kayıt gönderir; kategori seçici varsayılanı Kitchen (1).
   - **Doğrulama:** Buton `ChoreCatalogRules` ile aynı kuralları uygular:
     - başlık ≥3 karakter;
     - açıklama ≤1000 karakter (sınıra yaklaşınca sayaç);
     - tekrar 0–365 (stepper zaten 1–90).
5. **Hatalar:** Sunucu mesajı bugünkü bildirim bandında (hata görünümü) gösterilir.
   - **404:** mesaj gösterilir, ardından GET yapılır.
   - **403:** mesaj gösterilir; normalde UI bu duruma izin vermez.
   - **400:** mesaj gösterilir. İstemci doğrulaması bunu normalde engeller.
   - **401:** mevcut `NetworkService` oturum akışı.
   - **Silme hatası:** kart yerine geri konur.
6. **Kaldırılanlar** (yalnızca veri katmanı; görünümler §1.1'e göre korunur):
   - `ChoreDraftStore`, `ChoreDraftList`, `sourceTemplateId`, `choreDrafts.json` ve `ChoreDraftTests`.
   - Gömülü şablon listesi. `ChoreCatalog.swift` sadece kategori görünümüne iner: 9 raf, `kind`, renk, ikon, ad, slogan ve tekrar önayarları.
   - Özellik henüz yayınlanmadığı için cihazdaki yerel taslakları taşımaya gerek yok.

### F4 — Android katalog
1. **Köprü:** `choreCatalogRequestBody(recordsJson)` ve `choreCatalogResponse(status, body, sentJson, localJson)` eklenir.
   - İkincisi `{ok, records}` ya da `{ok:false, kind, message}` döner.
   - `bridgeVersion` ve `InviteCodeBridge.API_VERSION` 17 → 18 (17, F2'de `dashboardRequestBody` kategori parametresi için kullanıldı).
2. **Repository ve ViewModel:**
   - `ChoreCatalogRepository` (`platform/`), `DashboardRepository.call` ile aynı HTTP ve 401 yolunu kullanır.
   - `ChoreCatalogViewModel` (`viewmodel/`): `StateFlow` ile kayıtlar, faz ve bekleyen işlemler; PUT'lar sırayla gider.
3. **Tazeleme:** popup açılınca, ve popup açıkken `ON_RESUME` geldiğinde GET.
4. **Popup ve editör:** F3'teki davranışın birebir aynısı (iki platform aynı ekranlar).
5. **Kaldırılanlar:** iOS'takilerin karşılıkları; `ChoreCatalog.kt` kategori görünümüne iner.
6. Bugünkü `PendingCreation` + 1 saniyelik zaman aşımı mantığı görev oluşturma için aynen kalır.

### F5 — Seed teslimi (yapıldı, 13 Kasım 2026)
- Gömülü 62 şablon `shared/Fixtures/choreCatalog.json`'dan `Documents/choreCatalogSeed.json`'a aktarıldı.
- `records`: sunucu modelinde gövdeler — `title`, `description` (tr), `recurringInterval`, `level`, `category` int, `isDeleted: false`, `isSystem: true`; id yok. Raf sırasıyla; kategori başına 9/12/6/8/6/8/4/4/5.
- `reference[i]`, `records[i]`'ye aittir ve modelin parçası değildir: eski şablon id'si, İngilizce başlık/açıklama (S2'de çok dil kararı çıkarsa diye), dakika ve ikon.
- Core testi `testSeedRecordsPassTheServerRules` 62 kaydın sunucu kurallarından (tek batch, ≤100) geçtiğini doğrular.
- Fixture'dan şablonlar silindi; `choreCatalog.json` artık yalnızca rafları, tekrar ön ayarlarını ve gün sonu saatini tutar.
- Sistem kayıtlarını backend bu dosyaya bakarak ekler; kullanıcının diline göre yerelleştirilmiş döner (K3).

### F6 — Doğrulama
- **Otomatik (her fazın sonunda):**
  - `swift test --package-path shared`
  - iOS `build-for-testing`
  - Android `testDebugUnitTest`, `assembleDebug`, `compileDebugAndroidTestKotlin`
- **Canlı:** Deploy'dan sonra `Documents/choreCatalogLiveTestChecklist.md` yazılır. Senin cihazda çalıştıracağın adımlar:
  - GET: raflar ve boş Taslaklar.
  - Kaydet: sistem şablonunu taslak olarak kaydet; Taslaklar'dan açıp güncelle.
  - Silme ve 404 sonrası tazeleme (aynı kaydı iki cihazdan silmek).
  - Kategori: kategorili görev oluşturma; eski görevlerde "Kategorisiz".
  - Hata: uçak modunda kaydetme hatası.
  - Dil: uygulama dilini değiştir, yeniden giriş yap; sistem kayıtları yeni dilde gelsin. Taslaklar kaydedildikleri dilde kalır.
  - Bu sırada fixture'lar gerçek yanıtlarla karşılaştırılır.

## 4. Kabul kriterleri → iş eşlemesi

| Kriter | Nerede karşılanıyor |
|---|---|
| Görevde kategori seçimi; listede ve detayda gösterim; `0` → "Kategorisiz" | F2 |
| Kategorisiz güncelleme mevcut kategoriyi silmiyor | F1.2 (nil → anahtar yok) + test |
| Katalog listeleniyor; sistem kayıtları salt okunur | F3.3, F4.4 |
| Aynı PUT'ta ekleme, güncelleme ve silme; index'e göre patch | F1.7–F1.8 (UI tek işlem gönderir; Core çoklu diziyi destekler ve testlenir) |
| Silme `isDeleted: true` ile yapılıyor; kayıt listeden kalkıyor | F1.7, F3.5, F4.4 |
| 400/403/404 mesajı; 404'te tazeleme; başarısızlıkta geri alma | F1.8, F3.5, F4.4 |
| İstemci doğrulaması sunucuyla aynı | F1.6 + editör butonları |

## 5. Backend'e sorulacaklar

- **S1:** ~~Kaynak şablon için `sourceId` alanı~~ — gerek kalmadı (K2: bağ tutulmuyor).
- **S2:** ~~Sistem kayıtları seed edildi mi; başlıklar tek dilde mi?~~ — yanıtlandı (K3): backend ekler, kullanıcı diline göre yerelleştirilmiş döner.
- **S3:** 3–200 ve ≤1000 sınırları karakterle mi, byte ile mi ölçülüyor? Türkçe karakterler UTF-8'de 2 byte.
- **S4:** Deploy'dan önceki backend, `POST chore` gövdesindeki bilinmeyen `category` alanını yok sayıyor mu?
- **S5:** Backend dalı master'dan önce development ortamına (`houseflowapi.fly.dev`) deploy edilecek mi? Edilirse canlı test deploy'u beklemeden yapılabilir.

## 6. Sıra ve bağımlılık

`F0 → F1 → (F2 ‖ F3) → F4 → F5 → F6`

- F2 ile F3 birbirinden bağımsız ilerleyebilir.
- F4, F3'teki ekran davranışını birebir izler.
- F5 backend'in seed kararına (S2) bağlıdır. Uygulama tarafı K1 seçildiği anda boş rafla da çalışır.

## 7. Eksikler (13 Kasım 2026 gözden geçirmesi)

1. **Not sayacı (F3.4):** Plan "sınıra yaklaşınca sayaç" diyordu; iki platformda da yok. Bugün yalnızca 1000 karakter aşılınca kaydet butonunun altında uyarı çıkıyor.
2. **Dil değişince eski liste:** Store/ViewModel listeyi kullanıcı id'sine göre tutar. Aynı kullanıcı dil değiştirip yeniden giriş yapınca popup ilk açılışta, yeni liste gelene kadar bir an eski dildeki kayıtları gösterir. Çıkış yapıldığında listeyi temizlemek bunu giderir.
3. **401:** Katalog, diğer görev çağrıları gibi davranır: 401 hata kartı/mesajı olarak görünür; ayrı bir oturum akışı tetiklenmez (iki platformda da görev servislerinde böyle bir akış yok). F3.5'teki "mevcut `NetworkService` oturum akışı" ifadesi bu yüzden geçersiz.
4. **Backend'den yanıt bekleyen sorular:** S3 (karakter mi byte mı), S4 (eski backend bilinmeyen `category` alanını yok sayıyor mu), S5 (development ortamına önce deploy).
5. **F6 canlı test listesi:** deploy'dan sonra `Documents/choreCatalogLiveTestChecklist.md`.
6. **Commit:** Tüm çalışma `dev` dalında commit edilmemiş durumda.

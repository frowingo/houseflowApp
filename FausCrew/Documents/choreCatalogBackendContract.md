# Görev: Görev Kataloğu (ChoreCatalog) ve Görev Kategorisi entegrasyonu

> Kaynak: backend ajanının istemciye verdiği sözleşme (12 Kasım 2026). Değiştirilmeden
> saklanır; istemci planı `choreCatalogClientIntegrationPlan.md` içindedir.

Backend'e iki özellik eklendi:
1. Görevler (Chore) artık bir kategori (`category`) taşıyabiliyor.
2. Yeni bir "Görev Kataloğu" var. Kullanıcı tekrar tekrar kullanacağı görev şablonlarını burada tutuyor. Sistem de herkesin göreceği hazır şablonlar sağlıyor.

Mobil uygulamada bu iki özelliği entegre et. Aşağıdaki sözleşme kesin, bunun dışında bir alan ya da davranış varsayma.

## Genel
- Base path: `/api/v1`
- Tüm uçlar `Authorization: Bearer <token>` gerektirir.
- Tarih alanları ISO-8601 UTC formatında gelir, örnek: `"2026-11-12T08:30:00Z"`.
- Hata mesajları kullanıcının diline göre yerelleştirilmiş gelir. Kullanıcıya doğrudan gösterilebilir.

## 1. Kategori enum'u (ChoreCategory, int)
| Değer | Anlam |
|---|---|
| 1 | Kitchen (Mutfak) |
| 2 | BathLaundry (Banyo/Çamaşır) |
| 3 | Toilet (Tuvalet) |
| 4 | Rooms (Odalar) |
| 5 | FloorsGeneral (Zeminler/Genel) |
| 6 | Pets (Evcil hayvanlar) |
| 7 | TrashRecycling (Çöp/Geri dönüşüm) |
| 8 | PlantsBalcony (Bitkiler/Balkon) |
| 9 | ShoppingHome (Alışveriş/Ev) |

- `0` "kategori yok" anlamına gelir. Eski görevler `0` ile döner; UI'da "Kategorisiz" gibi göster.
- Tanımadığın bir değer gelirse uygulama çökmemeli; bu değeri de kategorisiz say.
- Kategori isimlerinin yerelleştirmesini istemci yapar.

Mevcut zorluk enum'u (`level`) değişmedi: 10 = Easy, 20 = Medium, 30 = Hard.

## 2. Görevlere (Chore) kategori alanı eklendi
### POST /chore (oluşturma) ve PUT /chore/{id} (güncelleme)
- İstek gövdesine opsiyonel `"category": <1-9>` alanı eklendi. Geri kalan alanlar aynı.
- Alan opsiyonel, ama yeni oluşturulan görevlerde kategori seçtirmeni öneririm.
- **Güncellemede (`PUT /chore/{id}`) `category` alanını hiç göndermezsen veya `null` gönderirsen görevin mevcut kategorisi korunur.** Kategoriyi değiştirmek için yeni değeri gönder.
- `0` ve 9'dan büyük değerler 400 döner.

### Tüm görev yanıtları (ChoreResponseModel)
Görev dönen her uçta artık `"category": <int>` alanı var: oluşturma, güncelleme, durum güncelleme, review ve ev detayları.

## 3. Görev Kataloğu (ChoreCatalog)

### Model: ChoreCatalogModel
İstekte de yanıtta da aynı model kullanılır.
```json
{
  "id": "6730f1c2a1b2c3d4e5f60718",
  "title": "Bulaşıkları yıka",
  "description": "Akşam yemeğinden sonra",
  "recurringInterval": 1,
  "level": 10,
  "category": 1,
  "isDeleted": false,
  "isSystem": false,
  "userId": "6730f1c2a1b2c3d4e5f60000",
  "createdOn": "2026-11-12T08:30:00Z",
  "updatedOn": "2026-11-12T08:30:00Z"
}
```

**Alanlar ve doğrulama kuralları**

| Alan | Kural |
|---|---|
| `id` | String. Yeni kayıtta gönderme (ya da boş string gönder). Varsa 24 karakter olmalı. |
| `title` | Zorunlu, 3–200 karakter. |
| `description` | Opsiyonel, en fazla 1000 karakter. |
| `recurringInterval` | Kaç günde bir tekrarlanacağı, 0–365. `0` tekrarsız demek. |
| `level` | Zorunlu: 10, 20 veya 30. |
| `category` | Zorunlu: 1–9. Katalogda `0` kabul edilmez. |
| `isDeleted` | `true` gönderilirse kayıt soft delete edilir (aşağıya bak). |
| `isSystem` | Sadece yanıtta anlamlı. `true` ise kayıt sistemin hazır şablonudur. Normal kullanıcılar `isSystem: true` göndermemeli. |
| `userId`, `createdOn`, `updatedOn` | Sunucu doldurur. İstekte gönderirsen yok sayılır. |

### GET /chore/catalog
- Sistem kayıtlarıyla kullanıcının kendi kayıtlarını döner. Silinmiş kayıtlar asla dönmez.
- Yanıt: `ChoreCatalogModel[]`. Liste kategoriye, sonra başlığa göre sıralı gelir.
- Gövde ya da parametre yok.

### PUT /chore/catalog (upsert: ekleme, güncelleme ve silme tek uçta)
**İstek:** `ChoreCatalogModel[]`, en az 1, en fazla 100 eleman.

**Her elemanın işlenişi:**
- **`id` yok veya boş:** Yeni kayıt eklenir. Yanıtta yeni `id`, `createdOn` ve `updatedOn` dolu gelir.
- **`id` var, `isDeleted: false`:** Kayıt güncellenir (`title`, `description`, `recurringInterval`, `level`, `category`). `createdOn` değişmez, `updatedOn` güncellenir.
- **`id` var, `isDeleted: true`:** Kayıt soft delete edilir. Diğer alanlar değiştirilmez. Yanıtta `isDeleted: true` döner. Bu kayıt sonraki GET'lerde gelmez.
  - Silme için de modelin doğrulama kurallarına uyması gerekir. En kolayı elindeki modelin tamamını `isDeleted: true` yaparak göndermek.
  - **Ayrı bir DELETE ucu yok; silme sadece bu yolla yapılır.**

**Yanıt:** `ChoreCatalogModel[]`, **istekteki sırayla birebir aynı sırada**. Yerel listeyi bu yanıtla patch'le:
- Yeni eklenen kayıtlar: Sunucunun döndüğü `id` ile yerel geçici kaydı eşle. Eşleştirmeyi dizideki sıraya (index) göre yap.
- Güncellenen kayıtlar: Sunucudan dönen hali yerel kaydın üzerine yaz.
- `isDeleted: true` dönen kayıtlar: Yerel listeden çıkar.

**İşlem atomik:** Dizideki tek bir eleman hata verirse hiçbir değişiklik kaydedilmez. Bu durumda yerel iyimser (optimistic) değişiklikleri geri al ya da listeyi GET ile yeniden çek.

### Sistem kayıtları (`isSystem: true`)
- Herkes görür, ama sadece yetkili kullanıcılar (rol 2) ekleyebilir, değiştirebilir ve silebilir.
- Normal kullanıcı için UI'da sistem kayıtlarını salt okunur göster: düzenleme ve silme aksiyonu olmasın.
- Kullanıcı bir sistem şablonunu kendi kopyası olarak düzenlemek isterse, `id`'siz ve `isSystem: false` olan yeni bir kayıt olarak gönder.

## 4. Hata yanıtları
İş kuralı hatalarının gövdesi: `{"success": false, "error": "<yerelleştirilmiş mesaj>"}`
Doğrulama hatalarının (400) gövdesi: `{"error": "<yerelleştirilmiş mesaj>"}`

| HTTP | Ne zaman | Önerilen davranış |
|---|---|---|
| 400 | Gövde geçersiz; alan kurallarına uymuyor; 0 ya da 100'den fazla eleman; `id`'siz kayıt `isDeleted: true` ile geldi | Mesajı göster. İstemci tarafında aynı kuralları uygulayarak bu hatanın oluşmasını engelle. |
| 403 | Rol 2 olmayan kullanıcı sistem kaydı eklemeye ya da değiştirmeye çalıştı | Mesajı göster. Normalde UI bu aksiyonlara izin vermemeli. |
| 404 | Gönderilen `id` ile kayıt yok, kayıt zaten silinmiş ya da başka bir kullanıcıya ait | Mesajı göster ("Görev kataloğu kaydı bulunamadı veya silinmiş."), ardından GET /chore/catalog ile listeyi tazele. |
| 401 | Token geçersiz | Mevcut oturum yenileme akışı. |

## 5. UI ve akış önerileri
- **Katalog ekranı:**
  - Kayıtları kategoriye göre grupla.
  - Sistem kayıtlarını görsel olarak ayırt et (rozet, kilit ikonu vb.).
  - Kullanıcının kendi kayıtlarında ekleme, düzenleme ve silme olsun.
- **Görev oluşturma ekranı:**
  - "Katalogdan seç" seçeneği ekle. Seçilen şablon `title`, `description`, `level`, `category` alanlarını doldursun.
  - `recurringInterval > 0` ise `isRecurring = true` ve `recurringInterval` aynı değerle doldurulsun.
  - Kullanıcı dueDate, assignedTo ve houseId gibi alanları yine kendisi seçer. Katalog kaydıyla görev arasında sunucu tarafında bir bağ yoktur; şablon sadece formu doldurur.
- **Toplu kaydetme:** Kullanıcı birden fazla değişiklik yaptıysa tek bir PUT ile gönderebilirsin (en fazla 100 eleman).
- **Güncel tutma:** Katalog ekranı açılırken ya da uygulama ön plana geldiğinde GET ile listeyi tazele. Tek bilgi kaynağı sunucudur.

## 6. Kabul kriterleri
- [ ] Görev oluştururken kategori seçilebiliyor; görev listelerinde ve detayında kategori görünüyor; `0` gelirse "Kategorisiz" yazıyor.
- [ ] Kategorisi değiştirilmeden yapılan görev güncellemesi mevcut kategoriyi silmiyor (alan gönderilmiyor ya da mevcut değer gönderiliyor).
- [ ] Katalog listeleniyor; sistem kayıtları salt okunur gösteriliyor.
- [ ] Aynı PUT isteğinde ekleme, güncelleme ve silme yapılabiliyor; yerel liste yanıttaki sıraya göre doğru patch'leniyor.
- [ ] Silme, `isDeleted: true` ile yapılıyor ve silinen kayıt listeden kalkıyor.
- [ ] 400, 403 ve 404 hatalarında yerelleştirilmiş mesaj gösteriliyor; 404'te liste yeniden çekiliyor; başarısız istekte yerel iyimser değişiklikler geri alınıyor.
- [ ] İstemci tarafı doğrulama sunucu kurallarıyla aynı: title 3–200, description ≤1000, recurringInterval 0–365, level 10/20/30, category 1–9, en fazla 100 eleman.

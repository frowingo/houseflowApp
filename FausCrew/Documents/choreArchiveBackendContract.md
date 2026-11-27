# Chore Arşivi – Client Entegrasyon Notu

> Backend ajanının 24 Kasım 2026'da verdiği not, olduğu gibi saklandı. Client planı: [choreArchiveClientPlan.md](choreArchiveClientPlan.md).

## Özet
- `GET /api/v1/house/details` artık evin **tüm** chore'larını dönmüyor.
- Daha eski kapanmış chore'lar yeni bir endpoint'ten, tarih aralığına göre 10'arlı sayfalar halinde çekiliyor: `GET /api/v1/chore/archive`.
- Failed chore'larda `completedAt` ve `completedBy` alanları artık dolu geliyor.
- Chore oluştururken ve güncellerken `dueDate` artık backend tarafında gerçekten zorunlu.

---

## 1. house/details – değişen davranış

`chores` dizisinde artık yalnızca şunlar var:

| Status | Değer | Koşul |
|---|---|---|
| Draft | 0 | Her zaman döner |
| Progress | 1 | Her zaman döner |
| InTest | 2 | Her zaman döner |
| Completed | 3 | Yalnızca son 48 saatte kapandıysa (`completedAt` ≥ şimdi − 48 saat) |
| Failed | 4 | Yalnızca son 48 saatte kapandıysa (`completedAt` ≥ şimdi − 48 saat) |

Daha eski Completed ve Failed chore'lar artık sadece arşiv endpoint'inden geliyor. Yanıtın yapısı aynı, bu değişiklik için model değişikliği gerekmiyor.

**Dikkat:** Client'ta puan, istatistik ya da leaderboard gibi bir hesap details'taki `chores` dizisinin tamamına dayanıyorsa, bu hesap artık eksik veriyle çalışır.

---

## 2. Yeni endpoint: GET /api/v1/chore/archive

**Auth:** Bearer token. Kullanıcının evin üyesi olması gerekiyor.

### Query parametreleri

| Parametre | Zorunlu | Açıklama |
|---|---|---|
| `houseId` | Evet | Ev ID'si |
| `from` | Evet | Aralığın başı, RFC 3339 formatında, **dahil** |
| `to` | Evet | Aralığın sonu, RFC 3339 formatında, **hariç** |
| `cursor` | Hayır | Client bunu kendisi oluşturmaz, `nextUrl` içinde hazır gelir |

- Aralık `[from, to)` şeklinde, `from` değeri `to` değerinden önce olmalı. Aralık uzunluğu için bir sınır yok.
- Bir chore, `completedAt` değeri bu aralıktaysa listeye girer.
- Arşiv son 48 saati **de içerir**. "Bu hafta" gibi bir aralıkta dünkü chore'lar da görünür. Aynı chore'un hem ana ekranda hem arşivde görünmesi normal.
- Yerel gün sınırlarını cihaz saat dilimiyle gönderin. Örneğin 1 Kasım 00:00 (TR) = `2026-11-01T00:00:00+03:00`.
- Offset'teki `+` karakteri URL-encode edilmeli (`%2B`). Ya da tarihi UTC'ye çevirip `Z` ile gönderin.

### Örnek istek
```
GET /api/v1/chore/archive?houseId=665f...a1&from=2026-11-01T00%3A00%3A00%2B03%3A00&to=2026-12-01T00%3A00%3A00%2B03%3A00
```

### Örnek yanıt (200)
```json
{
  "success": true,
  "data": {
    "chores": [
      {
        "id": "6741...",
        "title": "Bulaşık",
        "status": 3,
        "isCompleted": true,
        "completedAt": "2026-11-23T18:42:10Z",
        "completedBy": "<userId>",
        "...": "house/details'taki chore modeliyle birebir aynı (statusHistories, reviewVotes dahil)"
      }
    ],
    "nextUrl": "/api/v1/chore/archive?cursor=...&from=...&houseId=...&to=..."
  }
}
```

### Sayfalama
- Her yanıtta en fazla **10** chore gelir. Sıralama `completedAt` değerine göre yeniden eskiye.
- `nextUrl` dolu geldiyse aralıkta daha fazla chore var. Bu durumda "Daha fazla göster" butonu gösterilir. Butona basılınca `BASE_URL + nextUrl` olduğu gibi çağrılır ve gelen chore'lar listenin **sonuna eklenir**.
- `nextUrl` değeri `null` ise son sayfaya gelinmiştir, buton gizlenir.
- `nextUrl` host içermez, `/api/v1/...` ile başlayan bir path'tir. Parse etmeyin, değiştirmeyin.
- Kullanıcı sayfaları gezerken yeni bir chore kapansa bile aynı chore iki kez gelmez ve hiçbir chore atlanmaz.
- Kullanıcı tarih aralığını değiştirirse liste sıfırlanır ve ilk istek `cursor` olmadan atılır. Eski aralığa ait `nextUrl` kullanılmaz.

### Hatalar
Yanıt formatı `{ "success": false, "error": "<istek diline göre çevrilmiş mesaj>" }`.

| HTTP | Durum |
|---|---|
| 400 | `houseId` gönderilmemiş ya da geçersiz |
| 400 | `from` veya `to` eksik, RFC 3339 değil, ya da `from` ≥ `to` |
| 400 | `cursor` geçersiz (`nextUrl` değiştirilmişse) |
| 401 | Token yok ya da geçersiz |
| 403 | Kullanıcı evin üyesi değil |

---

## 3. Failed chore'lardaki alan değişikliği

| Alan | Eski | Yeni |
|---|---|---|
| `status` | 4 | 4 (değişmedi) |
| `isCompleted` | false | false (değişmedi) |
| `completedBy` | `""` | `"system"` |
| `completedAt` | `0001-01-01T00:00:00Z` (boş) | Chore'un kapandığı an |

`completedAt` değerinin hangi ana denk geldiği failure türüne göre değişiyor:
- **Deadline geçtiği için fail olduysa:** chore'un `dueDate` değeri.
- **3. review turunda reddedildiği için fail olduysa:** reddin yapıldığı an.

Eski Failed kayıtlar da migration ile bu şekilde dolduruldu.

**Dikkat:** Bir chore'un başarılı olup olmadığına `completedAt` doluluğuna bakarak karar vermeyin, artık `status` veya `isCompleted` alanına bakın.

`completedBy == "system"` bir kullanıcı ID'si değil. Kullanıcı listesinde aramayın, UI'da "Süresi doldu" ya da "Sistem" gibi bir ifade gösterin.

Açık chore'larda (Draft, Progress, InTest) `completedAt` eskisi gibi `0001-01-01T00:00:00Z` geliyor.

InTest durumundaki bir chore'un `dueDate`'i, review oyları tamamlanmadan geçerse chore Failed olur. Bu bilinçli bir kural: review dahil tüm iş akışının `dueDate`'ten önce bitmesi bekleniyor.

---

## 4. dueDate zorunluluğu

`POST /api/v1/chore` ve `PUT /api/v1/chore/{id}` isteklerinde `dueDate` eksik gönderilirse, ya da `null` veya `""` olarak gönderilirse artık **400** dönüyor. Daha önce bu istekler sessizce kabul ediliyordu.

---

## 5. Eski app versiyonları
Arşiv ekranı olmayan eski versiyonlarda kullanıcılar 48 saatten eski kapanmış chore'ları göremez. Bu bir çökmeye yol açmaz, sadece eksik veri gösterilir.

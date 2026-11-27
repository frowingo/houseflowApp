# Oyun İstatistikleri — Backend Sözleşmesi

**Kaynak:** backend ajanının brifi (27 Kasım 2026). **Durum:** backend'de hazır, prod'a henüz deploy edilmedi; bir sonraki backend release'i ile canlıya çıkacak. Client planı: [gameStatsClientPlan.md](gameStatsClientPlan.md).

## Endpoint

`GET /api/v1/game/stats?houseId={houseId}`

- Bearer token (diğer `/api/v1` uç noktaları gibi).
- `houseId` zorunlu; isteyen kullanıcı o evin üyesi olmalı.
- Kullanıcı başına rate limit (diğer kullanıcı uç noktalarıyla aynı).

## 200 yanıtı

```json
{
  "success": true,
  "data": [
    {
      "gameKey": "fausSwitch",
      "players": [
        { "userId": "u2", "wins": 5, "matchesPlayed": 9 },
        { "userId": "u1", "wins": 3, "matchesPlayed": 9 },
        { "userId": "u3", "wins": 0, "matchesPlayed": 0 }
      ]
    }
  ]
}
```

- `gameKey`: bugün `fausSwitch`, `houseRockets`, `houseTanks`. Bilinmeyen anahtar gelebilir; client çökmemeli.
- `players[].userId`: ad/avatar yanıtta yok, ev üyeleri listesinden eşlenir.
- `wins`: kazanılan tamamlanmış maç sayısı. `matchesPlayed`: oynanan tamamlanmış maç sayısı.

## Sayım kuralları (backend uygular, client yeniden hesaplamaz)

- Yalnız tamamlanmış maçlar sayılır; iptal edilenler hiç sayılmaz.
- Beraberlik / paylaşılan birincilik "oynandı" sayılır, galibiyet yazılmaz. Bu yüzden bir oyunda wins toplamı matchesPlayed'den küçük olabilir.
- Yalnız evin şu anki üyeleri listelenir. Ayrılan üyeyle oynanmış maçlar kalanların sayılarında durur.
- Her oyunun `players` listesi tüm güncel üyeleri içerir; hiç oynamamış üye `0/0` gelir.
- Bir oyun ancak güncel üyelerden en az biri onu tamamladıysa listede olur. Ev hiç oynamadıysa `data` boş dizi `[]` gelir (null değil).

## Sıralama (backend sıralı gönderir)

- `data`: `gameKey`'e göre alfabetik.
- `players`: wins azalan → matchesPlayed azalan → ev üyeliği sırası. İlk eleman, `wins > 0` ise oyunun lideri.

## Hatalar

Gövde: `{ "success": false, "error": "<Accept-Language'a göre yerelleştirilmiş metin>" }`. Mantık HTTP koduna göre kurulur.

| Kod | Anlam |
|---|---|
| 400 | `houseId` eksik ya da biçimi geçersiz |
| 401 | Token yok ya da geçersiz |
| 403 | Kullanıcı bu evin üyesi değil |
| 404 | Ev bulunamadı |
| 429 | Rate limit aşıldı |

## Güncellik

WebSocket güncellemesi yok. Ekran açıldığında ve kullanıcı bir maçı bitirip istatistik ekranına döndüğünde yeniden çekilir. Polling yapılmaz.

# HouseFlowCore

`HouseFlowCore`, HouseFlow'un platformdan bağımsız iş mantığı için ayrılmış tek ortak Swift target'ıdır.

## Sınırlar

- Bu target iş kuralları, domain modelleri, port sözleşmeleri ve deterministik oyun simülasyonlarını barındırabilir.
- `SwiftUI`, `UIKit`, `SpriteKit`, `Security`, `URLSession`, `UserDefaults`, Android veya JNI tipleri bu target'a eklenmez.
- iOS ve Android uygulamaları kendi UI, navigasyon, lifecycle, storage, network, input, renderer ve audio adapter'larının sahibi olur.
- Başlangıçta yeni production target veya package eklenmez. Bölme ancak ölçülmüş bir build, sahiplik veya dağıtım sorunu varsa ayrı kararla yapılır.

## Mevcut sahiplik

- Auth/user request-response DTO'ları ve saf `User` modeli Core'dadır.
- House request-response/info/details DTO'ları ile mevcut `InviteCodeRules` Core'dadır.
- House wire tarihleri API'nin kullandığı ISO-8601 string ve `{ "time.Time": "..." }` biçimlerini kabul eder; Core bu değerleri string olarak normalize eder.
- House details payload'ının nested member, announcement ve chore kayıtları Core wire DTO'larıdır.
- Chore request-response DTO'ları, `ChoreLevel`/`ChoreStatus` raw enum'ları ve saf `Chore` domain modeli Core'dadır.
- Chore localization anahtarları, response-to-house adapter'ı ve `HouseFlowDateFormatter` içindeki parse/encode/display/due-label davranışı iOS uygulamasındadır. Core tarihleri wire `String` değeri olarak taşır ve kullanıcıya gösterilecek metin üretmez.
- HTTP request/response ve hata zarfı sözleşmeleri ile secure session, preferences ve localization cache portları Core'dadır.
- `URLSession` yürütmesi, Keychain, UserDefaults ve disk cache implementasyonları iOS target'ındadır. `ObservableObject` state ve bütün UI davranışı da iOS'ta kalır.
- Port kararları ve doğrulama kapıları `Documents/PHASE3_PORT_DECISIONS.md` içindedir.

## Yerel doğrulama

```sh
swift test --package-path shared
```

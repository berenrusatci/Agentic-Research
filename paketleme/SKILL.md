---
name: paketleme
description: >-
  Bir depoyu, kabuğu ve canlı dosya sistemi olmayan güçlü bir sohbet modelinin gezebileceği
  alt sistem bazlı zip bundle'lara böler: node_modules'suz, derleme çıktısız, ikili varlıksız,
  sır taramasından geçmiş. Araştırma hattının "koda erişimli tur" ayağının ön koşuludur —
  model ancak bu bundle'lar yüklendiğinde gerçek dosyalara `dosya:satır` düzeyinde atıf yapabilir.
  Şu istekler bunu tetikler: "repoyu paketle", "inceleme için zip'le", "bundle'ları güncelle",
  "koda erişimli tur aç".
---

# Paketleme — depo → gezilebilir zip bundle'lar

Hedef model kabuğa, canlı dosya sistemine ve sınırsız bağlama sahip değildir. Bu yüzden depoyu
**alt sisteme göre** böleriz ve `node_modules`, derleme çıktısı, ikili varlıklar ile sırları ayıklarız
— modele boğulacağı 400 MB'lık bir arşiv yerine gerçekten gezebileceği bir şey veririz.

## Çalıştır

```bash
PROJE=/path/to/repo ./paketle.sh
```

Yapılandırma yoksa otomatik algılar: workspace paketleri (`apps/*`, `packages/*`, `services/*`,
`libs/*` ve kökteki `shared`/`server`/`web`/`api`/`core` gibi klasik workspace'ler), bir seviye
derine kadar arayarak şema-yalnız bir `db` bundle'ı, ve bir `docs` bundle'ı. Tek paketli depo tek
`src` bundle'ı alır.

İlk koşuda kullanılabilir bir bölme verir. **İyi** bir bölme için elle yapılandırma yaz — model
"bu şey hangi bundle'da olurdu" diye düşünerek gezinir, yani mimarine uyan bir bölme değerlidir.

| Değişken | Varsayılan | Anlamı |
|---|---|---|
| `PROJE` | `$PWD` | paketlenecek depo |
| `CIKTI` | `$PROJE/paket-bundles` | zip'lerin ineceği dizin |
| `ONEK` | depo dizin adı | zip adı öneki → `<onek>-<bundle>.zip` |
| `KONF` | script yanındaki `bundles.conf` | bundle tanımları; yoksa otomatik algılama |
| `SIRRA_IZIN` | `0` | `1` sert sır bulgusuna rağmen devam eder |

## Yapılandır

```bash
cp bundles.example.conf bundles.conf
```

Her satır bir bundle tanımlar; kaynaklar depo köküne göre `dir:<yol>` ya da
`file:<yol>[:<altdizin>]`:

```bash
define_bundle cekirdek "alan mantığı — mimari incelemesi için en önemli bundle" \
  dir:packages/core

define_bundle db "yalnız şema mimarisi — satır yok, seed yok" \
  dir:prisma file:docs/VERI-PLANI.md
```

`bundles.conf` varsa otomatik algılama **tamamen** devre dışı kalır.

## Neler dışarıda kalır

`.git`, `node_modules`, `.next`, `.turbo`, `dist`, `build`, `out`, `coverage`, `.vercel`, `target`,
`__pycache__`, `.venv`; `*.tsbuildinfo`, `.env`, `.env.*`, `*.log`, `.DS_Store` ve ikili varlıklar
(görsel, video, font, pdf, arşiv, paylaşılan kütüphane).

**Testler bilerek kalır** — sözleşmeleri kodlarlar ve depodaki en faydalı inceleme malzemesidir.

## Sır taraması

Zip'lemeden önce her bundle taranır. **İki katman**, çünkü gerçek bir depoda tek katmanlı tarama
baştan sona yanlış pozitiftir; her koşuda `SIRRA_IZIN=1` verirsin ve tarama hiç olmamış olur:

- **SERT** — sağlayıcı üretimi kimlik bilgisi biçimleri: özel anahtar başlıkları, `AKIA…`,
  `ghp_…`, `github_pat_…`, `xox…`, `AIza…`, uzun `sk-…`, JWT. Bulgu **paketlemeyi durdurur**.
- **YUMUŞAK** — genel `secret = "…"` / `password: "…"` atamaları. Yalnız gözüne sokulur, öldürücü değil.

`test/`, `__tests__/`, `fixtures/`, `spec`, `example` altındaki ya da açık yer tutucu taşıyan
(`FAKE`, `EXAMPLE`, `your-`, `env(…)`) bulgular YUMUŞAK'a indirilir — sır işleyen bir test paketi
kimlik-biçimli dizeler içerdiği için durdurmak, seni bekçiyi görmezden gelmeye alıştırır.

## Notlar

- **Boyuta göre değil, alt sisteme göre böl.** Eşit boyutlu zip'ler değersizdir; mimariye uyan
  bölme değerlidir.
- **Veritabanı bundle'ı mimari olmalı, veri değil.** Şema ve ileri-yönlü göçler ship edilir;
  satır ya da seed verisi asla.
- Çıktı dizinindeki eski `*.zip`'ler her koşuda silinir — yeniden koşmak bayat bundle bırakmaz.
- Docs/ADR/kural bundle'ını mutlaka koy. Model, bir kod tabanının **neden** o şekilde olduğunu
  okuyabildiğinde çok daha iyi akıl yürütür.

## Bundle yolları ≠ depo yolları (uyarı)

Bundle'lar dizin yapısını düzleştirdiği için model, atıflarında **satır numarasını doğru, dosya
yolunu yanlış** verme eğilimindedir. Araştırma hattındaki düzenleyici rolü bu yüzden her atfı
gerçek depoda doğrular. Bunu paketleme aşamasında tamamen çözemezsin; bilinen bir maliyet olarak kabul et.

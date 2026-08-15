---
name: arastirma-hatti
description: >-
  Geniş bir araştırma konusunu dört rollü, uçtan uca loglanabilir bir hat olarak yürütür:
  orkestratör konuları belirler, bir düzenleyici ajan prompt'ları yazar, ucuz/hızlı taşıyıcı
  ajanlar bir sohbet arayüzünü sürüp dönen çıktıyı BİREBİR bir Obsidian vault'una kaydeder, ikinci
  bir düzenleyici ajan o ham kayıtları gerçek kod deposuna karşı doğrulayıp düzenler ve puanlar.
  Yazılan her prompt ve her adım loglanır, böylece orkestratör ham yanıtları hiç okumadan hattı
  denetleyebilir. Şunlar için kullan: bir şemayı N ayrı sohbete bölmek, yanıtları toplamak,
  yeterliliklerini değerlendirmek, aynı sohbetten takip turuyla derinleştirmek, ve bütün turu
  denetlenebilir bir kayda dönüştürmek.
  "bunu 5 sohbete böl", "her başlığı ayrı sohbete gönder", "yanıtları değerlendir",
  "o sohbetten devam ettir", "ben dur diyene kadar sürdür" gibi istekler bu skill'i tetikler.
---

# Araştırma hattı — dört rol, tam log

## Neden bu yapı

Tek ajanın hem prompt yazıp hem arayüzü sürüp hem yanıtı değerlendirmesi iki şeyi bozar:
orkestratörün bağlamı 35 KB'lık ham yanıtlarla dolar, ve **taşıma ile yorum aynı elde birleşir** —
yani modelin gerçekte ne dediği ile ajanın ne anladığı ayırt edilemez hale gelir. Hat bu yüzden
dört role ayrılır ve **her rol yaptığı her işi loglar**.

| Rol | Model tipi | İşi | Yapmadığı |
|---|---|---|---|
| **Yönetici** | orkestratör (sen) | Araştırma konularını belirler, hattı kurar, **logları denetler** | Ham yanıtları okumaz |
| **Düzenleyici-2 (prompt yazarı)** | güçlü akıl yürüten | Konu brief'ini gerçek prompt'a çevirir, taşıyıcılara dağıtır | Arayüze dokunmaz |
| **Taşıyıcı** (konu başına 1) | hızlı/ucuz | Sürücüyü çalıştırır, çıktıyı **BİREBİR** kaydeder | Yorumlamaz, özetlemez, düzeltmez |
| **Düzenleyici-1 (editör)** | güçlü akıl yürüten | Ham kayıtları düzenler, iddiaları **gerçek repoya** karşı doğrular, puanlar | Kendi sürücüsünü çalıştırmaz |

Akış: **yönetici → D2 (prompt) → taşıyıcı (taşıma) → D1 (düzenleme) → yönetici (denetim)**.
Her okla birlikte bir log satırı düşer; yönetici hiçbir aşamada ham metne inmek zorunda kalmaz.

**Ham kayıt kutsaldır.** Taşıyıcının yazdığı dosya `ham: true` frontmatter'ı ve "BİREBİR KOPYA"
uyarısıyla durur; düzenleyici onu **değiştirmez**, yanına `duzenli/` altında ayrı bir sürüm yazar.

## İş akışı

### 1. Oturumu ve sürücüyü hazırla

Sürücü script'i (arayüzü süren kod) bu repoda yoktur — kurulumuna göre yaz ya da yazdır.
Karşılaması gereken sözleşme README'deki "Sürücüden beklenenler" bölümündedir. Özet: kullanıcının
kendi giriş yapmış tarayıcı oturumunu kullan, çok satırlı metni tek parça yaz, gönderimi doğrula,
akış bitişini iki ölçütle anla, aynı sohbette takip turu yapabil, ve **kaç karakter alındığını
dürüstçe bildir**.

Sırları asla terminale basma; yalnız dosyaya yaz ve o dosyayı `.gitignore`'la.

### 2. Şemayı dengeli prompt'lara böl (yönetici → D2)

Kaynak şemayı N adet bağımsız, birbirini örtmeyen konuya ayır (tipik 3-6). Her prompt **tek başına
anlaşılır** olmalı, çünkü sohbetler birbirini görmez — ortak proje bağlamını ayrı bir dosyaya koy ve
her prompt'un başına ekle.

Konu brief'lerini D2'ye ver; prompt'ları **o** yazsın (şablon: `sablonlar/duzenleyici-2-prompt.md`).
D2 yazdığı her prompt'u `vlog.py` ile loglar — prompt takibin buradan yürür.

### 3. Taşıyıcıları koş

Konu başına bir taşıyıcı; her biri **kendi tarayıcı profilini** alır (paylaşılan profil kilitlenir).
Şablon: `sablonlar/tasiyici.md`. Görev **dar** yazılmalı: "YORUM YAPMA / ÖZETLEME / DÜZENLEME /
tek kelimesini bile değiştirme" ile başlar ve adımları tek tek komut olarak verir. Serbest bırakılan
taşıyıcı yardımcı olmaya çalışıp metni "toparlar" — o an ham kayıt değerini kaybeder.

**Eşzamanlılık sınırı: aynı hesaptan en çok 2 akış.** Ölçüldü: 5 eşzamanlıdan yalnız 2'si tamamlandı,
diğerleri bağlantı kesilmesiyle yarıda kaldı. Lane'leri kaydırmalı başlat (ör. 90'ar saniye).

### 4. Düzenle ve doğrula (D1)

Şablon: `sablonlar/duzenleyici-1-editor.md`. D1 ham kaydı okur, **her `dosya:satır` atfını gerçek
repoda arar**, yolu düzeltir, doğrulanamayanı işaretler, en az üç iddiayı kodu okuyarak sınar,
riskin şiddetini kalibre eder, sonra düzenli sürümü + değerlendirmeyi ayrı dosyalar olarak yazar.

### 5. Denetle (yönetici)

```bash
python3 scripts/vlog.py ozet --vault "<vault>" --son 40
```

Sonucu `ok` olmayan olaylar, karakter sayısı beklenmedik düşük olan `ham` kayıtlar ve prompt'u
olmayan taşımalar buradan görünür. **Ham yanıtı ancak bir çelişki varsa aç.**

### 6. Takip turu (döngü)

Eksik kalan başlıkları **yeni sohbet açmadan** aynı sohbette derinleştir — bağlam orada durduğu için
model önceki yanıtının üstüne koyar. Takip prompt'unu yine D2 yazar, D1'in değerlendirmesindeki
boşluklara dayanarak: genel "daha detaylı anlat" yasak; en fazla 6 numaralı istek, her biri belirli
bir iddiaya atıfla ("N. maddede ... dedin ama ...").

Döngüyü şu ikisinden biri gelene kadar sürdür: kullanıcı **dur** diyene kadar, ya da bir başlıkta son
iki tur anlamlı yeni bilgi katmıyor + tüm alt sorular yanıtlanmış + kaynaklar sağlamsa "tamamlandı"
işaretle. Hepsi tamamlanınca döngü doğal olarak biter.

### 7. Sentez

Döngü bitince tek bir sentez üret: başlıklar arası çelişkiler, en güçlü bulgular, kaynak kalitesi.
Sentezdeki her iddia D1'in doğrulamasından geçmiş olmalı — ham yanıttan doğrudan alıntı yapma.

## Loglama sözleşmesi

Bütün roller `scripts/vlog.py` üzerinden yazar (tek giriş noktası olması şart — loglar tek biçimde
kalsın ve yönetici tek komutla denetlesin):

```bash
python3 vlog.py yaz  --vault V --rol <rol> --model <model> --tur <prompt|ham|duzen|not> \
                     --konu "<konu>" --dosya <dosya> [--ham] [--sohbet <url>] [--kaynak <x>]
python3 vlog.py olay --vault V --rol <rol> --model <model> --eylem <eylem> \
                     --konu "<konu>" --sonuc <ok|hata> [--sure <sn>] [--not "<açıklama>"]
python3 vlog.py ozet --vault V [--son 30]
```

`--ham` "bu içerik birebir kopyadır" demektir; taşıyıcılar **daima**, düzenleyiciler **asla**.

## Sürücünün YALAN SÖYLEDİĞİ dört yer (ölçüldü — hepsini doğrula)

Dördü de "iş başarısız" görüntüsü üretirken gerçek başka çıktı. **Raporu değil sonucu doğrula.**

1. **"0 karakter / kısmi" derken yanıt tam olabilir.** Akış-bitti tespiti uzun yanıtlarda erken
   kopar. Ölçüm: "0 karakter" raporlanan sohbet tekrar okununca **36.357 karakter** çıktı.
   *Her "boş" raporundan sonra sohbeti tekrar oku.* Bir başlığı "üretilemedi" diye işaretlemeden
   önce bu adım şart — aksi halde çalışan bir başlığa üç tur boşuna harcanır (bir kez fiilen oldu).

2. **Adres eşleştirmesi sessizce sıfır dönebilir.** Proje içinden açılan sohbetlerin adresi düz
   sohbet adresinden farklı biçimdedir; eşleştirme buna takılırsa script hata vermeden hiçbir şey
   okumaz. Okumada daima en yalın adres biçimini kullan.

3. **Takip gönderimi sessizce başarısız olup ÖNCEKİ turu kaydeder.** Gönderim tutmazsa okuyucu hâlâ
   son yanıtı okur. Ölçüm: "tur2" 33.972 bayt, tur1 34.152 bayt — birebir kopya. *Tur N'i N-1 ile
   boyutça karşılaştır; %5'ten yakınsa tur gitmemiştir* → `.GECERSIZ` diye karantinaya al.

4. **Taşıyıcı bozuk çıktıyı `ok` diye raporlar.** Ölçüm: 44 KB'lık sohbetten 52 karakterlik arayüz
   hata ekranı geldi, taşıyıcı `ok` dedi. *Sayısal kapı koy: <2000 karakter → başarısız; bilinen
   arayüz hata metinleri yanıt sayılmaz.* Taşıyıcıya "makul mü" diye sorma, eşik ver.

## Yüklenen arşiv yolları repo yollarıyla AYNI DEĞİL

Kod bundle'ları dizin yapısını düzleştirdiği için model **satır numarasını doğru, dosya yolunu
yanlış** verir (iki bağımsız koşuda ölçüldü). **Düzenleyici-1 bu yüzden zorunludur**: her atfı
gerçek repoda doğrular, yolu düzeltir, doğrulanamayanı işaretler. Bulguların kendisi genelde
sağlamdır — yol güvenilmezdir.

Aynı şekilde **şiddet kalibrasyonu da D1'in işidir**: bir tur "çift merge riski" diye raporladı,
kod okununca ikinci merge'ün boş diff yüzünden zararsız no-op olduğu, gerçek kusurun veri kaybı
değil durum tutarsızlığı olduğu görüldü. Model doğru yeri gösterir, şiddeti abartır.

## Sık tuzaklar

- **Profil kilidi**: "profile already in use" → o profilde açık tarayıcı var; her lane kendi
  profilini alsın.
- **Eşzamanlılık**: taşıyıcıların yanı sıra orkestratör ajanların kendi bağlantıları da aynı hesaba
  gidebilir; toplam akış sayısını buna göre say.
- **Kalıcı dosya yükleme** (proje kaynakları) kırılgandır: yükleme çoğu zaman kalıcı depo yerine
  geçici ek olarak düşer ve sayfa yenilenince kaybolur. Güvenilir yol kullanıcının elle yüklemesi,
  sonra doğrulanmasıdır.
- **Bot koruması / kullanım şartları**: tarayıcı oturumuyla otomasyon servisin şartlarına aykırı
  olabilir. Hesap kullanıcınındır; kararı bir kez belirt, sonra ısrar etme.

# arastirma-hatti

Geniş bir araştırma konusunu, **çok rollü ve uçtan uca loglanabilir** bir hat olarak yürüten bir
yöntem: ajanlar arasında iş bölümü, dokunulmaz ham kayıt, ve her adımın bir Obsidian vault'una
düşen kaydı.

Kısaca ne yapar: sen bir araştırma şeması verirsin; hat bunu bağımsız prompt'lara böler, her birini
bir sohbet arayüzünde ayrı ayrı çalıştırır, dönen yanıtları **birebir** bir vault'a yazar, sonra o
ham yanıtları **gerçek kod deposuna karşı doğrulayıp** düzenler. Yazılan her prompt dahil, her adım
loglanır — böylece hattı yöneten, 35 KB'lık ham yanıtları okumadan da ne olup bittiğini denetler.

> Bu repo **yöntemi ve log altyapısını** taşır: rol tanımları, görev şablonları, kayıt aracı.
> Tarayıcıyı süren sürücü script'lerini bilerek içermez — onlar hedef arayüze özeldir, hızla
> eskir ve zaten kullanacak kişinin ajanı tarafından o an yazılması daha doğrudur. Aşağıdaki
> "Sürücüden beklenenler" bölümü, o script'in hangi sözleşmeyi karşılaması gerektiğini anlatır.

---

## Neden bu yapı

Bir sohbet arayüzünün web tarafı, API'nin vermediği şeyleri verir: yüklenen dosyalara atıf yapabilen
proje sohbetleri, derin araştırma modları, bağlayıcılar, hafıza. Bunları otomatikleştirmek istiyorsan
tarayıcıyı sürmek gerekir.

Asıl sebep ise şu: **tek bir ajanın hem prompt yazıp hem tarayıcı sürüp hem yanıtı değerlendirmesi
iki şeyi bozuyor.** Yöneticinin bağlamı ham yanıtlarla doluyor; daha kötüsü, taşıma ile yorum aynı
elde birleştiği için "model gerçekte ne dedi" ile "ajan ne anladı" ayırt edilemez hale geliyor.
Bu hat o ikisini zorla ayırır.

---

## Mimari: dört rol

```
    yönetici                             konuları belirler, hattı kurar, LOGLARI denetler
          │  konu brief'i
          ▼
    düzenleyici-2  (güçlü akıl yürüten)  brief → gerçek prompt dosyaları
          │  prompt                       ↳ yazdığı her prompt vault'a loglanır
          ▼
    taşıyıcı       (hızlı/ucuz model)    arayüzü sürer, dönen çıktıyı BİREBİR kaydeder
          │  ham kayıt                    ↳ yorumlamaz, özetlemez, düzeltmez
          ▼
    düzenleyici-1  (güçlü akıl yürüten)  düzenler + iddiaları GERÇEK REPOYA karşı doğrular, puanlar
          │  düzenli sürüm + değerlendirme
          ▼
    yönetici                             `vlog.py ozet` ile denetler; ham metne ancak çelişkide iner
```

| Rol | Model tipi | İşi | Kesinlikle yapmadığı |
|---|---|---|---|
| **Yönetici** | Orkestratör ajan | Konu seçimi, hattın kurulumu, denetim | Ham yanıtları okumaz |
| **Düzenleyici-2** | Güçlü akıl yürüten | Prompt yazımı ve dağıtımı | Arayüze dokunmaz |
| **Taşıyıcı** (konu başına 1) | Hızlı/ucuz | Arayüzü sürme, birebir kayıt | Yorumlamaz, düzeltmez |
| **Düzenleyici-1** | Güçlü akıl yürüten | Düzenleme, doğrulama, puanlama | Kendi sürücüsünü çalıştırmaz |

Roller ayrı süreçler olarak koşar (ör. bir kodlama CLI'ının `exec` kipiyle, her biri kendi görev
dosyasıyla). Referans kurulumumda taşıyıcılar ucuz/hızlı bir modelle, düzenleyiciler yüksek akıl
yürütme ayarlı güçlü bir modelle çalışıyor.

**Neden taşıyıcı ucuz model?** Taşıma işi düşünmeyi değil *sadakati* ister: komutu çalıştır, çıkan
metni değiştirmeden kaydet. Düzenleme işi tersine yargı ister — iddiayı repoya karşı sına, yolu
düzelt, riskin şiddetini kalibre et.

**Ham kayıt kutsaldır.** Taşıyıcının yazdığı dosya `ham: true` frontmatter'ı ve "BİREBİR KOPYA"
uyarısıyla durur. Düzenleyici onu **değiştirmez**, yanına ayrı bir sürüm yazar. Böylece "model
gerçekten bunu mu dedi, yoksa düzenleyici mi ekledi" sorusu her zaman yanıtlanabilir.

---

## Loglama

Bütün roller `scripts/vlog.py` üzerinden yazar. Tek giriş noktası olması logların tek biçimde
kalmasını ve yöneticinin **ham metne inmeden** hattı denetlemesini sağlar.

```bash
V=/path/to/vault

# taşıyıcı: birebir kaydı logla
python3 vlog.py yaz --vault "$V" --rol tasiyici --model <model> \
  --tur ham --ham --konu "07-telemetri" --dosya ./ham/<id>.md

# düzenleyici-2: yazdığı prompt'u logla  → yöneticinin prompt takibi buradan
python3 vlog.py yaz --vault "$V" --rol duzenleyici-2 --model <model> \
  --tur prompt --konu "07-telemetri" --dosya ./prompt.md

# her rol, her adım: yalın olay
python3 vlog.py olay --vault "$V" --rol tasiyici --model <model> \
  --eylem gonderim --konu "07-telemetri" --sonuc ok --sure 412 --not "36k karakter"

# YÖNETİCİNİN DENETİM GÖRÜNÜMÜ
python3 vlog.py ozet --vault "$V" --son 40
```

Vault'ta oluşan yapı:

```
7 Log/olaylar.jsonl   append-only: zaman, rol, model, eylem, konu, sonuç, süre, artefakt
7 Log/promptlar/      düzenleyici-2'nin yazdığı her prompt
7 Log/ham/            taşıyıcının birebir kayıtları — ham: true, değiştirilmesi yasak
7 Log/duzenli/        düzenleyici-1'in düzeltilmiş sürümleri
7 Log/notlar/         karar kayıtları
```

Vault'u gezilebilir hale getiren üreteç (kapsama matrisi, rol bazlı olay tablosu, wikilink'li notlar)
**projeye özeldir** ve her araştırmanın kendi deposunda durur; burada genel bir sürümü yoktur.

---

## Dosyalar

| Dosya | Ne yapar |
|---|---|
| `SKILL.md` | Hattın tam iş akışı — orkestratör ajanın okuyacağı tanım, tuzaklar, dersler |
| `scripts/vlog.py` | Ortak kayıt aracı: `olay` / `yaz` / `ozet` |
| `scripts/sablonlar/*.md` | Üç rolün görev şablonları; `{{...}}` doldurulup ajana verilir |
| `paketleme/` | Depoyu alt sistem bazlı, sır taramasından geçmiş zip bundle'lara bölen skill |

## "Koda erişimli tur" ve güncelleme akışı

Modelin genel bilgiyle değil **senin gerçek kodunla** cevap vermesi için kaynak kodu sohbet
ortamına yüklemek gerekir. İki adım:

1. **Paketle** — `paketleme/paketle.sh` depoyu alt sisteme göre zip'lere böler
   (`node_modules` yok, ikili varlık yok, sır taraması geçilmiş).
2. **Kalıcı kaynaklara yükle** — bundle'ları sohbet ortamının *kalıcı* dosya deposuna koy.

Kullanıcı **"güncelle"** dediğinde tek akış çalışır: yeniden paketle → eski bundle'ları sil →
yenilerini yükle → sayfayı baştan yükleyip doğrula. Silme adımı şart, yoksa servis dosyayı
değiştirmez, yanına `(1)`, `(2)` ekli kopyalar biriktirir.

### Kalıcı yükleme neden "çalışmıyor" görünür (çözüldü)

Bu, hattın en çok zaman yediren tuzağıydı: yükleme başarılı görünüyor, dosya listede beliriyor,
**sayfa yenilenince kayboluyordu.**

Sebep: sayfada birden çok gizli dosya girdisi var ve menüden ilerleyen yükleme akışı çoğu zaman
**mesaj kutusunun (composer) girdisine** düşüyor — o da kalıcı depo değil, o anki mesaja iliştirilen
geçici ek. Çözüm, girdiyi menüye değil DOM'a bakarak seçmek:

- Önce **kalıcı kaynaklar sekmesine geç** — hedef girdi yalnız o sekme açıkken DOM'da bulunur.
- Yükleme girdisini **o panelin içinden** seç (panelin kapsayıcısına göre), formun/composer'ın
  içindeki genel yükleme girdisini değil.
- Yüklemeden sonra **sayfayı baştan yükleyip listeyi tekrar oku.** Geçici ek bu sınavı geçemez;
  doğrulaman bu olmalı, anlık DOM değil.

İki ek ayrıntı, ikisi de ölçüldü:

- **Satır menüsü gerçek fare tıklamasıyla açılmıyor**, DOM `click()` ile açılıyor — düğme
  koordinatında bir kaplama olayı yakalıyor. Silme akışı bu yüzden sentetik tıklama ister.
- Silinen bir dosyanın adı bir süre "meşgul" kalabilir; aynı adla yeniden yükleyince `(1)` eki gelir.
  Karşılaştırmalarını **kopya ekini atarak** yap, yoksa güncellediğin dosyayı bulamazsın.

---

## Sürücüden beklenenler (sözleşme)

Arayüzü fiilen süren script bu repoda yok; onu kendi kurulumuna göre yaz (ya da ajanına yazdır).
Hattın çalışması için karşılaması gereken sözleşme:

1. **Oturum**: kullanıcının kendi giriş yapmış tarayıcı oturumunu kullan. Şifre ya da API anahtarı
   isteme. Oturum sırlarını **asla** terminale basma, yalnız dosyaya yaz, o dosyayı `.gitignore`'la.
2. **Gönderim**: çok satırlı metni tek parça olarak yaz (satır sonlarında tuş basımı simüle etme —
   yarım gönderim olur), gönder, ve **sohbetin gerçekten oluştuğunu doğrula**.
3. **Okuma**: yanıtın akışı bittiğinde metni döndür; bitişi hem "durdur" göstergesinin kaybolmasına
   hem metnin birkaç saniye sabit kalmasına bakarak anla.
4. **Takip turu**: aynı sohbette devam edebil (bağlam orada durduğu için yeni sohbet açmak kayıptır).
5. **Dürüst raporlama**: kaç karakter alındığını ve gönderimin tutup tutmadığını ayrı ayrı bildir.
   Aşağıdaki derslerin çoğu, sürücünün bu konuda yalan söylemesinden çıktı.

---

## Ölçülmüş dersler (bunlar olmadan hat sessizce yalan söyler)

Hepsi gerçek koşularda ölçüldü, tahmin değil.

1. **Aynı hesaptan en çok 2 eşzamanlı akış.** 5 eşzamanlı gönderimden yalnız 2'si tamamlandı;
   diğerleri bağlantı kesilmesiyle yarıda kaldı. Lane'leri kaydırmalı başlat.

2. **"0 karakter / kısmi" raporuna inanma.** Akış-bitti tespiti uzun yanıtlarda erken kopar; yanıt
   tarayıcı kapandıktan sonra tamamlanır. Ölçüm: "0 karakter" raporlanan bir sohbet tekrar okununca
   **36.357 karakter** çıktı. *Her "boş" raporundan sonra sohbeti tekrar oku.* Bu adım atlandığı
   için bir başlık bir kez "üretilemedi" diye yanlış işaretlendi ve üç tur boşa harcandı.

3. **Sohbet listesi eşleştirmesi sessizce sıfır dönebilir.** Proje içinden açılan sohbetlerin
   adresi, düz sohbet adresinden farklı biçimdedir; adres eşleştirmen buna takılırsa script hata
   vermeden hiçbir şey okumaz. Okuma tarafında daima en yalın adres biçimini kullan.

4. **Takip gönderimi sessizce başarısız olup ÖNCEKİ turu kaydeder.** Gönderim tutmazsa okuyucu hâlâ
   son yanıtı okur ve bir önceki tur "tur 2" diye kaydedilir. Ölçüm: "tur2" 33.972 bayt, tur1
   34.152 bayt — birebir kopya. *Tur N'in boyutunu N-1 ile karşılaştır; %5'ten yakınsa tur
   gitmemiştir.*

5. **Taşıyıcıya "makul mü" diye sorma, sayısal eşik ver.** İlk taşıyıcı testinde 44 KB'lık bir
   sohbetten 52 karakterlik bir arayüz hata ekranı geldi ve taşıyıcı bunu `ok` diye raporladı.
   Şablona mutlak kapı eklendi: **<2000 karakter → başarısız**, ve bilinen arayüz hata metinleri
   yanıt sayılmaz. İkinci test tek denemede 31.768 karakteri temiz taşıdı.

6. **Yüklenen arşivlerin yolları repo yollarıyla aynı değil.** Kod bundle'ları dizin yapısını
   düzleştirdiği için model **satır numarasını doğru, dosya yolunu yanlış** verir. İki bağımsız
   koşuda ölçüldü (ör. bir bileşen `components/` altında gösterildi, gerçekte `views/` altındaydı).
   Düzenleyici-1 rolü tam da bu yüzden zorunlu: her atfı gerçek repoda arar, düzeltir,
   doğrulanamayanı işaretler.

7. **Model doğru yeri gösterir, şiddeti abartır.** Bir tur "çift merge riski" diye raporladı; kod
   okununca ikinci merge'ün boş diff yüzünden zararsız bir no-op olduğu, gerçek kusurun veri kaybı
   değil *durum tutarsızlığı* olduğu görüldü. Şiddet kalibrasyonu düzenleyicinin işidir.

**Ölçülen fayda tarafı:** taşıyıcının aldığı kayıt, daha önce elle alınmış bir kopyayla karakter
karakter karşılaştırıldı — gövde birebir aynı çıktı; tek fark eski kopyanın sonuna karışmış bir
bağlantı-kesildi uyarısıydı. Yani taşıyıcı hiçbir şey eklemedi/çıkarmadı ve üstelik eski artefaktın
bozuk olduğunu ortaya çıkardı.

---

## Sınırlar

- Bir sohbet arayüzünü tarayıcı oturumuyla otomatikleştirmek, o servisin kullanım şartlarına aykırı
  olabilir ve bot korumasına takılabilir. Hesap kullanıcınındır; kararı o verir.
- Derin araştırma / özel kipler genelde arayüzden elle seçilir; sürücü normal mesaj gönderir.
- Kalıcı dosya yükleme (proje kaynakları) otomasyonu kırılgandır: yükleme çoğu zaman kalıcı depo
  yerine geçici ek olarak düşer ve sayfa yenilenince kaybolur. Güvenilir yol, kullanıcının elle
  yüklemesi ve sonra doğrulanmasıdır.
- Referans kurulum Linux + tek makinedir; yollar ve keyring erişimi buna göredir.

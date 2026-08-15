#!/usr/bin/env python3
"""vlog — çok rollü araştırma hattının ortak kayıt aracı.

Her rol (yönetici, düzenleyici, taşıyıcı) yaptığı her işi BU araçla kaydeder.
Tek giriş noktası olması şart: yönetici ajan ham yanıtları okumadan da hattın
ne yaptığını buradan denetleyebilsin diye.

İki şey yazar:
  1) append-only olay kaydı  → <vault>/7 Log/olaylar.jsonl
  2) (isteğe bağlı) artefakt → <vault>/7 Log/<tur>/<zaman>-<konu>.md  (frontmatter'lı)

Kullanım:
  vlog.py olay   --vault V --rol tasiyici --model <model> --eylem gonderim \
                 --konu 07-telemetri --sonuc ok --sure 412 --not "36k karakter"
  vlog.py yaz    --vault V --rol duzenleyici-2 --model <model> --tur prompt \
                 --konu 07-telemetri --dosya /tmp/prompt.md [--sohbet URL] [--ham]
  vlog.py ozet   --vault V [--son 30]        # yöneticinin denetim görünümü (kısa)

`--ham` bayrağı "bu içerik birebir kopyadır, düzenlenmemiştir" demektir; taşıyıcı
taşıyıcıları DAİMA bu bayrakla yazar, düzenleyiciler asla.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import re
from pathlib import Path

TURLER = {
    "prompt": "promptlar",   # düzenleyici-2'nin yazdığı prompt
    "ham": "ham",            # taşıyıcının birebir aldığı çıktı
    "duzen": "duzenli",      # düzenleyici-1'in düzenlediği sürüm
    "not": "notlar",         # serbest not / karar kaydı
}


def slug(s: str) -> str:
    s = re.sub(r"[^\w\s-]", "", s, flags=re.UNICODE).strip().lower()
    return re.sub(r"[\s_]+", "-", s)[:60] or "adsiz"


def log_dir(vault: Path) -> Path:
    d = vault / "7 Log"
    d.mkdir(parents=True, exist_ok=True)
    return d


def olay_yaz(vault: Path, **alan) -> None:
    alan["zaman"] = dt.datetime.now().isoformat(timespec="seconds")
    with (log_dir(vault) / "olaylar.jsonl").open("a", encoding="utf-8") as f:
        f.write(json.dumps(alan, ensure_ascii=False) + "\n")


def cmd_olay(a: argparse.Namespace) -> None:
    vault = Path(a.vault)
    olay_yaz(vault, rol=a.rol, model=a.model, eylem=a.eylem, konu=a.konu,
             sonuc=a.sonuc, sure_sn=a.sure, aciklama=a.not_, artefakt=None)
    print(f"olay: {a.rol}/{a.eylem}/{a.konu} → {a.sonuc}")


def cmd_yaz(a: argparse.Namespace) -> None:
    vault = Path(a.vault)
    src = Path(a.dosya)
    metin = src.read_text(encoding="utf-8")
    ts = dt.datetime.now().strftime("%Y-%m-%d %H%M")
    klasor = log_dir(vault) / TURLER[a.tur]
    klasor.mkdir(parents=True, exist_ok=True)
    hedef = klasor / f"{ts} {slug(a.konu)}.md"

    fm = [
        "---",
        f"tags:\n  - log/{a.tur}\n  - rol/{slug(a.rol)}",
        f"rol: {a.rol}",
        f"model: {a.model}",
        f"konu: {a.konu}",
        f"tur: {a.tur}",
        f"zaman: {dt.datetime.now().isoformat(timespec='seconds')}",
        f"karakter: {len(metin)}",
        f"ham: {'true' if a.ham else 'false'}",
    ]
    if a.sohbet:
        fm.append(f"sohbet: {a.sohbet}")
    if a.kaynak:
        fm.append(f"kaynak: {a.kaynak}")
    fm.append("---")

    uyari = ("> [!warning] BİREBİR KOPYA — düzenlenmemiştir. Değiştiren, kaydı geçersiz kılar.\n\n"
             if a.ham else "")
    hedef.write_text("\n".join(fm) + "\n\n" + uyari + metin.rstrip() + "\n", encoding="utf-8")

    olay_yaz(vault, rol=a.rol, model=a.model, eylem=f"yaz:{a.tur}", konu=a.konu,
             sonuc="ok", sure_sn=None, aciklama=f"{len(metin)} karakter",
             artefakt=str(hedef.relative_to(vault)))
    print(f"yazildi: {hedef}")


def cmd_ozet(a: argparse.Namespace) -> None:
    vault = Path(a.vault)
    yol = log_dir(vault) / "olaylar.jsonl"
    if not yol.exists():
        print("kayit yok")
        return
    satirlar = [json.loads(x) for x in yol.read_text(encoding="utf-8").splitlines() if x.strip()]
    for o in satirlar[-a.son:]:
        sure = f" {o['sure_sn']}sn" if o.get("sure_sn") else ""
        art = f" → {o['artefakt']}" if o.get("artefakt") else ""
        print(f"{o['zaman']} [{o['rol']}/{o.get('model','-')}] {o['eylem']} "
              f"{o['konu']} = {o['sonuc']}{sure}{art}")
    hatalar = [o for o in satirlar if o.get("sonuc") not in ("ok", None)]
    print(f"\ntoplam {len(satirlar)} olay, {len(hatalar)} sorunlu")


def main() -> None:
    p = argparse.ArgumentParser(description="araştırma hattı kayıt aracı")
    alt = p.add_subparsers(dest="komut", required=True)

    o = alt.add_parser("olay", help="tek satırlık olay kaydı")
    o.add_argument("--vault", required=True)
    o.add_argument("--rol", required=True)
    o.add_argument("--model", default="-")
    o.add_argument("--eylem", required=True)
    o.add_argument("--konu", required=True)
    o.add_argument("--sonuc", default="ok")
    o.add_argument("--sure", type=int, default=None)
    o.add_argument("--not", dest="not_", default="")
    o.set_defaults(fn=cmd_olay)

    y = alt.add_parser("yaz", help="artefakt + olay kaydı")
    y.add_argument("--vault", required=True)
    y.add_argument("--rol", required=True)
    y.add_argument("--model", default="-")
    y.add_argument("--tur", required=True, choices=list(TURLER))
    y.add_argument("--konu", required=True)
    y.add_argument("--dosya", required=True)
    y.add_argument("--sohbet", default=None)
    y.add_argument("--kaynak", default=None)
    y.add_argument("--ham", action="store_true")
    y.set_defaults(fn=cmd_yaz)

    z = alt.add_parser("ozet", help="yöneticinin denetim görünümü")
    z.add_argument("--vault", required=True)
    z.add_argument("--son", type=int, default=30)
    z.set_defaults(fn=cmd_ozet)

    a = p.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()

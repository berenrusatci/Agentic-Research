#!/usr/bin/env bash
# Depoyu, bir sohbet modelinin gezebileceği alt sistem bazlı zip'lere böler.
#
#   PROJE=/path/to/repo ./paketle.sh
#
# Yapılandırma yoksa otomatik algılar: workspace paketleri (apps/*, packages/*,
# services/*, libs/*, ve npm workspaces), şema-yalnız bir db bundle'ı, bir docs bundle'ı.
# Tek paketli depo tek `src` bundle'ı alır.
set -euo pipefail

PROJE="${PROJE:-$PWD}"
CIKTI="${CIKTI:-$PROJE/paket-bundles}"
ONEK="${ONEK:-$(basename "$PROJE")}"
KONF="${KONF:-$(dirname "${BASH_SOURCE[0]}")/bundles.conf}"
SIRRA_IZIN="${SIRRA_IZIN:-0}"

HARIC=(.git node_modules .next .turbo dist build out coverage .vercel target
       __pycache__ .venv .pytest_cache .mypy_cache)
HARIC_DESEN=('*.tsbuildinfo' '.env' '.env.*' '*.log' '.DS_Store' '*.png' '*.jpg' '*.jpeg'
             '*.gif' '*.webp' '*.svg' '*.ico' '*.mp4' '*.mov' '*.woff' '*.woff2' '*.ttf'
             '*.otf' '*.pdf' '*.zip' '*.tar.gz' '*.so' '*.dylib' '*.wasm')

declare -a BUNDLE_ADLARI=()
declare -A BUNDLE_ACIKLAMA=() BUNDLE_KAYNAK=()

# define_bundle <ad> "<açıklama>" <dir:yol|file:yol[:altdizin]>...
define_bundle() {
  local ad="$1" aciklama="$2"; shift 2
  BUNDLE_ADLARI+=("$ad"); BUNDLE_ACIKLAMA["$ad"]="$aciklama"; BUNDLE_KAYNAK["$ad"]="$*"
}

otomatik_algila() {
  local bulundu=0
  for kok in apps packages services libs; do
    [[ -d "$PROJE/$kok" ]] || continue
    for d in "$PROJE/$kok"/*/; do
      [[ -d "$d" ]] || continue
      local ad; ad="$(basename "$d")"
      define_bundle "$ad" "$kok/$ad paketi" "dir:$kok/$ad"; bulundu=1
    done
  done
  # npm workspace kökündeki klasik üçlü
  for d in shared server web client api core; do
    [[ -d "$PROJE/$d" && -f "$PROJE/$d/package.json" ]] || continue
    define_bundle "$d" "$d workspace'i" "dir:$d"; bulundu=1
  done
  # Şema dizini kökte olmayabilir (ör. server/prisma) — bir seviye derine de bak.
  local db_var=0
  for sema in prisma db/migrations supabase/migrations migrations drizzle \
              */prisma */migrations */db/migrations; do
    [[ $db_var -eq 1 ]] && break
    for aday in $PROJE/$sema; do
      [[ -d "$aday" ]] || continue
      define_bundle db "şema mimarisi — satır/seed verisi yok" "dir:${aday#"$PROJE/"}"
      db_var=1; break
    done
  done
  local dok=(); for d in docs adrs doc; do [[ -d "$PROJE/$d" ]] && dok+=("dir:$d"); done
  for f in README.md CLAUDE.md AGENTS.md CONTRIBUTING.md ARCHITECTURE.md; do
    [[ -f "$PROJE/$f" ]] && dok+=("file:$f")
  done
  ((${#dok[@]})) && define_bundle docs "mimari ve kural bağlamı" "${dok[@]}"
  if [[ $bulundu -eq 0 ]]; then
    local src; for src in src lib app; do
      [[ -d "$PROJE/$src" ]] && { define_bundle src "tek paketli depo kaynağı" "dir:$src"; break; }
    done
  fi
}

kopyala() {
  local hedef="$1"; shift
  local -a rs=(-a)
  for e in "${HARIC[@]}"; do rs+=(--exclude "$e"); done
  for e in "${HARIC_DESEN[@]}"; do rs+=(--exclude "$e"); done
  for kaynak in "$@"; do
    case "$kaynak" in
      dir:*)  local yol="${kaynak#dir:}"
              [[ -d "$PROJE/$yol" ]] || { echo "  ! yok: $yol" >&2; continue; }
              mkdir -p "$hedef/$yol"; rsync "${rs[@]}" "$PROJE/$yol/" "$hedef/$yol/" ;;
      file:*) local rest="${kaynak#file:}" yol alt
              yol="${rest%%:*}"; alt="${rest#"$yol"}"; alt="${alt#:}"
              [[ -f "$PROJE/$yol" ]] || { echo "  ! yok: $yol" >&2; continue; }
              mkdir -p "$hedef/${alt:-$(dirname "$yol")}"
              cp "$PROJE/$yol" "$hedef/${alt:-$(dirname "$yol")}/" ;;
      *) echo "  ! tanınmayan kaynak: $kaynak" >&2 ;;
    esac
  done
}

# İki katmanlı sır taraması. Tek katmanlı tarama gerçek depoda tamamen yanlış pozitif
# üretir; her koşuda SIRRA_IZIN=1 verirsin ve tarama olmamış olur.
SERT='BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{50,}|xox[baprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{30,}|sk-[A-Za-z0-9_-]{30,}|eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.'
YUMUSAK='(secret|password|passwd|api_?key|token)[[:space:]]*[:=][[:space:]]*["'\''][^"'\'']{8,}'
YER_TUTUCU='FAKE|EXAMPLE|PLACEHOLDER|CHANGEME|xxxxxxxx|your-|<[a-z_]+>|env\('

tara() {
  local dizin="$1" sert=0
  while IFS= read -r hit; do
    local dosya="${hit%%:*}"
    if [[ "$dosya" =~ (test|__tests__|fixtures|spec|example|sample) ]] || \
       grep -qE "$YER_TUTUCU" <<<"$hit"; then
      echo "  yumuşak (test/örnek): ${hit:0:110}"
    else
      echo "  SERT: ${hit:0:110}"; sert=1
    fi
  done < <(grep -rEIn "$SERT" "$dizin" 2>/dev/null | head -40)
  grep -rEIn "$YUMUSAK" "$dizin" 2>/dev/null | head -10 | while IFS= read -r h; do
    echo "  yumuşak: ${h:0:110}"
  done
  return $sert
}

[[ -f "$KONF" ]] && { echo "yapılandırma: $KONF"; # shellcheck disable=SC1090
                      source "$KONF"; } || { echo "yapılandırma yok → otomatik algılama"; otomatik_algila; }
((${#BUNDLE_ADLARI[@]})) || { echo "hiç bundle tanımlanmadı" >&2; exit 1; }

mkdir -p "$CIKTI"; rm -f "$CIKTI"/*.zip
GECICI="$(mktemp -d)"; trap 'rm -rf "$GECICI"' EXIT
HATA=0

for ad in "${BUNDLE_ADLARI[@]}"; do
  echo "── $ad — ${BUNDLE_ACIKLAMA[$ad]}"
  sahne="$GECICI/$ad"; mkdir -p "$sahne"
  # shellcheck disable=SC2086
  kopyala "$sahne" ${BUNDLE_KAYNAK[$ad]}
  printf '# %s\n\n%s\n\nDepodan üretildi: %s\n' "$ad" "${BUNDLE_ACIKLAMA[$ad]}" \
    "$(date -I)" > "$sahne/BUNDLE.md"
  if ! tara "$sahne"; then
    if [[ "$SIRRA_IZIN" != "1" ]]; then
      echo "!! SERT sır bulgusu — durduruldu. Hepsini okuyup SIRRA_IZIN=1 ile geç." >&2
      HATA=1; continue
    fi
    echo "  (SIRRA_IZIN=1 — devam ediliyor)"
  fi
  (cd "$sahne" && zip -qr "$CIKTI/$ONEK-$ad.zip" .)
  echo "  → $ONEK-$ad.zip ($(du -h "$CIKTI/$ONEK-$ad.zip" | cut -f1), \
$(find "$sahne" -type f | wc -l) dosya)"
done

echo; echo "çıktı: $CIKTI"; ls -1 "$CIKTI"/*.zip 2>/dev/null | sed 's|.*/|  |'
exit $HATA

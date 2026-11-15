#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# tools/watermark.sh — marquage d'une livraison de code
#
# Produit trois choses à chaque remise :
#   1. lib/watermark.g.dart          identifiant de livraison compilé dans l'app
#   2. <out>/ANNEXE-A.md             inventaire daté + empreinte SHA-256
#   3. en-têtes de copyright         ajoutés dans chaque fichier source
#
# Le but n'est pas d'empêcher la copie (impossible) mais de la rendre prouvable :
# si le code réapparaît ailleurs, l'identifiant et l'empreinte établissent le lien.
#
# Usage :
#   tools/watermark.sh --client "Société ABC SARL"                 # simulation
#   tools/watermark.sh --client "Société ABC SARL" --apply         # écrit vraiment
#   tools/watermark.sh --client "..." --apply --out build/delivery # dossier de sortie
# -----------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CLIENT=""
APPLY=0
OUT=""
SOURCES=("lib" "backend/backend/src")

if [ -t 1 ]; then BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'
  GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RESET=$'\033[0m'
else BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; RESET=""; fi

usage() {
  cat <<'EOF'
Marque une livraison de code : identifiant, en-têtes, inventaire et empreinte.

Usage : tools/watermark.sh --client "<nom du client>" [options]

  -c, --client <nom>   Bénéficiaire de la livraison (obligatoire)
  -o, --out <dossier>  Où écrire les pièces (défaut : build/delivery/<id>)
      --apply          Écrit réellement (sans ce drapeau : simulation seule)
      --sources <dir>  Dossiers à marquer (défaut : lib backend/backend/src), répétable
  -h, --help           Cette aide

Sans --apply, rien n'est modifié dans le code : seuls les fichiers de la
livraison sont générés, pour inspection.
EOF
}

die() { printf '%serreur%s : %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }
step() { printf '\n%s▸ %s%s\n' "$BOLD" "$1" "$RESET"; }

while [ $# -gt 0 ]; do
  case "$1" in
    -c|--client) [ $# -ge 2 ] || die "valeur manquante pour $1"; CLIENT="$2"; shift 2 ;;
    -o|--out)    [ $# -ge 2 ] || die "valeur manquante pour $1"; OUT="$2"; shift 2 ;;
    --sources)   [ $# -ge 2 ] || die "valeur manquante pour $1"; SOURCES+=("$2"); shift 2 ;;
    --apply)     APPLY=1; shift ;;
    -h|--help)   usage; exit 0 ;;
    *)           die "option inconnue : $1 (voir --help)" ;;
  esac
done

[ -n "$CLIENT" ] || die "--client est obligatoire (nom du bénéficiaire de la livraison)."
[ -f "$APP_ROOT/pubspec.yaml" ] || die "pubspec.yaml introuvable : le script doit rester dans <projet>/tools/."

cd "$APP_ROOT"

STAMP_DAY="$(date -u +%Y%m%d)"
STAMP_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo 'sans-git')"
SEED="$(printf '%s|%s|%s' "$CLIENT" "$STAMP_ISO" "$COMMIT")"
SUFFIX="$(printf '%s' "$SEED" | shasum -a 256 | cut -c1-4 | tr 'a-f' 'A-F')"
DELIVERY_ID="EG39-${STAMP_DAY}-${SUFFIX}"
FINGERPRINT="$(printf '%s' "$SEED" | shasum -a 256 | cut -c1-16)"
HEADER="// © $(date +%Y) ÉCHELLE EG39 — Tous droits réservés — ${DELIVERY_ID}"

[ -n "$OUT" ] || OUT="build/delivery/$DELIVERY_ID"
mkdir -p "$OUT"

# --- 1. Constante compilée dans l'application -------------------------------
WATERMARK_FILE="$APP_ROOT/lib/watermark.g.dart"
step "Identifiant de livraison"
printf '  %s\n' "$DELIVERY_ID"
printf '  client      : %s\n' "$CLIENT"
printf '  empreinte   : %s\n' "$FINGERPRINT"
printf '  commit      : %s\n' "$COMMIT"

if [ "$APPLY" -eq 1 ]; then
  cat > "$WATERMARK_FILE" <<EOF
// © $(date +%Y) ÉCHELLE EG39 — Tous droits réservés. Reproduction interdite.
// Livraison ${DELIVERY_ID} — bénéficiaire : ${CLIENT} — ${STAMP_ISO}
// Fichier généré par tools/watermark.sh : ne pas modifier à la main.
class BuildWatermark {
  const BuildWatermark._();

  static const String owner = 'ÉCHELLE EG39';
  static const String licensee = '${CLIENT}';
  static const String deliveryId = '${DELIVERY_ID}';
  static const String deliveredAt = '${STAMP_ISO}';
  static const String sourceCommit = '${COMMIT}';
  static const String sourceFingerprint = '${FINGERPRINT}';
}
EOF
  printf '  %s✓%s lib/watermark.g.dart écrit\n' "$GREEN" "$RESET"
else
  printf '  %s(simulation : lib/watermark.g.dart serait écrit)%s\n' "$DIM" "$RESET"
fi

# --- 2. En-têtes de copyright sur les fichiers source -----------------------
step "En-têtes de copyright"
TOTAL=0
TOUCHED=0
ALREADY=0
for dir in "${SOURCES[@]}"; do
  [ -d "$APP_ROOT/$dir" ] || continue
  while IFS= read -r file; do
    TOTAL=$((TOTAL + 1))
    first3="$(head -n 3 "$file" 2>/dev/null || true)"
    case "$first3" in
      *"ÉCHELLE EG39 — Tous droits réservés"*) ALREADY=$((ALREADY + 1)); continue ;;
      '#!'*) continue ;;
    esac
    if [ "$APPLY" -eq 1 ]; then
      { printf '%s\n\n' "$HEADER"; cat "$file"; } > "$file.tmp.$$"
      mv "$file" "$file.bak.$$" && mv "$file.tmp.$$" "$file" && rm -f "$file.bak.$$"
    fi
    TOUCHED=$((TOUCHED + 1))
  done < <(find "$APP_ROOT/$dir" -type f \( -name '*.dart' -o -name '*.js' \) \
             ! -path '*/build/*' -not -name '*.g.dart' -print)
done
printf '  fichiers examinés : %s\n' "$TOTAL"
printf '  à marquer         : %s\n' "$TOUCHED"
printf '  déjà marqués      : %s\n' "$ALREADY"
if [ "$APPLY" -eq 0 ]; then
  printf '  %s(simulation : aucun fichier modifié)%s\n' "$DIM" "$RESET"
fi

# --- 3. Inventaire et empreinte --------------------------------------------
step "Pièces de livraison"
ARCHIVE="$OUT/echelle-eg39-${DELIVERY_ID}.zip"
if [ "$APPLY" -eq 1 ]; then
  ( cd "$APP_ROOT" && zip -r -q -X "$ARCHIVE" lib backend/backend/src pubspec.yaml docs \
      -x '*/build/*' '*.g.dart' ) || printf '  %s!%s archive non créée (zip absent ?)\n' "$YELLOW" "$RESET"
fi

if [ -f "$ARCHIVE" ]; then
  ARCHIVE_HASH="$(shasum -a 256 "$ARCHIVE" | cut -d' ' -f1)"
  ARCHIVE_SIZE="$(du -h "$ARCHIVE" | cut -f1)"
  printf '  archive : %s (%s)\n' "$(basename "$ARCHIVE")" "$ARCHIVE_SIZE"
else
  ARCHIVE_HASH="(archive non générée en simulation)"
  ARCHIVE_SIZE="—"
fi

cat > "$OUT/ANNEXE-A.md" <<EOF
# Annexe A — Inventaire de la livraison

| Champ | Valeur |
| --- | --- |
| Identifiant de livraison | \`${DELIVERY_ID}\` |
| Bénéficiaire | ${CLIENT} |
| Date de livraison (UTC) | ${STAMP_ISO} |
| Commit source | \`${COMMIT}\` |
| Empreinte de livraison | \`${FINGERPRINT}\` |
| Archive | \`$(basename "$ARCHIVE")\` (${ARCHIVE_SIZE}) |
| SHA-256 de l'archive | \`${ARCHIVE_HASH}\` |
| Fichiers source marqués | ${TOUCHED} |

## Vérification

\`\`\`sh
shasum -a 256 $(basename "$ARCHIVE")
\`\`\`

L'empreinte obtenue doit être identique à celle du tableau ci-dessus.

## Portée

Le code livré porte l'identifiant \`${DELIVERY_ID}\` dans ses en-têtes de
fichiers et dans la constante \`BuildWatermark.deliveryId\` compilée dans
l'application. La suppression de ces mentions constitue une altération au sens
du contrat de livraison.
EOF

printf '%s\n' "$ARCHIVE_HASH  $(basename "$ARCHIVE")" > "$OUT/ANNEXE-A.sha256"
printf '  %s✓%s %s\n' "$GREEN" "$RESET" "${OUT#"$APP_ROOT"/}/ANNEXE-A.md"
printf '  %s✓%s %s\n' "$GREEN" "$RESET" "${OUT#"$APP_ROOT"/}/ANNEXE-A.sha256"

printf '\n%sLivraison %s prête.%s\n' "$BOLD" "$DELIVERY_ID" "$RESET"
[ "$APPLY" -eq 1 ] && printf 'Code marqué et pièces écrites. Ne pas oublier de committer lib/watermark.g.dart.\n' \
                   || printf 'Simulation : relancez avec --apply pour marquer réellement le code.\n'

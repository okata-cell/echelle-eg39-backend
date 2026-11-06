#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# tools/build_iphone.sh
#
# Compile l'application et la réinstalle sur l'iPhone physique connecté,
# en une seule commande.
#
# Pourquoi ce script existe :
#   - Sur cet iPhone la session debug n'attache jamais le VM Service, et iOS
#     refuse de démarrer un bundle debug hors outillage. Seule une build
#     release s'installe ET se relance depuis l'écran d'accueil.
#   - Le profil de provisionnement (équipe personnelle gratuite) n'est valable
#     que 7 jours : relancer ce script renouvelle la signature.
#
# Exemples :
#   tools/build_iphone.sh                  # release sur l'iPhone connecté
#   tools/build_iphone.sh --list           # voit les appareils détectés
#   tools/build_iphone.sh --simulator      # simulateur, debug + hot reload
#   tools/build_iphone.sh --fresh          # flutter clean puis rebuild
#   tools/build_iphone.sh -n               # n'exécute rien, affiche la commande
# -----------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_SIM_NAME="iPhone 15 Pro Max"

MODE="release"
DEVICE_ID="${IPHONE_UDID:-}"
TARGET_SIM=0
FRESH=0
DRY_RUN=0
LIST_ONLY=0
FLAVOR=""
DEFINES=()

if [ -t 1 ]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'
  GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RESET=$'\033[0m'
else
  BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; RESET=""
fi

usage() {
  cat <<'EOF'
Compile et réinstalle l'app sur l'iPhone physique connecté au Mac.

Usage : tools/build_iphone.sh [options]

Ciblage
  -d, --device <udid|préfixe>   iPhone à cibler (défaut : le seul iPhone connecté)
  -s, --simulator               Cible le simulateur au lieu du téléphone
  -l, --list                    Liste les appareils iOS détectés puis quitte

Compilation
  -m, --mode <release|profile|debug>
                                Mode de compilation (défaut : release)
                                release = recommandé sur appareil physique
  -D, --define <clé=valeur>     Transmet --dart-define (répétable)
      --flavor <nom>            Transmet --flavor
      --fresh                   flutter clean + pub get avant de compiler

Divers
  -n, --dry-run                 Affiche la commande sans rien exécuter
  -h, --help                    Affiche cette aide

Variables d'environnement
  IPHONE_UDID                   Équivalent de --device

Notes
  * Sur appareil physique, la sortie se fait après le lancement (--no-resident)
    pour rendre la main sans arrêter l'application.
  * En mode debug sur appareil physique, la session reste ouverte pour le hot
    reload, mais l'app ne pourra pas être relancée depuis l'écran d'accueil.
EOF
}

step() { printf '\n%s▸ %s%s\n' "$BOLD" "$1" "$RESET"; }
log()  { printf '%s\n' "$*"; }
warn() { printf '%s!%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
die()  { printf '%serreur%s : %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    -d|--device)   [ $# -ge 2 ] || die "valeur manquante pour $1"; DEVICE_ID="$2"; shift 2 ;;
    -m|--mode)     [ $# -ge 2 ] || die "valeur manquante pour $1"; MODE="$2"; shift 2 ;;
    -s|--simulator) TARGET_SIM=1; shift ;;
    -D|--define)   [ $# -ge 2 ] || die "valeur manquante pour $1"; DEFINES+=("$2"); shift 2 ;;
    --flavor)      [ $# -ge 2 ] || die "valeur manquante pour $1"; FLAVOR="$2"; shift 2 ;;
    --fresh)       FRESH=1; shift ;;
    -n|--dry-run)  DRY_RUN=1; shift ;;
    -l|--list)     LIST_ONLY=1; shift ;;
    -h|--help)     usage; exit 0 ;;
    *)             die "option inconnue : $1 (voir --help)" ;;
  esac
done

case "$MODE" in
  release|profile|debug) ;;
  *) die "--mode attend release, profile ou debug (reçu : $MODE)" ;;
esac

cd "$REPO_ROOT"

# --- Pré-requis --------------------------------------------------------------
command -v flutter >/dev/null 2>&1 || die "flutter est introuvable dans le PATH."
command -v xcrun   >/dev/null 2>&1 || die "xcrun est introuvable : installez Xcode et ses outils en ligne de commande."
[ -f "$REPO_ROOT/pubspec.yaml" ] || die "pubspec.yaml introuvable : ce script doit rester dans <projet>/tools/."

# --- Détection des appareils -------------------------------------------------
# Sortie : une ligne par appareil iOS, colonnes séparées par des tabulations
#   udid <TAB> emulator(true|false) <TAB> sdk <TAB> nom
list_ios_devices() {
  local json
  json="$(mktemp "${TMPDIR:-/tmp}/echelle_devices.XXXXXX")"
  if ! flutter devices --machine >"$json" 2>/dev/null; then
    rm -f "$json"
    return 1
  fi
  awk '
    function flush() {
      if (platform == "ios" && id != "") printf "%s\t%s\t%s\t%s\n", id, emu, sdk, name
      id = ""; name = ""; platform = ""; emu = ""; sdk = ""
    }
    /"name":/           { v = $0; sub(/.*"name": *"/, "", v);           sub(/".*/, "", v); name = v }
    /"id":/             { v = $0; sub(/.*"id": *"/, "", v);             sub(/".*/, "", v); id = v }
    /"targetPlatform":/ { v = $0; sub(/.*"targetPlatform": *"/, "", v); sub(/".*/, "", v); platform = v }
    /"emulator":/       { emu = ($0 ~ /true/) ? "true" : "false" }
    /"sdk":/            { v = $0; sub(/.*"sdk": *"/, "", v);            sub(/".*/, "", v); sdk = v; flush() }
    END                 { flush() }
  ' "$json"
  rm -f "$json"
}

list_physical() { list_ios_devices | awk -F'\t' '$2=="false"'; }
list_simulators() { list_ios_devices | awk -F'\t' '$2=="true"'; }

if [ "$LIST_ONLY" -eq 1 ]; then
  step "Appareils iOS détectés"
  devices="$(list_ios_devices || true)"
  if [ -z "$devices" ]; then
    die "aucun appareil iOS détecté. Déverrouillez l'iPhone, vérifiez le câble, puis relancez."
  fi
  printf '%s\n' "$devices" | while IFS=$'\t' read -r udid emu sdk name; do
    if [ "$emu" = "true" ]; then kind="simulateur"; else kind="physique"; fi
    printf '  %-10s %-20s %-38s %s\n' "$kind" "$name" "$udid" "$sdk"
  done
  exit 0
fi

# --- Résolution de la cible --------------------------------------------------
DEVICE_NAME=""
TARGET_LABEL=""

if [ "$TARGET_SIM" -eq 1 ]; then
  step "Recherche des simulateurs"
  sims="$(list_simulators || true)"
  if [ -z "$sims" ]; then
    die "aucun simulateur iOS. Créez-en un dans Xcode > Window > Devices and Simulators."
  fi
  if [ -z "$DEVICE_ID" ]; then
    pick="$(printf '%s\n' "$sims" | grep -F "$DEFAULT_SIM_NAME" | head -n 1 || true)"
    [ -n "$pick" ] || pick="$(printf '%s\n' "$sims" | head -n 1)"
    DEVICE_ID="$(printf '%s' "$pick" | cut -f1)"
  else
    match="$(printf '%s\n' "$sims" | awk -F'\t' -v id="$DEVICE_ID" 'index($1, id) == 1' | head -n 1)"
    [ -n "$match" ] || die "simulateur « $DEVICE_ID » introuvable (voir --list)."
    DEVICE_ID="$(printf '%s' "$match" | cut -f1)"
  fi
  DEVICE_NAME="$(printf '%s\n' "$sims" | awk -F'\t' -v id="$DEVICE_ID" '$1 == id { print $4 }')"
  TARGET_LABEL="simulateur ${DEVICE_NAME:-$DEVICE_ID}"
else
  step "Recherche de l'iPhone connecté"
  devices="$(list_ios_devices || true)"
  if [ -n "$DEVICE_ID" ]; then
    match="$(printf '%s\n' "$devices" | awk -F'\t' -v id="$DEVICE_ID" 'index($1, id) == 1' | head -n 1)"
    [ -n "$match" ] || die "appareil « $DEVICE_ID » introuvable (voir --list)."
    DEVICE_ID="$(printf '%s' "$match" | cut -f1)"
    DEVICE_NAME="$(printf '%s' "$match" | cut -f4)"
  else
    physical="$(printf '%s\n' "$devices" | awk -F'\t' '$2=="false"')"
    count="$(printf '%s' "$physical" | grep -c . || true)"
    if [ "$count" -eq 0 ]; then
      die "aucun iPhone physique détecté. Déverrouillez l'iPhone et vérifiez le câble, ou utilisez --simulator pour itérer sans téléphone."
    elif [ "$count" -gt 1 ]; then
      printf 'Plusieurs iPhone connectés :\n' >&2
      printf '%s\n' "$physical" | awk -F'\t' '{ printf "  %s  %s\n", $1, $4 }' >&2
      die "choisissez-en un avec --device <udid>."
    fi
    DEVICE_ID="$(printf '%s' "$physical" | cut -f1)"
    DEVICE_NAME="$(printf '%s' "$physical" | cut -f4)"
  fi
  TARGET_LABEL="${DEVICE_NAME:-$DEVICE_ID} ($DEVICE_ID)"
  if pgrep -f "flutter_tools.snapshot run" >/dev/null 2>&1; then
    warn "une session « flutter run » semble déjà active ; si l'installation échoue, fermez-la avec la touche q."
  fi
fi

# --- Construction de la commande --------------------------------------------
run_cmd=(flutter run -d "$DEVICE_ID")
EFFECTIVE_MODE="$MODE"
if [ "$TARGET_SIM" -eq 1 ]; then
  # Simulateur : session résidente pour disposer du hot reload.
  EFFECTIVE_MODE="debug"
  run_cmd+=(--debug)
  xcrun simctl boot "$DEVICE_ID" >/dev/null 2>&1 || true
  open -a Simulator >/dev/null 2>&1 || true
else
  case "$MODE" in
    release|profile)
      run_cmd+=("--$MODE" --no-resident) ;;
    debug)
      # Debug sur appareil : session résidente (hot reload). L'app ne sera pas
      # relançable depuis l'écran d'accueil, iOS impose l'outillage.
      run_cmd+=(--debug)
      warn "mode debug sur appareil : hot reload disponible pendant la session, mais l'app devra être relancée par outillage." ;;
  esac
fi
[ -n "$FLAVOR" ] && run_cmd+=(--flavor "$FLAVOR")
if [ "${#DEFINES[@]}" -gt 0 ]; then
  for d in "${DEFINES[@]}"; do
    run_cmd+=(--dart-define "$d")
  done
fi

if [ "$DRY_RUN" -eq 1 ]; then
  step "Simulation (--dry-run)"
  printf '  cible    : %s\n' "$TARGET_LABEL"
  printf '  mode     : %s\n' "$EFFECTIVE_MODE"
  printf '  commande : %s\n' "${run_cmd[*]}"
  [ "$FRESH" -eq 1 ] && printf '  avant    : flutter clean && flutter pub get\n'
  exit 0
fi

# --- Compilation puis installation ------------------------------------------
LOG_DIR="$REPO_ROOT/build/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/build_iphone_$(date +%Y%m%d-%H%M%S).log"
START=$SECONDS

if [ "$FRESH" -eq 1 ]; then
  step "flutter clean + pub get"
  flutter clean >/dev/null
  flutter pub get
fi

step "Compilation $EFFECTIVE_MODE pour $TARGET_LABEL"
log "${DIM}log complet : ${LOG_FILE#"$REPO_ROOT"/}${RESET}"
log "${DIM}comptez ~6-12 min sur appareil physique (pods + Xcode + AOT)${RESET}"

status=0
"${run_cmd[@]}" 2>&1 | tee "$LOG_FILE" || status=${PIPESTATUS[0]}

if [ "$status" -ne 0 ]; then
  printf '\n%sechec%s : la compilation ou l'\''installation a renvoyé le code %s.\n' "$RED" "$RESET" "$status" >&2
  printf 'Dernières lignes du log :\n' >&2
  tail -n 25 "$LOG_FILE" >&2
  exit "$status"
fi

elapsed=$((SECONDS - START))
step "Résultat"
log "  ${GREEN}✓${RESET} build $EFFECTIVE_MODE installée et lancée sur $TARGET_LABEL"
log "  durée : $((elapsed / 60)) min $((elapsed % 60)) s"

# --- Vérifications post-installation (appareil physique uniquement) ----------
if [ "$TARGET_SIM" -eq 0 ]; then
  APP_PATH="$REPO_ROOT/build/ios/iphoneos/Runner.app"

  # L'app tourne-t-elle vraiment ? Si --no-resident l'a laissée en arrière-plan
  # ou si iOS l'a fermée, on la relance explicitement.
  if [ -d "$APP_PATH" ]; then
    bundle_id="$(plutil -extract CFBundleIdentifier raw "$APP_PATH/Info.plist" 2>/dev/null || true)"
    running="$(xcrun devicectl device info processes --device "$DEVICE_ID" 2>/dev/null | grep -c "Runner.app/Runner" || true)"
    if [ "${running:-0}" -gt 0 ]; then
      log "  ${GREEN}✓${RESET} processus actif sur l'appareil"
    elif [ -n "$bundle_id" ] && xcrun devicectl device process launch --device "$DEVICE_ID" "$bundle_id" >/dev/null 2>&1; then
      log "  ${GREEN}✓${RESET} app relancée sur l'appareil ($bundle_id)"
    else
      warn "l'app n'a pas pu être relancée automatiquement : ouvrez-la depuis l'écran d'accueil."
    fi
  fi

  # Validité de la signature : c'est elle qui décide si l'app survivra au
  # débranchement du câble.
  if [ -f "$APP_PATH/embedded.mobileprovision" ]; then
    profile_plist="$(mktemp "${TMPDIR:-/tmp}/echelle_profile.XXXXXX")"
    if security cms -D -i "$APP_PATH/embedded.mobileprovision" >"$profile_plist" 2>/dev/null; then
      expires_at="$(plutil -extract ExpirationDate raw "$profile_plist" 2>/dev/null || true)"
      team="$(plutil -extract TeamName raw "$profile_plist" 2>/dev/null || true)"
      if [ -n "$expires_at" ]; then
        expires_epoch="$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%SZ" "$expires_at" +%s 2>/dev/null || true)"
        if [ -n "$expires_epoch" ]; then
          seconds_left=$(( expires_epoch - $(date +%s) ))
          human="$(date -r "$expires_epoch" '+%d/%m/%Y à %H:%M')"
          if [ "$seconds_left" -le 0 ]; then
            log "  signature : ${team:-équipe inconnue} — profil expiré depuis le $human"
            warn "profil expiré : relancez ce script pour régénérer une signature valable 7 jours."
          elif [ "$seconds_left" -lt 86400 ]; then
            log "  signature : ${team:-équipe inconnue} — valable jusqu'au $human (dans ~$((seconds_left / 3600)) h)"
            warn "profil expirant dans moins de 24 h : après cette heure l'app ne se lancera plus, relancez ce script à ce moment-là."
          else
            log "  signature : ${team:-équipe inconnue} — valable jusqu'au $human ($((seconds_left / 86400)) jour(s))"
          fi
        fi
      fi
    fi
    rm -f "$profile_plist"
  fi
fi

printf '\n%sTerminé.%s L'\''app reste utilisable une fois le câble débranché, jusqu'\''à expiration du profil.\n' "$BOLD" "$RESET"

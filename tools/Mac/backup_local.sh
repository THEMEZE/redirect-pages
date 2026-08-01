#!/bin/bash
# `scp -r`` copie tout bêtement, sans reprise ni delta. Préfère rsync (incrémental, reprend en cas de coupure, exclut ce qui n'a pas besoin d'être sauvegardé) :
# backup_local.sh — à lancer depuis le Mac
#!/bin/bash
set -e

# ── Couleurs ──────────────────────────────────────────────
GREEN='\033[92m'
YELLOW='\033[93m'
RED='\033[91m'
BLUE='\033[94m'
RESET='\033[0m'
BOLD='\033[1m'

ok()   { echo -e "${GREEN}  ✅  $1${RESET}"; }
warn() { echo -e "${YELLOW}  ⚠️   $1${RESET}"; }
err()  { echo -e "${RED}  ❌  $1${RESET}"; exit 1; }
info() { echo -e "${BLUE}  ℹ️   $1${RESET}"; }


echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗"
echo    "║          🚐 Backup RodTrip       ║"
echo -e "╚══════════════════════════════════════════╝${RESET}"
echo ""

RPI_HOST="pi@192.168.1.71"
RPI_PATH="/mnt/mariage_data/BibiUnion/"
DEST="/Users/themezeguillaume/Downloads/backups_mariage/$(date +%Y%m%d_%H%M%S)/"

mkdir -p "$DEST"

rsync -avz --progress \
  --exclude 'venv/' --exclude '__pycache__/' --exclude 'staticfiles/' \
  --exclude '*.pyc' \
  "$RPI_HOST:$RPI_PATH" "$DEST"

echo "✅ Sauvegarde terminée dans $DEST"

# Sur macOS, planifie-le avec **launchd** (équivalent de cron, plus fiable sur Mac) toutes les nuits. Pour une clé USB branchée sur le Raspberry lui-même, même logique en local :

# rsync -avz --exclude 'venv/' /mnt/mariage_data/BibiUnion/ /mnt/usb_backup/BibiUnion_$(date +%Y%m%d)/

#Pour un serveur distant plus tard, c'est la même commande `rsync`` en remplaçant juste la destination par `user@autre-serveur:/chemin/``.
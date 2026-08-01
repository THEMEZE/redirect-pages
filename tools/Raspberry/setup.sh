#!/bin/bash

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
echo    "║          🚐 RodTrip — Installation       ║"
echo -e "╚══════════════════════════════════════════╝${RESET}"
echo ""


echo "🚐 Installation RodTrip Raspberry"


sudo apt update

sudo apt install -y \
git \
python3 \
python3-venv \
python3-pip


cd /mnt/mariage_data/RodTrip


echo "🐍 Création environnement Python"


python3 -m venv venv


source venv/bin/activate


pip install --upgrade pip


pip install -r requirements.txt


echo "🗄 Base Django"


python manage.py migrate


echo "Collect static"

python manage.py collectstatic --noinput


echo "✅ Installation terminée"
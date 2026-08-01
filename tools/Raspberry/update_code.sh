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


PROJECT="/mnt/mariage_data/RodTrip"
BACKUP_DIR="/mnt/mariage_data/backups_RodTrip"


echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗"
echo    "║          🚐 RodTrip — Update             ║"
echo -e "╚══════════════════════════════════════════╝${RESET}"
echo ""


cd "$PROJECT" || err "Projet introuvable : $PROJECT"


# ─────────────────────────────────────────────
# Git
# ─────────────────────────────────────────────

info "Récupération des changements GitHub..."

git fetch origin

ok "Git synchronisé"


info "Vérification du dépôt distant..."

if git ls-tree -r origin/main --name-only | grep -qE '^(db\.sqlite3|media/)'
then
    err "db.sqlite3 ou media/ détecté dans Git"
fi

ok "Données locales protégées"


# ─────────────────────────────────────────────
# Backup SQLite
# ─────────────────────────────────────────────

info "Sauvegarde SQLite..."

mkdir -p "$BACKUP_DIR"


if [ -f db.sqlite3 ]
then
    cp db.sqlite3 \
    "$BACKUP_DIR/db_$(date +%Y%m%d_%H%M%S).sqlite3"

    ok "Base sauvegardée"
else
    warn "Aucune base SQLite trouvée (création prévue par Django)"
fi


# ─────────────────────────────────────────────
# Mise à jour code
# ─────────────────────────────────────────────

info "Mise à jour du code..."

git reset --hard origin/main

ok "Code mis à jour"


# ─────────────────────────────────────────────
# Python
# ─────────────────────────────────────────────

if [ -d venv ]
then
    source venv/bin/activate

    info "Mise à jour dépendances Python..."

    pip install -r requirements.txt

    ok "Dépendances installées"
else
    warn "Pas de venv trouvé"
fi


# ─────────────────────────────────────────────
# Django
# ─────────────────────────────────────────────

info "Migration Django..."

python manage.py migrate

ok "Migration terminée"


# ─────────────────────────────────────────────
# Systemd Gunicorn
# ─────────────────────────────────────────────

info "Vérification du service Gunicorn..."


if [ -f deploy/gunicorn-rodtrip.socket ]
then
    sudo cp deploy/gunicorn-rodtrip.socket \
    /etc/systemd/system/

    ok "Socket Gunicorn installé"
fi


if [ -f deploy/gunicorn-rodtrip.service ]
then
    sudo cp deploy/gunicorn-rodtrip.service \
    /etc/systemd/system/

    ok "Service Gunicorn installé"
fi


sudo systemctl daemon-reload


if systemctl list-unit-files | grep -q gunicorn-rodtrip.socket
then
    sudo systemctl enable gunicorn-rodtrip.socket
    sudo systemctl restart gunicorn-rodtrip.socket
fi


if systemctl list-unit-files | grep -q gunicorn-rodtrip.service
then
    sudo systemctl enable gunicorn-rodtrip.service
    sudo systemctl restart gunicorn-rodtrip.service

    ok "Gunicorn redémarré"
else
    warn "Service Gunicorn absent"
fi


# ─────────────────────────────────────────────
# Fin
# ─────────────────────────────────────────────

ok "RodTrip opérationnel 🚐"

echo ""
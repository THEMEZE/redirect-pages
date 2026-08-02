#!/bin/bash
# ============================================================
# create_redirect_pages.sh
#
# Génère les pages "hors ligne" initiales de chaque projet dans le
# dépôt redirect-pages/, puis initialise git et affiche les commandes
# à lancer pour le publier sur GitHub.
#
# À lancer une seule fois, depuis redirect-pages/scripts/ :
#   chmod +x create_redirect_pages.sh
#   ./create_redirect_pages.sh
# ============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"          # .../RedirectPages

source "$REPO_DIR/tools/lib_redirect.sh"

cd "$REPO_DIR"

echo "🚀 Génération des pages hors ligne dans $REPO_DIR"

mkdir -p rodtrip bibiunion budget famille vacances

redirect_write_offline rodtrip/index.html \
    "Sunset Évasion — Carnet de route" \
    "<link rel=\"icon\" href=\"data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>🚐</text></svg>\">" \
    "🌅🚐" \
    "Le carnet de route de Nathalie &amp; Erwan n'est pas en ligne pour le moment.<br>Le Raspberry Pi est peut-être arrêté."

redirect_write_offline bibiunion/index.html \
    "BibiUnion — Notre Mariage" \
    "<link rel=\"icon\" type=\"image/png\" href=\"https://themeze.github.io/redirect-pages/assets/bibiunion/Bridgerton_logo_square.png\">" \
    "💍" \
    "Le site est momentanément indisponible.<br>Réessayez dans quelques instants."

redirect_write_offline budget/index.html \
    "Budget — Gestion financière" \
    "<link rel=\"icon\" href=\"data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>💰</text></svg>\">" \
    "💰" \
    "Le tableau de bord budget n'est pas en ligne pour le moment.<br>Le Raspberry Pi est peut-être arrêté."

redirect_write_offline famille/index.html \
    "Souvenirs famille" \
    "<link rel=\"icon\" href=\"data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>📸</text></svg>\">" \
    "📸" \
    "Cet espace n'est pas en ligne pour le moment."

redirect_write_offline vacances/index.html \
    "Vacances" \
    "<link rel=\"icon\" href=\"data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>🏖️</text></svg>\">" \
    "🏖️" \
    "Cet espace n'est pas en ligne pour le moment."

echo "✅ Pages hors ligne générées (rodtrip, bibiunion, budget, famille, vacances)."
echo ""
echo "Prochaine étape (une seule fois) :"
echo "  cd $REPO_DIR"
echo "  git init"
echo "  git add ."
echo "  git commit -m 'Initialisation redirect-pages'"
echo "  git remote add origin git@github.com:THEMEZE/redirect-pages.git"
echo "  git branch -M main"
echo "  git push -u origin main"
echo ""
echo "Puis sur GitHub : Settings → Pages → Deploy from branch → main → /(root) → Save"
echo "URL finale : https://themeze.github.io/redirect-pages/"

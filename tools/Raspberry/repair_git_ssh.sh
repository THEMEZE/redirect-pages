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
echo    "║           Diagnostic Git / GitHub SSH"       ║"
echo -e "╚══════════════════════════════════════════╝${RESET}"
echo ""


echo ""
echo "1. Utilisateur courant"
whoami

echo ""
echo "2. Dépôt Git"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "✔ Dépôt Git détecté"
else
    echo "❌ Ce dossier n'est pas un dépôt Git."
    exit 1
fi

echo ""
echo "3. Remote"
git remote -v

echo ""
echo "4. Configuration Git"
echo "Nom   : $(git config --global user.name || echo '<non défini>')"
echo "Email : $(git config --global user.email || echo '<non défini>')"

echo ""
echo "5. Clés SSH"

if [ -f ~/.ssh/id_ed25519 ]; then
    echo "✔ Clé privée trouvée"
else
    echo "❌ ~/.ssh/id_ed25519 absente"
    exit 1
fi

if [ -f ~/.ssh/id_ed25519.pub ]; then
    echo "✔ Clé publique trouvée"
else
    echo "❌ ~/.ssh/id_ed25519.pub absente"
    exit 1
fi

echo ""
echo "6. Démarrage ssh-agent"
eval "$(ssh-agent -s)" >/dev/null
ssh-add ~/.ssh/id_ed25519 >/dev/null

echo "✔ Clé chargée"

echo ""
echo "7. Test GitHub"
echo "-----------------------------------------"

set +e
OUTPUT=$(ssh -T git@github.com 2>&1)
STATUS=$?
set -e

echo "$OUTPUT"

echo "-----------------------------------------"

if echo "$OUTPUT" | grep -q "successfully authenticated"; then
    echo ""
    echo "✅ Authentification GitHub OK"
else
    echo ""
    echo "❌ GitHub refuse la clé SSH."
    echo ""
    echo "Ajoute cette clé dans :"
    echo "https://github.com/settings/keys"
    echo ""
    cat ~/.ssh/id_ed25519.pub
    exit 1
fi

echo ""
echo "8. Test du dépôt"

git ls-remote origin >/dev/null

echo "✅ Le dépôt est accessible."

echo ""
echo "========================================="
echo "Configuration Git OK"
echo "========================================="

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
echo    "║          Installation de Tectonic (LaTeX)        ║"
echo -e "╚══════════════════════════════════════════╝${RESET}"
echo ""


# ── 1. Déjà installé ? ──────────────────────────────────────
if command -v tectonic >/dev/null 2>&1; then
    ok "Tectonic déjà installé : $(command -v tectonic) ($(tectonic --version 2>/dev/null | head -1))"
else
    ARCH=$(uname -m)
    if [ "$ARCH" != "aarch64" ]; then
        warn "Architecture '$ARCH' non gérée automatiquement (attendu: aarch64/Raspberry Pi 4 64 bits)."
        warn "Installation manuelle requise : voir README section Tectonic."
    else
        echo "⏳ Tectonic introuvable — installation via Miniforge (conda-forge, ARM64)..."

        # ── 2. Miniforge (conda ARM64) ──────────────────────
        if [ ! -d "$HOME/miniforge3" ]; then
            echo "⏳ Téléchargement de Miniforge..."
            curl -L -O https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-aarch64.sh
            bash Miniforge3-Linux-aarch64.sh -b -p "$HOME/miniforge3"
            rm -f Miniforge3-Linux-aarch64.sh
            ok "Miniforge installé dans $HOME/miniforge3"
        else
            ok "Miniforge déjà présent dans $HOME/miniforge3"
        fi

        source "$HOME/miniforge3/etc/profile.d/conda.sh"

        # ── 3. Environnement conda tectonic-env ─────────────
        if conda env list | grep -q "^tectonic-env"; then
            ok "Environnement conda 'tectonic-env' déjà présent"
        else
            echo "⏳ Création de l'environnement tectonic-env..."
            conda create -n tectonic-env -c conda-forge tectonic=0.15.0 -y
            ok "tectonic-env créé"
        fi

        # ── 4. Symlink vers /usr/local/bin ──────────────────
        sudo ln -sf "$HOME/miniforge3/envs/tectonic-env/bin/tectonic" /usr/local/bin/tectonic

        if /usr/local/bin/tectonic --version >/dev/null 2>&1; then
            ok "Tectonic installé et accessible : $(tectonic --version 2>/dev/null | head -1 || /usr/local/bin/tectonic --version)"
        else
            err "Le symlink /usr/local/bin/tectonic ne fonctionne pas."
        fi
    fi
fi

# ── 5. Poppler (pdftoppm, pour les miniatures de lettres LaTeX) ──
if command -v pdftoppm >/dev/null 2>&1; then
    ok "poppler-utils déjà installé"
else
    echo "⏳ Installation de poppler-utils (miniatures PDF)..."
    sudo apt update -qq
    sudo apt install -y poppler-utils
    ok "poppler-utils installé"
fi

echo "── Fin installation Tectonic ──────────────────────────────"
echo ""

#!/bin/bash
# ============================================================
# lib_redirect.sh — Générateur commun des pages "redirect-pages"
#
# Copie UNIQUE, partagée par tous les projets (RodTrip, BibiUnion,
# Famille, Vacances...). Ce fichier vit dans RedirectPages/tools/ et
# ne doit PAS être dupliqué dans chaque projet : chaque projet le
# source depuis ici, en supposant que tous les projets sont des
# dossiers frères (voir 01_Architecture.md) :
#
#   /opt/MyPlatform/
#   ├── RedirectPages/tools/lib_redirect.sh   ← ce fichier
#   ├── RodTrip/start_tunnel.sh               ← le source à distance
#   └── BibiUnion/start_tunnel.sh             ← idem
#
#   source "$SCRIPT_DIR/../RedirectPages/tools/lib_redirect.sh"
#
# Fournit 3 fonctions :
#   redirect_write_online   → écrit une page qui redirige vers l'URL du tunnel
#   redirect_write_offline  → écrit une page d'attente ("service hors ligne")
#   redirect_publish        → clone/actualise le dépôt GitHub Pages et pousse
#                              uniquement le fichier du projet concerné
#
# Objectif : ne plus dupliquer le HTML dans chaque start_tunnel.sh, et
# garantir que toutes les pages (RodTrip, BibiUnion, Famille, Vacances...)
# partagent la même charte graphique.
# ============================================================

# ── redirect_write_online ────────────────────────────────────
# $1 OUT_FILE      chemin du index.html à écrire
# $2 TITLE         titre de l'onglet / og:title
# $3 FAVICON_TAG   balise <link rel="icon" ...> complète
# $4 LOGO          emoji ou petit visuel affiché dans la carte
# $5 REDIRECT_URL  URL complète vers laquelle rediriger
# $6 LABEL         nom du service, utilisé dans le texte ("... vers $LABEL")
redirect_write_online() {
    local OUT_FILE="$1" TITLE="$2" FAVICON_TAG="$3" LOGO="$4" REDIRECT_URL="$5" LABEL="$6"

    cat > "$OUT_FILE" <<HTMLEOF
<!doctype html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${TITLE}</title>

    ${FAVICON_TAG}

    <meta property="og:title" content="${TITLE}">
    <meta property="og:type" content="website">

    <meta http-equiv="refresh" content="0;url=${REDIRECT_URL}">
    <script>window.location.replace("${REDIRECT_URL}");</script>

    <style>
        :root{ --sand:#f7f0e2; --sky:#d7ece7; --sunset:#e8703a; --night:#223034; }
        *{ box-sizing:border-box; }
        body{
            margin:0; min-height:100vh; display:flex; align-items:center; justify-content:center;
            font-family: system-ui, -apple-system, sans-serif;
            background: linear-gradient(160deg, var(--sand) 0%, var(--sand) 45%, var(--sky) 100%);
            color: var(--night); text-align:center; padding:2rem;
        }
        .card{ background: rgba(255,255,255,.85); border-radius: 24px; padding: 2.5rem 2rem; max-width: 440px; box-shadow: 0 10px 34px rgba(34,48,52,.15); }
        .emoji{ font-size: 2.6rem; margin-bottom: .5rem; }
        h1{ color: var(--sunset); font-size: 1.3rem; margin: 0 0 .8rem; }
        a{ color: var(--sunset); font-weight: 600; }
    </style>
</head>
<body>
    <div class="card">
        <div class="emoji">${LOGO}</div>
        <h1>Redirection vers ${LABEL}...</h1>
        <p><a href="${REDIRECT_URL}">Cliquez ici si la redirection ne fonctionne pas.</a></p>
    </div>
</body>
</html>
HTMLEOF
}

# ── redirect_write_offline ───────────────────────────────────
# $1 OUT_FILE      chemin du index.html à écrire
# $2 TITLE         titre de l'onglet
# $3 FAVICON_TAG   balise <link rel="icon" ...> complète
# $4 LOGO          emoji ou petit visuel affiché dans la carte
# $5 MESSAGE       message affiché (HTML autorisé, ex: "&amp;")
redirect_write_offline() {
    local OUT_FILE="$1" TITLE="$2" FAVICON_TAG="$3" LOGO="$4" MESSAGE="$5"

    cat > "$OUT_FILE" <<HTMLEOF
<!doctype html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${TITLE}</title>

    ${FAVICON_TAG}

    <style>
        :root{ --sand:#f7f0e2; --sky:#d7ece7; --sunset:#e8703a; --night:#223034; }
        *{ box-sizing:border-box; }
        body{
            margin:0; min-height:100vh; display:flex; align-items:center; justify-content:center;
            font-family: system-ui, -apple-system, sans-serif;
            background: linear-gradient(160deg, var(--sand) 0%, var(--sand) 45%, var(--sky) 100%);
            color: var(--night); text-align:center; padding:2rem;
        }
        .card{ background: rgba(255,255,255,.85); border-radius: 24px; padding: 2.5rem 2rem; max-width: 440px; box-shadow: 0 10px 34px rgba(34,48,52,.15); }
        .emoji{ font-size: 2.6rem; margin-bottom: .5rem; }
        h1{ color: var(--sunset); font-size: 1.4rem; margin: 0 0 .6rem; }
        p{ line-height: 1.6; color: var(--night); opacity:.85; margin: 0 0 .4rem; }
        .sub{ font-size: .85rem; opacity:.6; }
    </style>
</head>
<body>
    <div class="card">
        <div class="emoji">${LOGO}</div>
        <h1>${TITLE}</h1>
        <p>${MESSAGE}</p>
        <p class="sub">Cette page se transforme automatiquement en redirection dès que le service redémarre.</p>
    </div>
</body>
</html>
HTMLEOF
}

# ── redirect_publish ──────────────────────────────────────────
# Clone (1re fois) ou actualise le dépôt de redirection, puis
# commit + push UNIQUEMENT le sous-dossier du projet concerné.
#
# $1 REPO_SSH      URL SSH du dépôt GitHub PUBLIC dédié (ex: git@github.com:USER/redirect-pages.git)
# $2 REDIRECT_DIR  chemin local du clone (ex: $SCRIPT_DIR/.pages_redirect)
# $3 PROJECT       sous-dossier du projet (ex: rodtrip, bibiunion)
# $4 GIT_NAME      git config user.name à utiliser si non déjà configuré
# $5 GIT_EMAIL     git config user.email à utiliser si non déjà configuré
# $6 COMMIT_MSG    message de commit
redirect_publish() {
    local REPO_SSH="$1" REDIRECT_DIR="$2" PROJECT="$3" GIT_NAME="$4" GIT_EMAIL="$5" COMMIT_MSG="$6"

    if ! git config --global user.name >/dev/null; then
        git config --global user.name "$GIT_NAME"
    fi
    if ! git config --global user.email >/dev/null; then
        git config --global user.email "$GIT_EMAIL"
    fi

    if [ ! -d "$REDIRECT_DIR/.git" ]; then
        echo "📥 Premier clonage du dépôt de redirection..."
        rm -rf "$REDIRECT_DIR"
        if ! git clone "$REPO_SSH" "$REDIRECT_DIR" 2>/tmp/clone_err.log; then
            echo "❌ Impossible de cloner $REPO_SSH"
            echo "   $(cat /tmp/clone_err.log)"
            echo ""
            echo "   Vérifie que :"
            echo "   1. Le dépôt existe bien sur GitHub (crée-le s'il n'existe pas encore)"
            echo "   2. L'URL est exacte (copie-la depuis le bouton « Code » → SSH sur GitHub)"
            echo "   3. Ta clé SSH a accès à ce dépôt : ssh -T git@github.com"
            return 1
        fi
    fi

    (
        cd "$REDIRECT_DIR" || exit 1

        # ── 1. Récupérer les modifications distantes ────────────────
        if ! git fetch origin 2>/tmp/fetch_err.log; then
            echo "❌ Impossible de récupérer les modifications distantes (git fetch)."
            echo "   $(cat /tmp/fetch_err.log)"
            exit 1
        fi

        # ── 2. Écrire/committer la modification locale AVANT de rebaser,
        #      pour qu'elle soit rejouée par-dessus la version distante à
        #      jour (et non perdue si le rebase s'arrête en conflit).
        git add "$PROJECT/index.html"
        local_change=1
        if git diff --cached --quiet; then
            local_change=0
        else
            git commit -m "$COMMIT_MSG"
        fi

        # ── 3. Synchroniser le dépôt local avec le distant ───────────
        if ! git pull --rebase origin main 2>/tmp/pull_err.log; then
            echo "❌ Conflit lors de la synchronisation avec GitHub ($PROJECT)."
            echo "   $(cat /tmp/pull_err.log)"
            echo ""
            echo "   Le dépôt distant contient des modifications qui entrent en"
            echo "   conflit avec la mise à jour locale. Rien n'a été écrasé ni"
            echo "   poussé : va dans \"$REDIRECT_DIR\" pour résoudre le conflit"
            echo "   manuellement (git status), puis relance la publication."
            git rebase --abort 2>/dev/null || true
            exit 1
        fi

        if [ "$local_change" -eq 0 ]; then
            echo "✔ Aucun changement à envoyer ($PROJECT)."
            exit 0
        fi

        # ── 4. Pousser la nouvelle version ────────────────────────────
        for i in 1 2 3; do
            echo ""
            echo "══════════════════════════════════════════════"
            echo "🚀 Publication GitHub Pages ($PROJECT)"
            echo "   Tentative $i/3"
            echo "══════════════════════════════════════════════"

            if git push origin main 2>/tmp/push_err.log; then
                echo "✅ Redirection publiée sur GitHub Pages ($PROJECT)"
                exit 0
            fi

            echo ""
            echo "⚠️ Le push a été refusé."
            cat /tmp/push_err.log

            echo ""
            echo "=== Diagnostic Git ==="
            git status

            echo ""
            git log --oneline --graph --decorate --all -20

            echo ""
            echo "🔄 Tentative de resynchronisation avec GitHub..."

            if git pull --rebase origin main 2>/tmp/pull_err.log; then
                echo "✔ Synchronisation terminée."
                echo "↻ Nouvelle tentative de publication..."
            else
                echo "❌ Conflit lors de la synchronisation."
                echo "   $(cat /tmp/pull_err.log)"
                git rebase --abort 2>/dev/null || true
                exit 1
            fi
        done

        echo ""
        echo "❌ Impossible de publier après 3 tentatives."
        echo ""

        echo "Causes fréquentes :"
        echo " • Le dépôt n'existe pas encore sur GitHub → crée-le (public, vide)"
        echo " • Faute de frappe dans l'URL SSH (vérifie le .git final)"
        echo " • Le dépôt est privé sans que GitHub Pages soit disponible sur ton plan"
        echo " • Une nouvelle modification distante est arrivée entre le pull et le push"
        echo "   → relance simplement la publication."
        echo " • Un conflit Git empêche le rebase automatique."
        echo ""

        echo "Dernier message Git :"
        cat /tmp/push_err.log

        exit 1
    )
}

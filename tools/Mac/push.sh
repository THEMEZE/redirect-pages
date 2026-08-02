#!/bin/bash

set -e

echo "📥 Synchronisation..."

git add .

if git diff --cached --quiet
then
    echo "Aucun changement"
    exit 0
fi

MESSAGE="${1:-Mise à jour RedirectPages}"

git commit -m "$MESSAGE"

# Lance le rebase
if ! git pull --rebase origin main
then
    echo "⚠️ Conflits détectés, résolution automatique..."

    # Tous les fichiers encore en conflit
    CONFLICTS=$(git diff --name-only --diff-filter=U)

    for FILE in $CONFLICTS
    do
        case "$FILE" in
            */index.html)
                echo "✅ Garde la version locale : $FILE"
                git checkout --ours "$FILE"
                git add "$FILE"
                ;;
        esac
    done

    git rebase --continue
fi

git push origin main

echo "✅ Envoyé sur GitHub"

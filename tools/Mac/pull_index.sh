#!/bin/bash
set -e

# tools/Mac/pull_index.sh
#!/bin/bash
git fetch origin
git checkout origin/main -- index.html
echo "index.html mis à jour depuis GitHub"


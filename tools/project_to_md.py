#!/usr/bin/env python3
"""
project_to_md.py
=================

Génère un unique fichier Markdown contenant :
  1. L'arborescence du projet (comme la commande `tree`)
  2. Le contenu de tous les fichiers de code trouvés (dans des blocs ```lang)

But : donner à un humain (ou à une IA) une vue complète et lisible d'un
projet en un seul fichier, facile à copier/coller ou à uploader.

Usage rapide
------------
    python project_to_md.py                     # scanne le dossier courant
    python project_to_md.py ../                 # scanne le dossier parent
    python project_to_md.py . -o dump.md         # choisit le nom de sortie
    python project_to_md.py . -d 0               # seulement les fichiers à la racine
    python project_to_md.py . -d 1               # racine + 1 niveau de sous-dossiers
    python project_to_md.py . -i .py .html       # ne dump que le contenu des .py et .html
    python project_to_md.py . -e .md .lock .csv  # exclut en plus ces extensions
    python project_to_md.py . --no-content       # arborescence seule, sans le contenu
    python project_to_md.py . --max-size 300      # ignore le contenu des fichiers > 300 Ko
    python project_to_md.py . --max-lines 300     # tronque le contenu de chaque fichier à 300 lignes
    python project_to_md.py . --stats             # ajoute un résumé (nb fichiers/extension, taille) en haut du .md
    python project_to_md.py . --include-hidden    # ne masque plus les dossiers cachés (.cache, .github, ...)

Voir aussi : python project_to_md.py -h
"""

import argparse
import os
import sys
from pathlib import Path

# --------------------------------------------------------------------------
# Configuration par défaut (modifiable en argument de ligne de commande)
# --------------------------------------------------------------------------

# Dossiers toujours ignorés (bruit habituel : VCS, venv, caches, deps...)
DEFAULT_EXCLUDE_DIRS = {
    ".git", ".svn", ".hg",
    "__pycache__", ".pytest_cache", ".mypy_cache", ".ruff_cache",
    "venv", ".venv", "env", ".env_dir",
    "node_modules", "dist", "build", ".next", ".nuxt",
    ".idea", ".vscode",
    "migrations",  # souvent auto-généré et peu utile à relire ; retire-le si besoin
    ".DS_Store",
}

# Extensions toujours ignorées pour le CONTENU (fichiers binaires ou peu utiles
# à lire pour comprendre le code). Elles restent visibles dans l'arborescence.
ALWAYS_IGNORE_CONTENT_EXT = {
    ".png", ".jpg", ".jpeg", ".gif", ".ico", ".webp", ".bmp", ".svg",
    ".pdf", ".zip", ".tar", ".gz", ".7z", ".rar",
    ".pyc", ".pyo", ".so", ".dll", ".exe", ".bin",
    ".woff", ".woff2", ".ttf", ".eot",
    ".sqlite3", ".db",
    ".lock",
    ".mp3", ".mp4", ".mov", ".avi",
}

# Extensions exclues du CONTENU par défaut (ajustable avec --exclude).
# L'utilisateur a demandé .md par défaut (pour éviter de dumper la doc,
# et pour éviter que le script se dump lui-même en boucle s'il est relancé
# sur un dossier contenant d'anciens dumps .md).
DEFAULT_EXCLUDE_EXT = {".md"}

# Association extension -> langage pour la coloration syntaxique Markdown
LANG_MAP = {
    ".py": "python", ".js": "javascript", ".jsx": "jsx", ".ts": "typescript",
    ".tsx": "tsx", ".html": "html", ".htm": "html", ".css": "css",
    ".scss": "scss", ".sass": "sass", ".json": "json", ".yaml": "yaml",
    ".yml": "yaml", ".toml": "toml", ".sh": "bash", ".bash": "bash",
    ".sql": "sql", ".xml": "xml", ".ini": "ini", ".cfg": "ini",
    ".txt": "text", ".java": "java", ".c": "c", ".h": "c", ".cpp": "cpp",
    ".hpp": "cpp", ".go": "go", ".rs": "rust", ".rb": "ruby", ".php": "php",
    ".swift": "swift", ".kt": "kotlin", ".r": "r", ".env": "bash",
    ".gitignore": "text", ".dockerfile": "dockerfile",
}

# Noms de fichiers spéciaux sans extension qu'on veut quand même pouvoir inclure
SPECIAL_NAMES_LANG = {
    "Dockerfile": "dockerfile",
    "Makefile": "makefile",
    "requirements.txt": "text",
}


# --------------------------------------------------------------------------
# Utilitaires
# --------------------------------------------------------------------------

def rel_depth(root: Path, path: Path) -> int:
    """Profondeur relative d'un dossier par rapport à root (root = 0)."""
    rel = path.relative_to(root)
    return 0 if str(rel) == "." else len(rel.parts)


def is_probably_binary(path: Path, sample_size: int = 2048) -> bool:
    """Détection simple : présence d'un octet nul dans le début du fichier."""
    try:
        with open(path, "rb") as f:
            chunk = f.read(sample_size)
        return b"\x00" in chunk
    except OSError:
        return True


def get_lang(path: Path) -> str:
    if path.name in SPECIAL_NAMES_LANG:
        return SPECIAL_NAMES_LANG[path.name]
    return LANG_MAP.get(path.suffix.lower(), "")


def is_dir_excluded(name: str, exclude_dirs, include_hidden: bool) -> bool:
    """Un dossier est exclu s'il est dans la liste d'exclusion, ou s'il est
    caché (commence par un point) et que --include-hidden n'a pas été passé."""
    if name in exclude_dirs:
        return True
    if not include_hidden and name.startswith("."):
        return True
    return False


def walk_project(root: Path, max_depth, exclude_dirs, include_hidden: bool = False):
    """
    Générateur qui parcourt root en respectant max_depth (None = illimité).
    Retourne pour chaque dossier visité (dirpath, dirnames, filenames)
    déjà filtrés/triés, comme os.walk mais élagué.
    """
    for dirpath, dirnames, filenames in os.walk(root):
        dirpath = Path(dirpath)
        depth = rel_depth(root, dirpath)

        # Filtre les dossiers exclus (in-place pour que os.walk n'y entre pas)
        dirnames[:] = sorted(
            d for d in dirnames if not is_dir_excluded(d, exclude_dirs, include_hidden)
        )

        # Élagage par profondeur : si on a atteint la limite, on ne descend plus
        if max_depth is not None and depth >= max_depth:
            dirnames[:] = []

        yield dirpath, dirnames, sorted(filenames)


# --------------------------------------------------------------------------
# Génération de l'arborescence (façon `tree`)
# --------------------------------------------------------------------------

def build_tree_lines(root: Path, max_depth, exclude_dirs, include_hidden: bool = False):
    lines = [f"{root.resolve().name}/"]

    def _recurse(dirpath: Path, prefix: str, depth: int):
        try:
            entries = sorted(
                dirpath.iterdir(),
                key=lambda p: (p.is_file(), p.name.lower())
            )
        except PermissionError:
            return

        entries = [
            e for e in entries
            if not (e.is_dir() and is_dir_excluded(e.name, exclude_dirs, include_hidden))
        ]

        for i, entry in enumerate(entries):
            is_last = (i == len(entries) - 1)
            connector = "└── " if is_last else "├── "
            display = entry.name + ("/" if entry.is_dir() else "")
            lines.append(f"{prefix}{connector}{display}")

            if entry.is_dir():
                if max_depth is not None and depth >= max_depth:
                    continue  # on n'entre pas plus loin
                extension = "    " if is_last else "│   "
                _recurse(entry, prefix + extension, depth + 1)

    _recurse(root, "", 0)
    return lines


# --------------------------------------------------------------------------
# Collecte des fichiers dont on veut dumper le contenu
# --------------------------------------------------------------------------

def collect_files(root: Path, max_depth, exclude_dirs, include_ext, exclude_ext,
                   max_size_kb, include_hidden: bool = False):
    """
    Retourne une liste de tuples (fpath, status, size_kb) où status vaut :
      - "ok"      : le contenu sera dumpé
      - "too_big" : fichier au-delà de max_size_kb, contenu ignoré
      - "binary"  : fichier détecté comme binaire, contenu ignoré
    `size_kb` est toujours renseigné (utile pour l'affichage des fichiers ignorés).
    """
    files = []
    for dirpath, dirnames, filenames in walk_project(root, max_depth, exclude_dirs, include_hidden):
        for fname in filenames:
            fpath = dirpath / fname
            ext = fpath.suffix.lower()

            if ext in exclude_ext:
                continue
            if ext in ALWAYS_IGNORE_CONTENT_EXT:
                continue
            if include_ext is not None and ext not in include_ext and fname not in SPECIAL_NAMES_LANG:
                continue

            try:
                size_kb = fpath.stat().st_size / 1024
            except OSError:
                continue
            if max_size_kb is not None and size_kb > max_size_kb:
                files.append((fpath, "too_big", size_kb))
                continue

            if is_probably_binary(fpath):
                files.append((fpath, "binary", size_kb))
                continue

            files.append((fpath, "ok", size_kb))

    files.sort(key=lambda t: str(t[0]).lower())
    return files


def collect_stats(root: Path, max_depth, exclude_dirs, include_hidden: bool = False):
    """
    Parcourt TOUT le projet (indépendamment des filtres d'inclusion/exclusion
    de contenu) pour produire un résumé : nombre de fichiers et taille totale
    par extension, et le total global.
    """
    per_ext_count = {}
    per_ext_size = {}
    total_files = 0
    total_size = 0

    for dirpath, dirnames, filenames in walk_project(root, max_depth, exclude_dirs, include_hidden):
        for fname in filenames:
            fpath = dirpath / fname
            ext = fpath.suffix.lower() or "(sans extension)"
            try:
                size = fpath.stat().st_size
            except OSError:
                size = 0

            per_ext_count[ext] = per_ext_count.get(ext, 0) + 1
            per_ext_size[ext] = per_ext_size.get(ext, 0) + size
            total_files += 1
            total_size += size

    return {
        "per_ext_count": per_ext_count,
        "per_ext_size": per_ext_size,
        "total_files": total_files,
        "total_size": total_size,
    }


def human_size(num_bytes: float) -> str:
    for unit in ("o", "Ko", "Mo", "Go"):
        if num_bytes < 1024:
            return f"{num_bytes:.1f} {unit}"
        num_bytes /= 1024
    return f"{num_bytes:.1f} To"


def count_lines(path: Path) -> int:
    """
    Compte le nombre de lignes d'un fichier, qu'il soit texte ou binaire
    (lecture en mode binaire pour ne pas planter sur un encodage inconnu).
    Retourne -1 si le fichier est illisible.
    """
    try:
        count = 0
        with open(path, "rb") as f:
            for _ in f:
                count += 1
        return count
    except OSError:
        return -1


def truncate_content(text: str, max_lines):
    """Tronque `text` à max_lines lignes si besoin. Retourne (texte, a_ete_tronque, total_lignes)."""
    if max_lines is None:
        return text, False, text.count("\n") + 1

    lines = text.splitlines()
    total = len(lines)
    if total <= max_lines:
        return text, False, total

    truncated = "\n".join(lines[:max_lines])
    return truncated, True, total


# --------------------------------------------------------------------------
# Écriture du Markdown final
# --------------------------------------------------------------------------

def write_markdown(root: Path, tree_lines, files, output_path: Path, dump_content: bool,
                    stats: dict = None, max_lines=None):
    section_num = 1
    with open(output_path, "w", encoding="utf-8") as out:
        out.write(f"# Aperçu du projet `{root.resolve().name}`\n\n")

        if stats is not None:
            out.write(f"## {section_num}. Statistiques\n\n")
            section_num += 1
            out.write(f"- **Fichiers au total** : {stats['total_files']}\n")
            out.write(f"- **Taille totale** : {human_size(stats['total_size'])}\n\n")
            out.write("| Extension | Fichiers | Taille |\n")
            out.write("|---|---|---|\n")
            # Trié par nombre de fichiers décroissant
            for ext, count in sorted(stats["per_ext_count"].items(), key=lambda kv: (-kv[1], kv[0])):
                size = human_size(stats["per_ext_size"][ext])
                out.write(f"| `{ext}` | {count} | {size} |\n")
            out.write("\n")

        out.write(f"## {section_num}. Architecture du projet\n\n")
        section_num += 1
        out.write("```\n")
        out.write("\n".join(tree_lines))
        out.write("\n```\n\n")

        if dump_content:
            out.write(f"## {section_num}. Contenu des fichiers\n\n")
            for fpath, status, size_kb in files:
                rel = fpath.relative_to(root)
                out.write(f"### `{rel}`\n\n")

                if status == "binary":
                    out.write(f"_Fichier binaire, contenu ignoré ({human_size(size_kb * 1024)})._\n\n")
                    continue
                if status == "too_big":
                    out.write(
                        f"_Fichier trop volumineux ({human_size(size_kb * 1024)}), "
                        f"contenu ignoré (voir --max-size)._\n\n"
                    )
                    continue

                lang = get_lang(fpath)
                try:
                    text = fpath.read_text(encoding="utf-8", errors="replace")
                except OSError as e:
                    out.write(f"_Impossible de lire le fichier : {e}_\n\n")
                    continue

                text, was_truncated, total_lines = truncate_content(text, max_lines)

                out.write(f"```{lang}\n")
                out.write(text)
                if not text.endswith("\n"):
                    out.write("\n")
                out.write("```\n")
                if was_truncated:
                    out.write(f"\n_(tronqué : {max_lines}/{total_lines} lignes affichées, voir --max-lines)_\n")
                out.write("\n")


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------

def parse_args():
    parser = argparse.ArgumentParser(
        description="Génère un fichier Markdown avec l'arborescence et le contenu d'un projet.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""Exemples :
  python project_to_md.py
  python project_to_md.py ../ -o parent_dump.md
  python project_to_md.py . -d 1 -i .py .html -e .md .csv
  python project_to_md.py . --no-content
""",
    )
    parser.add_argument(
        "path", nargs="?", default=".",
        help="Dossier à scanner (défaut : dossier courant '.')"
    )
    parser.add_argument(
        "-o", "--output", default="project_dump.md",
        help="Nom/chemin du fichier Markdown de sortie (défaut : project_dump.md)"
    )
    parser.add_argument(
        "-d", "--depth", type=int, default=None,
        help=(
            "Profondeur de récursion : 0 = uniquement les fichiers à la racine, "
            "1 = + les sous-dossiers directs, etc. Défaut : illimité."
        )
    )
    parser.add_argument(
        "-i", "--include", nargs="*", default=None,
        help="Liste d'extensions à inclure dans le contenu, ex: .py .html (défaut : toutes sauf exclusions)"
    )
    parser.add_argument(
        "-e", "--exclude", nargs="*", default=None,
        help=f"Extensions à exclure du contenu (défaut : {sorted(DEFAULT_EXCLUDE_EXT)})"
    )
    parser.add_argument(
        "--exclude-dirs", nargs="*", default=None,
        help="Dossiers supplémentaires à ignorer, en plus de la liste par défaut."
    )
    parser.add_argument(
        "--max-size", type=float, default=500,
        help="Taille max (Ko) au-delà de laquelle le contenu d'un fichier n'est pas dumpé (défaut : 500)."
    )
    parser.add_argument(
        "--no-content", action="store_true",
        help="Ne génère que l'arborescence, sans le contenu des fichiers."
    )
    parser.add_argument(
        "--max-lines", type=int, default=None,
        help=(
            "Tronque le contenu affiché de chaque fichier à ce nombre de lignes "
            "(défaut : pas de troncature). Utile pour éviter un .md géant sur un gros projet."
        )
    )
    parser.add_argument(
        "--stats", action="store_true",
        help="Ajoute une section de statistiques en haut du .md (nb de fichiers et taille par extension)."
    )
    parser.add_argument(
        "--include-hidden", action="store_true",
        help="N'exclut plus automatiquement les dossiers cachés (.cache, .github, ...)."
    )
    return parser.parse_args()


def normalize_exts(exts):
    if exts is None:
        return None
    return {e if e.startswith(".") else f".{e}" for e in exts}


def main():
    args = parse_args()
    root = Path(args.path).resolve()

    if not root.is_dir():
        print(f"Erreur : '{root}' n'est pas un dossier valide.", file=sys.stderr)
        sys.exit(1)

    exclude_dirs = set(DEFAULT_EXCLUDE_DIRS)
    if args.exclude_dirs:
        exclude_dirs |= set(args.exclude_dirs)

    include_ext = normalize_exts(args.include)
    exclude_ext = normalize_exts(args.exclude) if args.exclude is not None else set(DEFAULT_EXCLUDE_EXT)

    print(f"Scan de : {root}")
    print(f"Profondeur : {'illimitée' if args.depth is None else args.depth}")

    tree_lines = build_tree_lines(root, args.depth, exclude_dirs, args.include_hidden)

    files = []
    if not args.no_content:
        files = collect_files(
            root, args.depth, exclude_dirs, include_ext, exclude_ext,
            args.max_size, args.include_hidden
        )

    stats = None
    if args.stats:
        stats = collect_stats(root, args.depth, exclude_dirs, args.include_hidden)

    output_path = Path(args.output).resolve()
    write_markdown(
        root, tree_lines, files, output_path,
        dump_content=not args.no_content, stats=stats, max_lines=args.max_lines
    )

    ok_count = sum(1 for _, status, _ in files if status == "ok")
    ignored = [(fpath, status, size_kb) for fpath, status, size_kb in files if status != "ok"]

    print(f"Fichiers inclus (contenu) : {ok_count}")
    print(f"Fichiers ignorés (binaire/trop gros) : {len(ignored)}")
    for fpath, status, size_kb in ignored:
        rel = fpath.relative_to(root)
        reason = "trop volumineux" if status == "too_big" else "binaire"
        nb_lignes = count_lines(fpath)
        lignes_str = str(nb_lignes) if nb_lignes >= 0 else "?"
        print(f"  - {rel} [{reason}] : {human_size(size_kb * 1024)}, {lignes_str} lignes")

    if stats:
        print(f"Stats : {stats['total_files']} fichiers, {human_size(stats['total_size'])} au total")
    print(f"-> Écrit dans : {output_path}")


if __name__ == "__main__":
    main()
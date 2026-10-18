"""Build psi_autocast.kpf, package a release zip, or install into the game.

    py build.py            build dist/psi_autocast.kpf only
    py build.py --package  also build dist/psi_autocast_v<version>.zip for release
    py build.py --install  also copy the .kpf and the psi key files (.txt) into the game (developer use)
    py build.py --dev ...  include the dev/ tools (overload probe) in the .kpf; never for release

The .kpf can only be replaced while the game is closed. The key files can be
copied at any time; the game reads them fresh on every keypress.
"""
import argparse
import json
import shutil
import sys
import zipfile
from pathlib import Path

GAME_DIR = Path(r"D:\EpicLibrary\SystemShock225thAnniT5DFq")
SAVE_DIR = Path.home() / "Saved Games" / "Nightdive Studios" / "System Shock 2 Remastered"
PROJECT_DIR = Path(__file__).resolve().parent
MOD_SOURCE = PROJECT_DIR / "mod"
DEV_SOURCE = PROJECT_DIR / "dev"
KEYS_SOURCE = PROJECT_DIR / "psi"
DIST_DIR = PROJECT_DIR / "dist"
KPF_PATH = DIST_DIR / "psi_autocast.kpf"
RELEASE_DOCS = ["README.md", "MACROS_FOR_CLAUDE.md", "LICENSE"]


def mod_version():
    return json.loads((MOD_SOURCE / "modinfo.json").read_text())["version"]


def build_kpf(include_dev=False):
    DIST_DIR.mkdir(exist_ok=True)
    sources = [MOD_SOURCE, DEV_SOURCE] if include_dev else [MOD_SOURCE]
    with zipfile.ZipFile(KPF_PATH, "w", zipfile.ZIP_DEFLATED) as kpf:
        for source in sources:
            for file in sorted(source.rglob("*")):
                if file.is_file():
                    kpf.write(file, file.relative_to(source).as_posix())
    print(f"built {KPF_PATH.name}" + (" (with dev tools)" if include_dev else ""))


def player_files():
    """Key scripts, parts, chains and the macro builder page."""
    return sorted(p for p in KEYS_SOURCE.rglob("*") if p.suffix in (".txt", ".html"))


def package_release():
    """Lay the zip out like the game folder, so players can extract it straight in."""
    release = DIST_DIR / f"psi_autocast_v{mod_version()}.zip"
    with zipfile.ZipFile(release, "w", zipfile.ZIP_DEFLATED) as package:
        package.write(KPF_PATH, f"mods/{KPF_PATH.name}")
        for item in player_files():
            package.write(item, "psi/" + item.relative_to(KEYS_SOURCE).as_posix())
        for doc in RELEASE_DOCS:
            package.write(PROJECT_DIR / doc, f"psi/psi_autocast_{doc}")
    print(f"packaged {release.name}")


def game_is_running():
    # The game holds its log open exclusively while it runs.
    try:
        with open(SAVE_DIR / "kexengine.log", "rb"):
            return False
    except PermissionError:
        return True
    except FileNotFoundError:
        return False


def install():
    keys_target = GAME_DIR / "psi"
    for item in player_files():
        target = keys_target / item.relative_to(KEYS_SOURCE)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(item, target)
    print(f"copied key files to {keys_target}")

    if game_is_running():
        print("game is running: key files updated, .kpf NOT replaced (quit and re-run)")
        return 1
    shutil.copy2(KPF_PATH, GAME_DIR / "mods" / KPF_PATH.name)
    print(f"installed {KPF_PATH.name}")
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--package", action="store_true", help="build the release zip")
    parser.add_argument("--install", action="store_true", help="copy the build and key files into the game")
    parser.add_argument("--dev", action="store_true", help="include dev/ tools in the .kpf (never with --package)")
    args = parser.parse_args()
    if args.dev and args.package:
        parser.error("--dev builds must not be packaged for release")

    build_kpf(include_dev=args.dev)
    if args.package:
        package_release()
    return install() if args.install else 0


if __name__ == "__main__":
    sys.exit(main())

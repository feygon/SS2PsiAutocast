"""Build psi_autocast.kpf and install it, plus the key files, into the game.

    py build.py            build dist/psi_autocast.kpf only
    py build.py --install  build, then copy the .kpf and keys/*.cmd into the game

The .kpf can only be replaced while the game is closed. The .cmd files can be
copied at any time; the game reads them fresh on every keypress.
"""
import argparse
import shutil
import sys
import zipfile
from pathlib import Path

GAME_DIR = Path(r"D:\EpicLibrary\SystemShock225thAnniT5DFq")
SAVE_DIR = Path.home() / "Saved Games" / "Nightdive Studios" / "System Shock 2 Remastered"
PROJECT_DIR = Path(__file__).resolve().parent
MOD_SOURCE = PROJECT_DIR / "mod"
KEYS_SOURCE = PROJECT_DIR / "keys"
KPF_PATH = PROJECT_DIR / "dist" / "psi_autocast.kpf"


def build_kpf():
    KPF_PATH.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(KPF_PATH, "w", zipfile.ZIP_DEFLATED) as kpf:
        for file in sorted(MOD_SOURCE.rglob("*")):
            if file.is_file():
                kpf.write(file, file.relative_to(MOD_SOURCE).as_posix())
    print(f"built {KPF_PATH}")


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
    for cmd in sorted(KEYS_SOURCE.glob("*.cmd")):
        shutil.copy2(cmd, GAME_DIR / cmd.name)
        print(f"copied {cmd.name}")

    if game_is_running():
        print("game is running: key files updated, .kpf NOT replaced (quit and re-run)")
        return 1
    shutil.copy2(KPF_PATH, GAME_DIR / "mods" / KPF_PATH.name)
    print(f"installed {KPF_PATH.name}")
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--install", action="store_true", help="copy the build and key files into the game")
    args = parser.parse_args()

    build_kpf()
    return install() if args.install else 0


if __name__ == "__main__":
    sys.exit(main())

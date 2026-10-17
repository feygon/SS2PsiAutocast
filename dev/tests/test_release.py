"""
Test Suite: psi_autocast release (offline)

WHY THESE TESTS MATTER:
- The mod is mostly generated text files that the game reads blind: a key file that runs a missing part, or
  a regenerated file that drifted from what was tested, fails silently in game (the key just does nothing).
- The release zip is what players install; it must be exactly the tested files, with nothing that would
  trip Nexus's executable checks.
- starterPsiPowers.bat edits the player's user.bnd: it must never overwrite a binding the player made.

COVERAGE GOALS:
- Generated files are reproducible (make_keys.py is idempotent).
- Every "run psi\\..." reference resolves to a real file.
- Discipline table: ids, names, overload flags (against the wiki's list).
- Release zip contents match the repo.
- starterPsiPowers.bat on fixture user.bnd files: fresh, custom bindings, rerun, missing final newline.

Game behaviour (casting, timing, chains) can only be checked in game: see dev/tests/TEST_PLAN.md.
Run:  py -m pytest dev/tests -v
"""
import io
import re
import subprocess
import zipfile
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
PSI = REPO / "psi"


def git(*args):
    return subprocess.run(["git", *args], cwd=REPO, capture_output=True, text=True, check=True).stdout


def key_files():
    return sorted(PSI.rglob("*.cmd"))


def test_make_keys_is_idempotent():
    """
    WHY: The key files, discipline data and doc tables are generated. If make_keys.py no longer reproduces the
    committed files, the release would ship files nobody tested, or the next regeneration would silently
    change them.
    """
    def snapshot():
        files = [REPO / "README.md", REPO / "MACROS_FOR_CLAUDE.md"]
        files += [p for d in ("psi", "docs", "mod") for p in (REPO / d).rglob("*") if p.is_file()]
        return {p: p.read_bytes() for p in files}

    before = snapshot()
    subprocess.run(["py", "make_keys.py"], cwd=REPO, check=True, capture_output=True)
    after = snapshot()
    assert before.keys() == after.keys(), "make_keys.py added or removed files"
    assert [str(p.relative_to(REPO)) for p in before if before[p] != after[p]] == []


def test_every_run_reference_resolves():
    """
    WHY: A key file that runs a missing part does nothing in game, with no error the player would see.
    Paths are case-insensitive on Windows, and run needs a backslash.
    """
    existing = {p.relative_to(REPO).as_posix().lower() for p in PSI.rglob("*") if p.is_file()}
    missing = []
    for path in key_files():
        for line in path.read_text().splitlines():
            m = re.match(r"\s*run\s+(\S+)", line, re.I)
            if m:
                target = m.group(1)
                assert "/" not in target, f"{path.name}: run needs a backslash: {line}"
                if target.lower().replace("\\", "/") not in existing:
                    missing.append(f"{path.relative_to(REPO)}: {line}")
    assert not missing, "\n".join(missing)


def test_two_scripts_per_discipline():
    """
    WHY: The README and Macro Builder promise a quickfire and a conditional-overload script for all 35
    disciplines; a gap means a documented key that doesn't exist.
    """
    data = (REPO / "mod/sq_scripts/psi_autocast_disciplines.nut").read_text()
    names = re.findall(r'ND\.psiDisciplines\[(\d+)\] <- \{ name = "([^"]+)"', data)
    assert len(names) == 35
    for _, name in names:
        assert (PSI / f"{name}.cmd").exists(), name
        assert (PSI / f"{name}_Quickfire.cmd").exists(), name


def test_overload_flags_match_the_wiki():
    """
    WHY: Conditional overload only overloads disciplines flagged as benefiting. A wrong flag either wastes the
    overload timing on a discipline it doesn't help, or skips it on one it does. The wiki's "Powers affected by
    overloading" table (https://shodan.fandom.com/wiki/Psionic_Disciplines, read 2026-10-16) is the reference.
    """
    wiki_benefits = {3, 6, 7, 12, 17, 18, 22, 23, 27, 29, 30, 33, 34, 36, 37}
    data = (REPO / "mod/sq_scripts/psi_autocast_disciplines.nut").read_text()
    flags = {int(i): int(b) for i, b in re.findall(r'ND\.psiDisciplines\[(\d+)\] <- \{ name = "[^"]+", benefits = (\d) \}', data)}
    assert {i for i, b in flags.items() if b} == wiki_benefits


def tagged(tag, path):
    return subprocess.run(["git", "show", f"{tag}:{path}"], cwd=REPO, capture_output=True, check=True).stdout


def test_release_zip_matches_its_tag():
    """
    WHY: The zip is what players install. Every file in it must be the version committed at the release tag
    (v<version>), and it must carry no executables (Nexus quarantines those).
    """
    version = re.search(r'"version": "([^"]+)"', (REPO / "mod/modinfo.json").read_text()).group(1)
    tag = f"v{version}"
    zip_path = REPO / "dist" / f"psi_autocast_v{version}.zip"
    if not zip_path.exists():
        pytest.skip(f"{zip_path.name} not built (py build.py --package)")
    z = zipfile.ZipFile(zip_path)
    names = z.namelist()
    assert not [n for n in names if n.lower().endswith((".bat", ".exe", ".dll", ".ps1"))]
    kpf = zipfile.ZipFile(io.BytesIO(z.read("mods/psi_autocast.kpf")))
    for member in kpf.namelist():
        assert kpf.read(member) == tagged(tag, f"mod/{member}"), member
    docs = {"psi/psi_autocast_README.md": "README.md", "psi/psi_autocast_MACROS_FOR_CLAUDE.md": "MACROS_FOR_CLAUDE.md",
            "psi/psi_autocast_LICENSE": "LICENSE"}
    for name in names:
        if not name.startswith("mods/"):
            assert z.read(name) == tagged(tag, docs.get(name, name)), name


def test_shipped_code_unchanged_since_the_release_tag():
    """
    WHY: If the mod's code or key files changed after the release was tagged, players are running something
    different from the repo. Comment-only changes are fine; anything else needs a new release.
    """
    version = re.search(r'"version": "([^"]+)"', (REPO / "mod/modinfo.json").read_text()).group(1)
    diff = git("diff", f"v{version}", "--", "mod", "psi")
    changed = [l for l in diff.splitlines()
               if l[:1] in "+-" and not l.startswith(("+++", "---")) and not l[1:].strip().startswith("//")]
    assert not changed, "non-comment changes since the tag: " + " | ".join(changed)


# ---- starterPsiPowers.bat ------------------------------------------------------------------------------

BAT = REPO / "extras" / "starterPsiPowers.bat"


def run_bat(folder):
    """Runs the script against a fixture folder, passed as its argument so it never looks at the real one."""
    result = subprocess.run(["cmd", "/c", str(BAT), str(folder)], input="\n", capture_output=True, text=True)
    return result.stdout


def macro(folder, key):
    return (folder / "psi_macros" / f"Macro_{key}.cmd").read_text().splitlines()


def bindings(folder):
    return [l for l in (folder / "user.bnd").read_text().splitlines() if l.lower().startswith("bind ")]


def test_bat_has_windows_line_endings():
    """WHY: cmd can misread goto labels in a batch file with LF-only line endings."""
    data = BAT.read_bytes()
    assert b"\r\n" in data and b"\n" not in data.replace(b"\r\n", b"")


def test_bat_binds_free_keys(tmp_path):
    """WHY: The basic promise: on a user.bnd without G or J, both starter keys get bound, with a backup."""
    (tmp_path / "user.bnd").write_bytes(('bind k "keep"\r\n').encode())
    out = run_bat(tmp_path)
    assert "Done." in out
    # Bound through files in the save folder (the names psi_autocast_mfd uses), so the MFD can edit them later.
    assert 'bind g "run user:/psi_macros\\Macro_g.cmd"' in bindings(tmp_path)
    assert 'bind j "run user:/psi_macros\\Macro_j.cmd"' in bindings(tmp_path)
    assert macro(tmp_path, "g") == ["run psi\\T1_Projected_Cryokinesis.cmd"]
    assert macro(tmp_path, "j") == ["run psi\\chains\\Starter_Localized_Pyrokinesis.cmd"]
    assert (tmp_path / "user.bnd.before_starter_1").exists()


def test_bat_leaves_custom_bindings_alone(tmp_path):
    """WHY: Players may have their own G or J; overwriting them would break their setup without asking."""
    (tmp_path / "user.bnd").write_bytes(('bind g "my own"\r\nbind J "jump"\r\n').encode())
    out = run_bat(tmp_path)
    assert "Nothing to add" in out
    assert bindings(tmp_path) == ['bind g "my own"', 'bind J "jump"']
    assert not (tmp_path / "user.bnd.before_starter_1").exists()


def test_bat_rerun_adds_nothing(tmp_path):
    """WHY: Running it twice must not duplicate lines or stack backups."""
    (tmp_path / "user.bnd").write_bytes(('bind k "keep"\r\n').encode())
    run_bat(tmp_path)
    before = (tmp_path / "user.bnd").read_bytes()
    assert "Nothing to add" in run_bat(tmp_path)
    assert (tmp_path / "user.bnd").read_bytes() == before


def test_bat_handles_missing_final_newline(tmp_path):
    """WHY: If the last line has no newline, a naive append glues the new binding onto it."""
    (tmp_path / "user.bnd").write_bytes(('bind k "keep"').encode())
    run_bat(tmp_path)
    assert 'bind k "keep"' in bindings(tmp_path)


def test_bat_keeps_an_existing_macro_file(tmp_path):
    """WHY: Macro_g.cmd may hold a macro the player built in psi_autocast_mfd; it must never be overwritten."""
    (tmp_path / "user.bnd").write_bytes(b'bind k "keep"\r\n')
    (tmp_path / "psi_macros").mkdir()
    (tmp_path / "psi_macros" / "Macro_g.cmd").write_text("set psi_chain arm,3q\nsummon_obj PsiChain\n")
    run_bat(tmp_path)
    assert macro(tmp_path, "g")[0] == "set psi_chain arm,3q"
    assert 'bind g "run user:/psi_macros\\Macro_g.cmd"' in bindings(tmp_path)


def test_bat_upgrades_its_old_direct_bindings(tmp_path):
    """WHY: Earlier versions bound G and J straight to the psi scripts; running this version moves them into the
    files (same casts), so psi_autocast_mfd can edit them. Other bindings stay."""
    (tmp_path / "user.bnd").write_bytes(b'bind g "run psi\\t1_projected_cryokinesis.cmd"\r\n'
                                        b'bind j "run psi\\chains\\Starter_Localized_Pyrokinesis.cmd"\r\nbind k "keep"\r\n')
    run_bat(tmp_path)
    b = bindings(tmp_path)
    assert [l for l in b if l.startswith("bind g ")] == ['bind g "run user:/psi_macros\\Macro_g.cmd"']
    assert [l for l in b if l.startswith("bind j ")] == ['bind j "run user:/psi_macros\\Macro_j.cmd"']
    assert 'bind k "keep"' in b
    assert macro(tmp_path, "g") == ["run psi\\T1_Projected_Cryokinesis.cmd"]

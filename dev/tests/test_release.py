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
    return sorted(PSI.rglob("*.txt"))


def test_no_cmd_files_ship():
    """WHY: 1.4 renamed every key file to .txt: Nexus quarantined zips full of .cmd files, and double-clicking a .cmd
    runs it in Windows. `run` ignores the extension (verified in game 2026-10-18), so nothing needs .cmd."""
    assert not list(PSI.rglob("*.cmd"))
    assert len(key_files()) == 110


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
        assert (PSI / f"{name.lower()}.txt").exists(), name
        assert (PSI / f"{name.lower()}_quickfire.txt").exists(), name


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
    assert not [n for n in names if n.lower().endswith((".bat", ".exe", ".dll", ".ps1", ".cmd"))]
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
    if not git("tag", "--list", f"v{version}").strip():
        pytest.skip(f"v{version} isn't tagged yet: a new release is in progress")
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
    assert macro(tmp_path, "g") == ["run psi\\t1_projected_cryokinesis.txt"]
    assert macro(tmp_path, "j") == ["run psi\\chains\\starter_localized_pyrokinesis.txt"]
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
    assert macro(tmp_path, "g") == ["run psi\\t1_projected_cryokinesis.txt"]


# ---- overload window -----------------------------------------------------------------------------------

# Measured in game 2026-10-18 (OnOverloadSuccess in condump): (base PSI, tier, actual release ms, overloaded).
# Base PSI excludes implants: 6 + 1 implant and 6 alone gave the same tier-3 window.
OVERLOAD_MEASUREMENTS = [
    (5, 3, 535, False), (5, 3, 634, False), (5, 3, 733, True),
    (6, 1, 295, False), (6, 1, 461, False), (6, 1, 1794, True),
    (6, 2, 511, False), (6, 2, 677, False), (6, 2, 1344, True),
    (6, 3, 475, False), (6, 3, 478, False), (6, 3, 507, False), (6, 3, 652, True), (6, 3, 680, True),
    (6, 3, 683, True), (6, 3, 826, True), (6, 3, 832, True), (6, 3, 911, True),
    (6, 4, 478, True), (6, 4, 617, True), (6, 4, 695, True),
    (6, 5, 283, True), (6, 5, 343, True), (6, 5, 378, True),
]


def nut_floats(name):
    code = (REPO / "mod/sq_scripts/psi_autocast.nut").read_text(encoding="utf-8")
    return [float(x) for x in re.search(name + r" <- \[([^\]]*)\]", code).group(1).split(",")]


def test_overload_window_matches_the_game():
    """
    WHY: A cast held for the wrong time doesn't overload. In game the window followed base PSI one row lower in
    OLPARAM than psi_autocast assumed, at every tier; with total PSI it released far too early (a tier-3
    Molecular Duplication at PSI 6 = 5 + 1 implant never overloaded).
    """
    code = (REPO / "mod/sq_scripts/psi_autocast.nut").read_text(encoding="utf-8")
    assert 'Property.Get("Player", "BaseStatsDesc", "PSI")' in code
    starts, bars = nut_floats("PSI_ZONE_START"), nut_floats("PSI_BAR_SECONDS")
    row = re.search(r"function PsiZoneRow\(psi\) \{\s*return (.*?);", code, re.S).group(1)
    assert row == "psi < 2 ? 0 : (psi > 9 ? 7 : psi - 2)", row
    for base, tier, release, overloaded in OVERLOAD_MEASUREMENTS:
        r = 0 if base < 2 else min(base - 2, 7)
        start, bar = starts[r] * bars[tier - 1] * 1000, bars[tier - 1] * 1000
        assert (start < release < bar) == overloaded, (base, tier, release, overloaded, start)


# Release lag: actual release minus the planned hold, from the 2026-10-18 fixed-hold tests (15 casts).
RELEASE_LAGS_MS = [28, 34, 27, 24, 30, 27, 40, 35, 24, 31, 40, 28, 26, 21, 31]


def test_narrow_zones_are_aimed_at_their_middle():
    """
    WHY: Tier 5 at base PSI 5 has a 108 ms zone (292-400 ms), too narrow for the usual 50 ms margins, so it cast
    without overloading. The user chose to aim mid-zone, allowing for the measured release lag, so every measured
    lag still lands inside the zone with room to spare; zones under 50 ms still cast immediately.
    """
    code = (REPO / "mod/sq_scripts/psi_autocast.nut").read_text(encoding="utf-8")
    lag = int(re.search(r"const PSI_RELEASE_LAG_MS = (\d+);", code).group(1))
    assert lag == round(sum(RELEASE_LAGS_MS) / len(RELEASE_LAGS_MS))
    assert "startMs + (barMs - startMs) / 2 - PSI_RELEASE_LAG_MS" in code
    start, bar = 292, 400
    hold = start + (bar - start) // 2 - lag
    assert hold == 316
    for measured in RELEASE_LAGS_MS:
        assert start + 20 <= hold + measured <= bar - 20, measured
    assert re.search(r"barMs - startMs < PSI_NARROW_MIN_MS", code)


# ---- 1.3 -> 1.4: .cmd bindings move to .txt ----------------------------------------------------------------

def shipped_key_files():
    """ND.psiKeyFiles from the generated data file: lower-case paths under psi\\, without extension."""
    data = (REPO / "mod/sq_scripts/psi_autocast_disciplines.nut").read_text(encoding="utf-8")
    body = re.search(r"ND\.psiKeyFiles <- \{(.*?)\};", data, re.S)
    assert body, "ND.psiKeyFiles missing"
    return {k.replace("\\\\", "\\") for k in re.findall(r'\["([^"]+)"\] = true', body.group(1))}


def to_txt(text, ours):
    """The twin of PsiToTxt: 'run psi\\<file>.cmd' (or a .txt with capitals) becomes 'run psi\\<file, lower case>.txt',
    only when <file> is one psi_autocast ships."""
    def repl(m):
        path = m.group(2)
        if path.lower() not in ours:
            return m.group(0)
        return m.group(1) + path.lower() + ".txt"
    return re.sub(r"(run psi\\)([^\r\n\"]*?)\.(cmd|txt)", repl, text, flags=re.I)


def test_key_file_list_matches_the_psi_folder():
    """WHY: The migration only renames bindings to files in this list; it must be exactly the files that ship."""
    on_disk = {p.relative_to(PSI).with_suffix("").as_posix().lower().replace("/", "\\") for p in key_files()}
    assert shipped_key_files() == on_disk


def test_only_our_bindings_move_to_txt():
    """
    WHY: Players' user.bnd lines (and the save-folder macro files they run) point at the old .cmd names; without
    moving them, every psi_autocast key would stop working after the update. Only files psi_autocast ships are
    renamed: a chain the player saved from the Macro Builder (psi\\chains\\<name>.cmd), other mods' files and
    MFD macro files keep their names, because those files stay .cmd.
    """
    ours = shipped_key_files()
    before = ('bind g "run psi\\t1_projected_cryokinesis_quickfire.cmd"\r\n'
              'bind keypad_plus "run psi\\actions\\Cancel_Macro.CMD"\r\n'
              'bind j "run psi\\chains\\Starter_Localized_Pyrokinesis.cmd"\r\n'
              'bind k "run psi\\chains\\My_Own_Chain.cmd"\r\n'
              'bind l "run othermod\\thing.cmd"\r\n'
              'bind o "run user:/psi_macros\\Macro_o.cmd"\r\n'
              'bind t wpn_setting_toggle\r\n')
    after = to_txt(before, ours)
    assert 'bind g "run psi\\t1_projected_cryokinesis_quickfire.txt"' in after
    assert 'bind keypad_plus "run psi\\actions\\cancel_macro.txt"' in after
    assert 'bind j "run psi\\chains\\starter_localized_pyrokinesis.txt"' in after
    assert to_txt('bind x "run psi\\actions\\Use_Psi_Hypo.txt"', ours) == 'bind x "run psi\\actions\\use_psi_hypo.txt"'
    for line in ['bind k "run psi\\chains\\My_Own_Chain.cmd"', 'bind l "run othermod\\thing.cmd"',
                 'bind o "run user:/psi_macros\\Macro_o.cmd"', 'bind t wpn_setting_toggle']:
        assert line in after, line
    assert to_txt(after, ours) == after, "running it again changes nothing"
    code = (REPO / "mod/sq_scripts/psi_autocast.nut").read_text(encoding="utf-8")
    for name in ["PsiToTxt", "PsiMigrateBindings"]:
        assert f"function {name}(" in code, name
    assert "ND.psiKeyFiles" in code and "OnFrameUpdate" in code and 'Say("couldn\'t update' in code



def test_every_shipped_name_and_run_path_is_lower_case():
    """
    WHY: Key bindings look up a .txt name with its exact capitals (in game 2026-10-20: a binding to
    cancel_macro.txt didn't run Cancel_Macro.txt, while Cancel_Macro.txt and an all-lower-case pair did), and the
    game writes user.bnd in lower case. So every file psi_autocast ships, and every path it runs, is lower case.
    """
    names = [p.relative_to(PSI).as_posix() for p in PSI.rglob("*") if p.is_file() and p.suffix == ".txt"]
    assert names and [n for n in names if n != n.lower()] == []
    for path in key_files():
        for line in path.read_text().splitlines():
            if line.lower().startswith("run "):
                assert line == line.lower(), f"{path.name}: {line}"
    code = (REPO / "mod/sq_scripts/psi_autocast.nut").read_text(encoding="utf-8")
    for run in re.findall(r'Debug\.Command\("run psi[^)]*\)', code):
        literal = "".join(re.findall(r'"([^"]*)"', run))
        assert literal == literal.lower(), run
    assert 'step.tolower() + ".txt"' in code and 'weapon.tolower() + ".txt"' in code
    bat = (REPO / "extras/starterPsiPowers.bat").read_text(encoding="latin-1")
    for line in re.findall(r"run psi\\[^\"\r\n]*", bat):
        assert line == line.lower(), line

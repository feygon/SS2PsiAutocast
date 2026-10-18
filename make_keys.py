"""Generate the psi\\ key files and the README's discipline table.

    py make_keys.py           key files call the shared parts in psi\\lib\\ with run
    py make_keys.py --inline  key files contain the parts' lines directly (if nested run is unavailable)

Each discipline gets two files:
    T<tier>_<Name>_Quickfire.txt  draw if needed, cast immediately
    T<tier>_<Name>.txt            draw if needed, overload if the discipline benefits, else cast immediately
"""
import argparse
import json
import re
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parent
KEYS_DIR = PROJECT_DIR / "psi"
LIB_DIR = KEYS_DIR / "lib"
README = PROJECT_DIR / "README.md"
CLAUDE_GUIDE = PROJECT_DIR / "MACROS_FOR_CLAUDE.md"
SCRIPT_DATA = PROJECT_DIR / "mod" / "sq_scripts" / "psi_autocast_disciplines.nut"
BUILDER_TEMPLATE = PROJECT_DIR / "builder" / "Macro_Builder.template.html"
BUILDER = KEYS_DIR / "Macro_Builder.html"
SITE_BUILDER = PROJECT_DIR / "docs" / "Macro_Builder.html"  # published on GitHub Pages
BUILDER_DATA_MARKER = "/*DISCIPLINES*/"
TABLE_START = "<!-- disciplines:start -->"
TABLE_END = "<!-- disciplines:end -->"

# (power id, name, benefits from overload)
# Ids and names: Psi<N> in strings/psihelp.str, matching the PsiPower records in shock2.gam.
# Tier = id // 8 + 1; ids 0, 8, 16, 24 and 32 are the tiers' Neural Capacity entries, not castable.
# Overload benefit: https://shodan.fandom.com/wiki/Psionic_Disciplines ("Powers affected by overloading").
DISCIPLINES = [
    (1, "Psycho-Reflective Screen", False),
    (2, "Neuro-Reflex Dampening", False),
    (3, "Kinetic Redirection", True),
    (4, "Psychogenic Agility", False),
    (5, "Psychogenic Cyber-Affinity", False),
    (6, "Projected Cryokinesis", True),
    (7, "Remote Electron Tampering", True),
    (9, "Anti-Entropic Field", False),
    (10, "Adrenaline Overproduction", False),
    (11, "Neural Decontamination", False),
    (12, "Cerebro-Stimulated Regeneration", True),
    (13, "Psychogenic Strength", False),
    (14, "Recursive Psionic Amplification", False),
    (15, "Localized Pyrokinesis", False),
    (17, "Molecular Duplication", True),
    (18, "Electron Cascade", True),
    (19, "Energy Reflection", False),
    (20, "Neural Toxin-Blocker", False),
    (21, "Enhanced Motion Sensitivity", False),
    (22, "Projected Pyrokinesis", True),
    (23, "Psionic Hypnogenesis", True),
    (25, "Photonic Redirection", False),
    (26, "Remote Pattern Detection", False),
    (27, "Electron Suppression", True),
    (28, "Psychogenic Endurance", False),
    (29, "Molecular Transmutation", True),
    (30, "Remote Circuitry Manipulation", True),
    (31, "Cerebro-Energetic Extension", False),
    (33, "Advanced Cerebro-Stimulated Regeneration", True),
    (34, "Soma Transference", True),
    (35, "Instantaneous Quantum Relocation", False),
    (36, "Imposed Neural Restructuring", True),
    (37, "Metacreative Barrier", True),
    (38, "External Psionic Detonation", False),
    (39, "Psycho-Reflective Aura", False),
]

# Effect duration in seconds: power id -> (base, per PSI, source).
# "data": PsiShield Base Time / Add Time in shock2.gam (what the game uses).
# "help": the in-game help text (psihelp.str); these disciplines have no PsiShield entry.
# The help text disagrees with the data for 5 (says 120 + 60) and 31 (says 0 + 10); the data is used.
DURATIONS = {
    1: (20, 30, "data"), 2: (60, 20, "data"), 3: (0, 1, "help"), 4: (120, 60, "data"),
    5: (60, 30, "data"), 9: (10, 20, "help"), 10: (0, 10, "data"), 11: (10, 5, "data"),
    13: (120, 60, "data"), 14: (10, 10, "data"), 15: (15, 8, "data"), 19: (0, 20, "data"),
    20: (10, 5, "data"), 21: (0, 30, "data"), 23: (0, 20, "help"), 25: (5, 5, "data"),
    26: (0, 60, "data"), 27: (0, 3, "help"), 28: (120, 60, "data"), 31: (10, 10, "data"),
    36: (0, 10, "help"), 37: (240, 0, "help"), 38: (240, 0, "help"), 39: (10, 20, "data"),
}

# (display name, equip_weapon name). The names are the game's own, from its default user.bnd bindings.
WEAPONS = [
    ("Wrench", "wrench"),
    ("Pistol", "pistol"),
    ("Shotgun", "shotgun"),
    ("Assault Rifle", "assault rifle"),
    ("Laser Pistol", "laser pistol"),
    ("EMP Rifle", "emp rifle"),
    ("Laser Rapier", "electro shock"),
    ("Grenade Launcher", "gren launcher"),
    ("Stasis Field Generator", "stasis field generator"),
    ("Fusion Cannon", "fusion cannon"),
    ("Crystal Shard", "crystal shard"),
    ("Viral Proliferator", "viral prolif"),
    ("Annelid Launcher", "worm launcher"),
]

ACTIONS_DIR = KEYS_DIR / "actions"
BUILDER_WEAPONS_MARKER = "/*WEAPONS*/"

DRAW_MS = 800

# Key files are .txt: the game's run command ignores the extension (verified in game 2026-10-18), Nexus
# quarantined zips full of .cmd files, and double-clicking a .cmd runs it in Windows. Earlier versions used .cmd.
EXT = ".txt"

# The parts. Each is a key file in psi\lib\ that sets one aspect of a cast.
LIB_PARTS = {
    **{f"T{tier}": [f"set psi_tier {tier}"] for tier in range(1, 6)},
    "quickfire": ["set psi_mode 0"],
    "overload": ["set psi_mode 1"],
    "draw_cast": [f"set psi_draw_ms {DRAW_MS}", "summon_obj PsiCast", "equip_weapon psi amp"],
}


def tier_of(power):
    return power // 8 + 1


def file_stem(power, name):
    return f"T{tier_of(power)}_" + re.sub(r"[^A-Za-z0-9]+", "_", name).strip("_")


def key_file_lines(power, name, benefits, mode_part, inline):
    stem = file_stem(power, name) + ("_Quickfire" if mode_part == "quickfire" else "")
    lines = [
        f"set psi_name {stem}",
        f"set psi_power {power}",
        "set psi_slot 0",
        f"set psi_benefits {1 if benefits else 0}",
    ]
    for part in (f"T{tier_of(power)}", mode_part, "draw_cast"):
        lines += LIB_PARTS[part] if inline else [f"run psi\\lib\\{part}{EXT}"]
    return stem, lines


def write(path, lines):
    path.write_text("\n".join(lines) + "\n", newline="\n")


def discipline_table(with_ids):
    head = "| Tier | Discipline | Benefits from overload | Conditional overload script | Quickfire script |"
    rule = "|---|---|---|---|---|"
    rows = [("| `psi_power` " if with_ids else "") + head, ("|---" if with_ids else "") + rule]
    for power, name, benefits in DISCIPLINES:
        stem = file_stem(power, name)
        row = f"| {tier_of(power)} | {name} | {'Yes' if benefits else 'No'} | `{stem}{EXT}` | `{stem}_Quickfire{EXT}` |"
        rows.append((f"| {power} " if with_ids else "") + row)
    return "\n".join(rows)


def write_script_data():
    """The discipline list for PsiChain's inline casts (<id>o / <id>q)."""
    lines = [
        "// Generated by make_keys.py from its DISCIPLINES table - do not edit by hand.",
        "ND.psiDisciplines <- {};",
    ]
    for power, name, benefits in DISCIPLINES:
        lines.append(f'ND.psiDisciplines[{power}] <- {{ name = "{file_stem(power, name)}", benefits = {1 if benefits else 0} }};')
    # Weapon types for "previous weapon"; each has psi\actions\equip\<name, underscores>.txt.
    names = ", ".join(f'"{name}"' for _, name in WEAPONS)
    lines.append(f"ND.psiWeaponArchetypes <- [{names}];")
    # Every key file psi_autocast ships (lower case, under psi\, no extension). The 1.4 migration renames a
    # player's "run psi\X.cmd" binding to .txt only when X is in this list: other files stay as they are.
    lines.append("ND.psiKeyFiles <- {")
    for path in shipped_key_files():
        lines.append(f'\t["{path.replace(chr(92), chr(92) * 2)}"] = true,')
    lines.append("};")
    write(SCRIPT_DATA, lines)


def shipped_key_files():
    """Lower-case paths under psi\\ (no extension) of every key file make_keys writes, plus the chains folder."""
    paths = [f"lib\\{part.lower()}" for part in LIB_PARTS]
    for power, name, _ in DISCIPLINES:
        stem = file_stem(power, name).lower()
        paths += [stem, stem + "_quickfire"]
    paths += ["actions\\arm_psi_amp", "actions\\use_psi_hypo", "actions\\cancel_macro", "actions\\switch_to_previous_weapon"]
    paths += [f"actions\\switch_to_{display.replace(' ', '_').lower()}" for display, _ in WEAPONS]
    paths += [f"actions\\equip\\{name.replace(' ', '_').lower()}" for _, name in WEAPONS]
    paths += [f"chains\\{p.stem.lower()}" for p in (KEYS_DIR / "chains").glob(f"*{EXT}")]
    return sorted(set(paths))


def write_actions():
    """One-line action scripts, usable on their own key: psi hypo and weapon switches."""
    ACTIONS_DIR.mkdir(parents=True, exist_ok=True)
    for old in [*ACTIONS_DIR.glob("*.cmd"), *ACTIONS_DIR.glob(f"*{EXT}")]:
        old.unlink()
    # The chain runs these files rather than sending the commands itself: Debug.Command goes through
    # the console, which splits arguments at spaces ("equip_weapon psi amp" becomes "equip_weapon psi").
    write(ACTIONS_DIR / f"Arm_Psi_Amp{EXT}", ["equip_weapon psi amp"])
    write(ACTIONS_DIR / f"Use_Psi_Hypo{EXT}", ["use_obj psi booster"])
    write(ACTIONS_DIR / f"Cancel_Macro{EXT}", ["summon_obj PsiCancel"])
    # Not last_weapon: that skipped back past the weapon held before the macro drew the amp.
    write(ACTIONS_DIR / f"Switch_To_Previous_Weapon{EXT}", ["summon_obj PsiPreviousWeapon"])
    for display, name in WEAPONS:
        write(ACTIONS_DIR / f"Switch_To_{display.replace(' ', '_')}{EXT}", [f"equip_weapon {name}"])

    # Used by "previous weapon": psi\actions\equip\<equip name, underscores>.txt
    equip_dir = ACTIONS_DIR / "equip"
    equip_dir.mkdir(exist_ok=True)
    for old in [*equip_dir.glob("*.cmd"), *equip_dir.glob(f"*{EXT}")]:
        old.unlink()
    for _, name in WEAPONS:
        write(equip_dir / f"{name.replace(' ', '_')}{EXT}", [f"equip_weapon {name}"])


def write_builder():
    """Macro_Builder.html with the discipline list embedded, so it works offline."""
    disciplines = []
    for power, name, benefits in DISCIPLINES:
        entry = {"id": power, "tier": tier_of(power), "name": name, "file": file_stem(power, name), "benefits": benefits}
        if power in DURATIONS:
            base, per_psi, source = DURATIONS[power]
            entry["duration"] = {"base": base, "perPsi": per_psi, "source": source}
        disciplines.append(entry)
    template = BUILDER_TEMPLATE.read_text(encoding="utf-8")
    if BUILDER_DATA_MARKER not in template:
        raise SystemExit(f"{BUILDER_TEMPLATE.name} has no {BUILDER_DATA_MARKER} marker")
    if BUILDER_WEAPONS_MARKER not in template:
        raise SystemExit(f"{BUILDER_TEMPLATE.name} has no {BUILDER_WEAPONS_MARKER} marker")
    weapons = [{"label": display, "name": name} for display, name in WEAPONS]
    html = (template
            .replace(BUILDER_DATA_MARKER, json.dumps(disciplines, separators=(",", ":")))
            .replace(BUILDER_WEAPONS_MARKER, json.dumps(weapons, separators=(",", ":"))))
    for target in (BUILDER, SITE_BUILDER):
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(html, encoding="utf-8", newline="\n")


def update_table(doc, with_ids):
    text = doc.read_text()
    block = f"{TABLE_START}\n{discipline_table(with_ids)}\n{TABLE_END}"
    pattern = re.compile(re.escape(TABLE_START) + r".*?" + re.escape(TABLE_END), re.S)
    if not pattern.search(text):
        raise SystemExit(f"{doc.name} has no {TABLE_START} ... {TABLE_END} block")
    doc.write_text(pattern.sub(lambda _: block, text), newline="\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--inline", action="store_true", help="copy the parts into each key file instead of calling them")
    args = parser.parse_args()

    LIB_DIR.mkdir(parents=True, exist_ok=True)
    for part, lines in LIB_PARTS.items():
        write(LIB_DIR / f"{part}{EXT}", lines)
    for old in LIB_DIR.glob("*.cmd"):
        old.unlink()

    for old in [*KEYS_DIR.glob("*.cmd"), *KEYS_DIR.glob(f"*{EXT}")]:
        old.unlink()
    for power, name, benefits in DISCIPLINES:
        for mode_part in ("overload", "quickfire"):
            stem, lines = key_file_lines(power, name, benefits, mode_part, args.inline)
            write(KEYS_DIR / f"{stem}{EXT}", lines)

    update_table(README, with_ids=False)
    update_table(CLAUDE_GUIDE, with_ids=True)
    write_script_data()
    write_actions()
    write_builder()
    print(f"wrote {len(LIB_PARTS)} parts, {2 * len(DISCIPLINES)} key files, README and Claude guide tables")


if __name__ == "__main__":
    main()

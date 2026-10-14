# psi_autocast: one-key psi casting for System Shock 2 Remastered

**TLDR:** One key draws the psi amp, selects a power, and casts it, either as a normal cast or as a timed overload, with no click. A small script mod adds a timer-driven helper object. Each key is a `.cmd` file of settings that the game reads fresh on every press, so you can tune it while the game runs.

## Contents
1. [Current keys](#current-keys)
2. [How it works](#how-it-works)
3. [Key file settings](#key-file-settings)
4. [Adding a power](#adding-a-power)
5. [Tuning an overload](#tuning-an-overload)
6. [Loading the mod](#loading-the-mod)
7. [Building and installing](#building-and-installing)
8. [Packaging and performance](#packaging-and-performance)
9. [Engine facts learned the hard way](#engine-facts-learned-the-hard-way)
10. [Open questions](#open-questions)
11. [File locations](#file-locations)

## Current keys

| Key | File | Quick slot | Hold | Result |
|---|---|---|---|---|
| G | `psi_cryo.cmd` | 6, Projected Cryokinesis | 100 ms | Normal cast |
| J | `psi_cryo_overload.cmd` | 6, Projected Cryokinesis | 1550 ms | Overload |
| K | `psi_pyro.cmd` | 7, Localized Pyrokinesis | 100 ms | Normal cast |

From any weapon, the key draws the amp, waits for it to come up, then casts. With the amp already in hand, it casts straight away.

## How it works

1. The key's binding in `user.bnd` runs a command file: `bind g "run psi_cryo.cmd"`.
2. The `.cmd` file stores its settings in game config variables, summons a `PsiCast` helper object, then equips the amp.
3. `PsiCast` (a Squirrel script in the mod) checks whether the amp was already in hand, then waits the draw time or about 10 ms.
4. It runs `quickuse <slot>` and `fire_weapon 1`, which presses the trigger.
5. After the hold time it runs `fire_weapon 0` to release, which casts, and then deletes itself.

The helper exists because a `.cmd` file can't pause. Every line runs in the same frame, so a press and release in one file cancels the cast. The helper's timer supplies the delay.

## Key file settings

```
set psi_slot 6          quick slot holding the power
set psi_draw_ms 800     wait for the amp to come up (skipped if it's already in hand)
set psi_release_ms 100  how long fire is held: 100 = normal cast, longer = overload
summon_obj PsiCast      must come BEFORE equip_weapon, so the helper sees what was in hand
equip_weapon psi amp
```

- Edit these while the game is running. The next keypress uses the new values.
- `psi_draw_ms 800` was tested from the pistol only. Heavier weapons may need longer.

## Adding a power

1. In game, open the psi power list, hover over the **power itself** (not the tier's entry, which is the first in the list), and press **Shift+F8** (or any F-key slot from F8 to F12).
2. Copy a key file in `keys/`, rename it, and set `psi_slot` to that slot number.
3. Use `psi_release_ms 100` for a normal cast. For an overload, tune it as in the next section, and only for powers that benefit (the [wiki's list](https://shodan.fandom.com/wiki/Psionic_Disciplines)). Any power can burn out if held too long.
4. With the game **closed**, add a binding to `user.bnd` for a free key: `bind <key> "run <file>.cmd"`.
5. Run `py build.py --install` to copy the key file into the game.

Quick slots are saved per save game. On a save where the slot is empty, the key draws the amp and then does nothing. Set the slot again with Shift+F-key.

## Tuning an overload

- The overload zone is the yellow box at the right end of the bar. **Too early** gives a normal cast. **Too late** causes burnout: the power fails and you take damage.
- **Higher-tier powers fill the bar faster**, so each overloaded power needs its own hold time.
- **More PSI widens the yellow box**, so a value tuned now stays valid as PSI rises.
- Method: put three neighbouring values on three keys, then step until one prints `OnOverloadSuccess` in the console. Pick a value a little past where the zone starts.
- Cryokinesis (tier 1), at the PSI on 2026-10-14: 1450 ms gave a normal cast. 1500, 1550, 1600 and 1650 ms all overloaded with no burnout. 1550 ms is in use.
- The game runs at a locked 60 FPS (v-sync), so the timing is accurate to within about 17 ms, a single frame.

## Loading the mod

- The game loads the mod list stored **in the save** being loaded. A save made before the mod existed won't load it, even though the global mod list (`cam_user.cfg`) includes it.
- **Never run `mod_apply` mid-game.** It unloaded the level (empty world, silent, HUD of zeros), and pressing M (map) afterwards crashed the game.
- Safe method: **New Game → Mods → add psi_autocast → Apply → start → quickload (Alt+L)** once the first level loads. Then make a regular save.
- Check with `mod_list` in the console: psi_autocast should be under "Mods to load."

## Building and installing

```
py build.py            build dist/psi_autocast.kpf
py build.py --install  build, copy keys/*.cmd into the game, and replace the .kpf if the game is closed
```

- A `.kpf` is a renamed `.zip`. Its contents: `modinfo.json` and `sq_scripts/psi_autocast.nut`.
- **Script changes need a game restart.** The mod is only read at startup.
- **Key files don't need one.**
- **Bindings in `user.bnd` need the game closed.** The game rewrites the file on exit, so edits made while it runs are lost.

## Packaging and performance

**The packaging has no measurable effect on speed:**
- The script is read and compiled **once at startup**. Being inside a compressed `.kpf` costs a fraction of a millisecond, at load time only.
- A `.cmd` file is read **on each keypress**. That's under 200 bytes from the Windows file cache: microseconds, far below one 17 ms frame.
- Each cast creates **one helper object** with two timers, and it deletes itself within 2 seconds.

**What the current layout trades off:**

| Part | Where it lives | Why |
|---|---|---|
| Script | Inside the `.kpf` | Must be: the game only loads scripts from mod packages |
| Key files | Loose, in the game's install folder | Editable during play, with no rebuild or restart |
| Bindings | `user.bnd` | The only binding system that reaches game commands |

**Possible tidy-ups, untested:**
- **Moving the key files into a subfolder,** for example `run psi/psi_cryo.cmd`, would keep the install folder clean. That depends on `run` accepting paths.
- **Moving the key files inside the `.kpf`** would make the mod one file. That depends on `run` reading from mod packages, and every tuning change would then need a rebuild and restart. Not recommended while still tuning.
- **Removing the obsolete test helpers** from the script (`PsiAutoCast`, `PsiAutoOverload`, `PsiOverload090`–`150`, `PsiDraw080/100/120`). They cost nothing at runtime; it's only to keep the code clear.

## Engine facts learned the hard way

- **Two binding systems.** The console's `bind`, `listbinds` and `unbindkey` are Nightdive's (KEX) and are stored in `kexengine.cfg`, but binds made there never reached game commands. Game controls live in `user.bnd`.
- **Semicolons don't chain** commands in a `user.bnd` binding. One command per binding; use `run file.cmd` for several.
- **A second binding on the same key replaces the first.**
- **`+` (press/release) works only for built-in commands** such as `+fire_weapon`, not `+run`.
- **No `wait`, `alias` or delay command** exists.
- **`fire_weapon N`** means press for any non-zero N and release for 0. It is not a shot count.
- **Console arguments split on spaces:** `equip_weapon "psi amp"` needs quotes in the console. Inside a `.cmd` file, `equip_weapon psi amp` works without them.
- **Switching weapons and firing in the same frame** leaves the trigger stuck as held, which blocks weapon switching. A click releases it.
- **The scripts can run console commands** with `Debug.Command("...")`, set timers with `SetOneShotTimer`, read config with `Engine.ConfigGetInt(name, int_ref())`, and check the held weapon with `ShockGame.Equipped(0)`.
- **New script objects** are defined with `ND.Archetype("Name", "ND", function(){ AddScript("Name"); })`.
- **Under KEX, the game runs NewDark 2.48** (`App Version: System Shock 2 Patch Final 2.48` in the log).

## Open questions

- **Which folder does `run` read from?** Copies sit in both the install folder and the save folder. The install folder is the likely one: the log reports `CWD: base:`.
- **Draw time from heavier weapons,** once you can use them. The script could pick the wait by weapon type.
- **Tap for a normal cast and hold for an overload on the same key.** This isn't possible: a script can't read whether a key is held.

## File locations

| What | Path |
|---|---|
| Project (this folder) | `D:\repos\SS2PsiAutocast` |
| Game install | `D:\EpicLibrary\SystemShock225thAnniT5DFq` |
| Installed mod | `…\SystemShock225thAnniT5DFq\mods\psi_autocast.kpf` |
| Key files in use | `…\SystemShock225thAnniT5DFq\*.cmd` (also copied to the save folder) |
| Bindings | `%USERPROFILE%\Saved Games\Nightdive Studios\System Shock 2 Remastered\user.bnd` |
| Binding backups | same folder, `user.bnd.backup` … `user.bnd.backup6` |
| Global mod list | same folder, `cam_user.cfg` (`mod_path` line) |
| Engine log | same folder, `kexengine.log` (locked while the game runs) |
| Console dump | `condump` in the console writes `condump.txt` to the install folder |
| Game's own scripts | inside `mods\sshock2ee.kpf`, under `sq_scripts/` |

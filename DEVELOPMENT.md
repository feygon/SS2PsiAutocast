# Developer notes

**TLDR:** The mod is one Squirrel class (`PsiCast`) that runs console commands on a timer. A key's `.cmd` file passes it settings through config variables. These notes record how the remaster's engine behaves, so later changes don't have to rediscover it.

## Contents
1. [Layout](#layout)
2. [Build and install](#build-and-install)
3. [How a cast runs](#how-a-cast-runs)
4. [Packaging and performance](#packaging-and-performance)
5. [Engine facts](#engine-facts)
6. [Open questions](#open-questions)
7. [Useful paths](#useful-paths)

## Layout

| Path | Contents |
|---|---|
| `mod/` | Packed into `psi_autocast.kpf`: `modinfo.json` and `sq_scripts/psi_autocast.nut` |
| `psi/` | Example key files, installed to `<game>\psi\` |
| `build.py` | Build, package and install |
| `dist/` | Build output (ignored by git) |

## Build and install

```
py build.py            build dist/psi_autocast.kpf
py build.py --package  also build dist/psi_autocast_v<version>.zip, laid out to extract into the game folder
py build.py --install  also copy psi/*.cmd to <game>\psi\, and replace the .kpf if the game is closed
```

- `GAME_DIR` in `build.py` points at the author's Epic install. Change it for a different install.
- **Script changes need a game restart.** The mod is only read at startup.
- **Key files don't.** They're read on every keypress.
- **`user.bnd` must be edited with the game closed.** The game rewrites it on exit.

## How a cast runs

1. `bind j "run psi\T1_Projected_Cryokinesis.cmd"`: the binding runs the key file.
2. The key file sets `psi_name`, `psi_power`, `psi_slot` and `psi_benefits`. Then it runs three parts:
   - the tier part, which sets `psi_tier`;
   - the mode part, which sets `psi_mode`;
   - `draw_cast`, which sets `psi_draw_ms`, runs `summon_obj PsiCast`, then `equip_weapon psi amp`.
3. **`PsiCast.OnBeginScript`:**
   - reads the settings with `Engine.ConfigGetInt` / `ConfigGetRaw`;
   - takes effective PSI from `ShockGame.GetStat("Player", eStats.kStatPsi)`, capped to 1–8;
   - works out the overload zone from the `OLPARAM` values, and picks a hold time based on the mode and whether the discipline benefits;
   - prints the decision;
   - checks `ShockGame.Equipped(0)` against `Psi Amp`, then sets a timer: 10 ms if the amp is in hand, otherwise the draw time.
4. **Timer `PsiSelect`:** selects the discipline with `ShockGame.SetSelectedPsiPower(id)`, or `quickuse N` when `psi_power` is 0. Then it presses fire with `fire_weapon 1`.
5. **Timer `PsiRelease`:** releases fire with `fire_weapon 0`, which casts, then calls `Object.Destroy(self)`.

## Generating key files

- **`py make_keys.py`** writes `psi\lib\` (the parts), two scripts per discipline in `psi\`, and the README's discipline table (between the `disciplines:start/end` markers).
- **`py make_keys.py --inline`** copies the parts' lines into each script instead of calling them with `run`. Use it if nested `run` turns out not to work.
- **The discipline list** (id, name, overload benefit) is the `DISCIPLINES` table in `make_keys.py`. Edit it there, never the generated files.

## Game data used

- **Discipline ids:** each `PsiPower` record's `Power` field in `shock2.gam` / `shockscp.gam` equals the `Psi<N>` index in `strings/psihelp.str`. The internal archetype names are legacy names: 6 `Cryokinesis`, 15 `Immolate`, 22 `Pyrokinesis`.
  - **Tier** = id / 8 + 1.
  - **Ids 0, 8, 16, 24, 32** are the tiers' Neural Capacity entries, not castable.
  - **The `Start Cost` field** equals the tier.
- **Overload timing:** the `OLPARAM` chunk ("Overload Params", 16 floats). It's identical in the base game and SCP:
  - **Floats 0–7:** where the yellow zone starts, as a fraction of the bar, for pre-overload PSI 1–8: 1.00 0.94 0.85 0.73 0.58 0.40 0.19 0.01.
  - **Floats 8–12:** bar fill time in seconds for tiers 1–5: 2.0 1.5 1.0 0.75 0.4.
  - **Floats 13–15:** 0.85 0.82 0.78, meaning unknown (burnout-related?).
  - **Validated by testing:** tier 1 at PSI 4 (zone 1460–2000 ms, matched); tier 2 burnout just after 1500 ms, at PSI 4 and 5.
- **Psi amp refire:** its `BaseGunDesc` setting 0 has **Shot Interval = 500 ms**, which is the minimum time between casts. The remaster's `shoot` viewmodel animation (30 fps, 60 frames) is cosmetic and doesn't limit firing.
- **Reading game data files:** a `.gam` file is a Dark tag file. The first uint32 is the table-of-contents offset. The table of contents is a uint32 count followed by 20-byte entries (12-byte name, offset, size). Each chunk starts with a 24-byte header. Property chunks (`P$…`) are records of int32 object id, uint32 size, then the data.
- **Learned disciplines:** `PsiPowerDesc` / `PsiPower2Desc` on the player are probably bit sets of learned disciplines (ids 0–31 and 32–39). Unverified, so the script only warns.

## Packaging and performance

- **Script inside the `.kpf`:** required, since the game loads scripts only from mod packages. It's compiled once at startup, so being compressed costs nothing during play.
- **Key files loose in `psi\`:** each is read per keypress, under 200 bytes, from the Windows file cache. That takes microseconds, against a 17 ms frame.
- **Per cast:** one helper object and two timers, deleted within 2 seconds.
- **Timing accuracy:** timers and the overload bar both run on game time, so a slowdown affects both equally. The remaining error is one frame, about 17 ms at the v-sync-locked 60 FPS.

## Engine facts

**Bindings and console:**
- **Two binding systems.** The console's `bind`, `listbinds` and `unbindkey` belong to KEX and are stored in `kexengine.cfg`. Binds made there never triggered game commands. Game controls live in `user.bnd`.
- **`user.bnd` limits:**
  - **One command per binding.** Semicolons don't chain.
  - **A second binding on the same key replaces the first.**
  - **`+` (press/release) works only for built-in commands** such as `+fire_weapon`. `+run` does nothing.
- **No `wait`, `alias` or delay command exists.** `run` and `exec` execute a whole file in one frame.
- **`run` accepts a subfolder path with a backslash:** `run psi\file.cmd` works, `run psi/file.cmd` doesn't. Paths are relative to the install folder.
- **Console arguments split on spaces:** in the console, use `equip_weapon "psi amp"`. In a `.cmd` file, `equip_weapon psi amp` works.
- **`fire_weapon N`:** any non-zero N presses, 0 releases. It isn't a shot count.
- **Weapon switch plus fire in the same frame** leaves the trigger stuck as held, which blocks weapon switching until a click releases it.

**Saves and mods:**
- **Quick slots (`quickuse`/`quickbind`) are stored per save.**
- **The mod list is stored per save.** `cam_user.cfg`'s `mod_path` holds the global list, but loading a save uses that save's list.
- **`mod_apply` mid-game unloads the level** (empty world, no sound, HUD of zeros). Opening the map afterwards crashed the game with a null-pointer access violation.

**Scripting:**
- **Under KEX, the game runs NewDark 2.48** (`App Version: System Shock 2 Patch Final 2.48` in the log). `nvscript` and `squirrel` DLLs ship with the game.
- **Script API used here:**
  - `Debug.Command("cmd args")` runs a console command
  - `print()` writes to the console and the log; `Debug.MPrint` reaches the log only
  - `SetOneShotTimer(name, seconds)` / `OnTimer` handle timers
  - `Engine.ConfigIsDefined` / `ConfigGetInt(name, int_ref())` read config values
  - `ShockGame.Equipped(0)` returns the held weapon
  - `Object.InheritsFrom` / `Object.Named` check archetypes
- **New archetypes:** `ND.Archetype("Name", "ND", function(){ AddScript("Name"); })`, from the remaster's own `libs/archetype_system.nut`.
- **The game's scripts** are inside `mods\sshock2ee.kpf` under `sq_scripts/`. `libs/` and `debug/` load in the order given by `squirrel.ini`; top-level `.nut` files load automatically.
- **The remaster's player script** logs `OnOverloadSuccess` when the player gets an `OverloadSuccess` message. The player's four script slots are all taken, so a script of your own can't be added there. Instead, use `ND.g_PlayerCore.Subscribe(listener, "OverloadSuccess")` with a plain class instance that has an `OnOverloadSuccess(message)` method. The dev probe does this.
- **Script compile errors** show up only in the console or log, at load time, as `[darkscript] kpf:/mods/…nut line = (N) column = (M) : error …`. A file that fails to compile defines nothing, so `summon_obj` for its objects fails silently. After a script change, run `condump` and search for `error`.
- **Never call `Debug.Command("run …")` from `OnBeginScript`.** An object summoned by a `.cmd` file starts while that file is still being read, and a `run` at that moment re-enters the outer file. That re-summoned the chain endlessly, until the game reported `Native stack overflow`. Start work from a short timer instead. `PsiCast` and `PsiChain` both do.
- **`base` is a Squirrel keyword** (the parent class), so it can't be used as a variable name.

**Commands found in `help` / `dump_cmds`:**
- **Psi and controller:** `cycle_ammo_psipower`, `cycle_setting_psilevel`, `select_psi_mode`, `last_weapon`
- **Saving the console to a file:** `condump`
- **Data-file commands:** `dbmod_load`, `toggle_dbmod_remap`, `dump_props`

## Open questions

- **Tested in game (v1.1, 2026-10-14, PSI 4):**
  - **`ShockGame.SetSelectedPsiPower(id)`** selects the discipline that the next `fire_weapon` casts. Kinetic Redirection was selected and the pistol was in hand; the key drew the amp, switched to Cryokinesis and overloaded it.
  - **Nested `run`** works: key files calling `run psi\lib\…` apply every part.
  - **Chains (v1.2):** Localized Pyrokinesis (immediate), then Projected Cryokinesis (`OnOverloadSuccess`), from the pistol, with 700 ms and 500 ms gaps.
  - **Conditional overload:** tier 1 held 1564 ms, giving `OnOverloadSuccess`. The tier 2 no-benefit discipline cast immediately, with the console explanation.
- **Still untested:**
  - **Effective versus base PSI** for the zone lookup. They were equal during testing.
  - **The `PsiPowerDesc` learned-bits reading.** No false warnings for two learned disciplines; an unlearned one hasn't been tried.
  - **Tiers 3–5:** their timings are predicted from the table but not yet confirmed by an overload.
- **Draw time from heavier weapons.** `PsiCast` could pick the wait by the held weapon's archetype.
- **Tap for a normal cast and hold for an overload on the same key:** not possible, because a script can't read whether a key is held.
- **Steam and GOG installs:** untested. The expected difference is only the install path.

## Useful paths

| What | Path |
|---|---|
| Bindings, global mod list, log | `%USERPROFILE%\Saved Games\Nightdive Studios\System Shock 2 Remastered\` (`user.bnd`, `cam_user.cfg`, `kexengine.log`) |
| Mods | `<game>\mods\` |
| Console dump | `<game>\condump.txt` |
| Crash reports | `<game>\crashlog.tar` |

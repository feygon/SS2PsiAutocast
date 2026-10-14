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

1. `bind g "run psi\psi_slot6_quick.cmd"`: the binding runs the key file.
2. The key file runs `set psi_slot / psi_draw_ms / psi_release_ms`, then `summon_obj PsiCast`, then `equip_weapon psi amp`.
3. `PsiCast.OnBeginScript` reads the settings with `Engine.ConfigGetInt`. It checks `ShockGame.Equipped(0)` against the `Psi Amp` archetype, then sets a timer for 10 ms if the amp was in hand, or for the draw time if not.
4. Timer `PsiSelect` runs `Debug.Command("quickuse N")` and `Debug.Command("fire_weapon 1")`, then sets timer `PsiRelease`.
5. Timer `PsiRelease` runs `Debug.Command("fire_weapon 0")`, which casts, then calls `Object.Destroy(self)`.

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
- **The remaster's player script** logs `OnOverloadSuccess` when the player gets an `OverloadSuccess` message. A second script added to `The Player` archetype (four script slots, `NDPlayer` uses one) can catch the same message. The dev probe does this.
- **Script compile errors** show up only in the console or log, at load time, as `[darkscript] kpf:/mods/…nut line = (N) column = (M) : error …`. A file that fails to compile defines nothing, so `summon_obj` for its objects fails silently. After a script change, run `condump` and search for `error`.
- **`base` is a Squirrel keyword** (the parent class), so it can't be used as a variable name.

**Commands found in `help` / `dump_cmds`:**
- **Psi and controller:** `cycle_ammo_psipower`, `cycle_setting_psilevel`, `select_psi_mode`, `last_weapon`
- **Saving the console to a file:** `condump`
- **Data-file commands:** `dbmod_load`, `toggle_dbmod_remap`, `dump_props`

## Open questions

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

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
| `extras/` | GitHub only, never packaged: `starterPsiPowers.bat`, which binds the G and J starter keys. A `.bat` in the Nexus zip would trip Nexus's executable quarantine |
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

**Macro hooks (2026-10-21):** other scripts can act around every macro by defining global functions `PsiMacroStarted(obj)` and `PsiMacroEnded(obj)`.
- **Start:** a cast calls `PsiMacroStarted` at `PsiSelect`, just before it presses fire; a chain calls it at its first step.
- **End:** `PsiMacroEnded` is called however the macro ends: released, done, cancelled, or stopped on an error.
- **Nesting:** a chain's own casts call both hooks too.
- **Safety:** `PsiMacroHook` does nothing when a hook isn't defined, and prints a hook's error without stopping the macro.
- **Timing:** `fire_weapon 0` is only queued when `PsiMacroEnded` runs, so a hook shouldn't undo anything the cast needs until a moment later.
- **Who uses them:** psi_autocast_mfd's dev armor tool, to wear the worm skin while macros run.

## Generating key files

- **`py make_keys.py`** writes `psi\lib\` (the parts), two scripts per discipline in `psi\`, and the discipline tables in README.md and MACROS_FOR_CLAUDE.md (between the `disciplines:start/end` markers).
- **`py make_keys.py --inline`** copies the parts' lines into each script instead of calling them with `run`. Use it if nested `run` turns out not to work.
- **The discipline list** (id, name, overload benefit) is the `DISCIPLINES` table in `make_keys.py`. Edit it there, never the generated files.

## Game data used

- **Discipline ids:** each `PsiPower` record's `Power` field in `shock2.gam` / `shockscp.gam` equals the `Psi<N>` index in `strings/psihelp.str`. The internal archetype names are legacy names: 6 `Cryokinesis`, 15 `Immolate`, 22 `Pyrokinesis`.
  - **Tier** = id / 8 + 1.
  - **Ids 0, 8, 16, 24, 32** are the tiers' Neural Capacity entries, not castable.
  - **The `Start Cost` field** equals the tier.
- **Overload timing:** the `OLPARAM` chunk ("Overload Params", 16 floats). It's identical in the base game and SCP:
  - **Floats 0–7:** where the yellow zone starts, as a fraction of the bar: 1.00 0.94 0.85 0.73 0.58 0.40 0.19 0.01. **Measured in game (2026-10-18): the game uses BASE PSI (implants don't count), one entry lower than PSI 1–8 order suggests:** base PSI 6 uses 0.58, base 5 uses 0.73 (`PsiZoneRow`: entry = base PSI − 2).
  - **Floats 8–12:** bar fill time in seconds for tiers 1–5: 2.0 1.5 1.0 0.75 0.4.
  - **Floats 13–15:** 0.85 0.82 0.78, meaning unknown (burnout-related?).
  - **Validated by testing (2026-10-18, `OnOverloadSuccess` in condump):** fixed-hold casts at all five tiers at base PSI 6 (with and without a +1 PSI implant: same window) and tier 3 at base 5; 24 measurements, all in `test_overload_window_matches_the_game`. Then with the fix, at base PSI 5: 10 of 10 conditional overloads across tiers 1–5 landed. Tier 2 burnout just after 1500 ms (earlier). The original note "tier 1 at PSI 4 matched 1460 ms" read total PSI; its base PSI wasn't recorded.
  - **Release lag:** a release lands 21–40 ms (mean 30) after its timer (15 casts). Narrow zones (under the usual 150 ms of margins, e.g. tier 5 at base PSI 5: 292–400 ms) are aimed at their middle minus 30 ms; zones under 50 ms cast immediately.
- **Discipline durations:** `PsiShield` (Base Time, Add Time per PSI, in seconds) in `shock2.gam` covers 17 disciplines and matches `psihelp.str` except Psychogenic Cyber-Affinity (data 60 + 30, help 120 + 60) and Cerebro-Energetic Extension (data 10 + 10, help 0 + 10). The builder uses the data, and the help text for the 7 timed disciplines without a `PsiShield` entry. Durations haven't been timed in play.
- **Psi amp refire:** its `BaseGunDesc` setting 0 has **Shot Interval = 500 ms**, which is the minimum time between casts. It doesn't shrink with PSI: at PSI 6 a 400 ms chain gap dropped the second cast (the fire press was ignored), while 500 ms works. The remaster's `shoot` viewmodel animation (30 fps, 60 frames) is cosmetic and doesn't limit firing.
- **Reading game data files:** a `.gam` file is a Dark tag file. The first uint32 is the table-of-contents offset. The table of contents is a uint32 count followed by 20-byte entries (12-byte name, offset, size). Each chunk starts with a 24-byte header. Property chunks (`P$…`) are records of int32 object id, uint32 size, then the data.
- **Learned disciplines:** `PsiPowerDesc` / `PsiPower2Desc` on the player are bit sets of learned disciplines (ids 0–31 and 32–39; tier headers 0, 8, 16, 24 and 32 are the unlocked tiers). Verified 2026-10-16 through psi_autocast_mfd, whose "bought" column matched the player's disciplines.

## Packaging and performance

- **Script inside the `.kpf`:** required, since the game loads scripts only from mod packages. It's compiled once at startup, so being compressed costs nothing during play.
- **Key files loose in `psi\`:** each is read per keypress, under 200 bytes, from the Windows file cache. That takes microseconds, against a 17 ms frame.
- **Per cast:** one helper object and two timers, deleted within 2 seconds.
- **Timing accuracy:** timers and the overload bar both run on game time, so a slowdown affects both equally. The remaining error is one frame, about 17 ms at the v-sync-locked 60 FPS.

## Engine facts

**Bindings and console:**
- **`run` ignores the file extension (2026-10-18).** `run psi\zz_ext_test.txt` and `run user:/psi_macros\zz_ext_test.txt`, each holding `set psi_txt_test …`, both ran (`setting 'psi_txt_test' to '…'` in the condump). So key files could be `.txt` instead of `.cmd`. A missing file prints nothing.
- **`echo` prints nothing** to the console or condump (a `.txt` file holding only `echo …` ran without output). Use `set <name> <value>` to prove a file ran: every `set` logs `setting '<name>' to '<value>'`.
- **Two binding systems.** The console's `bind`, `listbinds` and `unbindkey` belong to KEX and are stored in `kexengine.cfg`. Binds made there never triggered game commands. Game controls live in `user.bnd`.
- **`user.bnd` limits:**
  - **One command per binding.** Semicolons don't chain.
  - **A second binding on the same key replaces the first.**
  - **`+` (press/release) works only for built-in commands** such as `+fire_weapon`. `+run` does nothing.
- **No `wait`, `alias` or delay command exists.** `run` and `exec` execute a whole file in one frame.
- **`run` accepts a subfolder path with a backslash:** `run psi\file.cmd` works, `run psi/file.cmd` doesn't. Paths are relative to the install folder.
- **`last_weapon` doesn't count `equip_weapon` switches.** After the pistol, then a macro drawing the amp, it went back to the wrench. "Previous weapon" therefore remembers `ShockGame.Equipped(0)` when a macro draws the amp. It matches that weapon to a known weapon type with `Object.InheritsFrom` (weapons can be variants: the amp is `StarterAmp`), then switches back by running `psi\actions\equip\<type>.cmd`, which uses `equip_weapon`.
- **Never use `ShockGame.Equip(0, weapon)` to switch the player's weapon.** In game it brought out the pistol, but afterwards the amp couldn't be equipped at all, not by macros or by its own key, until the save was reloaded. The game's cutscene code only uses it in a clear-then-restore pair around a cutscene.
- **`Debug.Command` only queues console commands.** A run of `set` lines followed by `summon_obj` from a script executed over several frames, each value picked up a trailing space (`'6 '`), and the summon never took effect. Chain casts therefore pass their settings in `ND.psiPendingCast` and create the helper with `Object.Create("PsiCast")`, the way the game's cutscene code creates objects.
- **`Debug.Command` goes through the console,** so a script sending `equip_weapon psi amp` gets `equip_weapon psi`, which does nothing. The arm, hypo and weapon chain steps hit this. They now run one-line action files (`psi\actions\*.cmd`) instead, because lines in `.cmd` files take multi-word arguments.
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
- **`condump` is a 1,025-line ring buffer.** Once it wraps, the newest lines continue at the top of `condump.txt`, so read the start of the file as well as the end.
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
- **Tested in game (2026-10-15, PSI 4, Normal or harder, no Pharmo-Friendly):** all of `dev/tests/TEST_PLAN.md` passed, from the pistol:
  - **`arm` + `6o`:** amp drawn, overload with `OnOverloadSuccess`.
  - **`6q,w500,15q`:** both casts go off, 549 ms apart.
  - **`hypo` between casts:** a hypo is used.
  - **`last`:** back to the pistol, twice in a row; the amp could still be drawn afterwards, by macro and by hand.
  - **`weapon:Wrench`:** wrench drawn.
  - **`psi_auto_hypo`:** at 13/51 psi, a hypo before cast 1 (threshold 31 = 51 − 20). At 32, no hypo. At 31, a second hypo. Re-checked before each cast, never wasting one.
  - **No-arm guard:** with a non-amp weapon, the chain stops without firing. With the amp out, it casts.
  - **Cancel:** Numpad + during a wait stopped the chain at step 5/8, with nothing stuck.
- **Fixed along the way:**
  - `Debug.Command` splitting at spaces (arm, hypo and weapon steps now run action files).
  - Queued console `set` commands (chain casts now use `ND.psiPendingCast` and `Object.Create`).
  - `last_weapon` going one weapon too far back.
  - `ShockGame.Equip` leaving the amp unequippable.
- **Still untested:**
  - **Auto psi hypo on Easy (30) and with Pharmo-Friendly (36 / 24).** Only the 20-point case has run.
  - **Cancel while a cast is mid-charge,** and Cancel with nothing running.
  - **Effective versus base PSI** for the zone lookup. They were equal during testing.
  - **Tiers 3–5:** confirmed 2026-10-18 (see "Overload timing").
  - **The starter keys in game:** `starterPsiPowers.bat` passed against a test `user.bnd` (free keys get bound; existing custom `bind g`/`bind J` bindings are left alone and reported; `g+shift` and `gamma` don't count as G; a second run adds nothing; a last line without a newline; a missing file). The J chain (`arm,15q,w500,last`) hasn't been pressed in game; it uses only steps that passed above.
- **Draw time from weapons other than the pistol:** untested. If it turns out to differ, `PsiCast` could pick the wait by the held weapon's archetype.
- **A psi-macro MFD (researched 2026-10-16, nothing built or tested).** MFDs are SS2's in-game HUD panels. The exe has NewDark's SS2 overlay API, including a Squirrel handler (`sqShockOverlayHandler`, under `IShockOverlayHandler`):
  - **Handler callbacks:** `DrawHUD`, `DrawTOverlay`, `OnUIEnterMode`, `CanEnableElement`, `IsMouseOver`, `MouseClick`, `MouseDblClick`, `MouseDragDrop`, `HandleKey`.
  - **`ShockOverlay` service:** `AddHandler`/`RemoveHandler`, `DrawString`, `GetStringSize`, `SetTextColor`, `SetFont`/`SetCustomFont`, `DrawBitmap`/`DrawSubBitmap`, `GetBitmap`, `DrawLine`, `DrawObjectIcon`, `GetOverlayRect`, the transparent-overlay calls (`CreateTOverlayItem`, `BeginTOverlayUpdate`, `FillTOverlay`, `DrawTOverlayItem`, `UpdateTOverlayPosition`/`Size`/`Alpha`), `SetKeyboardInputCapture`, cursor calls (`GetCursorMode`, `ClearCursorMode`, `SetCursorBitmap`), and `WorldToScreen`.
  - **So a script can draw its own panel, take mouse clicks, and capture keypresses:** for example, a list of macros where you click one and press a key to bind it. The bind would go through `Debug.Command`, which splits arguments at spaces; quoting (`bind g "run psi\…"`) works in the console but hasn't been tried from a script. The game saves `user.bnd` on exit.
  - **Saving macros written in the panel:** scripts can write files. The game links Squirrel's standard I/O library, and Nightdive's `libs/helpers.nut` writes with `file("user:/\\sq_cache\\" + name, "w")` and `writen(c, 'c')` (`ND.WriteToFile`, `ND.WriteStringToFile`). Which paths are writable, and whether `run` or `exec` can then run the written file, is untested.
  - **This is being built as a separate mod,** `psi_autocast_mfd`, in its own repo (`D:\repos\SS2PsiAutocastMFD`), so its file writing gets its own Nexus quarantine review. Its first dev build is a capability probe.
- **The Options menu, for comparison (same research):**
  - **The menus are RmlUi documents** in `base.kpf` (`menu/*.rml`, `*.rcss`). Options → Controls → Keyboard bindings is `menu/dialog_kbmbinds.rml`: a list of `<shock2_bind filter="kbm" command="…" label="…" />` elements, one per bindable command. The game's own entries include multi-word commands (`equip_weapon assault rifle`), so `run psi\T1_Projected_Cryokinesis.cmd` should fit the same format.
  - **So a mod could add psi macros to the game's own bindings page** by shipping its own copy of `menu/dialog_kbmbinds.rml` in the `.kpf` with extra `shock2_bind` rows. Unverified: whether a mod `.kpf` overrides a `base.kpf` file (none of the bundled mods override a menu file); whether `label` takes literal text (shipped labels are all `$string` references); and whether the bind validator ("Bind: `{}` is not a valid bind.") accepts `run …`. A full-file override would also need re-syncing after game updates, and would clash with any other mod that overrides the same page.
  - **A menu button can probably run any console command:** `kexRmlContainer` handles an `ev_execute` event and a `kex-command` attribute alongside `ev_dialog` and `ev_push_menu`. No shipped page uses them. `kex-shock2-action` itself only takes a fixed list (continue, endgame, quit, credits, start_game, abortload, continue-killsfx).
  - **Menus can't save macros themselves.** A text field (`kex_input`) exists, but there's no sign that `kex-command` can include its value. The console has `bind`, `unbind`, `exec` and `writeuserconfig`, so a menu could bind keys live, and the game saves `user.bnd` on exit. A chain written in game would live only in config variables until exit, unless `writeuserconfig` saves arbitrary `set` variables to `cam_user.cfg` (untested).
- **Tap for a normal cast and hold for an overload on the same key:** not possible, because a script can't read whether a key is held.
- **Steam and GOG installs:** untested. The expected difference is only the install path.

## Useful paths

| What | Path |
|---|---|
| Bindings, global mod list, log | `%USERPROFILE%\Saved Games\Nightdive Studios\System Shock 2 Remastered\` (`user.bnd`, `cam_user.cfg`, `kexengine.log`) |
| Mods | `<game>\mods\` |
| Console dump | `<game>\condump.txt` |
| Crash reports | `<game>\crashlog.tar` |

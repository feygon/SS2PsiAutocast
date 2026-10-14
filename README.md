# psi_autocast: one-key psi casting for System Shock 2: 25th Anniversary Remaster

**TLDR:** Press one key and your character draws the psi amp, selects a power and casts it, with no click and no F-key cycling. It can do a normal cast or a timed overload. You choose the powers with the game's own quick slots (Shift+F6 to F12) and bind keys in `user.bnd`.

## Contents
1. [What it does](#what-it-does)
2. [Requirements](#requirements)
3. [Install](#install)
4. [Set up a power](#set-up-a-power)
5. [Key file settings](#key-file-settings)
6. [Overloads](#overloads)
7. [Troubleshooting](#troubleshooting)
8. [Uninstall](#uninstall)
9. [License](#license)

## What it does

- **From any weapon:** the key puts the amp in your hand, waits for it to come up, then casts.
- **With the amp already out:** it casts immediately.
- **Normal or overload:** each key holds fire for a set time. A short hold is a normal cast. A tuned hold lands in the yellow overload zone, with no mouse timing needed.
- **Configured in plain text:** each key is a small `.cmd` file. Edit it while the game runs and the next keypress uses the new values.

## Requirements

- **System Shock 2: 25th Anniversary Remaster** on PC. Tested on the Epic Games version, game version 1.3.4984. It should work on Steam and GOG, but that hasn't been tested.
- **It won't work on the classic 1999 version.** It relies on the remaster's script engine.
- **Tested alongside** the remaster's bundled mods (SCP beta 6, SHTUP, Four Hundred, patch_ext).
- **Multiplayer:** untested.

## Install

1. **Extract the zip into the game's install folder,** the one containing `SystemShock2Remastered.exe`. That creates:
   - `mods\psi_autocast.kpf`, the script mod
   - `psi\psi_slot6_quick.cmd` and the other example key files, plus this readme
2. **Enable the mod.** Choose **New Game → Mods**, add **psi_autocast**, then **Apply** and start the game. Once the first level loads, **load your own save**. Then make a regular save, so the mod stays enabled for that save.
   - The game stores a mod list in each save. Loading an older save directly won't enable the mod.
   - **Don't use the `mod_apply` console command mid-game.** It can unload the level and crash the game.
   - To check: in the console (Ctrl+;), type `mod_list`. psi_autocast should be listed under "Mods to load."
3. **Set up a power and bind a key,** as in the next section.

## Set up a power

1. **Put the power in a quick slot.** Open the psi power list, hover over the **power itself** (not its tier's entry, which is first in the list), and press **Shift+F6**. Slots F6 to F12 work. Quick slots are saved with your game.
2. **Close the game.** It rewrites the bindings file when it exits, so edits made while it's running are lost.
3. **Open `user.bnd`** in Notepad. It's in:
   `%USERPROFILE%\Saved Games\Nightdive Studios\System Shock 2 Remastered\`
   Back it up first.
4. **Add one line per key.** Pick a key that isn't already bound (search the file for `bind <key> `):
   ```
   bind g "run psi\psi_slot6_quick.cmd"
   ```
   The example files:

   | File | Quick slot | Does |
   |---|---|---|
   | `psi_slot6_quick.cmd` … `psi_slot12_quick.cmd` | 6 … 12 | Normal cast |
   | `psi_slot6_overload.cmd` | 6 | Overload, tuned for a tier 1 power. See [Overloads](#overloads) |

5. **Start the game and press the key.**

One command per binding. `user.bnd` doesn't chain commands with semicolons, and a second `bind` on the same key replaces the first.

## Key file settings

Each `.cmd` file in the `psi` folder looks like this:

```
set psi_slot 6
set psi_draw_ms 800
set psi_release_ms 100
summon_obj PsiCast
equip_weapon psi amp
```

| Setting | Meaning |
|---|---|
| `psi_slot` | The quick slot (6 to 12) holding the power |
| `psi_draw_ms` | How long to wait for the amp to come up when it isn't already in hand. 800 ms is reliable from the pistol; heavier weapons may need more |
| `psi_release_ms` | How long fire is held. 100 is a normal cast. Longer values charge toward an overload |

- Keep `summon_obj PsiCast` **before** `equip_weapon psi amp`. The helper checks what's in your hand when it appears.
- To add more keys, copy a file, give it a new name, change the numbers, and bind it.

## Overloads

Holding a cast fills a bar. Releasing in the **yellow** box at its right end overloads the power: it casts with +2 effective PSI, up to a maximum of 10. Releasing too late causes **burnout**: the power fails and you take damage.

- **Only some powers benefit** (see the [wiki's list](https://shodan.fandom.com/wiki/Psionic_Disciplines)). Any power can burn out, so use quick-cast files for the rest.
- **Higher-tier powers fill the bar faster**, so each overloaded power needs its own hold time.
- **More PSI widens the yellow box**, so a value that works now keeps working as PSI rises.

**To tune a power:**
1. Copy `psi_slot6_overload.cmd` and set your slot.
2. Make two more copies with longer and shorter `psi_release_ms` values, and bind all three to spare keys.
3. Press each one and watch the console (Ctrl+;). An overload prints `OnOverloadSuccess`.
4. Pick a value a little past the first one that overloads, then edit the files during play to adjust.

Reference point: Projected Cryokinesis (tier 1) gave a normal cast at 1450 ms and overloaded from 1500 ms to 1650 ms with no burnout. The example uses 1550 ms.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| Key does nothing at all | The binding is missing, or `user.bnd` was edited while the game was running. Close the game and check the line |
| Amp comes out, nothing casts | Either the quick slot is empty in this save (set it again with Shift+F-key), or the mod isn't enabled for this save (`summon_obj` fails silently). Check `mod_list`, and see step 2 of [Install](#install) |
| Weapon switching is stuck after a cast | The trigger is still held. Click once. Then raise `psi_draw_ms`; the cast started before the amp was ready |
| Overload burns out | Lower `psi_release_ms` |
| Overload gives a normal cast | Raise `psi_release_ms` |

Each cast also prints `[psi_autocast]` lines to the game's log, showing the slot, whether the amp was in hand, and the timings.

## Uninstall

1. Remove the `bind` lines you added to `user.bnd`, with the game closed.
2. Delete `mods\psi_autocast.kpf` and the `psi` folder.
3. Remove psi_autocast from the mod list on your next New Game → Mods.

## License

MIT. See `LICENSE`. Source and developer notes: https://github.com/feygon/SS2PsiAutocast

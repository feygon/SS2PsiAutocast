# psi_autocast: one-key psi casting for System Shock 2: 25th Anniversary Remaster

**TLDR:** Bind a key to one of the included scripts. Pressing it draws the psi amp if needed, selects the discipline, and casts it. Quickfire scripts cast immediately. The other scripts overload automatically when the discipline benefits, timing the release from the game's own overload table for the discipline's tier and your current PSI. There's one pair of scripts per discipline, all 35.

**Step-by-step setup for psi_autocast and psi_autocast_mfd, and a troubleshooting table:** [SETUP_GUIDE.md](https://github.com/feygon/SS2PsiAutocast/blob/main/SETUP_GUIDE.md).

## Contents
1. [What it does](#what-it-does)
2. [Requirements](#requirements)
3. [Install](#install)
4. [Bind a key](#bind-a-key)
5. [How overload timing is calculated](#how-overload-timing-is-calculated)
6. [Build your own key script](#build-your-own-key-script)
7. [Chain several casts on one key](#chain-several-casts-on-one-key)
8. [Action scripts](#action-scripts)
9. [Troubleshooting](#troubleshooting)
10. [Uninstall](#uninstall)
11. [Discipline scripts](#discipline-scripts)
12. [License](#license)

## What it does

- **From any weapon:** the script puts the amp in your hand, waits for it to come up, then casts.
- **With the amp already out:** it casts immediately.
- **Quickfire** (`…_Quickfire.txt`): casts immediately, whether or not the discipline could be overloaded.
- **Conditional overload** (no suffix):
  - **If overloading helps the discipline,** it holds fire just long enough to land in the yellow overload zone.
  - **If it doesn't,** it casts immediately and says so in the console.
- **Console feedback:** every cast reports its tier, your base PSI, the overload zone in milliseconds, and the decision. Open the console with Ctrl+;.
  ```
  [psi_autocast] T1_Projected_Cryokinesis: overloading, holding 1564ms (tier 1, base PSI 5, overload zone 1460-2000ms)
  [psi_autocast] T1_Psychogenic_Agility doesn't benefit from an overload, so it's casting immediately (tier 1, base PSI 5, overload zone 1460-2000ms)
  ```

## Requirements

- **System Shock 2: 25th Anniversary Remaster** on PC. Tested on the Epic Games version, game version 1.3.4984. It should work on Steam and GOG, but that hasn't been tested.
- **It won't work on the classic 1999 version.** It relies on the remaster's script engine.
- **Tested alongside** the remaster's bundled mods (SCP beta 6, SHTUP, Four Hundred, patch_ext).
- **Multiplayer:** untested.

## Install

1. **Extract the zip into the game's install folder,** the one containing `SystemShock2Remastered.exe`. That creates:
   - `mods\psi_autocast.kpf`, the script mod
   - `psi\`, with a script for every discipline, the shared parts in `psi\lib\`, and this readme
2. **Enable the mod.** Choose **New Game → Mods**, add **psi_autocast**, then **Apply** and start the game. Once the first level loads, **load your own save**. Then make a regular save, so the mod stays enabled for that save.
   - The game stores a mod list in each save. Loading an older save directly won't enable the mod.
   - **Don't use the `mod_apply` console command mid-game.** It can unload the level and crash the game.
   - To check: in the console, type `mod_list`. psi_autocast should be listed under "Mods to load."
3. **Upgrading from 1.3 or earlier:** extract over the old version. The key files are now `.txt` instead of `.cmd`. On the first load, psi_autocast moves your key bindings to the new files (backing up `user.bnd` as `user.bnd.psi_backup`); your keys keep working on the old files until you next start the game, then use the new ones. No restart needed. Only psi_autocast's own files are renamed: chains you saved yourself keep their names. After that next start, the old `.cmd` files in the `psi` folder are no longer used, and you can delete them.

## Bind a key

1. **Close the game.** It rewrites the bindings file when it exits, so edits made while it's running are lost.
2. **Open `user.bnd`** in Notepad. It's in:
   `%USERPROFILE%\Saved Games\Nightdive Studios\System Shock 2 Remastered\`
   Back it up first.
3. **Add one line per key,** using a script name from the [table below](#discipline-scripts). Pick a key that isn't already bound (search the file for `bind <key> `):
   ```
   bind g "run psi\T1_Projected_Cryokinesis_Quickfire.txt"
   bind j "run psi\T1_Projected_Cryokinesis.txt"
   ```
4. **Start the game and press the key.**

One command per binding. `user.bnd` doesn't chain commands with semicolons, and a second `bind` on the same key replaces the first.

**Starter keys, set up for you:** [`extras/starterPsiPowers.bat`](https://github.com/feygon/SS2PsiAutocast/blob/main/extras/starterPsiPowers.bat), from the GitHub repo, binds two keys with the game closed, each through a one-line file in the save folder (`psi_macros\Macro_g.cmd`, `Macro_j.cmd`) that psi_autocast_mfd can later replace with a macro. If G or J already has a binding, it leaves that key alone, shows the existing binding, and prints the line to add on another key. It backs up `user.bnd` before changing it. If you use psi_autocast_mfd, run its `setupPsiMfd.bat` instead (or afterwards, if you add the MFD later): it sets up the same two keys, as macros you can edit in the MFD.
- **G** draws the amp and casts Projected Cryokinesis, overloading it automatically.
- **J** draws the amp, quickfires Localized Pyrokinesis, then switches back to your previous weapon (`psi\chains\Starter_Localized_Pyrokinesis.txt`).

## How overload timing is calculated

The numbers come from the game's own **Overload Params** table (`OLPARAM` in `shock2.gam`; SCP doesn't change it).

**Bar fill time by tier.** Releasing after the bar is full is burnout: the cast fails and you take damage.

| Tier | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| Bar fills in | 2.0 s | 1.5 s | 1.0 s | 0.75 s | 0.4 s |

**Where the yellow zone starts, as a fraction of the bar, by base PSI** (your PSI without implants). Higher PSI widens the zone to the left. The game reads `OLPARAM`'s values one step lower than their PSI 1–8 order suggests, which is how the table below lines up.

| Base PSI | 1–2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|
| Zone starts at | 1.00 | 0.94 | 0.85 | 0.73 | 0.58 | 0.40 | 0.19 |

**How the script uses them:**
- **Overload zone** = from (zone start × bar time) to (bar time).
- **Hold time** = zone start plus 10% of the zone's width (at least 50 ms), plus a flat 50 ms so the bar is visibly in the yellow before release.
- **If that hold would come within 50 ms of the end of the bar** (low PSI on a high tier), the script aims for the middle of the zone instead, 30 ms early to allow for the delay between its timer and the release. A zone under 50 ms wide (or none, at base PSI 1–2) casts immediately, and the console says so.
- **PSI is your base PSI.** Implants don't change the overload window. The +2 from an overload applies to that cast only.
- **Example:** at base PSI 5, a tier 1 discipline's zone runs from 1460 to 2000 ms, and the script holds 1564 ms (1460 + 54 + 50). A tier 5 discipline's zone runs from 292 to 400 ms, and the script holds 316 ms (the middle, 346, minus 30).

Within a tier, every discipline shares the same timing. Whether a discipline gains anything from an overload is per discipline. The scripts follow the wiki's list of disciplines that benefit, shown in the [table below](#discipline-scripts).

## Build your own key script

Every script is a few `set` lines plus calls to shared parts in `psi\lib\`. Combine them to make your own:

| Part | Sets |
|---|---|
| `psi\lib\T1.txt` … `T5.txt` | The discipline's tier |
| `psi\lib\quickfire.txt` | Quickfire: cast immediately |
| `psi\lib\overload.txt` | Conditional overload |
| `psi\lib\draw_cast.txt` | Draws the amp if needed (waits 800 ms), then casts. Must be last |

Example, `T1_Projected_Cryokinesis.txt`:
```
set psi_name T1_Projected_Cryokinesis
set psi_power 6
set psi_slot 0
set psi_benefits 1
run psi\lib\T1.txt
run psi\lib\overload.txt
run psi\lib\draw_cast.txt
```

| Setting | Meaning |
|---|---|
| `psi_name` | Label shown in the console |
| `psi_power` | Discipline number, from the [table below](#discipline-scripts). 0 means use a quick slot instead |
| `psi_slot` | Quick slot (6–12) to use when `psi_power` is 0. Fill it in game with Shift+F6 to F12 while hovering over the power |
| `psi_benefits` | 1 if overloading improves the discipline, otherwise 0 |
| `psi_mode` | Set by the parts: 0 quickfire, 1 conditional overload. 2 holds for exactly `psi_release_ms` (manual) |
| `psi_draw_ms` | How long to wait for the amp to come up. 800 ms works when switching from the pistol |

- **Set every value in every script.** Values carry over from the last script that ran.
- **`run psi\…` needs a backslash.** Forward slashes don't work.
- **Scripts are read on each keypress,** so edits take effect at once, even mid-game.
- **To have Claude write macros for you,** give it `psi\psi_autocast_MACROS_FOR_CLAUDE.md`, which documents the inner workings for Claude, and describe the macro you want.

## Chain several casts on one key

**The easiest way: open `psi\Macro_Builder.html` in your browser.** Pick disciplines, choose quickfire or conditional overload, and it builds the chain macro and the key binding line for you. It works offline.

By hand, a chain script casts several disciplines in a row. Put chains in `psi\chains\`:

```
set psi_chain T2_Localized_Pyrokinesis,T1_Projected_Cryokinesis
set psi_chain_gap_ms 500
summon_obj PsiChain
```

Bind it like any other script: `bind v "run psi\chains\Chain_Example.txt"`.

- **`psi_chain`** lists discipline script names from the [table below](#discipline-scripts), without `.txt`, separated by commas, with no spaces.
- **Chain steps can also be written directly,** as the builder does:
  - `arm` draws the amp if it isn't in hand, then waits `psi_draw_ms`.
  - `6o` casts discipline 6 with conditional overload; `6q` quickfires it.
  - `w500` waits 500 ms.
  - Direct casts never draw the amp themselves. Without an `arm` step, the chain stops if the amp isn't in hand.
  - `hypo` uses a psi hypo. It can go anywhere.
  - `last` switches back to the previous weapon, and `weapon:<Name>` switches to a weapon by running `psi\actions\Switch_To_<Name>.txt` (`weapon:Assault_Rifle`). Put these last.
  - Example: `set psi_chain arm,6o,w500,hypo,w500,15q,w500,last`.
- **Two casts must be at least 500 ms apart in total,** counting any hypo between them.
- **Auto psi hypo:** with `set psi_auto_hypo 1` in a chain, each cast first checks your psi points. If they're at or below your maximum minus what a hypo restores, it uses a psi hypo, waits `psi_auto_hypo_wait_ms` (500), then casts, so none is wasted. A hypo restores 30 on Easy and 20 on Normal, Hard and Impossible, plus 20% with the Pharmo-Friendly O/S upgrade (36 or 24). The mod reads your difficulty and upgrades itself.

## Action scripts

`psi\actions\` holds one-line scripts you can bind to a key on their own:

| Script | Does |
|---|---|
| `Use_Psi_Hypo.txt` | Uses a psi hypo (`use_obj psi booster`) |
| `Cancel_Macro.txt` | Stops any running macro (`summon_obj PsiCancel`). A cast that is mid-charge is released, so it casts at normal strength, or fizzles if the charge has only just started; the rest of the macro is skipped |
| `Switch_To_Previous_Weapon.txt` | Switches back to the weapon you held when your last macro drew the psi amp |
| `Switch_To_<Weapon>.txt` | Switches to that weapon: Wrench, Pistol, Shotgun, Assault_Rifle, Laser_Pistol, EMP_Rifle, Laser_Rapier, Grenade_Launcher, Stasis_Field_Generator, Fusion_Cannon, Crystal_Shard, Viral_Proliferator, Annelid_Launcher |

Example: `bind y "run psi\actions\Use_Psi_Hypo.txt"`.
- **Each step follows its own script:** the plain name overloads when the discipline benefits, and the `_Quickfire` name casts immediately.
- **The first step draws the amp if needed.** Later steps find it already in hand.
- **`psi_chain_gap_ms`** is the pause after each cast releases, before the next one starts. 500 ms matches the psi amp's refire limit (its `Shot Interval` in the game data). Lower values can swallow the next cast.
- **The console reports** each step (`chain: step 2/3: …`) and then `chain: done`. A step that never releases within 5 seconds stops the chain.
- **Don't fire or switch weapons while a chain runs.** Your input would mix with the chain's own.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| Key does nothing at all | The binding is missing, or `user.bnd` was edited while the game was running. Close the game and check the line |
| Amp comes out, nothing casts | The mod isn't enabled for this save (see [Install](#install)), or the discipline isn't learned. The console warns when a discipline seems to be unlearned |
| Weapon switching is stuck after a cast | The trigger is still held. Click once. Then raise `psi_draw_ms`; the cast started before the amp was ready |
| Overload burns out or misses | Report it with the console line. It shows the tier, PSI and timing used |

## Uninstall

1. Remove the `bind` lines you added to `user.bnd`, with the game closed.
2. Delete `mods\psi_autocast.kpf` and the `psi` folder.
3. Remove psi_autocast from the mod list on your next New Game → Mods.

## Discipline scripts

Discipline numbers and names come from the game's `psihelp.str`. "Benefits from overload" follows the [System Shock wiki](https://shodan.fandom.com/wiki/Psionic_Disciplines). This table is generated by `make_keys.py`.

<!-- disciplines:start -->
| Tier | Discipline | Benefits from overload | Conditional overload script | Quickfire script |
|---|---|---|---|---|
| 1 | Psycho-Reflective Screen | No | `T1_Psycho_Reflective_Screen.txt` | `T1_Psycho_Reflective_Screen_Quickfire.txt` |
| 1 | Neuro-Reflex Dampening | No | `T1_Neuro_Reflex_Dampening.txt` | `T1_Neuro_Reflex_Dampening_Quickfire.txt` |
| 1 | Kinetic Redirection | Yes | `T1_Kinetic_Redirection.txt` | `T1_Kinetic_Redirection_Quickfire.txt` |
| 1 | Psychogenic Agility | No | `T1_Psychogenic_Agility.txt` | `T1_Psychogenic_Agility_Quickfire.txt` |
| 1 | Psychogenic Cyber-Affinity | No | `T1_Psychogenic_Cyber_Affinity.txt` | `T1_Psychogenic_Cyber_Affinity_Quickfire.txt` |
| 1 | Projected Cryokinesis | Yes | `T1_Projected_Cryokinesis.txt` | `T1_Projected_Cryokinesis_Quickfire.txt` |
| 1 | Remote Electron Tampering | Yes | `T1_Remote_Electron_Tampering.txt` | `T1_Remote_Electron_Tampering_Quickfire.txt` |
| 2 | Anti-Entropic Field | No | `T2_Anti_Entropic_Field.txt` | `T2_Anti_Entropic_Field_Quickfire.txt` |
| 2 | Adrenaline Overproduction | No | `T2_Adrenaline_Overproduction.txt` | `T2_Adrenaline_Overproduction_Quickfire.txt` |
| 2 | Neural Decontamination | No | `T2_Neural_Decontamination.txt` | `T2_Neural_Decontamination_Quickfire.txt` |
| 2 | Cerebro-Stimulated Regeneration | Yes | `T2_Cerebro_Stimulated_Regeneration.txt` | `T2_Cerebro_Stimulated_Regeneration_Quickfire.txt` |
| 2 | Psychogenic Strength | No | `T2_Psychogenic_Strength.txt` | `T2_Psychogenic_Strength_Quickfire.txt` |
| 2 | Recursive Psionic Amplification | No | `T2_Recursive_Psionic_Amplification.txt` | `T2_Recursive_Psionic_Amplification_Quickfire.txt` |
| 2 | Localized Pyrokinesis | No | `T2_Localized_Pyrokinesis.txt` | `T2_Localized_Pyrokinesis_Quickfire.txt` |
| 3 | Molecular Duplication | Yes | `T3_Molecular_Duplication.txt` | `T3_Molecular_Duplication_Quickfire.txt` |
| 3 | Electron Cascade | Yes | `T3_Electron_Cascade.txt` | `T3_Electron_Cascade_Quickfire.txt` |
| 3 | Energy Reflection | No | `T3_Energy_Reflection.txt` | `T3_Energy_Reflection_Quickfire.txt` |
| 3 | Neural Toxin-Blocker | No | `T3_Neural_Toxin_Blocker.txt` | `T3_Neural_Toxin_Blocker_Quickfire.txt` |
| 3 | Enhanced Motion Sensitivity | No | `T3_Enhanced_Motion_Sensitivity.txt` | `T3_Enhanced_Motion_Sensitivity_Quickfire.txt` |
| 3 | Projected Pyrokinesis | Yes | `T3_Projected_Pyrokinesis.txt` | `T3_Projected_Pyrokinesis_Quickfire.txt` |
| 3 | Psionic Hypnogenesis | Yes | `T3_Psionic_Hypnogenesis.txt` | `T3_Psionic_Hypnogenesis_Quickfire.txt` |
| 4 | Photonic Redirection | No | `T4_Photonic_Redirection.txt` | `T4_Photonic_Redirection_Quickfire.txt` |
| 4 | Remote Pattern Detection | No | `T4_Remote_Pattern_Detection.txt` | `T4_Remote_Pattern_Detection_Quickfire.txt` |
| 4 | Electron Suppression | Yes | `T4_Electron_Suppression.txt` | `T4_Electron_Suppression_Quickfire.txt` |
| 4 | Psychogenic Endurance | No | `T4_Psychogenic_Endurance.txt` | `T4_Psychogenic_Endurance_Quickfire.txt` |
| 4 | Molecular Transmutation | Yes | `T4_Molecular_Transmutation.txt` | `T4_Molecular_Transmutation_Quickfire.txt` |
| 4 | Remote Circuitry Manipulation | Yes | `T4_Remote_Circuitry_Manipulation.txt` | `T4_Remote_Circuitry_Manipulation_Quickfire.txt` |
| 4 | Cerebro-Energetic Extension | No | `T4_Cerebro_Energetic_Extension.txt` | `T4_Cerebro_Energetic_Extension_Quickfire.txt` |
| 5 | Advanced Cerebro-Stimulated Regeneration | Yes | `T5_Advanced_Cerebro_Stimulated_Regeneration.txt` | `T5_Advanced_Cerebro_Stimulated_Regeneration_Quickfire.txt` |
| 5 | Soma Transference | Yes | `T5_Soma_Transference.txt` | `T5_Soma_Transference_Quickfire.txt` |
| 5 | Instantaneous Quantum Relocation | No | `T5_Instantaneous_Quantum_Relocation.txt` | `T5_Instantaneous_Quantum_Relocation_Quickfire.txt` |
| 5 | Imposed Neural Restructuring | Yes | `T5_Imposed_Neural_Restructuring.txt` | `T5_Imposed_Neural_Restructuring_Quickfire.txt` |
| 5 | Metacreative Barrier | Yes | `T5_Metacreative_Barrier.txt` | `T5_Metacreative_Barrier_Quickfire.txt` |
| 5 | External Psionic Detonation | No | `T5_External_Psionic_Detonation.txt` | `T5_External_Psionic_Detonation_Quickfire.txt` |
| 5 | Psycho-Reflective Aura | No | `T5_Psycho_Reflective_Aura.txt` | `T5_Psycho_Reflective_Aura_Quickfire.txt` |
<!-- disciplines:end -->

## License

MIT. See `LICENSE`. Source and developer notes: https://github.com/feygon/SS2PsiAutocast

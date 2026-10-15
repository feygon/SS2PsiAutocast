# psi_autocast: one-key psi casting for System Shock 2: 25th Anniversary Remaster

**TLDR:** Bind a key to one of the included scripts. Pressing it draws the psi amp if needed, selects the discipline, and casts it. Quickfire scripts cast immediately. The other scripts overload automatically when the discipline benefits, timing the release from the game's own overload table for the discipline's tier and your current PSI. There's one pair of scripts per discipline, all 35.

## Contents
1. [What it does](#what-it-does)
2. [Requirements](#requirements)
3. [Install](#install)
4. [Bind a key](#bind-a-key)
5. [How overload timing is calculated](#how-overload-timing-is-calculated)
6. [Build your own key script](#build-your-own-key-script)
7. [Chain several casts on one key](#chain-several-casts-on-one-key)
8. [Troubleshooting](#troubleshooting)
9. [Uninstall](#uninstall)
10. [Discipline scripts](#discipline-scripts)
11. [License](#license)

## What it does

- **From any weapon:** the script puts the amp in your hand, waits for it to come up, then casts.
- **With the amp already out:** it casts immediately.
- **Quickfire** (`…_Quickfire.cmd`): casts immediately, whether or not the discipline could be overloaded.
- **Conditional overload** (no suffix):
  - **If overloading helps the discipline,** it holds fire just long enough to land in the yellow overload zone.
  - **If it doesn't,** it casts immediately and says so in the console.
- **Console feedback:** every cast reports its tier, your pre-overload PSI, the overload zone in milliseconds, and the decision. Open the console with Ctrl+;.
  ```
  [psi_autocast] T1_Projected_Cryokinesis: overloading, holding 1564ms (tier 1, pre-overload PSI 4, overload zone 1460-2000ms)
  [psi_autocast] T1_Psychogenic_Agility doesn't benefit from an overload, so it's casting immediately (tier 1, pre-overload PSI 4, overload zone 1460-2000ms)
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

## Bind a key

1. **Close the game.** It rewrites the bindings file when it exits, so edits made while it's running are lost.
2. **Open `user.bnd`** in Notepad. It's in:
   `%USERPROFILE%\Saved Games\Nightdive Studios\System Shock 2 Remastered\`
   Back it up first.
3. **Add one line per key,** using a script name from the [table below](#discipline-scripts). Pick a key that isn't already bound (search the file for `bind <key> `):
   ```
   bind g "run psi\T1_Projected_Cryokinesis_Quickfire.cmd"
   bind j "run psi\T1_Projected_Cryokinesis.cmd"
   ```
4. **Start the game and press the key.**

One command per binding. `user.bnd` doesn't chain commands with semicolons, and a second `bind` on the same key replaces the first.

## How overload timing is calculated

The numbers come from the game's own **Overload Params** table (`OLPARAM` in `shock2.gam`; SCP doesn't change it).

**Bar fill time by tier.** Releasing after the bar is full is burnout: the cast fails and you take damage.

| Tier | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| Bar fills in | 2.0 s | 1.5 s | 1.0 s | 0.75 s | 0.4 s |

**Where the yellow zone starts, as a fraction of the bar, by PSI before casting.** Higher PSI widens the zone to the left.

| PSI | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|
| Zone starts at | 1.00 | 0.94 | 0.85 | 0.73 | 0.58 | 0.40 | 0.19 | 0.01 |

**How the script uses them:**
- **Overload zone** = from (zone start × bar time) to (bar time).
- **Hold time** = zone start plus 10% of the zone's width (at least 50 ms), plus a flat 50 ms so the bar is visibly in the yellow before release.
- **If that hold would come within 50 ms of the end of the bar** (low PSI on a high tier, or PSI 1, where there's no zone), the script casts immediately and says so.
- **PSI is the effective value** shown on your stats screen, including implants and boosters, capped to 1–8. The +2 from an overload applies to that cast only.
- **Example:** at PSI 4, a tier 1 discipline's zone runs from 1460 to 2000 ms, and the script holds 1564 ms (1460 + 54 + 50).

Within a tier, every discipline shares the same timing. Whether a discipline gains anything from an overload is per discipline. The scripts follow the wiki's list of disciplines that benefit, shown in the [table below](#discipline-scripts).

## Build your own key script

Every script is a few `set` lines plus calls to shared parts in `psi\lib\`. Combine them to make your own:

| Part | Sets |
|---|---|
| `psi\lib\T1.cmd` … `T5.cmd` | The discipline's tier |
| `psi\lib\quickfire.cmd` | Quickfire: cast immediately |
| `psi\lib\overload.cmd` | Conditional overload |
| `psi\lib\draw_cast.cmd` | Draws the amp if needed (waits 800 ms), then casts. Must be last |

Example, `T1_Projected_Cryokinesis.cmd`:
```
set psi_name T1_Projected_Cryokinesis
set psi_power 6
set psi_slot 0
set psi_benefits 1
run psi\lib\T1.cmd
run psi\lib\overload.cmd
run psi\lib\draw_cast.cmd
```

| Setting | Meaning |
|---|---|
| `psi_name` | Label shown in the console |
| `psi_power` | Discipline number, from the [table below](#discipline-scripts). 0 means use a quick slot instead |
| `psi_slot` | Quick slot (6–12) to use when `psi_power` is 0. Fill it in game with Shift+F6 to F12 while hovering over the power |
| `psi_benefits` | 1 if overloading improves the discipline, otherwise 0 |
| `psi_mode` | Set by the parts: 0 quickfire, 1 conditional overload. 2 holds for exactly `psi_release_ms` (manual) |
| `psi_draw_ms` | How long to wait for the amp to come up. Heavier weapons may need more than 800 ms |

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

Bind it like any other script: `bind v "run psi\chains\Chain_Example.cmd"`.

- **`psi_chain`** lists discipline script names from the [table below](#discipline-scripts), without `.cmd`, separated by commas, with no spaces.
- **Chain steps can also be written directly,** as the builder does:
  - `arm` draws the amp if it isn't in hand, then waits `psi_draw_ms`.
  - `6o` casts discipline 6 with conditional overload; `6q` quickfires it.
  - `w500` waits 500 ms.
  - Direct casts never draw the amp themselves. Without an `arm` step, the chain stops if the amp isn't in hand.
  - Example: `set psi_chain arm,6o,w500,15q`.
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
| 1 | Psycho-Reflective Screen | No | `T1_Psycho_Reflective_Screen.cmd` | `T1_Psycho_Reflective_Screen_Quickfire.cmd` |
| 1 | Neuro-Reflex Dampening | No | `T1_Neuro_Reflex_Dampening.cmd` | `T1_Neuro_Reflex_Dampening_Quickfire.cmd` |
| 1 | Kinetic Redirection | Yes | `T1_Kinetic_Redirection.cmd` | `T1_Kinetic_Redirection_Quickfire.cmd` |
| 1 | Psychogenic Agility | No | `T1_Psychogenic_Agility.cmd` | `T1_Psychogenic_Agility_Quickfire.cmd` |
| 1 | Psychogenic Cyber-Affinity | No | `T1_Psychogenic_Cyber_Affinity.cmd` | `T1_Psychogenic_Cyber_Affinity_Quickfire.cmd` |
| 1 | Projected Cryokinesis | Yes | `T1_Projected_Cryokinesis.cmd` | `T1_Projected_Cryokinesis_Quickfire.cmd` |
| 1 | Remote Electron Tampering | Yes | `T1_Remote_Electron_Tampering.cmd` | `T1_Remote_Electron_Tampering_Quickfire.cmd` |
| 2 | Anti-Entropic Field | No | `T2_Anti_Entropic_Field.cmd` | `T2_Anti_Entropic_Field_Quickfire.cmd` |
| 2 | Adrenaline Overproduction | No | `T2_Adrenaline_Overproduction.cmd` | `T2_Adrenaline_Overproduction_Quickfire.cmd` |
| 2 | Neural Decontamination | No | `T2_Neural_Decontamination.cmd` | `T2_Neural_Decontamination_Quickfire.cmd` |
| 2 | Cerebro-Stimulated Regeneration | Yes | `T2_Cerebro_Stimulated_Regeneration.cmd` | `T2_Cerebro_Stimulated_Regeneration_Quickfire.cmd` |
| 2 | Psychogenic Strength | No | `T2_Psychogenic_Strength.cmd` | `T2_Psychogenic_Strength_Quickfire.cmd` |
| 2 | Recursive Psionic Amplification | No | `T2_Recursive_Psionic_Amplification.cmd` | `T2_Recursive_Psionic_Amplification_Quickfire.cmd` |
| 2 | Localized Pyrokinesis | No | `T2_Localized_Pyrokinesis.cmd` | `T2_Localized_Pyrokinesis_Quickfire.cmd` |
| 3 | Molecular Duplication | Yes | `T3_Molecular_Duplication.cmd` | `T3_Molecular_Duplication_Quickfire.cmd` |
| 3 | Electron Cascade | Yes | `T3_Electron_Cascade.cmd` | `T3_Electron_Cascade_Quickfire.cmd` |
| 3 | Energy Reflection | No | `T3_Energy_Reflection.cmd` | `T3_Energy_Reflection_Quickfire.cmd` |
| 3 | Neural Toxin-Blocker | No | `T3_Neural_Toxin_Blocker.cmd` | `T3_Neural_Toxin_Blocker_Quickfire.cmd` |
| 3 | Enhanced Motion Sensitivity | No | `T3_Enhanced_Motion_Sensitivity.cmd` | `T3_Enhanced_Motion_Sensitivity_Quickfire.cmd` |
| 3 | Projected Pyrokinesis | Yes | `T3_Projected_Pyrokinesis.cmd` | `T3_Projected_Pyrokinesis_Quickfire.cmd` |
| 3 | Psionic Hypnogenesis | Yes | `T3_Psionic_Hypnogenesis.cmd` | `T3_Psionic_Hypnogenesis_Quickfire.cmd` |
| 4 | Photonic Redirection | No | `T4_Photonic_Redirection.cmd` | `T4_Photonic_Redirection_Quickfire.cmd` |
| 4 | Remote Pattern Detection | No | `T4_Remote_Pattern_Detection.cmd` | `T4_Remote_Pattern_Detection_Quickfire.cmd` |
| 4 | Electron Suppression | Yes | `T4_Electron_Suppression.cmd` | `T4_Electron_Suppression_Quickfire.cmd` |
| 4 | Psychogenic Endurance | No | `T4_Psychogenic_Endurance.cmd` | `T4_Psychogenic_Endurance_Quickfire.cmd` |
| 4 | Molecular Transmutation | Yes | `T4_Molecular_Transmutation.cmd` | `T4_Molecular_Transmutation_Quickfire.cmd` |
| 4 | Remote Circuitry Manipulation | Yes | `T4_Remote_Circuitry_Manipulation.cmd` | `T4_Remote_Circuitry_Manipulation_Quickfire.cmd` |
| 4 | Cerebro-Energetic Extension | No | `T4_Cerebro_Energetic_Extension.cmd` | `T4_Cerebro_Energetic_Extension_Quickfire.cmd` |
| 5 | Advanced Cerebro-Stimulated Regeneration | Yes | `T5_Advanced_Cerebro_Stimulated_Regeneration.cmd` | `T5_Advanced_Cerebro_Stimulated_Regeneration_Quickfire.cmd` |
| 5 | Soma Transference | Yes | `T5_Soma_Transference.cmd` | `T5_Soma_Transference_Quickfire.cmd` |
| 5 | Instantaneous Quantum Relocation | No | `T5_Instantaneous_Quantum_Relocation.cmd` | `T5_Instantaneous_Quantum_Relocation_Quickfire.cmd` |
| 5 | Imposed Neural Restructuring | Yes | `T5_Imposed_Neural_Restructuring.cmd` | `T5_Imposed_Neural_Restructuring_Quickfire.cmd` |
| 5 | Metacreative Barrier | Yes | `T5_Metacreative_Barrier.cmd` | `T5_Metacreative_Barrier_Quickfire.cmd` |
| 5 | External Psionic Detonation | No | `T5_External_Psionic_Detonation.cmd` | `T5_External_Psionic_Detonation_Quickfire.cmd` |
| 5 | Psycho-Reflective Aura | No | `T5_Psycho_Reflective_Aura.cmd` | `T5_Psycho_Reflective_Aura_Quickfire.cmd` |
<!-- disciplines:end -->

## License

MIT. See `LICENSE`. Source and developer notes: https://github.com/feygon/SS2PsiAutocast

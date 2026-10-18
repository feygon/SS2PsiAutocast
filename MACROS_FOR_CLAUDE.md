# psi_autocast macro guide for Claude

**TLDR:** This file is for an AI assistant helping a player write psi_autocast macros for System Shock 2: 25th Anniversary Remaster. A macro is a plain-text `.txt` file in the game's `psi\` folder. It sets config values and then summons a helper object (`PsiCast` or `PsiChain`) from the psi_autocast mod; the helper does the timed work. The rules below are the hard constraints, all found by testing. Breaking them fails silently.

## Contents
1. [How a cast works](#how-a-cast-works)
2. [File locations](#file-locations)
3. [Single-cast macro](#single-cast-macro)
4. [Chain macro](#chain-macro)
5. [Settings](#settings)
6. [Overload timing](#overload-timing)
7. [Hard rules](#hard-rules)
8. [Binding a macro to a key](#binding-a-macro-to-a-key)
9. [Checking a macro works](#checking-a-macro-works)
10. [Discipline numbers](#discipline-numbers)

## How a cast works

1. A key binding in `user.bnd` runs a macro: `bind g "run psi\T1_Projected_Cryokinesis.txt"`.
2. The macro `set`s config values, runs shared parts from `psi\lib\`, and ends with `summon_obj PsiCast` followed by `equip_weapon psi amp`.
3. **`PsiCast`, a Squirrel script in `mods\psi_autocast.kpf`:**
   - reads the values;
   - checks whether the amp was already in hand;
   - waits for the amp to come up if not;
   - selects the discipline by number;
   - presses fire;
   - releases after the hold time it chose;
   - prints its reasoning to the console.
4. **`PsiChain`** runs several macros in turn. It waits for each cast to release, then pauses for the gap before the next one.

Macros can't pause: every line runs in the same frame. All timing therefore happens in the helper objects, never in the macro file.

## File locations

| What | Path |
|---|---|
| Game install folder | The folder containing `SystemShock2Remastered.exe` |
| Macros | `<install>\psi\*.txt`; chains in `<install>\psi\chains\` |
| Shared parts | `<install>\psi\lib\` |
| Key bindings | `%USERPROFILE%\Saved Games\Nightdive Studios\System Shock 2 Remastered\user.bnd` |
| Console dump | `<install>\condump.txt`, written by the `condump` console command |

## Single-cast macro

```
set psi_name T1_Projected_Cryokinesis
set psi_power 6
set psi_slot 0
set psi_benefits 1
run psi\lib\T1.txt
run psi\lib\overload.txt
run psi\lib\draw_cast.txt
```

**The parts:**

| Part | Contents |
|---|---|
| `psi\lib\T1.txt` … `T5.txt` | `set psi_tier N` |
| `psi\lib\quickfire.txt` | `set psi_mode 0` |
| `psi\lib\overload.txt` | `set psi_mode 1` |
| `psi\lib\draw_cast.txt` | `set psi_draw_ms 800`, `summon_obj PsiCast`, `equip_weapon psi amp` |

- **The tier part must match the discipline's tier** (number ÷ 8, rounded down, + 1). If it doesn't, the helper corrects it and warns.
- **`draw_cast` must be the last line.**
- **For a custom hold time,** replace the mode part with `set psi_mode 2` and `set psi_release_ms N`.

## Chain macro

```
set psi_chain T2_Localized_Pyrokinesis,T1_Projected_Cryokinesis
set psi_chain_gap_ms 500
summon_obj PsiChain
```

- **Step kinds,** comma-separated, with no spaces:
  - `arm`: draw the amp if it isn't in hand, then wait `psi_draw_ms` (set it in the chain file, normally 800).
  - `<id>o`: cast discipline `<id>` with conditional overload. `<id>q`: quickfire it. The ids are in the [table](#discipline-numbers).
  - `w<ms>`: wait that many milliseconds. Put one between steps.
  - `hypo`: use a psi hypo (`use_obj psi booster`). Allowed anywhere.
  - `last`: switch back to the weapon held when a macro last drew the amp. The mod remembers it and re-equips it with `ShockGame.Equip`. The game's `last_weapon` command goes one weapon too far back, because it doesn't count `equip_weapon` switches. `weapon:<Name>`: switch weapon by running `psi\actions\Switch_To_<Name>.txt`. Valid names: `Wrench`, `Pistol`, `Shotgun`, `Assault_Rifle`, `Laser_Pistol`, `EMP_Rifle`, `Laser_Rapier`, `Grenade_Launcher`, `Stasis_Field_Generator`, `Fusion_Cannon`, `Crystal_Shard`, `Viral_Proliferator`, `Annelid_Launcher` (case matters). **Put a weapon switch only as the last step,** because casts after it would find the amp put away.
  - **Two casts must be at least 500 ms apart in total,** counting the waits around any hypo between them.
  - `<name>`: run `psi\<name>.txt`, a discipline script. These draw the amp themselves.
- **Direct casts (`<id>o` / `<id>q`) never draw the amp.** Without a leading `arm` step, the chain stops with a console message when the amp isn't in hand.
- **Preferred form,** as produced by `psi\Macro_Builder.html`:
  ```
  set psi_chain arm,6o,w500,15q
  set psi_draw_ms 800
  set psi_chain_gap_ms 500
  summon_obj PsiChain
  ```
- **If no `w` step follows a cast,** the chain pauses `psi_chain_gap_ms` instead.
- **Each step follows its own macro's rules.** A conditional-overload step overloads only when the discipline benefits.
- **The gap must be at least 500.** That's the psi amp's Shot Interval, and higher PSI doesn't shorten it. At 400 ms, the next cast's fire press was ignored.
- **A step that hasn't released after 5 seconds stops the chain.** Usually that means the file name was misspelled.

## Settings

| Setting | Values | Meaning |
|---|---|---|
| `psi_name` | text, no spaces | Label in console output |
| `psi_power` | 1–39, see [table](#discipline-numbers) | Discipline to cast; 0 = use `psi_slot` |
| `psi_slot` | 1–12 | Quick slot to use when `psi_power` is 0. The player fills it in game with Shift+F-key while hovering over the power |
| `psi_benefits` | 0 or 1 | Whether overloading improves this discipline |
| `psi_tier` | 1–5 | Set by `psi\lib\T<N>.txt` |
| `psi_mode` | 0, 1, 2 | 0 quickfire, 1 conditional overload, 2 manual hold |
| `psi_release_ms` | ms | Hold time for mode 2 |
| `psi_draw_ms` | ms | Wait for the amp to come up when it isn't already in hand. 800 is reliable from the pistol |
| `psi_chain` | comma-separated names | Chain steps |
| `psi_chain_gap_ms` | ms, at least 500 | Pause after each release in a chain |
| `psi_auto_hypo` | 0 or 1 | Before each cast in a chain, use a psi hypo if psi points are at or below max minus what a hypo restores. The mod works this out from `Quest.Get("Difficulty")` (1 = Easy: 30, otherwise 20) and the Pharmo-Friendly trait (× 1.2), giving 36 or 24. Always set it, to 0 or 1, because it carries over between macros |
| `psi_auto_hypo_wait_ms` | ms | Pause after an auto hypo before the cast (default 500) |

**Cancel:** `psi\actions\Cancel_Macro.txt` (`summon_obj PsiCancel`) stops any running macro at its next timer. It releases fire first, so a cast that is mid-charge casts at normal strength, or fizzles if the charge has only just started. Suggest binding it alongside any chain.

## Overload timing

This comes from the game's Overload Params table (`OLPARAM` in `shock2.gam`; SCP doesn't change it):
- **Bar fill time by tier:** 2.0 / 1.5 / 1.0 / 0.75 / 0.4 s for tiers 1–5.
- **Where the yellow zone starts, as a fraction of the bar,** by base PSI (without implants): 1.00 for base PSI 1–2, then 0.94 / 0.85 / 0.73 / 0.58 / 0.40 / 0.19 for base PSI 3–8 (the game reads `OLPARAM` one step lower than its PSI 1–8 order).
- **The zone** runs from (start fraction × bar time) to (bar time). Releasing after the bar is full is burnout.
- **Conditional mode's hold** = zone start + max(10% of the zone's width, 50 ms) + 50 ms. If that comes within 50 ms of the end of the bar, it aims for the middle of the zone minus 30 ms (release lag) instead; a zone under 50 ms wide casts immediately.
- **PSI** is base PSI: implants don't count. Timing depends on tier and base PSI only; every discipline in a tier is the same.

## Hard rules

- **One command per binding in `user.bnd`.** Semicolons don't chain, and a second `bind` on the same key replaces the first. Use `run file.txt` to do several things.
- **Edit `user.bnd` only with the game closed.** The game rewrites it on exit.
- **Paths use backslashes:** `run psi\file.txt` works, `run psi/file.txt` doesn't.
- **Set every value in every macro.** Config values persist, so a macro that leaves one out inherits whatever the last macro set.
- **`summon_obj` must come before `equip_weapon psi amp`.** The helper checks what was in hand when it appeared.
- **No comments or blank-line tricks in `.txt` files.** Keep to plain commands, one per line.
- **`psi_name` and chain lists must not contain spaces.**
- **Don't suggest `mod_apply` mid-game.** It unloads the level, and the game can crash afterwards.
- **Macros take effect on the next keypress,** so they can be edited while the game runs. Bindings and the `.kpf` need a restart.

## Binding a macro to a key

1. The player closes the game.
2. Back up `user.bnd`.
3. Pick a key that isn't bound yet: search for `bind <key> ` at the start of a line.
4. Add `bind <key> "run psi\<macro>.txt"`, or `"run psi\chains\<chain>.txt"` for a chain.

## Checking a macro works

- **After pressing the key,** the player types `condump` in the console (Ctrl+;). Search `condump.txt` for `[psi_autocast]`.
- **An overload succeeded** if `OnOverloadSuccess` appears just before `released`.
- **Each cast logs** its tier, base PSI, overload zone and decision. Chains log `chain: step N/M` and `chain: done`.
- **`condump.txt` is a 1,025-line ring buffer.** Once it wraps, the newest lines continue at the top of the file.
- **If the amp comes out but nothing casts,** either the mod isn't enabled for this save (check `mod_list`) or the discipline isn't learned.

## Discipline numbers

From the game's `psihelp.str`. "Benefits" follows the System Shock wiki's list of disciplines that gain from overloading.

<!-- disciplines:start -->
| `psi_power` | Tier | Discipline | Benefits from overload | Conditional overload script | Quickfire script |
|---|---|---|---|---|---|
| 1 | 1 | Psycho-Reflective Screen | No | `T1_Psycho_Reflective_Screen.txt` | `T1_Psycho_Reflective_Screen_Quickfire.txt` |
| 2 | 1 | Neuro-Reflex Dampening | No | `T1_Neuro_Reflex_Dampening.txt` | `T1_Neuro_Reflex_Dampening_Quickfire.txt` |
| 3 | 1 | Kinetic Redirection | Yes | `T1_Kinetic_Redirection.txt` | `T1_Kinetic_Redirection_Quickfire.txt` |
| 4 | 1 | Psychogenic Agility | No | `T1_Psychogenic_Agility.txt` | `T1_Psychogenic_Agility_Quickfire.txt` |
| 5 | 1 | Psychogenic Cyber-Affinity | No | `T1_Psychogenic_Cyber_Affinity.txt` | `T1_Psychogenic_Cyber_Affinity_Quickfire.txt` |
| 6 | 1 | Projected Cryokinesis | Yes | `T1_Projected_Cryokinesis.txt` | `T1_Projected_Cryokinesis_Quickfire.txt` |
| 7 | 1 | Remote Electron Tampering | Yes | `T1_Remote_Electron_Tampering.txt` | `T1_Remote_Electron_Tampering_Quickfire.txt` |
| 9 | 2 | Anti-Entropic Field | No | `T2_Anti_Entropic_Field.txt` | `T2_Anti_Entropic_Field_Quickfire.txt` |
| 10 | 2 | Adrenaline Overproduction | No | `T2_Adrenaline_Overproduction.txt` | `T2_Adrenaline_Overproduction_Quickfire.txt` |
| 11 | 2 | Neural Decontamination | No | `T2_Neural_Decontamination.txt` | `T2_Neural_Decontamination_Quickfire.txt` |
| 12 | 2 | Cerebro-Stimulated Regeneration | Yes | `T2_Cerebro_Stimulated_Regeneration.txt` | `T2_Cerebro_Stimulated_Regeneration_Quickfire.txt` |
| 13 | 2 | Psychogenic Strength | No | `T2_Psychogenic_Strength.txt` | `T2_Psychogenic_Strength_Quickfire.txt` |
| 14 | 2 | Recursive Psionic Amplification | No | `T2_Recursive_Psionic_Amplification.txt` | `T2_Recursive_Psionic_Amplification_Quickfire.txt` |
| 15 | 2 | Localized Pyrokinesis | No | `T2_Localized_Pyrokinesis.txt` | `T2_Localized_Pyrokinesis_Quickfire.txt` |
| 17 | 3 | Molecular Duplication | Yes | `T3_Molecular_Duplication.txt` | `T3_Molecular_Duplication_Quickfire.txt` |
| 18 | 3 | Electron Cascade | Yes | `T3_Electron_Cascade.txt` | `T3_Electron_Cascade_Quickfire.txt` |
| 19 | 3 | Energy Reflection | No | `T3_Energy_Reflection.txt` | `T3_Energy_Reflection_Quickfire.txt` |
| 20 | 3 | Neural Toxin-Blocker | No | `T3_Neural_Toxin_Blocker.txt` | `T3_Neural_Toxin_Blocker_Quickfire.txt` |
| 21 | 3 | Enhanced Motion Sensitivity | No | `T3_Enhanced_Motion_Sensitivity.txt` | `T3_Enhanced_Motion_Sensitivity_Quickfire.txt` |
| 22 | 3 | Projected Pyrokinesis | Yes | `T3_Projected_Pyrokinesis.txt` | `T3_Projected_Pyrokinesis_Quickfire.txt` |
| 23 | 3 | Psionic Hypnogenesis | Yes | `T3_Psionic_Hypnogenesis.txt` | `T3_Psionic_Hypnogenesis_Quickfire.txt` |
| 25 | 4 | Photonic Redirection | No | `T4_Photonic_Redirection.txt` | `T4_Photonic_Redirection_Quickfire.txt` |
| 26 | 4 | Remote Pattern Detection | No | `T4_Remote_Pattern_Detection.txt` | `T4_Remote_Pattern_Detection_Quickfire.txt` |
| 27 | 4 | Electron Suppression | Yes | `T4_Electron_Suppression.txt` | `T4_Electron_Suppression_Quickfire.txt` |
| 28 | 4 | Psychogenic Endurance | No | `T4_Psychogenic_Endurance.txt` | `T4_Psychogenic_Endurance_Quickfire.txt` |
| 29 | 4 | Molecular Transmutation | Yes | `T4_Molecular_Transmutation.txt` | `T4_Molecular_Transmutation_Quickfire.txt` |
| 30 | 4 | Remote Circuitry Manipulation | Yes | `T4_Remote_Circuitry_Manipulation.txt` | `T4_Remote_Circuitry_Manipulation_Quickfire.txt` |
| 31 | 4 | Cerebro-Energetic Extension | No | `T4_Cerebro_Energetic_Extension.txt` | `T4_Cerebro_Energetic_Extension_Quickfire.txt` |
| 33 | 5 | Advanced Cerebro-Stimulated Regeneration | Yes | `T5_Advanced_Cerebro_Stimulated_Regeneration.txt` | `T5_Advanced_Cerebro_Stimulated_Regeneration_Quickfire.txt` |
| 34 | 5 | Soma Transference | Yes | `T5_Soma_Transference.txt` | `T5_Soma_Transference_Quickfire.txt` |
| 35 | 5 | Instantaneous Quantum Relocation | No | `T5_Instantaneous_Quantum_Relocation.txt` | `T5_Instantaneous_Quantum_Relocation_Quickfire.txt` |
| 36 | 5 | Imposed Neural Restructuring | Yes | `T5_Imposed_Neural_Restructuring.txt` | `T5_Imposed_Neural_Restructuring_Quickfire.txt` |
| 37 | 5 | Metacreative Barrier | Yes | `T5_Metacreative_Barrier.txt` | `T5_Metacreative_Barrier_Quickfire.txt` |
| 38 | 5 | External Psionic Detonation | No | `T5_External_Psionic_Detonation.txt` | `T5_External_Psionic_Detonation_Quickfire.txt` |
| 39 | 5 | Psycho-Reflective Aura | No | `T5_Psycho_Reflective_Aura.txt` | `T5_Psycho_Reflective_Aura_Quickfire.txt` |
<!-- disciplines:end -->

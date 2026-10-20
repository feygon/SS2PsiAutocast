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

1. A key binding in `user.bnd` runs a macro: `bind g "run psi\t1_projected_cryokinesis.txt"`.
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
run psi\lib\t1.txt
run psi\lib\overload.txt
run psi\lib\draw_cast.txt
```

**The parts:**

| Part | Contents |
|---|---|
| `psi\lib\t1.txt` … `t5.txt` | `set psi_tier N` |
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
  - `last`: switch back to the weapon held when a macro last drew the amp. The mod remembers it and re-equips it with `ShockGame.Equip`. The game's `last_weapon` command goes one weapon too far back, because it doesn't count `equip_weapon` switches. `weapon:<Name>`: switch weapon by running `psi\actions\switch_to_<name>.txt`. Valid names: `Wrench`, `Pistol`, `Shotgun`, `Assault_Rifle`, `Laser_Pistol`, `EMP_Rifle`, `Laser_Rapier`, `Grenade_Launcher`, `Stasis_Field_Generator`, `Fusion_Cannon`, `Crystal_Shard`, `Viral_Proliferator`, `Annelid_Launcher` (case matters). **Put a weapon switch only as the last step,** because casts after it would find the amp put away.
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
| `psi_tier` | 1–5 | Set by `psi\lib\t<n>.txt` |
| `psi_mode` | 0, 1, 2 | 0 quickfire, 1 conditional overload, 2 manual hold |
| `psi_release_ms` | ms | Hold time for mode 2 |
| `psi_draw_ms` | ms | Wait for the amp to come up when it isn't already in hand. 800 is reliable from the pistol |
| `psi_chain` | comma-separated names | Chain steps |
| `psi_chain_gap_ms` | ms, at least 500 | Pause after each release in a chain |
| `psi_auto_hypo` | 0 or 1 | Before each cast in a chain, use a psi hypo if psi points are at or below max minus what a hypo restores. The mod works this out from `Quest.Get("Difficulty")` (1 = Easy: 30, otherwise 20) and the Pharmo-Friendly trait (× 1.2), giving 36 or 24. Always set it, to 0 or 1, because it carries over between macros |
| `psi_auto_hypo_wait_ms` | ms | Pause after an auto hypo before the cast (default 500) |

**Cancel:** `psi\actions\cancel_macro.txt` (`summon_obj PsiCancel`) stops any running macro at its next timer. It releases fire first, so a cast that is mid-charge casts at normal strength, or fizzles if the charge has only just started. Suggest binding it alongside any chain.

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
| 1 | 1 | Psycho-Reflective Screen | No | `t1_psycho_reflective_screen.txt` | `t1_psycho_reflective_screen_quickfire.txt` |
| 2 | 1 | Neuro-Reflex Dampening | No | `t1_neuro_reflex_dampening.txt` | `t1_neuro_reflex_dampening_quickfire.txt` |
| 3 | 1 | Kinetic Redirection | Yes | `t1_kinetic_redirection.txt` | `t1_kinetic_redirection_quickfire.txt` |
| 4 | 1 | Psychogenic Agility | No | `t1_psychogenic_agility.txt` | `t1_psychogenic_agility_quickfire.txt` |
| 5 | 1 | Psychogenic Cyber-Affinity | No | `t1_psychogenic_cyber_affinity.txt` | `t1_psychogenic_cyber_affinity_quickfire.txt` |
| 6 | 1 | Projected Cryokinesis | Yes | `t1_projected_cryokinesis.txt` | `t1_projected_cryokinesis_quickfire.txt` |
| 7 | 1 | Remote Electron Tampering | Yes | `t1_remote_electron_tampering.txt` | `t1_remote_electron_tampering_quickfire.txt` |
| 9 | 2 | Anti-Entropic Field | No | `t2_anti_entropic_field.txt` | `t2_anti_entropic_field_quickfire.txt` |
| 10 | 2 | Adrenaline Overproduction | No | `t2_adrenaline_overproduction.txt` | `t2_adrenaline_overproduction_quickfire.txt` |
| 11 | 2 | Neural Decontamination | No | `t2_neural_decontamination.txt` | `t2_neural_decontamination_quickfire.txt` |
| 12 | 2 | Cerebro-Stimulated Regeneration | Yes | `t2_cerebro_stimulated_regeneration.txt` | `t2_cerebro_stimulated_regeneration_quickfire.txt` |
| 13 | 2 | Psychogenic Strength | No | `t2_psychogenic_strength.txt` | `t2_psychogenic_strength_quickfire.txt` |
| 14 | 2 | Recursive Psionic Amplification | No | `t2_recursive_psionic_amplification.txt` | `t2_recursive_psionic_amplification_quickfire.txt` |
| 15 | 2 | Localized Pyrokinesis | No | `t2_localized_pyrokinesis.txt` | `t2_localized_pyrokinesis_quickfire.txt` |
| 17 | 3 | Molecular Duplication | Yes | `t3_molecular_duplication.txt` | `t3_molecular_duplication_quickfire.txt` |
| 18 | 3 | Electron Cascade | Yes | `t3_electron_cascade.txt` | `t3_electron_cascade_quickfire.txt` |
| 19 | 3 | Energy Reflection | No | `t3_energy_reflection.txt` | `t3_energy_reflection_quickfire.txt` |
| 20 | 3 | Neural Toxin-Blocker | No | `t3_neural_toxin_blocker.txt` | `t3_neural_toxin_blocker_quickfire.txt` |
| 21 | 3 | Enhanced Motion Sensitivity | No | `t3_enhanced_motion_sensitivity.txt` | `t3_enhanced_motion_sensitivity_quickfire.txt` |
| 22 | 3 | Projected Pyrokinesis | Yes | `t3_projected_pyrokinesis.txt` | `t3_projected_pyrokinesis_quickfire.txt` |
| 23 | 3 | Psionic Hypnogenesis | Yes | `t3_psionic_hypnogenesis.txt` | `t3_psionic_hypnogenesis_quickfire.txt` |
| 25 | 4 | Photonic Redirection | No | `t4_photonic_redirection.txt` | `t4_photonic_redirection_quickfire.txt` |
| 26 | 4 | Remote Pattern Detection | No | `t4_remote_pattern_detection.txt` | `t4_remote_pattern_detection_quickfire.txt` |
| 27 | 4 | Electron Suppression | Yes | `t4_electron_suppression.txt` | `t4_electron_suppression_quickfire.txt` |
| 28 | 4 | Psychogenic Endurance | No | `t4_psychogenic_endurance.txt` | `t4_psychogenic_endurance_quickfire.txt` |
| 29 | 4 | Molecular Transmutation | Yes | `t4_molecular_transmutation.txt` | `t4_molecular_transmutation_quickfire.txt` |
| 30 | 4 | Remote Circuitry Manipulation | Yes | `t4_remote_circuitry_manipulation.txt` | `t4_remote_circuitry_manipulation_quickfire.txt` |
| 31 | 4 | Cerebro-Energetic Extension | No | `t4_cerebro_energetic_extension.txt` | `t4_cerebro_energetic_extension_quickfire.txt` |
| 33 | 5 | Advanced Cerebro-Stimulated Regeneration | Yes | `t5_advanced_cerebro_stimulated_regeneration.txt` | `t5_advanced_cerebro_stimulated_regeneration_quickfire.txt` |
| 34 | 5 | Soma Transference | Yes | `t5_soma_transference.txt` | `t5_soma_transference_quickfire.txt` |
| 35 | 5 | Instantaneous Quantum Relocation | No | `t5_instantaneous_quantum_relocation.txt` | `t5_instantaneous_quantum_relocation_quickfire.txt` |
| 36 | 5 | Imposed Neural Restructuring | Yes | `t5_imposed_neural_restructuring.txt` | `t5_imposed_neural_restructuring_quickfire.txt` |
| 37 | 5 | Metacreative Barrier | Yes | `t5_metacreative_barrier.txt` | `t5_metacreative_barrier_quickfire.txt` |
| 38 | 5 | External Psionic Detonation | No | `t5_external_psionic_detonation.txt` | `t5_external_psionic_detonation_quickfire.txt` |
| 39 | 5 | Psycho-Reflective Aura | No | `t5_psycho_reflective_aura.txt` | `t5_psycho_reflective_aura_quickfire.txt` |
<!-- disciplines:end -->

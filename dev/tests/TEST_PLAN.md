# In-game test plan: chain steps, psi hypo, weapon switch, auto hypo

**TLDR:** Seven test macros, each bound to its own key. Press each one, then run `condump` and check `condump.txt` against the expected lines. The installed copies are in `<game>\psi\chains\`, and the bindings are in `user.bnd` (backups: `user.bnd.backup10` before the test keys, `user.bnd.backup11` before the cancel key).

## Before you start

- Load a save. Run `mod_list` and check that psi_autocast is under "Mods to load".
- Run `condump` once, before testing, so script errors can be checked first.
- Have the **pistol** out, at least **two psi hypos** in your inventory, and **Projected Cryokinesis** and **Localized Pyrokinesis** learned.
- Stand in a clear spot. Localized Pyrokinesis damages anything nearby.

## Tests

| Key | File | Start state | Expected |
|---|---|---|---|
| C | `Test1_Arm_Overload.cmd` | Pistol out | Amp comes up, then an overloaded Cryokinesis. Console: `arm - drawing the psi amp, waiting 800ms`, `overloading, holding …ms`, `OnOverloadSuccess`, `chain: done` |
| I | `Test2_Two_Casts.cmd` | Pistol out | Cryokinesis, then 500 ms later Localized Pyrokinesis. Both cast |
| X | `Test3_Hypo_Between.cmd` | Pistol out | Cryokinesis, a psi hypo is used (one fewer in inventory, psi goes up), then Localized Pyrokinesis |
| Ins | `Test4_Previous_Weapon.cmd` | Pistol out | Cryokinesis, then back to the **pistol**. This checks what `last_weapon` returns to |
| Home | `Test5_Named_Weapon.cmd` | Pistol out | Localized Pyrokinesis, then the **wrench** is drawn |
| End | `Test6_Auto_Hypo.cmd` | Pistol out, psi **more than 24 below max** (36 on Easy) | Before the first cast: `psi N/M is at or below … using a psi hypo first`, then four quickfire Cryokinesis casts |
| End | `Test6_Auto_Hypo.cmd` | Psi **full** | Four Cryokinesis casts with no hypo, until psi drops past the threshold. At that point, a hypo before the next cast |
| V | `Test7_No_Arm_Guard.cmd` | **Pistol** out | No shot fired. Console: `the psi amp isn't in hand (add an arm step first), stopping` |
| V | `Test7_No_Arm_Guard.cmd` | **Amp** out | Cryokinesis casts immediately |
| End, then **Numpad +** | `Test6_Auto_Hypo.cmd`, then `actions\Cancel_Macro.cmd` | Pistol out | Press Numpad + after the first or second cast. The remaining casts don't happen. Console: `cancel: stopping any running macro`, then `chain: cancelled at step N/M, stopping`. If a cast was charging, `cancelled` from the cast too. Nothing stays stuck |
| Numpad + | `actions\Cancel_Macro.cmd` | Nothing running | Only `cancel: stopping any running macro`. No other effect |

## What to report

- For each test: whether it did what's in the Expected column.
- Anything stuck. If the trigger stays held, a click frees it.
- `condump` after the run, for the exact console lines.

## Afterwards

- Restore the old bindings by copying `user.bnd.backup10` over `user.bnd`, with the game closed. Or keep the test keys.

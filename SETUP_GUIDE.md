# Setup guide and troubleshooting: psi_autocast and psi_autocast_mfd

**TLDR:** Install psi_autocast (one-key psi casting), optionally add psi_autocast_mfd (an in-game MFD that builds macros), enable both for your save from New Game → Mods, then bind keys once in `user.bnd` with the game closed: by script, or by hand. The troubleshooting table at the end covers every problem we've hit.

## Contents
1. [What you need](#what-you-need)
2. [Install psi_autocast](#install-psi_autocast)
3. [Install psi_autocast_mfd (optional)](#install-psi_autocast_mfd-optional)
4. [Enable the mods for your save](#enable-the-mods-for-your-save)
5. [Bind your keys](#bind-your-keys)
6. [First use](#first-use)
7. [Troubleshooting](#troubleshooting)

## What you need

- **System Shock 2: 25th Anniversary Remaster** on PC. Tested on the Epic version, game version 1.3.4984.
- **The game started and quit at least once,** so your settings folder and `user.bnd` exist.
- **Your Saved Games folder:** usually `%USERPROFILE%\Saved Games\Nightdive Studios\System Shock 2 Remastered\`. If you've moved Saved Games (its Properties, OneDrive), it's wherever you moved it; the setup scripts find it either way.

## Install psi_autocast

1. **Download** the psi_autocast zip from Nexus.
2. **Extract it into the game folder,** the one with `SystemShock2Remastered.exe`. It adds `mods\psi_autocast.kpf` and a `psi` folder of key scripts.

## Install psi_autocast_mfd (optional)

1. **Download** the psi_autocast_mfd zip from Nexus.
2. **Extract it into the same game folder.** It adds `mods\psi_autocast_mfd.kpf`. It needs psi_autocast installed too.

## Enable the mods for your save

Each save remembers its own mod list, so loading an old save directly won't turn the mods on.

1. **New Game → Mods.** Add **psi_autocast**, and **psi_autocast_mfd** if you installed it. Click **Apply**.
2. **Start the new game.** Once the first level loads, **load your own save**.
3. **Make a regular save.** From now on that save loads with the mods.
4. **To check:** open the console and type `mod_list`. Both mods should be under "Mods to load".

**Don't use the `mod_apply` console command mid-game:** it can unload the level.

## Bind your keys

Key bindings live in `user.bnd`, in your Saved Games folder above. **The game must be closed:** it rewrites the file when it exits, so edits made while it runs are lost. Scripts can't bind keys while the game runs, which is why this is a one-time step outside the game.

### The easy way: the setup scripts (GitHub)

Both are double-click `.bat` files. Each backs up `user.bnd` first, never changes a key you've already bound, and lists what it bound. Run them from any folder.

- **`starterPsiPowers.bat`** (psi_autocast's repo, `extras/`): binds **G** to Projected Cryokinesis with automatic overload and **J** to Localized Pyrokinesis then your previous weapon, if those keys are free.
- **`setupPsiMfd.bat`** (psi_autocast_mfd's repo, `extras/`): binds keypad * to open the MFD, keypad + to cancel a running macro, and a macro key on every plain key you haven't bound (letters, digits, F-keys, then keypad and navigation keys). It leaves the mouse wheel alone.

### By hand

Open `user.bnd` in Notepad, back it up, and add lines like these:

```
bind g "run psi\T1_Projected_Cryokinesis_Quickfire.cmd"
bind keypad_plus "run psi\actions\Cancel_Macro.cmd"
bind keypad_star "summon_obj PsiMfd"
bind keypad_minus "run user:/psi_macros\MacroKPMinus.cmd"
```

- **A discipline key** runs one of the scripts in the game's `psi` folder (the psi_autocast readme lists them all).
- **The cancel key** stops any running macro.
- **The MFD key** opens and closes the MFD.
- **A macro key** runs a macro the MFD saves for it. Change the key and the file name together.

Optional, so the mouse wheel scrolls the MFD in cursor mode (it still switches weapons away from the MFD):

```
game2 bind mouse_wheel_up "summon_obj PsiMfdWheelUp"
game2 bind mouse_wheel_down "summon_obj PsiMfdWheelDown"
```

## First use

- **psi_autocast:** press a discipline key. The psi amp comes out and the discipline casts; conditional-overload keys overload when the discipline benefits.
- **The Macro Builder:** open `psi\Macro_Builder.html` in your browser to build chains outside the game.
- **The MFD:** press keypad *. Pick a macro key at the top, click disciplines to add casts, **Save**, close it, and press the key. Leaving cursor mode (Tab) also closes it; unsaved edits are dropped.
- **The console** shows a line for every cast and macro step, which helps when something doesn't happen.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| A key does nothing at all | The binding is missing, or `user.bnd` was edited while the game ran | Close the game, check the line in `user.bnd`, start again |
| A key does nothing; the binding is there | The game may not accept that key name | Start and quit the game, then check the line is still in `user.bnd`; if it's gone, the game didn't accept the key, so use a different one |
| The amp comes out but nothing casts | The mod isn't enabled for this save, or the discipline isn't learned | See "Enable the mods for your save"; the console warns about an unlearned discipline |
| Weapon switching is stuck after a cast | The trigger is still held | Click once; then raise `psi_draw_ms` in that script |
| Keypad * doesn't open the MFD | psi_autocast_mfd isn't enabled for this save, or the binding is missing | `mod_list` in the console; check `bind keypad_star "summon_obj PsiMfd"` |
| The MFD opens, then closes by itself | An MFD error | The console shows `[psi_mfd] error in ...`; report that line |
| The MFD says "No macro keys bound" | No `user.bnd` line runs a `psi_macros` file | Run `setupPsiMfd.bat`, or add a macro key line by hand |
| A saved macro key does nothing | The binding's file name differs from the one the MFD saved, or psi_autocast isn't enabled | Check the line in `user.bnd`; the MFD saves to the name the binding uses |
| The console says "psi_autocast isn't loaded" | psi_autocast_mfd is enabled without psi_autocast | Enable psi_autocast for the save as well |
| The wheel switches weapons over the MFD | The optional `game2` wheel lines aren't in `user.bnd` | Add them (above), or scroll with Up / Dn and T1–T5 |
| A setup script says the game is running | It is, or it hasn't fully closed | Quit the game, wait a moment, run it again |
| A setup script can't find `user.bnd` | The game has never been started, or Saved Games is somewhere unusual | Start and quit the game once; or paste the folder when the script asks |
| An overload burns out or misses | Unexpected timing | Report the console line: it shows the tier, PSI and timing used |

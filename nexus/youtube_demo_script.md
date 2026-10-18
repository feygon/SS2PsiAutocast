# psi_autocast: YouTube demo script

## TLDR

- Video: System Shock 2 psi casting, base game vs. the psi_autocast mod, plus the Macro Builder.
- Length: about 8-12 minutes of narration, 10 scenes.
- Format: each scene has a time estimate, an **On screen** list (what you do) and a **Say** block (what you read aloud).
- Anything in [square brackets] is a detail for you to fill in or confirm while recording.
- Tested on the Epic version of the 25th Anniversary Remaster only. Do not claim more.

## Contents

1. Pre-recording checklist
2. Scene 1: Intro
3. Scene 2: The base game's way
4. Scene 3: Key binding menu
5. Scene 4: Overloading by hand
6. Scene 5: The mod, one key
7. Scene 6: Overload timing and console feedback
8. Scene 7: Binding a script
9. Scene 8: The Macro Builder
10. Scene 9: Building and running the demo macro
11. Scene 10: Extras
12. Scene 11: Outro

## Pre-recording checklist

- Pistol equipped and ready.
- Psi hypos in inventory.
- Projected Cryokinesis, Localized Pyrokinesis and Psychogenic Agility learned.
- A clear open spot to test in. Localized Pyrokinesis damages anything nearby, including you.
- A save to reload if things go wrong.
- Console font readable at recording resolution (console opens with Ctrl+;).
- Mod extracted into the folder with SystemShock2Remastered.exe, and enabled: New Game, Mods, add psi_autocast, Apply, start, then load your save.
- Do not use mod_apply mid-game.
- Binding lines ready to paste into user.bnd (game closed when you edit it).
- Macro Builder open in a browser, offline copy at psi\Macro_Builder.html.
- Plain `bind` line for Cryokinesis ready: `bind j "run psi\T1_Projected_Cryokinesis.cmd"`.
- Screen recorder set to capture both the game and the browser.
- [Note which key you will use for the amp, and which key for the macro.]

---

## Scene 1: Intro (about 45 s)

**On screen**
- Game running, pistol in hand, standing in a calm spot.
- Title card: "psi_autocast for System Shock 2: 25th Anniversary Remaster".

**Say**
> Hi. This is a quick tour of a mod I made for System Shock 2, the 25th Anniversary Remaster.
>
> It's called psi_autocast. It makes psi powers a lot less fiddly to use.
>
> Quick summary of the problem. To cast a psi power, you need the psi amp in your hand. Then you need the right power selected. Then you fire. Mid-combat, that's a lot of steps.
>
> First I'll show how the base game does it, honestly. Then the mod. Then a little web tool I built to chain casts into one key.

---

## Scene 2: The base game's way (about 2 min)

**On screen**
- Pistol in hand. Press the key that switches to the psi amp. [Show your key.]
- Open the psi power list. Show the tiers and the powers under them.
- Press F1 to F5 to cycle psi tiers. Point out that you land on a tier, not a specific power.
- In the power list, hover the power itself (not the tier entry, which is the first item in the list). Press Shift+F6.
- Close the list. Press F6 and show that it selects that power.
- Fire the power at a wall or target.

**Say**
> Here's the base game. I'm holding a pistol.
>
> Step one: switch to the psi amp. That's its own key, separate from everything else.
>
> Step two: pick a power. By default, F1 through F5 select or cycle psi tiers. So you get a tier, and then you hunt through it for the power you want.
>
> There is a better way, but the game never explains it clearly. You open the psi power list. You hover over the power itself. Not the tier's entry, which is the first item in the list. The power. Then you press Shift and one of F6 through F12.
>
> Now, F6 through F12 select that power directly. Quick slots are saved per save game, so you set them up again for each save.
>
> Step three: fire.
>
> That works. But look at what it took. Switch to the amp, pick the power, fire. And if you hadn't set up the quick slot, you'd be hunting through tiers with an enemy running at you.

---

## Scene 3: The key binding menu (about 30 s)

**On screen**
- Open the Options menu. [Show the Options menu path you use to reach the controls.]
- Scroll the key list briefly.

**Say**
> Maybe you think: I'll just bind it in the key binding menu. Let's look.
>
> Here are the controls. There's no entry for psi powers. You can't bind them here.
>
> That's why people end up editing a file called user.bnd by hand. We'll come back to that.

---

## Scene 4: Overloading by hand (about 1 min)

**On screen**
- Select a power with an overload option [confirm which power you use, e.g. Projected Cryokinesis].
- Hold fire. Show the bar filling.
- Release inside the yellow zone at the right end of the bar. Show the result.
- Do it again and release too late. Show the burnout: the power fails and you take damage.

**Say**
> Now overloading. This is a stronger cast, but you do it by hand.
>
> You hold fire. A bar fills. You have to release inside the yellow zone at the right end.
>
> Release in the zone, and it works.
>
> Release too late, and you get burnout. The power fails, and you take damage.
>
> That's a timing game you have to win every time you cast, usually while something is shooting at you.

---

## Scene 5: The mod, one key (about 1 min 30 s)

**On screen**
- Switch back to the pistol.
- Press the mod's key for Projected Cryokinesis. The amp is drawn, the power is selected, it casts.
- Show the psi folder in a file explorer: the `T1_Projected_Cryokinesis_Quickfire.cmd` and `T1_Projected_Cryokinesis.cmd` files.

**Say**
> Here's the mod. I'm holding a pistol. I press one key.
>
> The mod draws the psi amp if it isn't already in my hand. It waits about 800 milliseconds for it. Then it selects the power directly, so no quick slots needed. Then it casts.
>
> One key. That's the whole thing.
>
> The mod ships with two ready-made scripts for each psi discipline, all 35 of them.
>
> The first is the Quickfire one. For example, T1 Projected Cryokinesis Quickfire. It casts immediately.
>
> The second has no suffix. T1 Projected Cryokinesis. That one does a conditional overload. It overloads only if that discipline actually benefits from it. If it doesn't, it casts immediately, and it tells you why in the console.

---

## Scene 6: Overload timing and console feedback (about 1 min 30 s)

**On screen**
- Open the console with Ctrl+;.
- Cast Projected Cryokinesis with the overload script.
- Zoom in on the console output: tier, base PSI, zone, decision, OnOverloadSuccess.
- Optional: show a cast where the console says the discipline doesn't benefit from overload, and read the reason aloud.

**Say**
> How does it hit the timing? It doesn't guess. It uses the game's own data table, called Overload Params.
>
> The bar fill time depends on the tier. For tiers one to five, it's 2.0, 1.5, 1.0, 0.75 and 0.4 seconds.
>
> The yellow zone starts at a fraction of the bar. That fraction is set by your PSI before the overload. At PSI 4, it's 0.73.
>
> So here's an example. Tier 1, PSI 4. The zone runs from 1460 to 2000 milliseconds. The mod holds for 1564 milliseconds, inside the zone.
>
> Open the console with Control and semicolon. Each cast prints its tier, your PSI before the overload, the zone, and the decision. And there it is: OnOverloadSuccess.
>
> As your PSI goes up, the numbers change, and the mod adapts.

---

## Scene 7: Binding a script (about 45 s)

**On screen**
- Close the game.
- Open user.bnd in a text editor.
- Add the line: `bind j "run psi\T1_Projected_Cryokinesis.cmd"`
- Save the file.

**Say**
> To use a script, you bind it to a key. This is the part that needs the game closed.
>
> Open user.bnd. Add a line like this one: bind j, then run, then the path to the script. This binds J to the Cryokinesis overload script.
>
> Save, start the game, and J does the whole thing.
>
> Now, one cast on one key is nice. But what if you want a whole combo?

---

## Scene 8: The Macro Builder (about 2 min)

**On screen**
- Open the Macro Builder. Mention it works offline from psi\Macro_Builder.html.
- Show the online address on screen: https://feygon.github.io/SS2PsiAutocast/Macro_Builder.html
- Walk through the sections from top to bottom, in order.

**Say**
> This is the Macro Builder. It's an HTML page. It works offline from the psi folder, and it's also online. The link is on screen and in the description.
>
> It has five sections, top to bottom.
>
> Section one: Settings. There's a checkbox, "Auto psi hypo before every cast". Before each cast, the macro uses a psi hypo if your psi points are at or below your max minus what a hypo restores. A hypo restores 30 on Easy, and 20 on Normal, Hard and Impossible. Add 20 percent if you have the Pharmo-Friendly O/S upgrade. So a hypo is never wasted.
>
> There's also the amp draw wait. That's the 800 milliseconds from before.
>
> Section two: Add steps. There's a discipline dropdown. Each discipline shows its max duration in grey on the right. For example, Psychogenic Agility, max 10 minutes.
>
> You choose conditional overload or quickfire, and click Add cast.
>
> There's also an Other steps group. You can Add psi hypo anywhere. And you can Finish with a weapon switch. That can be Previous weapon, or any weapon by name. It's always the last step.
>
> Section three: Steps. This is your list, in order. It starts with a removable "Arm psi amp" step. It puts 500 millisecond waits between steps. 500 milliseconds is the psi amp's refire limit. It blocks two casts closer than 500 milliseconds in total, counting any hypo between them.
>
> Each timed step shows its duration formula. For example: "Lasts 2 min plus 1 min times PSI. Max 10 min, at PSI 8."
>
> Section four: Name and key.
>
> Section five: Your macro. That's the generated file, with Download and Copy buttons. It also gives you the user.bnd binding line, and the install steps.

---

## Scene 9: Building and running the demo macro (about 2 min)

**On screen**
1. In Add steps, pick Psychogenic Agility, choose quickfire, click Add cast.
2. Pick Projected Cryokinesis, choose conditional overload, click Add cast.
3. Click Add psi hypo.
4. Pick Localized Pyrokinesis, choose quickfire, click Add cast.
5. Under Finish with a weapon switch, choose Previous weapon.
6. Show the Steps list with the 500 ms waits and the duration formulas.
7. Enter a name and a key in Name and key. [Show the name and key you pick.]
8. Show the generated macro. It looks like: `set psi_chain arm,4q,w500,6o,w500,hypo,w500,15q,w500,last` [read the real output on screen, it may differ].
9. Click Download. Save it into psi\chains\.
10. Close the game. Add the bind line from section five to user.bnd.
11. Start the game, load the save. With the pistol in hand, press the key.
12. Show the chain running: Agility, Cryokinesis, hypo, Pyrokinesis, then back to the pistol.

**Say**
> Let's build one. I want Psychogenic Agility first, as a quickfire cast. Then Projected Cryokinesis with the conditional overload. Then a psi hypo. Then Localized Pyrokinesis, quickfire. Then switch back to my previous weapon.
>
> I add each one. Here's the steps list. The Arm psi amp step is first. Look at the 500 millisecond waits between everything.
>
> I'll give it a name and a key.
>
> And here's the generated macro. It's a short line of text. Download it, and save it into psi\chains\.
>
> Then the install steps. Close the game, and add this bind line to user.bnd.
>
> Now I start the game and load my save. I have the pistol out. And I press the key.
>
> Agility. Cryokinesis. The hypo. Pyrokinesis. And back to the pistol.
>
> One key.
>
> A warning: Localized Pyrokinesis damages anything nearby. So pick your spot.

---

## Scene 10: Extras (about 1 min)

**On screen**
- Show psi\actions\Cancel_Macro.cmd in the file explorer.
- Show the one-line action scripts: Use_Psi_Hypo, Switch_To_Previous_Weapon, Switch_To_<Weapon>.
- Show the file psi\psi_autocast_MACROS_FOR_CLAUDE.md.

**Say**
> A few extras, one line each.
>
> A cancel key. Bind a key to psi\actions\Cancel_Macro.cmd. It stops the rest of a running macro. If a cast is mid-charge, it's released, and it casts at normal strength.
>
> There are also one-line action scripts in psi\actions. Use Psi Hypo. Switch To Previous Weapon. And Switch To, then a weapon name. You can bind those to their own keys.
>
> And there's a guide file, psi_autocast MACROS FOR CLAUDE, in the psi folder. Give it to Claude, and ask it to write macros for you.

---

## Scene 11: Outro (about 1 min)

**On screen**
- Show the Nexus Mods page for the remaster mod.
- Show the GitHub page: https://github.com/feygon/SS2PsiAutocast
- Show the install steps as a short on-screen list.
- [Show the license line on GitHub if you want to point at it.]

**Say**
> That's psi_autocast.
>
> You can get it on Nexus Mods, on the System Shock 2 remaster page. The source is on GitHub, at github.com/feygon/SS2PsiAutocast. It's MIT licensed.
>
> Install is quick. Extract the zip into the folder with SystemShock2Remastered.exe. Then, in the game: New Game, Mods, add psi_autocast, Apply, and start. Then load your save. Don't use mod_apply mid-game.
>
> I've tested it on the Epic version of the game. That's the only one I can vouch for.
>
> If you try it, let me know how it goes. Thanks for watching.

---

## Facts you must not stretch

- Tested on the Epic version only. Do not say it works on Steam or GOG.
- Do not mention multiplayer or the classic 1999 game as supported.
- The numbers in Scene 6 are one example (tier 1, PSI 4). Do not say they apply to every tier.

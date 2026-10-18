// psi_autocast: one-key psi casting.
//
// A key's .cmd file sets config values, then summons a PsiCast helper and equips the amp.
// The helper waits for the amp if it wasn't already in hand, selects the power, presses fire,
// releases after the hold time, then deletes itself. It exists because .cmd files cannot pause:
// a press and release in the same frame cancels the cast.
//
// Settings (see psi\lib\ for the parts that set them):
//   psi_power N      discipline id, 1-39 (Psi<N> in strings/psihelp.str); 0 = use psi_slot instead
//   psi_slot N       quick slot to use when psi_power is 0 (Shift+F<N> fills it)
//   psi_tier N       1-5; checked against the tier implied by psi_power
//   psi_benefits 0|1 whether overloading improves this discipline
//   psi_mode N       0 = quickfire, 1 = overload when it helps, 2 = manual hold of psi_release_ms
//   psi_name text    label for console output
//   psi_draw_ms N    wait for the amp to come up when it isn't already in hand
//   psi_release_ms N hold time for psi_mode 2
//
// Overload timing comes from the game's "Overload Params" table (OLPARAM in shock2.gam,
// unchanged by SCP): the bar fills in a fixed time per tier, and the yellow zone starts at a
// fraction of the bar set by PSI. Releasing after the bar is full is burnout. Measured in game
// (2026-10-18, all five tiers): the fraction follows BASE PSI (implants don't count), one row lower
// in the table than its PSI 1-8 order suggests - base PSI 6 uses the 0.58 entry.

const PSI_QUICKFIRE_MS = 100;
const PSI_SAFETY_MS = 50;           // minimum distance kept from both edges of the overload zone
const PSI_ZONE_AIM = 0.1;           // aim this far into the zone, as a fraction of its width
const PSI_VISIBLE_MS = 50;          // extra hold so the bar is visibly in the yellow before release

// Bar fill time in seconds, tiers 1-5.
PSI_BAR_SECONDS <- [2.0, 1.5, 1.0, 0.75, 0.4];
// Overload zone start as a fraction of the bar: OLPARAM's first eight floats, in table order.
PSI_ZONE_START <- [1.0, 0.94, 0.85, 0.73, 0.58, 0.4, 0.19, 0.01];

// The PSI_ZONE_START entry for a base PSI (see the note above: base PSI 6 -> entry 4, 0.58).
function PsiZoneRow(psi) {
	return psi < 2 ? 0 : (psi > 9 ? 7 : psi - 2);
}

// True when the psi amp is the weapon in hand.
function PsiAmpInHand() {
	local weapon = ShockGame.Equipped(0);
	return weapon != 0 && Object.InheritsFrom(weapon, Object.Named("Psi Amp"));
}

// "Previous weapon": the weapon in hand just before a macro drew the amp. The game's own
// last_weapon doesn't count an equip_weapon switch, so it went one weapon further back (the
// wrench instead of the pistol). So the macro remembers ShockGame.Equipped(0) and switches back
// through the normal path: psi\actions\equip\<archetype>.cmd, which runs equip_weapon.
// Not ShockGame.Equip(0, weapon): in game that left the amp unequippable, even by hand,
// until the save was reloaded.
ND.psiWeaponBeforeArm <- 0;

// "Assault Rifle" -> "assault_rifle": the file name of psi\actions\equip\<name>.cmd.
function PsiFileSafe(text) {
	local result = "";
	foreach (ch in text.tolower())
		result += ch == ' ' ? "_" : ch.tochar();
	return result;
}

function PsiRememberWeapon() {
	local weapon = ShockGame.Equipped(0);
	if (weapon != 0 && !PsiAmpInHand())
		ND.psiWeaponBeforeArm = weapon;
}

function PsiSwitchToRememberedWeapon() {
	local weapon = ND.psiWeaponBeforeArm;
	if (weapon == 0 || !Object.Exists(weapon))
		return "previous weapon: no weapon remembered (no macro has drawn the amp yet)";
	// Match the weapon to a known type (it may be a variant, as the amp is "StarterAmp"),
	// then switch through that type's equip file.
	local equipName = null;
	foreach (name in ND.psiWeaponArchetypes) {
		local type = Object.Named(name);
		if (type != 0 && Object.InheritsFrom(weapon, type)) {
			equipName = name;
			break;
		}
	}
	if (equipName == null)
		equipName = ShockGame.GetArchetypeName(weapon);
	Debug.Command("run psi\\actions\\equip\\" + PsiFileSafe(equipName) + ".cmd");
	return "switch back to the previous weapon (" + equipName + ")";
}

// PsiPreviousWeapon: the standalone "switch back to previous weapon" (psi\actions\Switch_To_Previous_Weapon.cmd).
class PsiPreviousWeapon extends SqRootScript {
	function OnBeginScript() {
		SetOneShotTimer("Switch", 0.01);
	}

	function OnTimer() {
		if (message().name != "Switch")
			return;
		print("[psi_autocast] " + PsiSwitchToRememberedWeapon());
		Object.Destroy(self);
	}
}

class PsiCast extends SqRootScript {
	function CfgInt(name, fallback) {
		if (!Engine.ConfigIsDefined(name))
			return fallback;
		local value = int_ref();
		Engine.ConfigGetInt(name, value);
		return value.tointeger();
	}

	function CfgText(name, fallback) {
		if (!Engine.ConfigIsDefined(name))
			return fallback;
		local value = string();
		Engine.ConfigGetRaw(name, value);
		return value.tostring();
	}

	function Say(text) {
		print("[psi_autocast] " + text);
	}

	// PsiPowerDesc / PsiPower2Desc are bit sets of learned disciplines (verified 2026-10-16, see DEVELOPMENT.md).
	function SeemsLearned(power) {
		local bits = power < 32
			? Property.Get("Player", "PsiPowerDesc")
			: Property.Get("Player", "PsiPower2Desc");
		if (typeof bits != "integer")
			return true; // can't tell, so don't warn
		return ((bits >> (power % 32)) & 1) == 1;
	}

	// Returns the hold time in ms, explaining the decision on the console.
	function ChooseHold(name, mode, tier, psi, benefits) {
		local barMs = (PSI_BAR_SECONDS[tier - 1] * 1000).tointeger();
		local startMs = (PSI_ZONE_START[PsiZoneRow(psi)] * barMs).tointeger();
		local basis = "tier " + tier + ", base PSI " + psi
			+ ", overload zone " + startMs + "-" + barMs + "ms";

		if (mode == 2) {
			local holdMs = CfgInt("psi_release_ms", PSI_QUICKFIRE_MS);
			Say(name + ": manual hold " + holdMs + "ms (" + basis + ")");
			return holdMs;
		}
		if (mode == 0) {
			Say(name + ": quickfire, casting immediately (" + basis + ")");
			return PSI_QUICKFIRE_MS;
		}
		if (!benefits) {
			Say(name + " doesn't benefit from an overload, so it's casting immediately (" + basis + ")");
			return PSI_QUICKFIRE_MS;
		}

		local aimMs = (PSI_ZONE_AIM * (barMs - startMs)).tointeger();
		local holdMs = startMs + (aimMs > PSI_SAFETY_MS ? aimMs : PSI_SAFETY_MS) + PSI_VISIBLE_MS;
		if (holdMs > barMs - PSI_SAFETY_MS) {
			Say(name + ": overload zone too narrow to hit safely, casting immediately (" + basis + ")");
			return PSI_QUICKFIRE_MS;
		}
		Say(name + ": overloading, holding " + holdMs + "ms (" + basis + ")");
		return holdMs;
	}

	function OnBeginScript() {
		// A chain passes its settings directly (ND.psiPendingCast) and creates this object itself.
		// Otherwise the settings come from config values set by a key file.
		local pending = ND.psiPendingCast;
		ND.psiPendingCast = null;

		local power = pending ? pending.power : CfgInt("psi_power", 0);
		local slot = pending ? 0 : CfgInt("psi_slot", 6);
		local mode = pending ? pending.mode : CfgInt("psi_mode", 0);
		local benefits = pending ? pending.benefits : CfgInt("psi_benefits", 0) != 0;
		local name = pending ? pending.name : CfgText("psi_name", power > 0 ? "discipline " + power : "quick slot " + slot);

		local impliedTier = power > 0 ? power / 8 + 1 : 0;
		local tier = pending ? impliedTier : CfgInt("psi_tier", impliedTier > 0 ? impliedTier : 1);
		if (impliedTier > 0 && impliedTier != tier) {
			Say(name + ": psi_tier " + tier + " doesn't match discipline " + power + " (tier " + impliedTier + "), using tier " + impliedTier);
			tier = impliedTier;
		}
		tier = tier < 1 ? 1 : (tier > 5 ? 5 : tier);

		// Base PSI: the overload window ignores implants (and GetStat includes them).
		local psi = Property.Get("Player", "BaseStatsDesc", "PSI");
		if (psi == null || psi < 1)
			psi = ShockGame.GetStat("Player", eStats.kStatPsi);
		psi = psi < 1 ? 1 : psi;

		if (power > 0 && !SeemsLearned(power))
			Say(name + ": warning - this discipline may not be learned yet");

		// Chain casts only start with the amp in hand, so they never wait for a draw.
		local waitMs = PsiAmpInHand() || pending ? 10 : CfgInt("psi_draw_ms", 800);
		// A key file is about to draw the amp: remember what was in hand, for "previous weapon".
		if (!pending)
			PsiRememberWeapon();

		SetData("Power", power);
		SetData("Slot", slot);
		SetData("HoldMs", ChooseHold(name, mode, tier, psi, benefits));
		SetData("CancelAt", ND.psiCancelCount);
		SetOneShotTimer("PsiSelect", waitMs / 1000.0);
	}

	function OnTimer() {
		local name = message().name;
		// Cancelled (PsiCancel): don't press, or stop waiting to release. PsiCancel already let go of fire.
		if (ND.psiCancelCount != GetData("CancelAt")) {
			Say("cancelled");
			Object.Destroy(self);
			return;
		}
		if (name == "PsiSelect") {
			local power = GetData("Power");
			if (power > 0)
				ShockGame.SetSelectedPsiPower(power);
			else
				Debug.Command("quickuse " + GetData("Slot"));
			Debug.Command("fire_weapon 1");
			SetOneShotTimer("PsiRelease", GetData("HoldMs") / 1000.0);
		}
		else if (name == "PsiRelease") {
			Debug.Command("fire_weapon 0");
			Say("released");
			ND.psiCastsReleased++;
			Object.Destroy(self);
		}
	}
}

// Counts finished casts, so a chain can tell when its current step has released.
ND.psiCastsReleased <- 0;

// Settings a chain hands to the PsiCast it creates: { power, mode, benefits, name }.
// Passed directly rather than through console "set" commands, which a script's Debug.Command
// only queues: they ran over several frames, and the summon after them never took effect.
ND.psiPendingCast <- null;

// Raised by PsiCancel. Each running PsiCast and PsiChain remembers its value at the start
// and stops at its next timer if it has changed.
ND.psiCancelCount <- 0;

// PsiCancel: stops any running macro.  summon_obj PsiCancel  (psi\actions\Cancel_Macro.cmd)
// A cast that is mid-charge is released, so it casts at normal strength (or fizzles if the
// charge has only just started); everything after it is skipped.
class PsiCancel extends SqRootScript {
	function OnBeginScript() {
		SetOneShotTimer("Cancel", 0.01);
	}

	function OnTimer() {
		if (message().name != "Cancel")
			return;
		ND.psiCancelCount++;
		Debug.Command("fire_weapon 0");
		print("[psi_autocast] cancel: stopping any running macro");
		Object.Destroy(self);
	}
}

// PsiChain: runs several steps in a row from one key.
//   set psi_chain arm,6o,w500,15q
//   set psi_draw_ms 800        how long the arm step waits for the amp to come up
//   set psi_chain_gap_ms 500   default pause after a cast when no wait step follows it
//   summon_obj PsiChain
// Steps, comma-separated:
//   arm      draw the psi amp if it isn't in hand, then wait psi_draw_ms
//   <id>o    cast discipline <id>, overloading if it benefits (conditional overload)
//   <id>q    cast discipline <id> immediately (quickfire)
//   w<ms>    wait <ms> milliseconds
//   hypo     use a psi hypo (runs psi\actions\Use_Psi_Hypo.cmd)
//   last     switch back to the weapon held before the amp was drawn (PsiSwitchToRememberedWeapon)
//   weapon:<Name>  switch weapon by running psi\actions\Switch_To_<Name>.cmd (weapon:Assault_Rifle)
// Steps whose commands take multi-word arguments run action files: Debug.Command goes through the
// console, which splits at spaces, so "equip_weapon psi amp" sent directly becomes "equip_weapon psi".
//   <name>   run psi\<name>.cmd (a discipline script, which draws the amp itself)
// Inline casts (<id>o / <id>q) never draw the amp: without an arm step the amp must already be in hand.
const PSI_CHAIN_POLL_S = 0.05;
const PSI_CHAIN_TIMEOUT_MS = 5000;  // longest a cast may take before the chain gives up
const PSI_REFIRE_MS = 500;          // the psi amp's Shot Interval
// set psi_auto_hypo 1            before each cast, use a psi hypo if psi points <= max - PsiHypoRestore()
// set psi_auto_hypo_wait_ms 500  pause after an auto hypo before the cast

// Splits "a,b, c" into ["a", "b", "c"], skipping empty entries.
function PsiSplitList(text) {
	local items = [];
	local current = "";
	foreach (ch in text) {
		local c = ch.tochar();
		if (c == "," || c == " " || c == "\t") {
			if (current.len() > 0)
				items.push(current);
			current = "";
		}
		else
			current += c;
	}
	if (current.len() > 0)
		items.push(current);
	return items;
}

// Psi points a hypo restores: 30 on Easy (Difficulty 1), 20 on Normal, Hard and Impossible,
// plus 20% with the Pharmo-Friendly O/S upgrade (36 / 24). Difficulty and trait are read the way SCP reads them.
function PsiHypoRestore() {
	local restore = Quest.Get("Difficulty") == 1 ? 30 : 20;
	if (ShockGame.HasTrait("Player", eTrait.kTraitPharmo))
		restore = (restore * 1.2).tointeger();
	return restore;
}

// "assault_rifle" -> "assault rifle" (chain steps can't contain spaces).
function PsiUnderscoresToSpaces(text) {
	local result = "";
	foreach (ch in text)
		result += ch == '_' ? " " : ch.tochar();
	return result;
}

function PsiIsDigits(text) {
	if (text.len() == 0)
		return false;
	foreach (ch in text) {
		if (ch < '0' || ch > '9')
			return false;
	}
	return true;
}

class PsiChain extends SqRootScript {
	function Say(text) {
		print("[psi_autocast] chain: " + text);
	}

	function CfgInt(name, fallback) {
		if (!Engine.ConfigIsDefined(name))
			return fallback;
		local value = int_ref();
		Engine.ConfigGetInt(name, value);
		return value.tointeger();
	}

	function OnBeginScript() {
		local list = string();
		if (Engine.ConfigIsDefined("psi_chain"))
			Engine.ConfigGetRaw("psi_chain", list);
		local steps = PsiSplitList(list.tostring());
		if (steps.len() == 0) {
			Say("psi_chain is empty, nothing to do");
			Object.Destroy(self);
			return;
		}

		SetData("Steps", list.tostring());
		SetData("Count", steps.len());
		SetData("Index", 0);
		SetData("AutoHypoFor", -1);
		SetData("CancelAt", ND.psiCancelCount);
		SetData("GapMs", CfgInt("psi_chain_gap_ms", PSI_REFIRE_MS));
		Say(steps.len() + " steps: " + list.tostring());
		// Never run commands from OnBeginScript: it runs while the chain's .cmd file is still being
		// read, and a run from here re-enters that file (endless PsiChain creation, stack overflow).
		SetOneShotTimer("ChainStart", 0.01);
	}

	function Step(index) {
		return PsiSplitList(GetData("Steps"))[index];
	}

	function IsWaitStep(step) {
		return step.len() > 1 && step.slice(0, 1) == "w" && PsiIsDigits(step.slice(1));
	}

	function IsInlineCast(step) {
		if (step.len() < 2)
			return false;
		local mode = step.slice(step.len() - 1);
		return (mode == "o" || mode == "q") && PsiIsDigits(step.slice(0, step.len() - 1));
	}

	// True when psi_auto_hypo is on, this step casts, it hasn't already had its hypo,
	// and psi points are at or below max minus what a hypo restores.
	function AutoHypoDue(index) {
		if (CfgInt("psi_auto_hypo", 0) == 0 || GetData("AutoHypoFor") == index)
			return false;
		local step = Step(index);
		if (step == "arm" || step == "hypo" || step == "last" || IsWaitStep(step)
			|| (step.len() > 7 && step.slice(0, 7) == "weapon:"))
			return false;
		return ShockGame.GetPlayerPsiPoints() <= ShockGame.GetPlayerMaxPsiPoints() - PsiHypoRestore();
	}

	function Stop(reason) {
		Say(reason + ", stopping");
		Object.Destroy(self);
	}

	function StartStep() {
		local index = GetData("Index");
		local step = Step(index);
		local label = "step " + (index + 1) + "/" + GetData("Count") + ": ";

		if (step == "arm") {
			if (PsiAmpInHand()) {
				Say(label + "arm - psi amp already in hand");
				SetOneShotTimer("ChainNext", 0.01);
			}
			else {
				local drawMs = CfgInt("psi_draw_ms", 800);
				Say(label + "arm - drawing the psi amp, waiting " + drawMs + "ms");
				PsiRememberWeapon();
				Debug.Command("run psi\\actions\\Arm_Psi_Amp.cmd");
				SetOneShotTimer("ChainNext", drawMs / 1000.0);
			}
			return;
		}

		if (step == "hypo") {
			Say(label + "use psi hypo");
			Debug.Command("run psi\\actions\\Use_Psi_Hypo.cmd");
			SetOneShotTimer("ChainNext", 0.01);
			return;
		}

		if (step == "last") {
			Say(label + PsiSwitchToRememberedWeapon());
			SetOneShotTimer("ChainNext", 0.01);
			return;
		}

		if (step.len() > 7 && step.slice(0, 7) == "weapon:") {
			local weapon = step.slice(7);
			Say(label + "switch to " + PsiUnderscoresToSpaces(weapon));
			Debug.Command("run psi\\actions\\Switch_To_" + weapon + ".cmd");
			SetOneShotTimer("ChainNext", 0.01);
			return;
		}

		if (IsWaitStep(step)) {
			local waitMs = step.slice(1).tointeger();
			Say(label + "wait " + waitMs + "ms");
			SetOneShotTimer("ChainNext", waitMs / 1000.0);
			return;
		}

		// Auto psi hypo: top up before a cast when a hypo can't be wasted.
		if (AutoHypoDue(index)) {
			local points = ShockGame.GetPlayerPsiPoints();
			local maxPoints = ShockGame.GetPlayerMaxPsiPoints();
			local waitMs = CfgInt("psi_auto_hypo_wait_ms", PSI_REFIRE_MS);
			local restore = PsiHypoRestore();
			Say(label + "psi " + points + "/" + maxPoints + " is at or below " + (maxPoints - restore)
				+ " (max - " + restore + ", what a hypo restores on this difficulty"
				+ (ShockGame.HasTrait("Player", eTrait.kTraitPharmo) ? " with Pharmo-Friendly" : "")
				+ "), using a psi hypo first, then waiting " + waitMs + "ms");
			Debug.Command("run psi\\actions\\Use_Psi_Hypo.cmd");
			SetData("AutoHypoFor", index);
			SetOneShotTimer("ChainRetry", waitMs / 1000.0);
			return;
		}

		SetData("ReleasedBefore", ND.psiCastsReleased);
		SetData("WaitedMs", 0);

		if (IsInlineCast(step)) {
			local power = step.slice(0, step.len() - 1).tointeger();
			local quickfire = step.slice(step.len() - 1) == "q";
			if (!(power in ND.psiDisciplines))
				return Stop(label + "there's no discipline " + power);
			if (!PsiAmpInHand())
				return Stop(label + "the psi amp isn't in hand (add an arm step first)");
			local discipline = ND.psiDisciplines[power];
			Say(label + discipline.name + (quickfire ? " (quickfire)" : " (overload if it helps)"));
			ND.psiPendingCast = {
				power = power,
				mode = quickfire ? 0 : 1,
				benefits = discipline.benefits != 0,
				name = discipline.name + (quickfire ? "_Quickfire" : "")
			};
			Object.Create("PsiCast");
		}
		else {
			Say(label + step);
			Debug.Command("run psi\\" + step + ".cmd");
		}
		SetOneShotTimer("ChainPoll", PSI_CHAIN_POLL_S);
	}

	function OnTimer() {
		local name = message().name;
		if (ND.psiCancelCount != GetData("CancelAt"))
			return Stop("cancelled at step " + (GetData("Index") + 1) + "/" + GetData("Count"));
		if (name == "ChainStart" || name == "ChainRetry") {
			StartStep();
		}
		else if (name == "ChainPoll") {
			if (ND.psiCastsReleased > GetData("ReleasedBefore")) {
				// An explicit wait step after this cast replaces the default gap.
				local next = GetData("Index") + 1;
				local explicitWait = next < GetData("Count") && IsWaitStep(Step(next));
				SetOneShotTimer("ChainNext", explicitWait ? 0.01 : GetData("GapMs") / 1000.0);
				return;
			}
			local waited = GetData("WaitedMs") + (PSI_CHAIN_POLL_S * 1000).tointeger();
			if (waited > PSI_CHAIN_TIMEOUT_MS)
				return Stop("step " + (GetData("Index") + 1) + " (" + Step(GetData("Index")) + ") never released");
			SetData("WaitedMs", waited);
			SetOneShotTimer("ChainPoll", PSI_CHAIN_POLL_S);
		}
		else if (name == "ChainNext") {
			local next = GetData("Index") + 1;
			if (next >= GetData("Count")) {
				Say("done");
				Object.Destroy(self);
				return;
			}
			SetData("Index", next);
			StartStep();
		}
	}
}

ND.Archetype("PsiCast", "ND", function(){ AddScript("PsiCast"); });
ND.Archetype("PsiChain", "ND", function(){ AddScript("PsiChain"); });
ND.Archetype("PsiCancel", "ND", function(){ AddScript("PsiCancel"); });
ND.Archetype("PsiPreviousWeapon", "ND", function(){ AddScript("PsiPreviousWeapon"); });

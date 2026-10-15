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
// fraction of the bar set by pre-overload PSI. Releasing after the bar is full is burnout.

const PSI_QUICKFIRE_MS = 100;
const PSI_SAFETY_MS = 50;           // minimum distance kept from both edges of the overload zone
const PSI_ZONE_AIM = 0.1;           // aim this far into the zone, as a fraction of its width
const PSI_VISIBLE_MS = 50;          // extra hold so the bar is visibly in the yellow before release

// Bar fill time in seconds, tiers 1-5.
PSI_BAR_SECONDS <- [2.0, 1.5, 1.0, 0.75, 0.4];
// Overload zone start as a fraction of the bar, pre-overload PSI 1-8.
PSI_ZONE_START <- [1.0, 0.94, 0.85, 0.73, 0.58, 0.4, 0.19, 0.01];

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

	// Unverified reading: PsiPowerDesc / PsiPower2Desc as bit sets of learned disciplines.
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
		local startMs = (PSI_ZONE_START[psi - 1] * barMs).tointeger();
		local basis = "tier " + tier + ", pre-overload PSI " + psi
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
		local power = CfgInt("psi_power", 0);
		local slot = CfgInt("psi_slot", 6);
		local mode = CfgInt("psi_mode", 0);
		local benefits = CfgInt("psi_benefits", 0) != 0;
		local name = CfgText("psi_name", power > 0 ? "discipline " + power : "quick slot " + slot);

		local impliedTier = power > 0 ? power / 8 + 1 : 0;
		local tier = CfgInt("psi_tier", impliedTier > 0 ? impliedTier : 1);
		if (impliedTier > 0 && impliedTier != tier) {
			Say(name + ": psi_tier " + tier + " doesn't match discipline " + power + " (tier " + impliedTier + "), using tier " + impliedTier);
			tier = impliedTier;
		}
		tier = tier < 1 ? 1 : (tier > 5 ? 5 : tier);

		local psi = ShockGame.GetStat("Player", eStats.kStatPsi);
		psi = psi < 1 ? 1 : (psi > 8 ? 8 : psi);

		if (power > 0 && !SeemsLearned(power))
			Say(name + ": warning - this discipline may not be learned yet");

		local weapon = ShockGame.Equipped(0);
		local ampInHand = weapon != 0 && Object.InheritsFrom(weapon, Object.Named("Psi Amp"));
		local waitMs = ampInHand ? 10 : CfgInt("psi_draw_ms", 800);

		SetData("Power", power);
		SetData("Slot", slot);
		SetData("HoldMs", ChooseHold(name, mode, tier, psi, benefits));
		SetOneShotTimer("PsiSelect", waitMs / 1000.0);
	}

	function OnTimer() {
		local name = message().name;
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

// PsiChain: casts several disciplines in a row from one key.
//   set psi_chain T2_Localized_Pyrokinesis,T1_Projected_Cryokinesis   discipline scripts in psi\, comma-separated
//   set psi_chain_gap_ms 700                                          pause after each release before the next cast
//   summon_obj PsiChain
// Each step runs its discipline script, so it draws, quickfires or overloads by that script's own rules.
const PSI_CHAIN_POLL_S = 0.05;
const PSI_CHAIN_TIMEOUT_MS = 5000;  // longest a step may take before the chain gives up

// Splits "a,b, c" into ["a", "b", "c"], skipping empty entries.
function PsiSplitList(text) {
	local items = [];
	local current = "";
	foreach (ch in text) {
		local c = ch.tochar();
		if (c == "," || c == " " || c == "	") {
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

class PsiChain extends SqRootScript {
	function Say(text) {
		print("[psi_autocast] chain: " + text);
	}

	function OnBeginScript() {
		local list = string();
		if (Engine.ConfigIsDefined("psi_chain"))
			Engine.ConfigGetRaw("psi_chain", list);
		local steps = PsiSplitList(list.tostring());
		if (steps.len() == 0) {
			Say("psi_chain is empty, nothing to cast");
			Object.Destroy(self);
			return;
		}

		local gap = int_ref();
		local gapMs = 700;
		if (Engine.ConfigIsDefined("psi_chain_gap_ms")) {
			Engine.ConfigGetInt("psi_chain_gap_ms", gap);
			gapMs = gap.tointeger();
		}

		SetData("Steps", list.tostring());
		SetData("Count", steps.len());
		SetData("Index", 0);
		SetData("GapMs", gapMs);
		Say(steps.len() + " casts, " + gapMs + "ms between them");
		StartStep();
	}

	function StepName(index) {
		return PsiSplitList(GetData("Steps"))[index];
	}

	function StartStep() {
		local index = GetData("Index");
		SetData("ReleasedBefore", ND.psiCastsReleased);
		SetData("WaitedMs", 0);
		Say("step " + (index + 1) + "/" + GetData("Count") + ": " + StepName(index));
		Debug.Command("run psi\\" + StepName(index) + ".cmd");
		SetOneShotTimer("ChainPoll", PSI_CHAIN_POLL_S);
	}

	function OnTimer() {
		local name = message().name;
		if (name == "ChainPoll") {
			if (ND.psiCastsReleased > GetData("ReleasedBefore")) {
				SetOneShotTimer("ChainNext", GetData("GapMs") / 1000.0);
				return;
			}
			local waited = GetData("WaitedMs") + (PSI_CHAIN_POLL_S * 1000).tointeger();
			if (waited > PSI_CHAIN_TIMEOUT_MS) {
				Say("step " + (GetData("Index") + 1) + " never released, stopping (check that psi\\" + StepName(GetData("Index")) + ".cmd exists)");
				Object.Destroy(self);
				return;
			}
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

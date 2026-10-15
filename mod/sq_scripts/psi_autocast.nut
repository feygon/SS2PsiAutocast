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
		local holdMs = startMs + (aimMs > PSI_SAFETY_MS ? aimMs : PSI_SAFETY_MS);
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
			Object.Destroy(self);
		}
	}
}

ND.Archetype("PsiCast", "ND", function(){ AddScript("PsiCast"); });

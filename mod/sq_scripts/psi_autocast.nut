// psi_autocast: one-key psi casting.
//
// A key's .cmd file sets these config values, summons a PsiCast helper, then equips the amp:
//   set psi_slot 6          quick slot holding the power (Shift+F6 sets slot 6)
//   set psi_draw_ms 800     wait for the amp to come up, if it isn't already in hand
//   set psi_release_ms 100  how long fire is held: ~100 = normal cast, longer = overload
//   summon_obj PsiCast
//   equip_weapon psi amp
//
// Summon the helper BEFORE equip_weapon so it can see whether the amp was already out.
// The helper selects the slot, presses fire, releases it after the hold time, then deletes itself.
// It exists because .cmd files cannot pause: a press and release in the same frame cancels the cast.

class PsiCast extends SqRootScript {
	function Cfg(name, fallback) {
		if (!Engine.ConfigIsDefined(name))
			return fallback;
		local value = int_ref();
		Engine.ConfigGetInt(name, value);
		return value.tointeger();
	}

	function OnBeginScript() {
		local slot = Cfg("psi_slot", 6);
		local drawMs = Cfg("psi_draw_ms", 800);
		local releaseMs = Cfg("psi_release_ms", 100);

		local weapon = ShockGame.Equipped(0);
		local ampInHand = weapon != 0 && Object.InheritsFrom(weapon, Object.Named("Psi Amp"));
		local waitMs = ampInHand ? 10 : drawMs;

		SetData("Slot", slot);
		SetData("ReleaseMs", releaseMs);
		Debug.MPrint("[psi_autocast] slot " + slot + ", amp in hand: " + ampInHand + ", wait " + waitMs + "ms, hold " + releaseMs + "ms");
		SetOneShotTimer("PsiSelect", waitMs / 1000.0);
	}

	function OnTimer() {
		local name = message().name;
		if (name == "PsiSelect") {
			Debug.Command("quickuse " + GetData("Slot"));
			Debug.Command("fire_weapon 1");
			SetOneShotTimer("PsiRelease", GetData("ReleaseMs") / 1000.0);
		}
		else if (name == "PsiRelease") {
			Debug.Command("fire_weapon 0");
			Debug.MPrint("[psi_autocast] released");
			Object.Destroy(self);
		}
	}
}

ND.Archetype("PsiCast", "ND", function(){ AddScript("PsiCast"); });

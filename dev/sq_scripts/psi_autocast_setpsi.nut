// psi_autocast_setpsi: developer-only. Sets the player's base PSI. Not part of release builds.
//
//   set psi_set_value 6
//   summon_obj PsiSetPsi
//
// The change is permanent in the current game: quicksave first and reload to undo it.

class PsiSetPsi extends SqRootScript {
	function OnBeginScript() {
		SetOneShotTimer("SetPsi", 0.01);
	}

	function OnTimer() {
		if (message().name != "SetPsi")
			return;
		if (!Engine.ConfigIsDefined("psi_set_value")) {
			print("[psi_setpsi] set psi_set_value first, e.g. 'set psi_set_value 6'");
		}
		else {
			local value = int_ref();
			Engine.ConfigGetInt("psi_set_value", value);
			local oldPsi = Property.Get("Player", "BaseStatsDesc", "PSI");
			Property.Set("Player", "BaseStatsDesc", "PSI", value.tointeger());
			ShockGame.RecalcStats("Player");
			print("[psi_setpsi] base PSI " + oldPsi + " -> " + value.tointeger()
				+ ", effective PSI now " + ShockGame.GetStat("Player", eStats.kStatPsi));
		}
		Object.Destroy(self);
	}
}

ND.Archetype("PsiSetPsi", "ND", function(){ AddScript("PsiSetPsi"); });

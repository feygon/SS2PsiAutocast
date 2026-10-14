// psi_autocast_probe: developer-only overload measurement. Not part of release builds.
//
// Summon with:  summon_obj PsiProbe   (amp drawn or not; it waits for the draw first)
// It casts each step below, logs whether it overloaded, raises base PSI by 1, then repeats.
// Results go to the console and kexengine.log as "[psi_probe]" lines.
// The PSI increase is permanent in the current game: quicksave first and reload afterwards to undo it.

// Overload successes are counted by subscribing to the remaster's player core, which forwards
// the player's OverloadSuccess message to subscribers. (The player's four script slots are full,
// so a script of our own can't be attached to it.)
ND.psiProbeOverloads <- 0;

class PsiOverloadCounter {
	m_name = "PsiOverloadCounter";

	function OnOverloadSuccess(message) {
		ND.psiProbeOverloads++;
	}
}

ND.psiProbeCounter <- PsiOverloadCounter();
ND.g_PlayerCore.Subscribe(ND.psiProbeCounter, "OverloadSuccess");

const PROBE_DRAW_MS = 800;    // first cast waits for the amp to come up
const PROBE_SETTLE_MS = 2500; // after each release: let the cast finish before checking and casting again

class PsiProbe extends SqRootScript {
	// [quick slot, hold ms]
	static Steps = [[6, 1500], [6, 1550], [7, 1500], [7, 1550]];

	function Log(text) {
		print("[psi_probe] " + text);
	}

	function PsiSummary() {
		return "PSI " + ShockGame.GetStat("Player", eStats.kStatPsi)
			+ " (base " + Property.Get("Player", "BaseStatsDesc", "PSI") + ")"
			+ ", psi points " + ShockGame.GetPlayerPsiPoints();
	}

	function OnBeginScript() {
		SetData("Round", 1);
		SetData("Step", 0);
		Log("start - " + PsiSummary());
		SetOneShotTimer("Cast", PROBE_DRAW_MS / 1000.0);
	}

	function RaisePsi() {
		local oldPsi = Property.Get("Player", "BaseStatsDesc", "PSI");
		Property.Set("Player", "BaseStatsDesc", "PSI", oldPsi + 1);
		ShockGame.RecalcStats("Player");
		Log("raised base PSI " + oldPsi + " -> " + (oldPsi + 1) + " - " + PsiSummary());
	}

	function OnTimer() {
		local name = message().name;
		local step = GetData("Step");
		local current = Steps[step];

		if (name == "Cast") {
			SetData("Before", ND.psiProbeOverloads);
			Log("round " + GetData("Round") + ", slot " + current[0] + ", holding " + current[1] + "ms - " + PsiSummary());
			Debug.Command("quickuse " + current[0]);
			Debug.Command("fire_weapon 1");
			SetOneShotTimer("Release", current[1] / 1000.0);
		}
		else if (name == "Release") {
			Debug.Command("fire_weapon 0");
			SetOneShotTimer("Check", PROBE_SETTLE_MS / 1000.0);
		}
		else if (name == "Check") {
			local overloaded = ND.psiProbeOverloads > GetData("Before");
			Log("RESULT round " + GetData("Round") + ", slot " + current[0] + ", " + current[1] + "ms: "
				+ (overloaded ? "OVERLOAD" : "no overload") + " - " + PsiSummary());

			if (step + 1 < Steps.len()) {
				SetData("Step", step + 1);
				SetOneShotTimer("Cast", 0.01);
			}
			else if (GetData("Round") == 1) {
				RaisePsi();
				SetData("Round", 2);
				SetData("Step", 0);
				SetOneShotTimer("Cast", 0.5);
			}
			else {
				Log("done");
				Object.Destroy(self);
			}
		}
	}
}

ND.Archetype("PsiProbe", "ND", function(){ AddScript("PsiProbe"); });

// psi_autocast: one-key psi casting.
// A key's run file selects a power, presses fire, then summons one of these
// helpers. The helper waits, releases fire (which casts), and deletes itself.
//
// PsiAutoCast        - releases after 0.1s: a normal cast.
// PsiAutoOverload    - releases after PSI_AUTOOVERLOAD_DELAY: aims for the overload window.
// PsiOverload090..150 - fixed delays (0.90s to 1.50s) for finding the window;
//                      swap the name in a .cmd file, no restart needed.

const PSI_AUTOCAST_DELAY = 0.1;
const PSI_AUTOOVERLOAD_DELAY = 1.05;

class PsiAutoRelease extends SqRootScript {
	function Delay() { return PSI_AUTOCAST_DELAY; }

	function OnBeginScript() {
		Debug.MPrint("[psi_autocast] armed, releasing in " + Delay() + "s");
		SetOneShotTimer("PsiRelease", Delay());
	}

	function OnTimer() {
		if (message().name != "PsiRelease")
			return;
		Debug.Command("fire_weapon 0");
		Debug.MPrint("[psi_autocast] released");
		Object.Destroy(self);
	}
}

class PsiAutoCast extends PsiAutoRelease {
}

class PsiAutoOverload extends PsiAutoRelease {
	function Delay() { return PSI_AUTOOVERLOAD_DELAY; }
}

class PsiOverload090 extends PsiAutoRelease { function Delay() { return 0.90; } }
class PsiOverload100 extends PsiAutoRelease { function Delay() { return 1.00; } }
class PsiOverload110 extends PsiAutoRelease { function Delay() { return 1.10; } }
class PsiOverload120 extends PsiAutoRelease { function Delay() { return 1.20; } }
class PsiOverload130 extends PsiAutoRelease { function Delay() { return 1.30; } }
class PsiOverload140 extends PsiAutoRelease { function Delay() { return 1.40; } }
class PsiOverload150 extends PsiAutoRelease { function Delay() { return 1.50; } }

// Draw-then-cast: the key's run file equips the psi amp and summons one of these.
// After the amp has had time to come up, it runs the cast file.
class PsiDrawThenRun extends SqRootScript {
	function Delay() { return 0.8; }
	function CastFile() { return "psi_cryo_cast.cmd"; }

	function OnBeginScript() {
		Debug.MPrint("[psi_autocast] drawing amp, casting in " + Delay() + "s");
		SetOneShotTimer("PsiDrawn", Delay());
	}

	function OnTimer() {
		if (message().name != "PsiDrawn")
			return;
		Debug.MPrint("[psi_autocast] run " + CastFile());
		Debug.Command("run " + CastFile());
		Object.Destroy(self);
	}
}

class PsiDraw080 extends PsiDrawThenRun { function Delay() { return 0.8; } }
class PsiDraw100 extends PsiDrawThenRun { function Delay() { return 1.0; } }
class PsiDraw120 extends PsiDrawThenRun { function Delay() { return 1.2; } }


// PsiCast: the general-purpose helper. The key's .cmd file sets these, then summons it:
//   set psi_slot 6          quick slot holding the power (Shift+F6 sets slot 6)
//   set psi_draw_ms 800     wait for the amp to come up, if it isn't already in hand
//   set psi_release_ms 100  how long fire is held: ~100 = normal cast, longer = overload
// Summon it BEFORE equip_weapon so it can see whether the amp was already out.
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


ND.Archetype("PsiAutoCast", "ND", function(){ AddScript("PsiAutoCast"); });
ND.Archetype("PsiAutoOverload", "ND", function(){ AddScript("PsiAutoOverload"); });
ND.Archetype("PsiOverload090", "ND", function(){ AddScript("PsiOverload090"); });
ND.Archetype("PsiOverload100", "ND", function(){ AddScript("PsiOverload100"); });
ND.Archetype("PsiOverload110", "ND", function(){ AddScript("PsiOverload110"); });
ND.Archetype("PsiOverload120", "ND", function(){ AddScript("PsiOverload120"); });
ND.Archetype("PsiOverload130", "ND", function(){ AddScript("PsiOverload130"); });
ND.Archetype("PsiOverload140", "ND", function(){ AddScript("PsiOverload140"); });
ND.Archetype("PsiOverload150", "ND", function(){ AddScript("PsiOverload150"); });
ND.Archetype("PsiDraw080", "ND", function(){ AddScript("PsiDraw080"); });
ND.Archetype("PsiDraw100", "ND", function(){ AddScript("PsiDraw100"); });
ND.Archetype("PsiDraw120", "ND", function(){ AddScript("PsiDraw120"); });
ND.Archetype("PsiCast", "ND", function(){ AddScript("PsiCast"); });

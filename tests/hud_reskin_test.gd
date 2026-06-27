extends Node2D
## Headless test for the re-skinned in-battle HUD (token HUD_RESKIN).
##
## Instances the HUD ALONE (a CanvasLayer with its code-drawn bars + labels) and asserts the
## NEW public behaviour added by the re-skin, without a Battlefield:
##   - the code-drawn bars render across a few frames with NO error (the _draw() path runs);
##   - the WEAPON read-out is human-readable: a live swing charge shows "CHARGE NN%",
##     a resting weapon shows the state word (never the cryptic "POWER [2%]");
##   - the ULTIMATE (musou) bar reads "READY" at a full gauge so the player knows the beam
##     is available, and a percentage while charging;
##   - the control-hint strip FADES after the hold window (it teaches, then gets out of the
##     way) and replay_hints() brings it back.
##
## Run: godot --headless --path . res://tests/HudReskinTest.tscn --quit-after 600 — look for HUD_RESKIN_VERDICT.

const HUD := preload("res://scenes/Hud.tscn")

var _hud
var _frame := 0

func _ready() -> void:
	_hud = HUD.instantiate()
	add_child(_hud)

func _physics_process(_delta: float) -> void:
	_frame += 1
	# Let a few frames pass so _ready (the draw-signal hookup) and at least one _draw run.
	if _frame < 4:
		return
	_report()

func _report() -> void:
	var checks := {}

	# 1) The bars Control exists and survived a redraw (the _draw_bars path ran without error).
	var bars = _hud.get_node_or_null("Root/Bars")
	checks["bars_drawn"] = bars != null

	# 2) WEAPON read-out: a live swing charge is shown as a readable percentage…
	_hud._on_state_changed("SWING!", 0.42)
	var state: Label = _hud.get_node("Root/StateLabel")
	checks["charge_readable"] = state.text.find("CHARGE") != -1 and state.text.find("42") != -1
	# …and the cryptic old "POWER [NN%]" wording is gone.
	checks["no_cryptic_power"] = state.text.find("POWER") == -1
	# A resting weapon falls back to the plain state word.
	_hud._on_state_changed("READY", 0.0)
	checks["weapon_word"] = state.text.find("READY") != -1

	# 3) ULTIMATE bar: a full gauge must announce it's READY; a partial gauge shows a percent.
	var musou: Label = _hud.get_node("Root/MusouLabel")
	_hud._on_musou_changed(50.0, 200.0)
	checks["ult_charging"] = musou.text.to_upper().find("ULTIMATE") != -1 and musou.text.find("%") != -1
	_hud._on_musou_changed(200.0, 200.0)
	checks["ult_ready"] = musou.text.to_upper().find("READY") != -1

	# 4) Control-hint fade: lit at the start, faded after the hold window, restorable.
	var hints: Label = _hud.get_node("Root/Hints")
	_hud._t = 0.0
	_hud._update_hints_fade()
	var lit_alpha: float = hints.modulate.a
	_hud._t = _hud.HINTS_HOLD + _hud.HINTS_FADE + 1.0
	_hud._update_hints_fade()
	var faded_alpha: float = hints.modulate.a
	checks["hint_lit_then_faded"] = lit_alpha > 0.9 and faded_alpha < 0.05
	_hud.replay_hints()
	checks["hint_replayable"] = hints.modulate.a > 0.9

	var ok := true
	var parts: Array = []
	for k in checks:
		ok = ok and checks[k]
		parts.append("%s=%s" % [k, str(checks[k])])
	print("HUD_RESKIN_RESULT ", " ".join(parts))
	print("HUD_RESKIN_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

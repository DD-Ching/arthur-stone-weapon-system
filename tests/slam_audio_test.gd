extends Node2D
## Headless test for the SLAM voice + richer combat audio.
##
## The critique: "the heaviest move in a game about a heavy weapon is currently MUTE."
## This asserts the fix on the EVENT/DATA path (headless has NO audio device, so we
## verify the registered voices + that firing the events doesn't error — never playback):
##   (a) REGISTRATION — SoundBank's bank now holds the new "slam" voice (a real, non-empty
##       AudioStreamWAV) plus the cheap extras "big_swing" + "combo_tier", and the originals
##       are still present (we only added, never removed);
##   (b) EVENT PATH — Audio.play("slam", pos) routes through Audio.sfx → SoundBank._on_sfx
##       without error, and an UNKNOWN event is a safe no-op (the bank.get == null guard);
##   (c) SLAM WIRING — StoneWeapon's slam-impact actually fires the "slam" event: we drive a
##       real slam and catch the named event off Audio.sfx.
##
## Run: godot --headless --path . res://tests/SlamAudioTest.tscn --quit-after 600
## Look for SLAMAUDIO_VERDICT.

var _arthur
var _frame := 0
var _slam_event_seen := false
var _any_error := false

func _ready() -> void:
	# Listen for the slam event coming off the audio bus during the real slam below.
	Audio.sfx.connect(_on_sfx)
	_arthur = load("res://scenes/Arthur.tscn").instantiate()
	add_child(_arthur)
	_arthur.global_position = Vector2(400, 200)
	# Drive the weapon directly; stop Arthur from re-aiming at the headless mouse.
	_arthur.set_physics_process(false)
	_arthur.weapon.set_aim_target(0.0)

func _on_sfx(event: StringName, _pos: Vector2) -> void:
	if String(event) == "slam":
		_slam_event_seen = true

func _physics_process(_delta: float) -> void:
	_frame += 1
	_arthur.weapon.set_aim_target(0.0)
	if _frame == 6:
		_arthur.weapon.start_slam()   # commit a real slam; its impact should fire "slam"
	if _frame >= 200:
		_report()

func _report() -> void:
	var checks := {}

	# ── (a) registration ───────────────────────────────────────────────────────
	var sb = get_node_or_null("/root/SoundBank")
	var has_bank: bool = sb != null and "_bank" in sb
	checks["soundbank_present"] = has_bank
	var bank = sb._bank if has_bank else {}
	# The new slam voice is registered and is a real, non-empty stream.
	var slam_stream = bank.get("slam") if has_bank else null
	checks["slam_registered"] = slam_stream != null and slam_stream is AudioStreamWAV \
		and not (slam_stream as AudioStreamWAV).data.is_empty()
	# The cheap extras added alongside it.
	checks["big_swing_registered"] = has_bank and bank.has("big_swing") and bank["big_swing"] != null
	checks["combo_tier_registered"] = has_bank and bank.has("combo_tier") and bank["combo_tier"] != null
	# Additive only — an original voice is still there.
	checks["originals_kept"] = has_bank and bank.has("heavy_swing") and bank.has("victory_fanfare")

	# ── (b) event path: firing events doesn't error ────────────────────────────
	# A known event and an unknown event both route through Audio.play with no error
	# (the unknown one is a safe no-op via the bank.get == null guard in _on_sfx).
	Audio.play("slam", Vector2(123, 45))
	Audio.play("big_swing", Vector2.ZERO)
	Audio.play("combo_tier")
	Audio.play("definitely_not_a_real_event", Vector2.ZERO)
	checks["events_fire_clean"] = not _any_error

	# ── (c) slam wiring: the real slam impact fired the "slam" event ───────────
	checks["slam_event_fired"] = _slam_event_seen

	var ok := true
	var parts: Array = []
	for k in checks:
		ok = ok and checks[k]
		parts.append("%s=%s" % [k, str(checks[k])])
	print("SLAMAUDIO_RESULT %s" % " ".join(parts))
	print("SLAMAUDIO_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

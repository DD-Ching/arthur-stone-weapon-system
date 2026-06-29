extends Node2D
## Difficulty probe (token DIFFPROBE) — a deterministic regression guard for the difficulty rebalance,
## so the game can't silently drift back to "too easy". It checks the LEVERS that make the horde a
## real threat (rather than an emergent AI fight, which is too noisy to assert a stable number on):
##   1. i-frames are SHORT but real — a single attacker still can't chain-melt (a hit during the
##      window is rejected), yet once the window passes the NEXT hit lands, so a CROWD stacks damage
##      over time (the i-frame wall that capped the whole army at ~27 dps is gone);
##   2. getting hit no longer floods the ult gauge (musou_hurt_gain small);
##   3. the ult is a positioned reset, not a screen-wipe (smaller radius + lower dmg-mult + a cooldown);
##   4. enemy melee damage is buffed so a crowd genuinely hurts;
##   5. the boss SIGNATURE moves exist (per-boss differentiation).
##
## Run: godot --headless --path . res://tests/DifficultyProbeTest.tscn --quit-after 600 — look for DIFFPROBE_VERDICT.

const ARTHUR := preload("res://scenes/Arthur.tscn")

var _arthur
var _frame := 0
var _hp0 := 0.0
var _hp1 := 0.0
var _hp2 := 0.0
var _hp3 := 0.0
var _first := false
var _blocked := true
var _third := false

func _ready() -> void:
	Impact.reset()
	_arthur = ARTHUR.instantiate()
	add_child(_arthur)
	_arthur.global_position = Vector2.ZERO
	_arthur.set_physics_process(false)   # drive damage directly — no AI/physics noise

func _physics_process(_dt: float) -> void:
	_frame += 1
	if _frame == 2:
		_hp0 = _arthur.health
		_first = _arthur.take_damage(10.0, Vector2(0.0, -50.0))    # lands
		_hp1 = _arthur.health
		_blocked = _arthur.take_damage(10.0, Vector2(0.0, -50.0))  # rejected by i-frames (single attacker can't chain)
		_hp2 = _arthur.health
		_arthur._invuln = 0.0                                       # i-frame window passes (a crowd keeps coming)
		_third = _arthur.take_damage(10.0, Vector2(0.0, -50.0))     # lands again
		_hp3 = _arthur.health
	elif _frame >= 4:
		_report()

func _report() -> void:
	var checks := {}
	# (1) i-frames: first lands, the immediate repeat is blocked, the post-window hit lands again.
	checks["first_lands"] = _first and _hp1 <= _hp0 - 9.0
	checks["iframe_blocks"] = (not _blocked) and is_equal_approx(_hp2, _hp1)
	checks["crowd_stacks_over_time"] = _third and _hp3 <= _hp2 - 9.0
	checks["short_iframes"] = _arthur.invuln_time <= 0.32          # was 0.45 — the master "can't lose" lever
	# (2) suffering doesn't charge the win button.
	checks["small_hurt_gain"] = _arthur.musou_hurt_gain <= 8.0
	# (3) the ult is a positioned reset, not a screen-wipe, and is on a real cooldown.
	checks["ult_tamed"] = Arthur.MUSOU_DAMAGE_MULT <= 3.0 and Arthur.MUSOU_RADIUS_MAX <= 760.0 \
		and Arthur.MUSOU_COOLDOWN >= 8.0
	# (4) enemy melee is buffed so a crowd hurts.
	checks["enemy_damage_up"] = float(AbilityLibrary.TABLE["pound"]["aoe_damage"]) >= 18.0 \
		and float(AbilityLibrary.TABLE["thrust"]["damage"]) >= 12.0
	# (5) the boss signature catalogue exists (per-boss differentiation).
	checks["boss_signatures"] = AbilityLibrary.TABLE.has("charge") and AbilityLibrary.TABLE.has("whirlwind") \
		and AbilityLibrary.TABLE.has("ground_quake") and AbilityLibrary.TABLE.has("spell_bolt") \
		and AbilityLibrary.TABLE.has("hex_nova")

	var ok := true
	var parts: Array = []
	for k in checks:
		ok = ok and checks[k]
		parts.append("%s=%s" % [k, str(checks[k])])
	print("DIFFPROBE_RESULT %s" % " ".join(parts))
	print("DIFFPROBE_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

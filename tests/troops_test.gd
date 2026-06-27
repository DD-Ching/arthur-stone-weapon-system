extends Node2D
## Headless test for the five Three-Kingdoms troop configs (token TROOPS). Each troop is a
## PURE .tscn config of scripts/Enemy.gd — no new scripts, no edits to the shared base:
##   scenes/troops/Halberdier.tscn     — Wei reach line (spear / thrust + bash)
##   scenes/troops/Crossbow.tscn       — Wei slow long-range single-shot (spear / javelin)
##   scenes/troops/ShockTrooper.tscn   — Wei heavy breaker (heavy / bash + lunge)
##   scenes/troops/Drummer.tscn        — Shu war-drum morale support (banner, no attack)
##   scenes/troops/StandardBearer.tscn — Wu morale support (banner, no attack)
##
## This proves the contract that lets a troop type be data alone:
##   - GROUPS:   every troop joins "raiders" + "targets" on _ready; the SUPPORT troops
##               (is_support, raider team) also join "officers" (the DefeatOfficer group).
##   - MOVESET:  each ATTACKING troop builds one Ability per id in its `moves`
##               (Enemy._abilities is non-empty) so the data-driven brain has real moves.
##   - BEHAVES:  placed near a foe and stepped a few physics frames, each acts without error.
##   - DAMAGE:   apply_hit(dir, big, 0.2, 50.0, 0.0) reduces each ATTACKING troop's health.
##               The SUPPORT troops carry no attack — for them we assert presence + support
##               role instead (they are morale anchors, not punching bags).
##
## Run: godot --headless --path . res://tests/TroopsTest.tscn --quit-after 600
## Look for the TROOPS_VERDICT line.

# name → {path, expected move ids (empty = support, no moveset), support?}
const SPECS := {
	"Halberdier":     {"path": "res://scenes/troops/Halberdier.tscn",     "moves": ["thrust", "bash"], "support": false},
	"Crossbow":       {"path": "res://scenes/troops/Crossbow.tscn",       "moves": ["javelin"],        "support": false},
	"ShockTrooper":   {"path": "res://scenes/troops/ShockTrooper.tscn",   "moves": ["bash", "lunge"],  "support": false},
	"Drummer":        {"path": "res://scenes/troops/Drummer.tscn",        "moves": [],                 "support": true},
	"StandardBearer": {"path": "res://scenes/troops/StandardBearer.tscn", "moves": [],                 "support": true},
}

var _troops := {}     ## name → instance
var _foe              ## an ally for the attacking troops to engage (drives the brain)
var _checks := {}
var _frame := 0

func _ready() -> void:
	# A lone ally the raiders can target, so the attacking troops have a foe and exercise
	# the move-selection / steering paths while we step physics.
	_foe = _spawn_dummy("ally", Vector2(140.0, 0.0))

	var y := -200.0
	for name in SPECS:
		var spec: Dictionary = SPECS[name]
		var t = load(spec["path"]).instantiate()
		t.team = "raiders"          # set before add_child so _ready() joins the right groups
		t.ai_enabled = true         # let the brain run so we prove it acts without error
		add_child(t)
		t.global_position = Vector2(-60.0, y)
		_troops[name] = t
		y += 100.0

		# GROUPS — every troop is hittable, on the raider team, and a "target".
		_checks["%s_in_raiders" % name] = t.is_in_group("raiders")
		_checks["%s_in_targets" % name] = t.is_in_group("targets")

		if spec["support"]:
			# SUPPORT troops (Drummer / Standard Bearer): morale anchors. They must be flagged
			# is_support and counted among the officers the DefeatOfficer objective hunts.
			_checks["%s_is_support" % name] = bool(t.is_support)
			_checks["%s_in_officers" % name] = t.is_in_group("officers")
			# Support troops now also DEFEND themselves — every minion can attack (a ranged bolt
			# from their standoff distance), so they carry a built moveset too.
			_checks["%s_armed" % name] = not (t._abilities as Array).is_empty()
		else:
			# ATTACKING troops: the data-driven brain built exactly one Ability per move id, in order.
			var built: Array = t._abilities
			var ids: Array = []
			for ab in built:
				ids.append(ab.id)
			_checks["%s_moves_built" % name] = ids == spec["moves"]

	print("TROOPS_READY ok")

func _physics_process(_delta: float) -> void:
	_frame += 1
	# Let each troop's brain tick against the foe for a few frames — attacking ones pick moves
	# and steer, supports hold their morale spacing — and assert nothing errors out.
	if _frame == 40:
		for name in _troops:
			var t = _troops[name]
			_checks["%s_alive_after_steps" % name] = is_instance_valid(t) and not t._dead

		# DAMAGE — a solid hit must reduce (or defeat) each ATTACKING troop's health; they are
		# real, killable raiders. Supports may carry heavy health and exist only to rally — for
		# them the presence + support-role checks above stand in for the damage check.
		for name in _troops:
			var spec: Dictionary = SPECS[name]
			if spec["support"]:
				_checks["%s_exists" % name] = is_instance_valid(_troops[name])
				continue
			var t = _troops[name]
			var h0: float = t.health
			t.apply_hit(Vector2.RIGHT, 200.0, 0.2, 50.0, 0.0)
			var hurt: bool = t.health < h0 or t._dead
			_checks["%s_takes_damage" % name] = hurt
		_report()

func _spawn_dummy(team: String, pos: Vector2):
	var n = load("res://scenes/TargetDummy.tscn").instantiate()
	n.team = team
	n.ai_enabled = false
	add_child(n)
	n.global_position = pos
	return n

func _report() -> void:
	var ok := true
	var parts: Array = []
	for k in _checks:
		ok = ok and _checks[k]
		parts.append("%s=%s" % [k, str(_checks[k])])
	print("TROOPS_RESULT ", " ".join(parts))
	print("TROOPS_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

extends Node2D
## Headless test for the five Arthurian troop configs (token ARTHURTROOPS). Each is a PURE
## .tscn config of scripts/Enemy.gd — no new scripts, no edits to the shared base:
##   scenes/arthur/Merlin.tscn       — Camelot wizard counsel (banner, no attack, big morale aura)
##   scenes/arthur/SaxonRaider.tscn  — Saxon fast melee raider (soldier / slash + lunge)
##   scenes/arthur/SaxonAxeman.tscn  — Saxon heavy axe breaker (heavy / bash + pound)
##   scenes/arthur/BritonLevy.tscn   — Camelot militia footman (soldier / slash)
##   scenes/arthur/BritonArcher.tscn — Camelot ranged archer (spear / javelin, big keep_distance)
##
## This proves the contract that lets an Arthurian unit be data alone:
##   - GROUPS:   a "raiders" unit joins "raiders" + "targets"; an "ally" unit joins "ally" +
##               "allies". Merlin (a support ALLY) is is_support and NOT in "officers" (that group
##               is only for SUPPORT RAIDERS, per Enemy._ready).
##   - MOVESET:  each ATTACKING unit builds one Ability per id in its `moves`, in order
##               (Enemy._abilities), so the data-driven brain has real moves.
##   - BEHAVES:  placed near a foe and stepped a few physics frames, each acts without error.
##   - DAMAGE:   apply_hit(dir, big, 0.2, 50.0, 0.0) reduces each NON-SUPPORT unit's health.
##               Merlin (the support) carries no attack — presence + support-role checks stand in.
##
## Run: godot --headless --path . res://tests/ArthurTroopsTest.tscn --quit-after 600
## Look for the ARTHURTROOPS_VERDICT line.

# name → {path, team, expected move ids (empty = support, no moveset), support?}
const SPECS := {
	"Merlin":       {"path": "res://scenes/arthur/Merlin.tscn",       "team": "ally",    "moves": [],                 "support": true},
	"SaxonRaider":  {"path": "res://scenes/arthur/SaxonRaider.tscn",  "team": "raiders", "moves": ["slash", "lunge"], "support": false},
	"SaxonAxeman":  {"path": "res://scenes/arthur/SaxonAxeman.tscn",  "team": "raiders", "moves": ["bash", "pound"],  "support": false},
	"BritonLevy":   {"path": "res://scenes/arthur/BritonLevy.tscn",   "team": "ally",    "moves": ["slash"],          "support": false},
	"BritonArcher": {"path": "res://scenes/arthur/BritonArcher.tscn", "team": "ally",    "moves": ["javelin"],        "support": false},
}

var _units := {}      ## name → instance
var _raider_foe       ## an ally for raiders to engage
var _ally_foe         ## a raider for allies to engage
var _checks := {}
var _frame := 0

func _ready() -> void:
	# Two lone dummies so BOTH sides have a foe to engage and exercise move-selection / steering.
	_raider_foe = _spawn_dummy("ally", Vector2(160.0, 0.0))     # raiders hunt this
	_ally_foe = _spawn_dummy("raiders", Vector2(-160.0, 0.0))   # allies hunt this

	var y := -240.0
	for name in SPECS:
		var spec: Dictionary = SPECS[name]
		var u = load(spec["path"]).instantiate()
		# team is authored in the .tscn; ai_enabled isn't, so turn the brain on to prove it acts.
		u.ai_enabled = true
		add_child(u)
		u.global_position = Vector2(0.0, y)
		_units[name] = u
		y += 100.0

		# GROUPS — team decides the targeting groups: raiders→targets, ally→allies.
		_checks["%s_in_team" % name] = u.is_in_group(spec["team"])
		if spec["team"] == "raiders":
			_checks["%s_in_targets" % name] = u.is_in_group("targets")
			_checks["%s_not_allies" % name] = not u.is_in_group("allies")
		else:
			_checks["%s_in_allies" % name] = u.is_in_group("allies")
			_checks["%s_not_targets" % name] = not u.is_in_group("targets")

		if spec["support"]:
			# Merlin: a support ALLY. Flagged is_support, but NOT an "officer" (that group is only
			# for support RAIDERS the DefeatOfficer objective hunts), and carries no attack moveset.
			_checks["%s_is_support" % name] = bool(u.is_support)
			_checks["%s_not_officer" % name] = not u.is_in_group("officers")
			_checks["%s_no_moveset" % name] = (u._abilities as Array).is_empty()
		else:
			# ATTACKING units: the data-driven brain built exactly one Ability per move id, in order.
			var built: Array = u._abilities
			var ids: Array = []
			for ab in built:
				ids.append(ab.id)
			_checks["%s_moves_built" % name] = ids == spec["moves"]

	print("ARTHURTROOPS_READY ok")

func _physics_process(_delta: float) -> void:
	_frame += 1
	# Let each brain tick against its foe for a few frames — attackers pick moves and steer,
	# Merlin holds its morale spacing — and assert nothing errors out.
	if _frame == 40:
		for name in _units:
			var u = _units[name]
			_checks["%s_alive_after_steps" % name] = is_instance_valid(u) and not u._dead

		# DAMAGE — a solid hit must reduce (or defeat) each NON-SUPPORT unit's health; they are
		# real, killable combatants. Merlin (support) carries no attack and exists only to rally,
		# so for it the presence + support-role checks above stand in for the damage check.
		for name in _units:
			var spec: Dictionary = SPECS[name]
			if spec["support"]:
				_checks["%s_exists" % name] = is_instance_valid(_units[name])
				continue
			var u = _units[name]
			var h0: float = u.health
			u.apply_hit(Vector2.RIGHT, 200.0, 0.2, 50.0, 0.0)
			var hurt: bool = u.health < h0 or u._dead
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
	print("ARTHURTROOPS_RESULT ", " ".join(parts))
	print("ARTHURTROOPS_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

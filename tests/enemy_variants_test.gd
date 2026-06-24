extends Node2D
## Headless test for the three new raider variants (unit #10, token VARIANTS):
##   scenes/Archer.tscn   — ranged harasser (spear / javelin, holds keep_distance)
##   scenes/Brute.tscn    — heavy mini-boss (heavy / pound + bash, high HP + stagger wall)
##   scenes/Outrider.tscn — fast flanker (soldier / lunge + slash)
##
## Each variant is a PURE .tscn config of scripts/Enemy.gd — no new scripts. This test
## proves the contract that makes that possible:
##   - GROUPS:    each instance joins the raider groups ("raiders" + "targets") on _ready;
##   - MOVESET:   each builds one Ability per id in its `moves` (Enemy._abilities), so the
##                data-driven brain has real moves to choose from (no silent fallback);
##   - BEHAVES:   placed near a foe and stepped a few physics frames, each acts without error;
##   - DAMAGE:    apply_hit(dir, strength, 0.2, 50.0, 0.0) reduces each variant's health
##                (they are real, killable raiders — not invulnerable dummies).
##
## Run: godot --headless --path . res://tests/EnemyVariantsTest.tscn --quit-after 600
## Look for the VARIANTS_VERDICT line.

# id → {path, expected move ids}. The move list mirrors each .tscn's `moves` export.
const SPECS := {
	"Archer":   {"path": "res://scenes/Archer.tscn",   "moves": ["javelin"]},
	"Brute":    {"path": "res://scenes/Brute.tscn",    "moves": ["pound", "bash"]},
	"Outrider": {"path": "res://scenes/Outrider.tscn", "moves": ["lunge", "slash"]},
}

var _variants := {}     ## name → instance
var _foe                ## an ally for the variants to engage (drives the brain without error)
var _checks := {}
var _frame := 0

func _ready() -> void:
	# A lone ally the raiders can target, so their AI has a foe and exercises the move
	# selection / steering paths while we step physics.
	_foe = _spawn_dummy("ally", Vector2(120.0, 0.0))

	var y := -120.0
	for name in SPECS:
		var spec: Dictionary = SPECS[name]
		var v = load(spec["path"]).instantiate()
		v.team = "raiders"          # set before add_child so _ready() joins the right groups
		v.ai_enabled = true         # let the brain run so we prove it acts without error
		add_child(v)
		v.global_position = Vector2(-40.0, y)
		_variants[name] = v
		y += 120.0

		# GROUPS — every raider variant must be hittable, on its team, and a "target".
		_checks["%s_in_raiders" % name] = v.is_in_group("raiders")
		_checks["%s_in_targets" % name] = v.is_in_group("targets")

		# MOVESET — the data-driven brain built exactly one Ability per move id, in order.
		var built: Array = v._abilities
		var ids: Array = []
		for ab in built:
			ids.append(ab.id)
		_checks["%s_moves_built" % name] = ids == spec["moves"]

	print("VARIANTS_READY ok")

func _physics_process(_delta: float) -> void:
	_frame += 1
	# Let each variant's brain tick against the foe for a few frames — picking moves,
	# steering, holding spacing (Archer) — and assert nothing errors out.
	if _frame == 40:
		for name in _variants:
			var v = _variants[name]
			_checks["%s_alive_after_steps" % name] = is_instance_valid(v) and not v._dead

		# DAMAGE — a solid hit must reduce (or defeat) each variant's health. These are
		# real raiders, not invulnerable dummies, so apply_hit chips them.
		for name in _variants:
			var v = _variants[name]
			var h0: float = v.health
			v.apply_hit(Vector2.RIGHT, 200.0, 0.2, 50.0, 0.0)
			var hurt: bool = v.health < h0 or v._dead
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
	print("VARIANTS_RESULT ", " ".join(parts))
	print("VARIANTS_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

extends Node2D
## Headless test for the Knights of the Round Table (Camelot's champions, token KNIGHTS):
##   scenes/knights/Lancelot.tscn — greatest knight (lunge / slash / thrust)
##   scenes/knights/Gawain.tscn   — strength-of-the-sun bruiser (slash / bash)
##   scenes/knights/Percival.tscn — pure young knight (thrust / lunge)
##   scenes/knights/Bedivere.tscn — steadfast shield guardian (bash, shielded)
##
## Each knight is a PURE .tscn config of scripts/Enemy.gd — no new scripts. This test
## proves the contract that makes them deployable Camelot allies:
##   - GROUPS:    each instance joins the ally groups ("ally" + "allies") on _ready;
##   - FACTION:   each reads as Camelot (faction == "camelot");
##   - MOVESET:   each builds one Ability per id in its `moves` (Enemy._abilities), so the
##                data-driven brain has real moves to choose from (no silent fallback);
##   - BEHAVES:   placed near a raider foe and stepped a few physics frames, each acts
##                without error (the brain picks moves / steers / guards);
##   - DAMAGE:    apply_hit(dir, big, 0.2, 50.0, 0.0) reduces each knight's health (they
##                are real, killable champions — not invulnerable dummies).
##
## Run: godot --headless --path . res://tests/KnightsTest.tscn --quit-after 600
## Look for the KNIGHTS_VERDICT line.

# name → {path, expected move ids}. The move list mirrors each .tscn's `moves` export.
const SPECS := {
	"Lancelot": {"path": "res://scenes/knights/Lancelot.tscn", "moves": ["lunge", "slash", "thrust"]},
	"Gawain":   {"path": "res://scenes/knights/Gawain.tscn",   "moves": ["slash", "bash"]},
	"Percival": {"path": "res://scenes/knights/Percival.tscn", "moves": ["thrust", "lunge"]},
	"Bedivere": {"path": "res://scenes/knights/Bedivere.tscn", "moves": ["bash"]},
}

var _knights := {}      ## name → instance
var _foe                ## a raider for the knights to engage (drives the brain without error)
var _checks := {}
var _frame := 0

func _ready() -> void:
	# A lone raider the knights can target, so their AI has a foe and exercises the move
	# selection / steering / guard paths while we step physics.
	_foe = _spawn_dummy("raiders", Vector2(120.0, 0.0))

	var y := -180.0
	for name in SPECS:
		var spec: Dictionary = SPECS[name]
		var k = load(spec["path"]).instantiate()
		add_child(k)                 # _ready() joins the ally groups from the .tscn's team
		k.global_position = Vector2(-40.0, y)
		_knights[name] = k
		y += 120.0

		# GROUPS — every knight is an ALLY: hittable, on the "ally" team, in "allies".
		_checks["%s_in_ally" % name] = k.is_in_group("ally")
		_checks["%s_in_allies" % name] = k.is_in_group("allies")

		# FACTION — each reads as a Camelot champion.
		_checks["%s_faction_camelot" % name] = k.faction == "camelot"

		# MOVESET — the data-driven brain built exactly one Ability per move id, in order.
		var built: Array = k._abilities
		var ids: Array = []
		for ab in built:
			ids.append(ab.id)
		_checks["%s_moves_built" % name] = ids == spec["moves"]

	print("KNIGHTS_READY ok")

func _physics_process(_delta: float) -> void:
	_frame += 1
	# Let each knight's brain tick against the raider foe for a few frames — picking moves,
	# steering, guarding (Bedivere) — and assert nothing errors out.
	if _frame == 40:
		for name in _knights:
			var k = _knights[name]
			_checks["%s_alive_after_steps" % name] = is_instance_valid(k) and not k._dead

		# DAMAGE — a solid hit must reduce (or defeat) each knight's health. These are real
		# champions, not invulnerable dummies, so apply_hit chips them.
		for name in _knights:
			var k = _knights[name]
			var h0: float = k.health
			k.apply_hit(Vector2.RIGHT, 2000.0, 0.2, 50.0, 0.0)
			var hurt: bool = k.health < h0 or k._dead
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
	print("KNIGHTS_RESULT ", " ".join(parts))
	print("KNIGHTS_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

extends Node2D
## Headless test for the Arthurian VILLAIN GENERALS (boss-tier ENEMIES), token VILLAINS:
##   scenes/villains/Mordred.tscn      — the arch-traitor (rebel knight); General.gd war-cry brain
##   scenes/villains/BlackKnight.tscn  — the Black Knight (neutral heavy); General.gd war-cry brain
##   scenes/villains/SaxonWarlord.tscn — Cerdic the Saxon warlord (heavy); plain Enemy.gd config
##   scenes/villains/MorganLeFay.tscn  — Morgan le Fay (rebel sorceress); is_support officer, no melee
##
## Each villain is a boss-tier ENEMY built on the shared Enemy base (the two strongest via the
## General.gd subclass for a signature war-cry). This test proves the boss contract:
##   - GROUPS:   each joins "generals" (so the boss health-bar UI can find it) AND the raider
##               groups "raiders" + "targets" on _ready; Morgan also joins "officers" (is_support);
##   - BOSS HP:  each has a high max_health (>= 300) — a real boss, not fodder;
##   - MOVESET:  a config with `moves` builds one Ability per id (Enemy._abilities, in order) and
##               acts without error near a foe; Morgan has NO moves — asserted is_support instead;
##   - DAMAGE:   apply_hit(dir, big, 0.2, 60.0, 0.0) reduces each villain's health (mortal bosses).
##
## Run: godot --headless --path . res://tests/VillainsTest.tscn --quit-after 600
## Look for the VILLAINS_VERDICT line.

# name → scene path. Move expectations are read from each instance's own `moves` export, so this
# stays correct even if a config is retuned (it asserts moves → _abilities, in order).
const SPECS := {
	"Mordred":      "res://scenes/villains/Mordred.tscn",
	"BlackKnight":  "res://scenes/villains/BlackKnight.tscn",
	"SaxonWarlord": "res://scenes/villains/SaxonWarlord.tscn",
	"MorganLeFay":  "res://scenes/villains/MorganLeFay.tscn",
}
const MIN_BOSS_HP := 300.0

var _villains := {}     ## name → instance
var _foe                ## a lone ally for the bosses to engage (drives the brain without error)
var _checks := {}
var _frame := 0

func _ready() -> void:
	# A lone ally the raider-bosses can target, so their AI has a foe and exercises the
	# move-selection / steering (and, for General.gd, the war-cry) paths while we step physics.
	_foe = _spawn_dummy("ally", Vector2(120.0, 0.0))

	var y := -180.0
	for name in SPECS:
		var path: String = SPECS[name]
		var g = load(path).instantiate()
		g.ai_enabled = true          # let the brain run so we prove it acts without error
		add_child(g)
		g.global_position = Vector2(-40.0, y)
		_villains[name] = g
		y += 120.0

		# GROUPS — every villain is a boss the UI can find AND a raider target.
		_checks["%s_in_generals" % name] = g.is_in_group("generals")
		_checks["%s_in_raiders" % name] = g.is_in_group("raiders")
		_checks["%s_in_targets" % name] = g.is_in_group("targets")

		# BOSS HP — a real boss-tier pool, not fodder.
		_checks["%s_boss_hp" % name] = g.max_health >= MIN_BOSS_HP

		# MOVESET vs. SUPPORT — a config with `moves` builds one Ability per id, in order. A
		# support villain (Morgan) may have NO moves; for her we assert is_support + "officers".
		if g.moves.size() > 0:
			var ids: Array = []
			for ab in g._abilities:
				ids.append(ab.id)
			var want: Array = []
			for m in g.moves:
				want.append(m)
			_checks["%s_moves_built" % name] = ids.size() > 0 and ids == want
		else:
			_checks["%s_support" % name] = g.is_support and g.is_in_group("officers")

	print("VILLAINS_READY ok")

func _physics_process(_delta: float) -> void:
	_frame += 1
	# Let each boss's brain tick against the foe for a few frames — picking moves, steering,
	# and (for the General.gd bosses) sounding the war-cry — and assert nothing errors out.
	if _frame == 40:
		for name in _villains:
			var g = _villains[name]
			_checks["%s_alive_after_steps" % name] = is_instance_valid(g) and not g._dead

		# DAMAGE — a solid hit must reduce (or defeat) each boss's health. Bosses are mortal.
		for name in _villains:
			var g = _villains[name]
			var h0: float = g.health
			g.apply_hit(Vector2.RIGHT, 200.0, 0.2, 60.0, 0.0)
			var hurt: bool = g.health < h0 or g._dead
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
	print("VILLAINS_RESULT ", " ".join(parts))
	print("VILLAINS_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

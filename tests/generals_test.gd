extends Node2D
## Headless test for the named Generals (boss warlords), unit token GENERALS:
##   scenes/generals/LuBu.tscn      — Octa, a Saxon warlord; General.gd war-cry brain
##   scenes/generals/GuanYu.tscn    — Colgrin, a Saxon knight; plain Enemy.gd config
##   scenes/generals/ZhangFei.tscn  — Baldulf, a Saxon heavy; General.gd war-cry brain
##   scenes/generals/XiahouDun.tscn — Drust, a Pict heavy; plain Enemy.gd config
##
## Each general is a boss-tier unit built on the shared Enemy base (some via the
## General.gd subclass for a signature war-cry). This test proves the boss contract:
##   - GROUPS:   each instance joins "generals" (so the boss health-bar UI can find it)
##               AND the raider groups "targets" + "raiders" on _ready;
##   - BOSS HP:  each has a high max_health (>= 200) — a real boss, not fodder;
##   - MOVESET:  each builds one Ability per id in its `moves` (Enemy._abilities), so the
##               data-driven brain has real moves (and acts without error near a foe);
##   - DAMAGE:   apply_hit(dir, big, 0.2, 60.0, 0.0) reduces each general's health (they
##               are mortal bosses, not invulnerable dummies).
##
## Run: godot --headless --path . res://tests/GeneralsTest.tscn --quit-after 600
## Look for the GENERALS_VERDICT line.

# name → scene path. Move expectations are read from each instance's own `moves` export,
# so this stays correct even if a config is retuned (it asserts moves → _abilities, in order).
const SPECS := {
	"Octa":    "res://scenes/generals/LuBu.tscn",
	"Colgrin": "res://scenes/generals/GuanYu.tscn",
	"Baldulf": "res://scenes/generals/ZhangFei.tscn",
	"Drust":   "res://scenes/generals/XiahouDun.tscn",
}
const MIN_BOSS_HP := 200.0

var _generals := {}     ## name → instance
var _foe                ## a lone ally for the bosses to engage (drives the brain without error)
var _checks := {}
var _frame := 0

func _ready() -> void:
	# A lone ally the raider-bosses can target, so their AI has a foe and exercises the
	# move-selection / steering (and, for General.gd, the war-cry) paths while we step physics.
	_foe = _spawn_dummy("ally", Vector2(120.0, 0.0))

	var y := -160.0
	for name in SPECS:
		var path: String = SPECS[name]
		var g = load(path).instantiate()
		g.ai_enabled = true          # let the brain run so we prove it acts without error
		add_child(g)
		g.global_position = Vector2(-40.0, y)
		_generals[name] = g
		y += 110.0

		# GROUPS — every general is a boss the UI can find AND a raider target.
		_checks["%s_in_generals" % name] = g.is_in_group("generals")
		_checks["%s_in_raiders" % name] = g.is_in_group("raiders")
		_checks["%s_in_targets" % name] = g.is_in_group("targets")

		# BOSS HP — a real boss-tier pool, not fodder.
		_checks["%s_boss_hp" % name] = g.max_health >= MIN_BOSS_HP

		# MOVESET — the data-driven brain built one Ability per move id, in order.
		var ids: Array = []
		for ab in g._abilities:
			ids.append(ab.id)
		var want: Array = []
		for m in g.moves:
			want.append(m)
		_checks["%s_moves_built" % name] = ids.size() > 0 and ids == want

	print("GENERALS_READY ok")

func _physics_process(_delta: float) -> void:
	_frame += 1
	# Let each boss's brain tick against the foe for a few frames — picking moves, steering,
	# and (for the General.gd bosses) sounding the war-cry — and assert nothing errors out.
	if _frame == 40:
		for name in _generals:
			var g = _generals[name]
			_checks["%s_alive_after_steps" % name] = is_instance_valid(g) and not g._dead

		# DAMAGE — a solid hit must reduce (or defeat) each boss's health. Bosses are mortal.
		for name in _generals:
			var g = _generals[name]
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
	print("GENERALS_RESULT ", " ".join(parts))
	print("GENERALS_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

extends Node2D
## Headless test for the archer-volley raiders (token ARCHERVOLLEY).
##
## scenes/villains/SaxonArcher.tscn is a PURE .tscn config of scripts/Enemy.gd with
## moves = ["javelin"] — a ranged harasser that holds its keep_distance band and lobs
## the shared Javelin projectile. This test proves the volley actually fires and that
## the concurrent-projectile count stays sane (the Javelin self-frees, so a swarm of
## archers can never flood the scene with shafts):
##   - FIRES:   spawn a few ai_enabled SaxonArchers + a target within sight_range, step
##              physics, and assert at least one "Javelin" node appears in the scene
##              (the brain picked the javelin move + Ability spawned the projectile);
##   - BOUNDED: the peak number of live Javelin nodes at any one frame stays under a
##              sane cap (< 30), proving they expire instead of piling up forever.
##
## Run: godot --headless --path . res://tests/ArcherVolleyTest.tscn --quit-after 600
## Look for the ARCHERVOLLEY_VERDICT line.

const SAXON_ARCHER := "res://scenes/villains/SaxonArcher.tscn"
const TARGET := "res://scenes/TargetDummy.tscn"

var _archers: Array = []
var _target
var _frame := 0
var _saw_javelin := false      ## did at least one Javelin projectile ever appear?
var _peak_javelins := 0        ## the most live Javelin nodes seen in a single frame

func _ready() -> void:
	# A lone ally the raider archers can target, parked inside their sight_range so the
	# brain engages and reaches for the javelin move immediately.
	_target = load(TARGET).instantiate()
	_target.team = "ally"
	_target.ai_enabled = false
	_target.max_health = 1.0e9        # a punching bag — it must survive the whole volley
	add_child(_target)
	_target.global_position = Vector2(260.0, 0.0)

	# A few archers spread out, each within sight of the target so they all start firing.
	var ys: Array = [-80.0, 0.0, 80.0]
	for y in ys:
		var a = load(SAXON_ARCHER).instantiate()
		a.team = "raiders"            # set before add_child so _ready() joins the right groups
		a.ai_enabled = true
		add_child(a)
		a.global_position = Vector2(-120.0, y)
		_archers.append(a)
	print("ARCHERVOLLEY_READY archers=%d" % _archers.size())

func _physics_process(_delta: float) -> void:
	_frame += 1
	# Count the live Javelin projectiles this frame. Ability spawns them into the current
	# scene (this test's root), so we scan our own children for the projectile type.
	var live := _count_javelins()
	if live > 0:
		_saw_javelin = true
	_peak_javelins = maxi(_peak_javelins, live)
	# Give the archers time to wind up + throw a few volleys, then report.
	if _frame >= 120:
		_report()

## Count Javelin nodes currently in the scene (added by Ability._throw_javelin as
## children of the current scene — this test's root).
func _count_javelins() -> int:
	var n := 0
	for child in get_children():
		if child is Javelin:
			n += 1
	return n

func _report() -> void:
	var fires_ok := _saw_javelin
	var bounded_ok := _peak_javelins < 30
	var ok := fires_ok and bounded_ok
	print("ARCHERVOLLEY_RESULT fires=%s bounded=%s peak_javelins=%d" % [
		str(fires_ok), str(bounded_ok), _peak_javelins])
	print("ARCHERVOLLEY_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

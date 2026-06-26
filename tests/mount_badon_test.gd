extends Node2D
## Test for Mount Badon (Mons Badonicus) — the Briton hilltop last-stand map — plus the
## reusable Survive + HoldLine objective composition it ships.
##
## (a) OBJECTIVE LOGIC — the composed win/lose reads the ctx the BattleMap base provides:
##       - SurviveObjective(75, 90): wins on EITHER the clock (time>=75) OR the body count
##         (kos>=90). We assert the time bar and the KO bar each resolve it.
##       - HoldLineObjective: a constraint — it only ever FAILS (breaches>=max), never "done".
## (b) The map BOOTS — a thin BattleMap subclass instantiates Arthur + the HUD, and pours its
##     first Saxon wave so the field has live targets (group "targets" > 0 → the horde is here).
## (c) The map WINS by holding the hill — its SurviveObjective is set short in-test, and after
##     enough elapsed time the base resolves to `_won`. We loop-kill the climbing Saxons each
##     frame so none crest the hill (no breach loss) — a clean hold to the clock.
##
## Run: godot --headless --path . res://tests/MountBadonTest.tscn --quit-after 600
## Look for BADON_VERDICT.

var _map
var _frame := 0
var _spawned_seen := false

# (a) pure-logic checks, run immediately in _ready (no scene needed).
var _obj_time_ok := false
var _obj_ko_ok := false
var _obj_holdline_ok := false

func _ready() -> void:
	# (a) SurviveObjective — the timed bar wins (KO bar off so the WIN is unambiguously time).
	var timed := SurviveObjective.new(0.5, 0)
	timed.evaluate({"time": 0.0, "kos": 0})
	var not_done_yet: bool = not timed.is_done()
	timed.evaluate({"time": 1.0, "kos": 0})
	var done_on_time: bool = timed.is_done()
	_obj_time_ok = not_done_yet and done_on_time

	# (a) SurviveObjective — the body-count bar wins even at time 0.
	var counted := SurviveObjective.new(0.0, 3)
	counted.evaluate({"time": 0.0, "kos": 3})
	_obj_ko_ok = counted.is_done()

	# (a) HoldLineObjective — a constraint: it FAILS when the breach budget is spent, and never
	# reports "done" (the hill can only fall, never be "completed" by holding).
	var line := HoldLineObjective.new()
	line.evaluate({"breaches": 0, "max_breaches": 4})
	var holds_while_under: bool = not line.is_failed() and not line.is_done()
	line.evaluate({"breaches": 4, "max_breaches": 4})
	var fails_when_overrun: bool = line.is_failed() and not line.is_done()
	_obj_holdline_ok = holds_while_under and fails_when_overrun

	# (b)/(c) Boot the real map. Force a SHORT survival so (c) can resolve to a win in-test.
	_map = _ShortBadon.new()
	add_child(_map)

func _physics_process(_dt: float) -> void:
	_frame += 1
	if _frame == 12:
		# The base should have spawned its first Saxon wave on its first scan.
		_spawned_seen = get_tree().get_nodes_in_group("targets").size() > 0
	# Loop-kill the climbing Saxons every frame so none crest the hill — keep the hold clean
	# (no breach loss) so the short survival clock is what resolves the win.
	for e in get_tree().get_nodes_in_group("targets"):
		if is_instance_valid(e):
			e.apply_hit(Vector2.DOWN, 6000.0, 0.1, 1.0e9, 0.0)
	if _frame >= 240:
		_report()

func _report() -> void:
	var has_arthur: bool = _map.arthur != null and is_instance_valid(_map.arthur)
	var has_hud: bool = _map.hud != null
	var won: bool = _map._won
	var ok: bool = _obj_time_ok and _obj_ko_ok and _obj_holdline_ok and has_arthur and has_hud \
		and _spawned_seen and won
	print("BADON_RESULT obj_time=%s obj_ko=%s obj_holdline=%s arthur=%s hud=%s spawned=%s won=%s kos=%d" % [
		str(_obj_time_ok), str(_obj_ko_ok), str(_obj_holdline_ok), str(has_arthur), str(has_hud),
		str(_spawned_seen), str(won), Impact.kills])
	print("BADON_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

## The real Mount Badon map, but with a SHORT survival window so the headless test can watch
## it reach victory by outlasting the clock (the loop-kill keeps any Saxon from cresting the
## hill, so the breach constraint never trips — the WIN is unambiguously the survival bar).
class _ShortBadon extends MountBadon:
	func _init() -> void:
		super()
		survive_seconds = 2.0
		ko_target = 0          # disable the KO bar so the WIN is unambiguously the time bar
		wave_interval = 1.0
		density = 1.0

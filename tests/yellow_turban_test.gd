extends Node2D
## Test for the Yellow Turban Rebellion (黃巾之亂) survival map + the reusable SurviveObjective.
##
## (a) SurviveObjective LOGIC — the "endure" objective wins on EITHER bar:
##       - survive_seconds=0.5: ctx {time:0.0} → not done; ctx {time:1.0} → done (the clock).
##       - ko_target=3:         ctx {kos:3}   → done (the body-count), even at time 0.
## (b) The map BOOTS — a thin BattleMap subclass instantiates Arthur + the HUD, and pours its
##     first rebel wave so the field has live targets (group "targets" > 0 → the mob is here).
## (c) The map WINS by survival — its SurviveObjective is set short, and after enough elapsed
##     time the base resolves to `_won` (no officer, no breach — pure last-stand).
##
## Run: godot --headless --path . res://tests/YellowTurbanTest.tscn --quit-after 600
## Look for YELLOWTURBAN_VERDICT.

var _map
var _frame := 0
var _spawned_seen := false

# (a) pure-logic checks, run immediately in _ready (no scene needed).
var _obj_time_ok := false
var _obj_ko_ok := false

func _ready() -> void:
	# (a) SurviveObjective — the timed bar.
	var timed := SurviveObjective.new(0.5, 0)        # win on time only (ko bar off)
	timed.evaluate({"time": 0.0, "kos": 0})
	var not_done_yet: bool = not timed.is_done()
	timed.evaluate({"time": 1.0, "kos": 0})
	var done_on_time: bool = timed.is_done()
	_obj_time_ok = not_done_yet and done_on_time

	# (a) SurviveObjective — the body-count bar wins even at time 0.
	var counted := SurviveObjective.new(0.0, 3)      # win on KO only (time bar off)
	counted.evaluate({"time": 0.0, "kos": 3})
	_obj_ko_ok = counted.is_done()

	# (b)/(c) Boot the real map. Force a SHORT survival so (c) can resolve to a win in-test.
	_map = _ShortSurviveYellowTurban.new()
	add_child(_map)

func _physics_process(_dt: float) -> void:
	_frame += 1
	if _frame == 12:
		# The base should have spawned its first horde wave on its first scan.
		_spawned_seen = get_tree().get_nodes_in_group("targets").size() > 0
	if _frame >= 220:
		_report()

func _report() -> void:
	var has_arthur: bool = _map.arthur != null and is_instance_valid(_map.arthur)
	var has_hud: bool = _map.hud != null
	var won: bool = _map._won
	var ok: bool = _obj_time_ok and _obj_ko_ok and has_arthur and has_hud \
		and _spawned_seen and won
	print("YELLOWTURBAN_RESULT obj_time=%s obj_ko=%s arthur=%s hud=%s spawned=%s won=%s kos=%d" % [
		str(_obj_time_ok), str(_obj_ko_ok), str(has_arthur), str(has_hud),
		str(_spawned_seen), str(won), Impact.kills])
	print("YELLOWTURBAN_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

## The real Yellow Turban map, but with a SHORT survival window so the headless test can watch
## it reach victory by outlasting the clock (no officer, no breach — pure last-stand).
class _ShortSurviveYellowTurban extends YellowTurban:
	func _init() -> void:
		super()
		survive_seconds = 2.0
		ko_target = 0          # disable the KO bar so the WIN is unambiguously the time bar

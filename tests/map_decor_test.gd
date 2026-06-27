extends Node2D
## MapDecorTest — the Changban (長坂坡) escort map must BOOT and be DRESSED, not an empty grey
## field. A thin smoke test for the `_build_decor()` placement pass this batch adds:
##
##   (1) The map instances + boots with NO parse/script error — its base orchestration runs and
##       Arthur + the HUD come up (a broken `_build_decor`/`_draw`/the super-call fix would crash
##       the boot here).
##   (2) The field has DECOR on it — banners/drums join the "decor" group and shovable crates/rocks
##       land as children, so `decor.size() > 0` AND a count of placed props > 0 (not an empty arena).
##   (3) The central RETREAT LANE is kept clear — no decor/prop sits in the central corridor
##       (|x| < lane_half) so the escort/ward path the banner flees down isn't blocked.
##
## Run: godot --headless --path . res://tests/MapDecorTest.tscn --quit-after 600
## Look for MAPDECOR_VERDICT.

const CHANGBAN := preload("res://scenes/maps/Changban.tscn")

var _map = null
var _frame := 0

# results
var _booted := false
var _has_arthur := false
var _has_hud := false
var _decor_count := 0
var _prop_count := 0
var _lane_clear := true

func _ready() -> void:
	# Light density + fast waves so the headless boot is cheap; decor is unaffected by these.
	_map = CHANGBAN.instantiate()
	_map.density = 0.2
	_map.wave_interval = 0.4
	add_child(_map)

func _physics_process(_dt: float) -> void:
	_frame += 1
	if _frame == 10:
		_inspect()
		_report()

func _inspect() -> void:
	# (1) It booted: the instance is alive and its base brought up Arthur + the HUD.
	_booted = _map != null and is_instance_valid(_map)
	_has_arthur = _booted and _map.arthur != null and is_instance_valid(_map.arthur)
	_has_hud = _booted and _map.hud != null

	# (2) Decor is on the field. Banners/drums add themselves to "decor"; the shovable Crate/Rock
	# scenery joins "props". (Spawned raiders are RigidBody2D too but join "targets", NOT "props",
	# so counting via the group keeps the head-count from mistaking enemies for scenery.)
	_decor_count = get_tree().get_nodes_in_group("decor").size()
	_prop_count = get_tree().get_nodes_in_group("props").size()

	# (3) The central RETREAT LANE is kept clear: no PLACED decor/prop sits in the central corridor
	# (|x| < lane_half). Only scenery we placed is checked — spawned raiders legitimately pour down
	# the centre, so the lane-clear assertion reads the "decor" + "props" groups, not "targets".
	var lane_half := 130.0
	var placed: Array = get_tree().get_nodes_in_group("decor")
	placed.append_array(get_tree().get_nodes_in_group("props"))
	for n in placed:
		if not (is_instance_valid(n) and n is Node2D):
			continue
		if absf((n as Node2D).global_position.x) < lane_half:
			_lane_clear = false

func _report() -> void:
	var dressed: bool = _decor_count > 0 and _prop_count > 0
	var ok: bool = _booted and _has_arthur and _has_hud and dressed and _lane_clear
	print("MAPDECOR_RESULT booted=%s arthur=%s hud=%s decor=%d props=%d lane_clear=%s" % [
		str(_booted), str(_has_arthur), str(_has_hud),
		_decor_count, _prop_count, str(_lane_clear)])
	print("MAPDECOR_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

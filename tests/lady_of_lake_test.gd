extends Node2D
## Headless test for "The Lady of the Lake" (Avalon) map + its shrine-capture win (token AVALON).
##
## Three things to prove:
##   (a) THE MAP BOOTS — the LadyOfLake scene instantiates Arthur + the HUD, places its two
##       shrines (group "bases"), and spawns its first wave of foes within the first scans.
##   (b) THE WIN RULE — it composes the reusable CaptureBasesObjective.
##   (c) THE OUTCOME — looping-kill every "targets" foe each frame (the shrine guardians + every
##       wave) clears each shrine's garrison, so both shrines capture and the map reaches
##       VICTORY (_won) well within ~450 frames.
##
## Run: godot --headless --path . res://tests/LadyOfLakeTest.tscn --quit-after 600 → AVALON_VERDICT.

const AVALON := preload("res://scenes/maps/LadyOfLake.tscn")

var _map
var _frame := 0
var _spawned_seen := false
var _has_arthur := false
var _has_hud := false
var _bases_seen := 0
var _uses_objective := false

func _ready() -> void:
	_map = AVALON.instantiate()
	# Brisk waves + density 1.0 so the loop-kill clears the field fast and deterministically.
	_map.wave_interval = 1.0
	_map.density = 1.0
	add_child(_map)
	_has_arthur = _map.arthur != null and is_instance_valid(_map.arthur)
	_has_hud = _map.hud != null
	_bases_seen = get_tree().get_nodes_in_group("bases").size()
	_uses_objective = _map._objectives != null \
		and _map._objectives.objectives.size() >= 1 \
		and _map._objectives.objectives[0] is CaptureBasesObjective
	print("AVALON_READY arthur=%s hud=%s bases=%d" % [
		str(_has_arthur), str(_has_hud), _bases_seen])

func _physics_process(_dt: float) -> void:
	_frame += 1
	# (a) The base should have spawned wave 0 within its first scans.
	if _frame == 20:
		_spawned_seen = get_tree().get_nodes_in_group("targets").size() > 0
	# (c) Loop-kill: from frame 20 on, defeat every live foe each frame so each shrine empties +
	# captures and the waves keep coming → both shrines held → victory. We wait until frame 20 so
	# the shrines' Base has scanned its guardians INSIDE the radius first (it only captures a base
	# that was ever ENGAGED) — killing them on frame 1 would leave a shrine forever un-engaged.
	if _frame >= 20 and not (_map._won or _map._lost):
		for e in get_tree().get_nodes_in_group("targets"):
			if is_instance_valid(e):
				e.apply_hit(Vector2.DOWN, 9000.0, 0.1, 1.0e9, 0.0)
	if _frame >= 240:
		_report()

func _report() -> void:
	var has_arthur: bool = _map.arthur != null and is_instance_valid(_map.arthur)
	var has_hud: bool = _map.hud != null
	var won: bool = _map._won
	var bases_ok: bool = _bases_seen >= 1
	var ok: bool = has_arthur and has_hud and _spawned_seen and bases_ok \
		and _uses_objective and won
	print("AVALON_RESULT arthur=%s hud=%s bases=%d spawned=%s obj=%s won=%s kos=%d" % [
		str(has_arthur), str(has_hud), _bases_seen, str(_spawned_seen),
		str(_uses_objective), str(won), Impact.kills])
	print("AVALON_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

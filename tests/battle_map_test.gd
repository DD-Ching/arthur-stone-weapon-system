extends Node2D
## Smoke test for the reusable BattleMap base (the Musou map foundation): a tiny subclass map
## must BOOT — instantiate Arthur + the HUD + the score screen and spawn its wave via the
## WaveSpawner — and reach VICTORY once every raider is defeated (the RepelWaves objective).
##
## Run: godot --headless --path . res://tests/BattleMapTest.tscn — look for MAP_VERDICT.

var _map
var _frame := 0
var _spawned_seen := false

func _ready() -> void:
	_map = _TestMap.new()
	add_child(_map)

func _physics_process(_dt: float) -> void:
	_frame += 1
	if _frame == 10:
		# The base should have spawned wave 0 on its first scan.
		_spawned_seen = get_tree().get_nodes_in_group("targets").size() > 0
		# Defeat every raider so the RepelWaves objective completes → the map wins.
		for e in get_tree().get_nodes_in_group("targets"):
			if is_instance_valid(e):
				e.apply_hit(Vector2.DOWN, 6000.0, 0.1, 1.0e9, 0.0)
	if _frame >= 180:
		_report()

func _report() -> void:
	var has_arthur: bool = _map.arthur != null and is_instance_valid(_map.arthur)
	var has_hud: bool = _map.hud != null
	var has_score: bool = _map._score_screen != null
	var won: bool = _map._won
	var ok: bool = has_arthur and has_hud and has_score and _spawned_seen and won
	print("MAP_RESULT arthur=%s hud=%s score=%s spawned=%s won=%s kos=%d" % [
		str(has_arthur), str(has_hud), str(has_score), str(_spawned_seen), str(won), Impact.kills])
	print("MAP_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

## A minimal concrete map: one wave of four light raiders, RepelWaves to win.
class _TestMap extends BattleMap:
	func _map_title() -> String:
		return "TEST FIELD"

	func _build_wave_spawner() -> WaveSpawner:
		var ws := WaveSpawner.new()
		var w := Wave.new()
		var arr: Array[PackedScene] = [preload("res://scenes/LightSoldier.tscn")]
		w.scenes = arr
		w.count = 4
		w.lane_y = -250.0
		w.x_min = -200.0
		w.x_max = 200.0
		w.team = "raiders"
		ws.waves = [w]
		return ws

extends Node2D
## Test for the Hu Lao Gate (虎牢關) battle map — a concrete BattleMap subclass (token HULAO).
##
## Asserts the map BOOTS (Arthur + HUD instanced), the Wei raiders SPAWN (group "targets" fills
## within a few frames), and that by clearing the field every physics frame the map drives all
## five waves + the officer down and reaches VICTORY (`_won`) inside ~400 frames — proving the
## RepelWaves + DefeatOfficer objectives compose to a win through the shared BattleMap loop.
##
## Run: godot --headless --path . res://tests/HuLaoGateTest.tscn --quit-after 600 — look for HULAO_VERDICT.

var _map: HuLaoGate
var _frame := 0
var _spawned_seen := false
var _max_alive := 0

func _ready() -> void:
	_map = HuLaoGate.new()
	# Speed the battle up for the headless test: small wave interval, no density inflation.
	_map.wave_interval = 1.0
	_map.density = 1.0
	add_child(_map)

func _physics_process(_dt: float) -> void:
	_frame += 1
	var targets := get_tree().get_nodes_in_group("targets")
	if targets.size() > 0:
		_spawned_seen = true
	_max_alive = maxi(_max_alive, targets.size())
	# Clear the field every frame so waves keep advancing and the officer wave falls.
	for e in targets:
		if is_instance_valid(e):
			e.apply_hit(Vector2.DOWN, 6000.0, 0.1, 1.0e9, 0.0)
	if _map._won or _frame >= 400:
		_report()

func _report() -> void:
	var has_arthur: bool = _map.arthur != null and is_instance_valid(_map.arthur)
	var has_hud: bool = _map.hud != null
	var won: bool = _map._won
	var ok: bool = has_arthur and has_hud and _spawned_seen and won and not _map._lost
	print("HULAO_RESULT arthur=%s hud=%s spawned=%s max_alive=%d wave=%d/%d won=%s lost=%s frame=%d kos=%d" % [
		str(has_arthur), str(has_hud), str(_spawned_seen), _max_alive,
		_map._wave, _map._wave_count(), str(won), str(_map._lost), _frame, Impact.kills])
	print("HULAO_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

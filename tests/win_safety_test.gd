extends Node2D
## Headless test for the out-of-bounds WIN-SAFETY NET (token WINSAFE) — the softlock fix.
##
## Boots a real BattleMap (Camlann), waits for raiders, then forcibly FLINGS one far outside the
## world (simulating a knockback that escapes the wall) with a huge velocity. Asserts the safety
## net (_recover_strays) hauls it back inside the bounds (or retires it) within a couple of scans —
## so the last enemy can never be stranded off-map and make the battle unwinnable.
##
## Run: godot --headless --path . res://tests/WinSafetyTest.tscn --quit-after 600 — look for WINSAFE_VERDICT.

var _map: Camlann
var _frame := 0
var _victim
var _fling_frame := -1
var _ok := false
var _done := false

func _ready() -> void:
	_map = Camlann.new()
	_map.wave_interval = 1.0
	_map.density = 1.0
	add_child(_map)

func _physics_process(_dt: float) -> void:
	_frame += 1
	if _done:
		return
	var targets := get_tree().get_nodes_in_group("targets")
	if _fling_frame < 0:
		if targets.size() > 0:
			_victim = targets[0]
			var b := _map._world_bounds()
			# Hurl it WAY out of the world with a huge velocity (a wall-escaping launch).
			_victim.global_position = b.end + Vector2(1800.0, 1800.0)
			if _victim is RigidBody2D:
				_victim.linear_velocity = Vector2(6000.0, 6000.0)
			_fling_frame = _frame
		return
	# Give the 0.15s scan a few ticks to run the safety net, then check the victim came home.
	if _frame >= _fling_frame + 40:
		var b := _map._world_bounds()
		var inside: bool = is_instance_valid(_victim) and b.grow(60.0).has_point(_victim.global_position)
		var retired: bool = (not is_instance_valid(_victim)) or (is_instance_valid(_victim) and not _victim.is_in_group("targets"))
		_ok = inside or retired
		_report(inside, retired)

func _report(inside: bool, retired: bool) -> void:
	_done = true
	print("WINSAFE_RESULT recovered=%s inside=%s retired=%s" % [str(_ok), str(inside), str(retired)])
	print("WINSAFE_VERDICT %s" % ("PASS" if _ok else "FAIL"))
	get_tree().quit(0 if _ok else 1)

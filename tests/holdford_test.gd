extends Node2D
## Headless test for the v0.8 "Hold the Ford" systems:
##   - allied footmen spawn on Arthur's side,
##   - the structured waves advance once the field is cleared,
##   - a raider that crosses the defence line is counted as a BREACH, and reaching the
##     breach cap loses the ford.
##
## Run: godot --headless --path . res://tests/HoldFordTest.tscn — look for HOLDFORD_VERDICT.

const RAIDER := preload("res://scenes/LightSoldier.tscn")

var bf
var _frame := 0
var _allies := 0
var _wave_before := 0
var _wave_after := 0
var _lost := false

func _ready() -> void:
	bf = load("res://scenes/Battlefield.tscn").instantiate()
	add_child(bf)
	bf.max_breaches = 2
	_allies = get_tree().get_nodes_in_group("allies").size()
	# Freeze the garrison so only our scripted spawns drive waves + breaches.
	for e in get_tree().get_nodes_in_group("targets"):
		e.ai_enabled = false
	_wave_before = bf._wave
	print("HOLDFORD_READY allies=%d" % _allies)

func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame == 10:
		# Clear the field → the next wave should launch on the following scan tick.
		for t in get_tree().get_nodes_in_group("targets"):
			if is_instance_valid(t):
				t.queue_free()
	elif _frame == 34:
		_wave_after = bf._wave
		# Drop two stationary raiders south of the defence line → two breaches → loss.
		for i in range(2):
			var r = RAIDER.instantiate()
			bf.add_child(r)
			r.ai_enabled = false
			r.global_position = Vector2(60.0 * i, 515.0)
	elif _frame >= 70:
		_lost = bf._lost
		_report()

func _report() -> void:
	print("HOLDFORD_RESULT allies=%d wave_before=%d wave_after=%d breaches=%d lost=%s"
		% [_allies, _wave_before, _wave_after, bf._breaches, str(_lost)])
	var ok: bool = _allies >= 1 and _wave_after > _wave_before and bf._breaches >= 1 and _lost
	print("HOLDFORD_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

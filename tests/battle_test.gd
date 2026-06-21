extends Node2D
## Headless test for the battlefield systems. Asserts:
##   - enemy AI works: a shield-wall soldier actually advances on Arthur,
##   - Arthur can be hurt: take_damage lowers his health,
##   - the wave objective resolves: with every wave repelled and the field cleared,
##     the ford holds (the battle is won).
##
## Run: godot --headless --path . res://tests/BattleTest.tscn — look for BATTLE_VERDICT.

var bf
var arthur
var _frame := 0
var _shield_start := 0.0
var _moved_closer := false
var _damaged := false
var _won := false

func _ready() -> void:
	bf = load("res://scenes/Battlefield.tscn").instantiate()
	add_child(bf)
	arthur = bf.get_node("Arthur")
	print("BATTLE_READY ok")

func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame == 5:
		var shields := get_tree().get_nodes_in_group("shieldwall")
		if shields.size() > 0:
			_shield_start = shields[0].global_position.distance_to(arthur.global_position)
	elif _frame == 70:
		var shields := get_tree().get_nodes_in_group("shieldwall")
		if shields.size() > 0 and is_instance_valid(shields[0]):
			var d: float = shields[0].global_position.distance_to(arthur.global_position)
			_moved_closer = d < _shield_start - 8.0
		# Arthur takes a hit (clear i-frames first so the forced hit always lands).
		arthur._invuln = 0.0
		var h0: float = arthur.health
		arthur.take_damage(20.0, Vector2(0, -100))
		_damaged = arthur.health < h0
		# Drive the wave objective to completion: mark all waves repelled and clear the
		# field — the ford should then be held (a win).
		bf._wave = 99
		for t in get_tree().get_nodes_in_group("targets"):
			if is_instance_valid(t):
				t.queue_free()
	elif _frame >= 110:
		_won = bf._won
		_report()

func _report() -> void:
	print("BATTLE_RESULT moved_closer=%s damaged=%s won=%s" % [str(_moved_closer), str(_damaged), str(_won)])
	var ok: bool = _moved_closer and _damaged and _won
	print("BATTLE_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

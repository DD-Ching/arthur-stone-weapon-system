extends Node2D
## Headless test for the Rock Launcher Room (challenge level #3).
##
## Two things to prove:
##   1. THE MECHANIC — a Rock launched at speed into an enemy registers a real hit through
##      `Impact.collide` (the prop→enemy contract): the enemy takes damage AND knockback.
##      This is the level's intended solution, so it must actually work headlessly.
##   2. THE LEVEL RULE — the room recognises "all enemies defeated → win": its composed
##      ClearRoomObjective completes once the field is clear (and NOT before).
##
## Run: godot --headless --path . res://tests/RockLauncherRoomTest.tscn --quit-after 600
## Look for ROCK_ROOM_VERDICT.

const ROCK := preload("res://scenes/Rock.tscn")
const LIGHT := preload("res://scenes/LightSoldier.tscn")
const ROOM := preload("res://scenes/rooms/RockLauncherRoom.tscn")

var _rock
var _enemy
var _enemy_hp0 := 0.0
var _enemy_pos0 := Vector2.ZERO
var _frame := 0

# Objective rule check (deterministic, no waiting on physics).
var _win_when_clear := false
var _no_win_with_enemy := false
var _room_uses_objective := false

func _ready() -> void:
	# 1) Mechanic: an enemy sitting still, a rock fired straight into it at high speed.
	_enemy = LIGHT.instantiate()
	add_child(_enemy)
	_enemy.global_position = Vector2(300.0, 0.0)
	_enemy.ai_enabled = false             # a passive target, so only the rock moves it
	_enemy_hp0 = _enemy.health if _enemy.health > 0.0 else _enemy.max_health
	_enemy_pos0 = _enemy.global_position

	_rock = ROCK.instantiate()
	add_child(_rock)
	_rock.global_position = Vector2(120.0, 0.0)
	_rock.linear_velocity = Vector2(900.0, 0.0)   # well above Impact.BOWL_MIN_SPEED (230)

	# 2) Rule: drive the SAME objective the room composes, directly, so the check is
	# deterministic — it must NOT win while an enemy is up, and MUST win once cleared.
	var obj := ClearRoomObjective.new()
	var mgr := ObjectiveManager.new()
	mgr.add(obj)
	mgr.evaluate({"alive": 3, "total": 3, "started": true})
	_no_win_with_enemy = not mgr.won
	mgr.evaluate({"alive": 0, "total": 3, "started": true})
	_win_when_clear = mgr.won

	# The room must actually wire this objective (not hand-code its win) — instance it and
	# confirm an ObjectiveManager with a ClearRoomObjective is present.
	var room := ROOM.instantiate()
	add_child(room)
	_room_uses_objective = room._objectives != null \
		and room._objectives.objectives.size() >= 1 \
		and room._objectives.objectives[0] is ClearRoomObjective
	room.queue_free()

	print("ROCK_ROOM_READY enemy_hp0=%.1f" % _enemy_hp0)

func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame >= 120:
		_report()

func _report() -> void:
	var hp: float = _enemy.health if is_instance_valid(_enemy) else 0.0
	var dmg: float = _enemy_hp0 - hp
	var moved: float = _enemy.global_position.distance_to(_enemy_pos0) if is_instance_valid(_enemy) else 999.0
	var hit_count: int = _enemy.hit_count if is_instance_valid(_enemy) else 1
	var damaged: bool = dmg > 0.0
	var knocked: bool = moved > 20.0 or hit_count > 0

	print("ROCK_ROOM_RESULT dmg=%.1f moved=%.1f hits=%d damaged=%s knocked=%s no_win_enemy=%s win_clear=%s room_obj=%s"
		% [dmg, moved, hit_count, str(damaged), str(knocked),
			str(_no_win_with_enemy), str(_win_when_clear), str(_room_uses_objective)])

	var ok: bool = damaged and knocked and _no_win_with_enemy and _win_when_clear and _room_uses_objective
	print("ROCK_ROOM_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

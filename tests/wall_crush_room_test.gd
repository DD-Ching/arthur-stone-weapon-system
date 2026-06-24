extends Node2D
## Headless test for the Wall-Crush Training room (challenge level #2).
##
## Asserts the room's core promise — that pinning a raider to a wall is detectable and
## lethal, and that clearing the room is recognised as a win — using the SAME shared
## `Impact.cushion` raycast the room and the weapon use, so the test can't drift from them:
##   1. an enemy with a wall right behind it (along the strike direction) reads a wall —
##      `Impact.cushion(...) > 0` — while an enemy in open space reads ~0 (no cushion);
##   2. a strong pinning hit DEFEATS that enemy (Arthur's strength wins);
##   3. the actual WallCrushRoom scene recognises "field cleared → win" once every raider
##      it placed is defeated.
##
## Run: godot --headless --path . res://tests/WallCrushRoomTest.tscn — look for WALL_ROOM_VERDICT.

const ROOM := preload("res://scenes/rooms/WallCrushRoom.tscn")
const ENEMY := preload("res://scenes/LightSoldier.tscn")

var _walls: StaticBody2D
var _pinned
var _open
var _room
var _frame := 0
var _cushion_pin := 0.0
var _cushion_open := 0.0
var _defeated := false

func _ready() -> void:
	Impact.reset()

	# A solid wall slab on layer 1 ("world") — exactly what Impact.cushion raycasts for.
	_walls = StaticBody2D.new()
	_walls.collision_layer = 1
	_walls.collision_mask = 0
	add_child(_walls)
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40.0, 240.0)
	cs.shape = shape
	cs.position = Vector2(0.0, 0.0)   # slab spans x ∈ [-20, 20]
	_walls.add_child(cs)

	# Pinned enemy: 30px in front of the slab, struck INTO it (+X) → a wall is behind it.
	_pinned = ENEMY.instantiate()
	add_child(_pinned)
	_pinned.global_position = Vector2(-50.0, 0.0)

	# Open enemy: far from any wall, struck the same way → open space, no cushion.
	_open = ENEMY.instantiate()
	add_child(_open)
	_open.global_position = Vector2(600.0, 0.0)

	# The real room scene — we'll defeat every raider it placed and assert it clears.
	_room = ROOM.instantiate()
	add_child(_room)

func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame == 2:
		# Wall-crush detection through the shared raycast.
		var into := Vector2.RIGHT   # toward the slab from the pinned enemy
		_cushion_pin = Impact.cushion(self, _pinned.global_position, into)
		_cushion_open = Impact.cushion(self, _open.global_position, into)

		# A strong pinning hit: heavy knockback + lethal damage + a full pin. The enemy owns
		# its own defeat, so this proves Arthur's strength wins the contest.
		_pinned.apply_hit(into, 1600.0, 0.8, 200.0, 1.0)
		_defeated = _pinned._dead

		# Defeat every raider the room placed (lethal hits) so the room's scan sees an empty
		# field and recognises the win.
		for e in _room._enemies:
			if is_instance_valid(e):
				e.apply_hit(Vector2.RIGHT, 1600.0, 0.8, 500.0, 1.0)

	# Give the room's throttled scan (_scan_cd ≈ 0.15s) several physics frames to fire.
	if _frame >= 30:
		_report()

func _report() -> void:
	var wall_detected: bool = _cushion_pin > 0.0
	var open_clear: bool = _cushion_open <= 0.01
	var cleared: bool = _room.is_cleared()
	var ok: bool = wall_detected and open_clear and _defeated and cleared
	print("WALL_ROOM_RESULT cushion_pin=%.2f cushion_open=%.2f defeated=%s cleared=%s" \
		% [_cushion_pin, _cushion_open, str(_defeated), str(cleared)])
	print("WALL_ROOM_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

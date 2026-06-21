extends Node2D
## The battlefield — the test arena grown into a small ancient-battlefield sandbox.
##
## It turns the enemies' AI on, lays down terrain (mud that drags, fences that
## funnel and trip), runs the "Break the Shield Wall" objective, and handles
## win/lose. Like Arena.gd it keeps itself small: the *systems* live in Enemy,
## StoneWeapon, and Impact — this is the stage they perform on.
##
## Fences + mud are data-driven (Rect2 lists), so the thing you crush enemies
## against and the thing that slows them are exactly what you see drawn.

const HALF := Vector2(900.0, 560.0)
const GRID_STEP := 100
const MUD_DRAG := 0.86   ## velocity kept per frame inside mud (slows cavalry/charges)

## Static fences/obstacles (also drawn). World-space Rect2 (top-left + size).
const FENCES := [
	Rect2(-540, -260, 30, 360),   # left funnel wall
	Rect2(510, -260, 30, 360),    # right funnel wall
	Rect2(-300, -360, 220, 28),   # back-left fence behind the line
	Rect2(80, -360, 220, 28),     # back-right fence
]
## Mud bands — slow anything heavy that tries to cross (great for stalling charges).
const MUD := [
	Rect2(-340, 60, 680, 90),
]

## The ford — a shallow river the raiders must cross to reach Arthur's bank. Off the
## bridge it drags bodies AND a light current drifts them downstream, so cavalry and
## carts lose their line in the water. The dry BRIDGE deck in the middle is the only
## clean crossing — the choke point. Two Rect2 segments leave the bridge gap open.
const RIVER := [
	Rect2(-900, 212, 830, 112),   # left of the bridge
	Rect2(70, 212, 830, 112),     # right of the bridge
]
const BRIDGE := Rect2(-70, 200, 140, 136)        ## dry deck (drawn; the gap in the river)
const WATER_DRAG := 0.93         ## velocity kept per frame in water (lighter than mud)
const CURRENT := Vector2(48.0, 0.0)  ## downstream push (left → right) applied in water

## Reinforcements — the musou horde. Keep this many enemies alive by trickling in
## fresh fodder from the back of the field, so you always have an army to mow.
@export var horde_target := 22   ## kept conservative for the single-threaded web build
@export var spawn_interval := 1.0
const LIGHT := preload("res://scenes/LightSoldier.tscn")
const SHIELD := preload("res://scenes/ShieldSoldier.tscn")
const SPEAR := preload("res://scenes/Spearman.tscn")

@onready var arthur = $Arthur
@onready var hud = $Hud
@onready var walls: StaticBody2D = $Walls

var _won := false
var _lost := false
var _wall_total := 1
var _scan_cd := 0.0          ## throttles the (rare-to-change) objective scan
var _spawn_cd := 2.0         ## gap before the first reinforcements arrive
var _mud_bodies: Array = []  ## cached enemy+prop list, refreshed periodically
var _wet := {}               ## instance_id -> was-in-water, for splash-on-entry

func _ready() -> void:
	Impact.reset()
	_build_fences()
	# Wake the army up — the type scenes ship AI-off so the v0.3 sandbox stays calm.
	for e in get_tree().get_nodes_in_group("targets"):
		e.ai_enabled = true
	for s in $ShieldWall.get_children():
		s.add_to_group("shieldwall")
	_wall_total = maxi(1, get_tree().get_nodes_in_group("shieldwall").size())
	arthur.died.connect(_on_arthur_died)
	hud.bind(arthur)
	hud.set_objective("HOLD THE FORD — BREAK THE SHIELD WALL   0 / %d" % _wall_total)
	Impact.popup("THE FORD OF THE STONE KING", arthur.global_position + Vector2(0, -120),
		Color(0.85, 0.8, 0.6), 1.4)
	queue_redraw()

func _build_fences() -> void:
	for r in FENCES:
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = r.size
		cs.shape = shape
		cs.position = r.position + r.size * 0.5
		walls.add_child(cs)

func _physics_process(delta: float) -> void:
	# Refresh the body list + check the objective a few times a second — they change
	# only on a defeat, so scanning groups every frame is wasted work on the web build.
	_scan_cd -= delta
	_spawn_cd -= delta
	if _scan_cd <= 0.0:
		_scan_cd = 0.15
		_mud_bodies = get_tree().get_nodes_in_group("targets") + get_tree().get_nodes_in_group("props")
		# Drop splash-state for bodies freed since the last scan. Instance IDs get
		# reused, so a stale 'wet' flag must not suppress a fresh body's splash — same
		# reason Impact prunes its collision debounce.
		for id in _wet.keys():
			if not is_instance_valid(instance_from_id(id)):
				_wet.erase(id)
		_check_objective()
		if _spawn_cd <= 0.0:
			_spawn_reinforcements()
			_spawn_cd = spawn_interval
	# Terrain forces on the cached bodies (point-in-rect), applied every frame so charges
	# actually bog down; is_instance_valid guards bodies freed since the last refresh.
	for b in _mud_bodies:
		if not (is_instance_valid(b) and b is RigidBody2D):
			continue
		if _in_mud(b.global_position):
			b.linear_velocity *= MUD_DRAG
		if _in_water(b.global_position):
			b.linear_velocity *= WATER_DRAG
			b.linear_velocity += CURRENT * delta      # the downstream drift
			_splash_check(b)
		elif _wet.has(b.get_instance_id()):
			_wet.erase(b.get_instance_id())
	# Arthur wades too: the current gently shoves him while he stands in the ford.
	if _in_water(arthur.global_position):
		arthur.global_position += CURRENT * delta * 0.55

func _check_objective() -> void:
	if _won or _lost:
		return
	var remaining := get_tree().get_nodes_in_group("shieldwall").size()
	hud.set_objective("HOLD THE FORD — BREAK THE SHIELD WALL   %d / %d" % [_wall_total - remaining, _wall_total])
	if remaining == 0:
		_won = true
		hud.show_banner("SHIELD WALL BROKEN!", Color(0.5, 0.95, 0.55))
		Impact.popup("FORMATION BROKEN", arthur.global_position + Vector2(0, -64), Color(1.0, 0.85, 0.3), 1.5)

func _in_mud(p: Vector2) -> bool:
	for r in MUD:
		if r.has_point(p):
			return true
	return false

func _in_water(p: Vector2) -> bool:
	for r in RIVER:
		if r.has_point(p):
			return true
	return false

## Splash + sound the first frame a moving body crosses into the ford.
func _splash_check(b: RigidBody2D) -> void:
	var id := b.get_instance_id()
	if not _wet.get(id, false) and b.linear_velocity.length() > 130.0:
		Audio.play("water_splash", b.global_position)
		Impact.popup("SPLASH", b.global_position + Vector2(0, -24), Color(0.6, 0.85, 1.0), 0.9)
	_wet[id] = true

## Trickle fresh fodder in from the back rank until the field is full again.
func _spawn_reinforcements() -> void:
	if _won or _lost:
		return
	for _i in 2:
		if get_tree().get_nodes_in_group("targets").size() >= horde_target:
			return
		var e = _pick_reinforcement().instantiate()
		add_child(e)
		e.ai_enabled = true
		e.global_position = Vector2(randf_range(-300.0, 300.0), -HALF.y + 70.0)

func _pick_reinforcement() -> PackedScene:
	var r := randf()
	if r < 0.66:
		return LIGHT      # mostly cannon fodder
	if r < 0.86:
		return SPEAR
	return SHIELD

func _on_arthur_died() -> void:
	if _won:
		return
	_lost = true
	hud.show_banner("ARTHUR HAS FALLEN", Color(0.95, 0.4, 0.4))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_arena"):
		get_tree().reload_current_scene()

func _draw() -> void:
	var rect := Rect2(-HALF, HALF * 2.0)
	draw_rect(rect, Color(0.17, 0.16, 0.14))            # muddy ground
	for x in range(-int(HALF.x), int(HALF.x) + 1, GRID_STEP):
		draw_line(Vector2(x, -HALF.y), Vector2(x, HALF.y), Color(1, 1, 1, 0.03), 1.0)
	for y in range(-int(HALF.y), int(HALF.y) + 1, GRID_STEP):
		draw_line(Vector2(-HALF.x, y), Vector2(HALF.x, y), Color(1, 1, 1, 0.03), 1.0)
	# the ford — river water with a faint downstream current stripe
	for r in RIVER:
		draw_rect(r, Color(0.16, 0.34, 0.44, 0.78))
		var midy: float = r.position.y + r.size.y * 0.5
		draw_line(Vector2(r.position.x, midy), Vector2(r.position.x + r.size.x, midy),
			Color(0.45, 0.7, 0.8, 0.35), 2.0)
		draw_rect(r, Color(0.3, 0.55, 0.65, 0.5), false, 2.0)
	# the wooden bridge — the dry choke across the ford
	draw_rect(BRIDGE, Color(0.42, 0.31, 0.19))
	for px in range(int(BRIDGE.position.x), int(BRIDGE.position.x + BRIDGE.size.x), 18):
		draw_line(Vector2(px, BRIDGE.position.y), Vector2(px, BRIDGE.position.y + BRIDGE.size.y),
			Color(0.3, 0.22, 0.13), 2.0)
	draw_rect(BRIDGE, Color(0.55, 0.42, 0.27), false, 3.0)
	# mud bands
	for r in MUD:
		draw_rect(r, Color(0.26, 0.2, 0.12, 0.65))
		draw_rect(r, Color(0.32, 0.25, 0.15), false, 2.0)
	# fences (same Rect2s that became collision)
	for r in FENCES:
		draw_rect(r, Color(0.34, 0.26, 0.18))
		draw_rect(r, Color(0.5, 0.4, 0.28), false, 3.0)
	draw_rect(rect, Color(0.4, 0.36, 0.3), false, 6.0)  # boundary

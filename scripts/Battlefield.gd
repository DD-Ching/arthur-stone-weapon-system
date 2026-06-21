extends Node2D
## The Ford of the Stone King — Arthur (and a few allies) hold a river crossing against
## a raider warband that attacks in five escalating waves and tries to cross the ford.
##
## This stage runs the battlefield SYSTEMS; the behaviours live in Enemy/StoneWeapon/
## Impact. It owns: the ford terrain (mud, river current, the bridge as a damageable
## choke), the structured 5-wave assault, the allied line + "Hold the Ford" lose
## condition (too many raiders cross = the ford falls), drifting log hazards, and
## win/lose. Terrain is data-driven Rect2s — the thing that slows you is what you see.

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
const MUD := [
	Rect2(-340, 60, 680, 90),
]

## The ford — a shallow river the raiders must cross to reach Arthur's bank. Off the
## bridge it drags bodies AND a light current drifts them downstream; the dry BRIDGE
## deck in the middle is the one clean crossing (the choke). Two Rect2 segments leave
## the bridge gap open; if the bridge collapses, that gap becomes water too.
const RIVER := [
	Rect2(-900, 212, 830, 112),   # left of the bridge
	Rect2(70, 212, 830, 112),     # right of the bridge
]
const BRIDGE := Rect2(-70, 200, 140, 136)        ## dry deck (drawn; the gap in the river)
const BRIDGE_GAP := Rect2(-70, 212, 140, 112)    ## becomes water once the bridge falls
const WATER_DRAG := 0.93
const CURRENT := Vector2(48.0, 0.0)

## Arthur's home bank: a raider that gets south of this line has broken through.
const DEFENCE_Y := 480.0
const GOAL_POS := Vector2(0.0, 528.0)             ## the allied banner the raiders march at

@export var max_breaches := 12        ## raiders allowed across before the ford falls
@export var bridge_max_hp := 200.0
@export var ally_count := 6
@export var wave_interval := 18.0     ## max seconds before the next wave is forced in
@export var wave_clear_threshold := 5 ## launch the next wave once the field thins to this
@export var log_interval := 7.0       ## seconds between floating logs
@export var max_logs := 4

const LIGHT := preload("res://scenes/LightSoldier.tscn")
const SHIELD := preload("res://scenes/ShieldSoldier.tscn")
const SPEAR := preload("res://scenes/Spearman.tscn")
const CAVALRY := preload("res://scenes/Cavalry.tscn")
const CART := preload("res://scenes/WarCart.tscn")
const BANNER := preload("res://scenes/BannerBearer.tscn")
const ALLY := preload("res://scenes/Ally.tscn")
const LOG := preload("res://scenes/Log.tscn")

@onready var arthur = $Arthur
@onready var hud = $Hud
@onready var walls: StaticBody2D = $Walls

var _won := false
var _lost := false
var _scan_cd := 0.0
var _mud_bodies: Array = []   ## cached enemy+prop+ally list, refreshed periodically
var _wet := {}                ## instance_id -> was-in-water, for splash-on-entry
var _waves: Array = []
var _wave := 0                ## waves spawned so far
var _wave_cd := 5.0           ## countdown to the next wave
var _breaches := 0
var _breached := {}           ## ids already counted as having crossed the line
var _bridge_hp := 0.0
var _bridge_down := false
var _log_cd := 6.0

func _ready() -> void:
	Impact.reset()
	_bridge_hp = bridge_max_hp
	_build_fences()
	_build_goal()
	_waves = [
		{"name": "LIGHT RAIDERS", "col": Color(1.0, 0.82, 0.4), "spawns": [LIGHT, LIGHT, LIGHT, LIGHT, LIGHT, LIGHT]},
		{"name": "SHIELD SOLDIERS", "col": Color(0.72, 0.78, 0.9), "spawns": [SHIELD, SHIELD, SHIELD, SHIELD, SHIELD]},
		{"name": "SPEARS BEHIND SHIELDS", "col": Color(0.8, 0.88, 0.7), "spawns": [SHIELD, SHIELD, SPEAR, SPEAR, SPEAR]},
		{"name": "CAVALRY CHARGE", "col": Color(1.0, 0.55, 0.3), "spawns": [CAVALRY, CAVALRY, CART]},
		{"name": "THE OFFICER", "col": Color(1.0, 0.5, 0.3), "spawns": [BANNER, SHIELD, SHIELD, SPEAR, LIGHT, LIGHT]},
	]
	# Wake the pre-placed garrison (the type scenes ship AI-off so the sandbox stays calm).
	for e in get_tree().get_nodes_in_group("targets"):
		e.ai_enabled = true
	for s in $ShieldWall.get_children():
		s.add_to_group("shieldwall")
	_spawn_allies()
	arthur.died.connect(_on_arthur_died)
	hud.bind(arthur)
	Impact.popup("THE FORD OF THE STONE KING", arthur.global_position + Vector2(0, -120),
		Color(0.85, 0.8, 0.6), 1.4)
	_update_objective()
	queue_redraw()

func _build_fences() -> void:
	for r in FENCES:
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = r.size
		cs.shape = shape
		cs.position = r.position + r.size * 0.5
		walls.add_child(cs)

## The allied banner at Arthur's bank — the point the raiders march at, and the marker
## for the defence line. A node in group "ford_goal" so raiders can find it.
func _build_goal() -> void:
	var goal := Node2D.new()
	goal.global_position = GOAL_POS
	goal.add_to_group("ford_goal")
	add_child(goal)

func _spawn_allies() -> void:
	for i in ally_count:
		var a = ALLY.instantiate()
		add_child(a)
		a.ai_enabled = true
		var x := lerpf(-260.0, 260.0, float(i) / maxf(1.0, ally_count - 1.0))
		a.global_position = Vector2(x, 430.0)

func _physics_process(delta: float) -> void:
	if not (_won or _lost):
		_wave_cd -= delta
		_log_cd -= delta
	# Refresh the body list + run the slow systems a few times a second — they change
	# only on a spawn/defeat, so scanning groups every frame is wasted on the web build.
	_scan_cd -= delta
	if _scan_cd <= 0.0:
		_scan_cd = 0.15
		_mud_bodies = get_tree().get_nodes_in_group("targets") \
			+ get_tree().get_nodes_in_group("props") \
			+ get_tree().get_nodes_in_group("allies")
		# Drop splash-state for bodies freed since the last scan (instance IDs get reused,
		# so a stale 'wet' flag must not suppress a fresh body's splash).
		for id in _wet.keys():
			if not is_instance_valid(instance_from_id(id)):
				_wet.erase(id)
		_update_waves()
		_check_breaches()
		_check_victory()
		_update_objective()
		_maybe_spawn_log()
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
		_bridge_pound(b)   # checked for any prop over the deck (dry or, once down, water)
	# Arthur wades too: the current gently shoves him while he stands in the ford.
	# move_and_collide (not a raw transform write) so the push still respects walls/bodies.
	if _in_water(arthur.global_position):
		arthur.move_and_collide(CURRENT * delta * 0.55)

# ── waves ───────────────────────────────────────────────────────────────────

func _update_waves() -> void:
	if _won or _lost or _wave >= _waves.size():
		return
	var alive := get_tree().get_nodes_in_group("targets").size()
	# Launch the next wave once the field thins out, or patience runs out.
	if alive <= wave_clear_threshold or _wave_cd <= 0.0:
		_spawn_wave(_wave)
		_wave += 1
		_wave_cd = wave_interval

func _spawn_wave(idx: int) -> void:
	var wave: Dictionary = _waves[idx]
	Impact.popup("WAVE %d / %d — %s" % [idx + 1, _waves.size(), wave["name"]],
		arthur.global_position + Vector2(0, -150), wave["col"], 1.5)
	Audio.play("cavalry_charge", arthur.global_position)   # a war-horn for the incoming wave
	var spawns: Array = wave["spawns"]
	for i in spawns.size():
		var e = spawns[i].instantiate()
		add_child(e)
		e.ai_enabled = true
		e.global_position = Vector2(randf_range(-380.0, 380.0), -HALF.y + 70.0)

# ── "Hold the Ford": breaches + win/lose ────────────────────────────────────

## Count raiders that walk past the defence line (under their own power, not launched).
## Each counts once, then is removed (it "broke through"); enough breaches lose the ford.
func _check_breaches() -> void:
	if _won or _lost:
		return
	for e in get_tree().get_nodes_in_group("targets"):
		if not is_instance_valid(e) or e._dead:
			continue
		if e.global_position.y <= DEFENCE_Y:
			continue
		if _breached.has(e.get_instance_id()):
			continue
		# A launched/stunned body flying past doesn't count — only a raider that marched.
		if e._stun > 0.0 or e.linear_velocity.length() > e.control_regain:
			continue
		_breached[e.get_instance_id()] = true
		_breaches += 1
		Impact.popup("BREACH!", e.global_position + Vector2(0, -30), Color(1.0, 0.4, 0.35), 1.2)
		Audio.play("banner_down", e.global_position)
		e.queue_free()
		if _breaches >= max_breaches:
			_defeat_ford()

func _check_victory() -> void:
	if _won or _lost:
		return
	# The assault is over once every wave is spawned and the field is essentially clear.
	if _wave >= _waves.size() and get_tree().get_nodes_in_group("targets").size() <= 2:
		# But a breach REMOVES a raider too — so if the field only "cleared" because the
		# line was overrun (half the breach budget spent), that's not holding, it's losing.
		if _breaches * 2 >= max_breaches:
			_defeat_ford()
			return
		_won = true
		hud.show_banner("THE FORD HOLDS!", Color(0.5, 0.95, 0.55))
		Impact.popup("VICTORY — THE FORD IS YOURS", arthur.global_position + Vector2(0, -64),
			Color(1.0, 0.85, 0.3), 1.6)

func _defeat_ford() -> void:
	if _won or _lost:
		return
	_lost = true
	hud.show_banner("THE FORD IS LOST", Color(0.95, 0.45, 0.4))

func _update_objective() -> void:
	var wave_n := mini(_wave, _waves.size())
	hud.set_objective("HOLD THE FORD   WAVE %d/%d   ·   BREACH %d/%d"
		% [wave_n, _waves.size(), _breaches, max_breaches])

# ── terrain helpers ─────────────────────────────────────────────────────────

func _in_mud(p: Vector2) -> bool:
	for r in MUD:
		if r.has_point(p):
			return true
	return false

func _in_water(p: Vector2) -> bool:
	for r in RIVER:
		if r.has_point(p):
			return true
	# Once the bridge falls, its dry gap becomes part of the river.
	return _bridge_down and BRIDGE_GAP.has_point(p)

## Splash + sound the first frame a moving body crosses into the ford.
func _splash_check(b: RigidBody2D) -> void:
	var id := b.get_instance_id()
	if not _wet.get(id, false) and b.linear_velocity.length() > 130.0:
		Audio.play("water_splash", b.global_position)
		Impact.popup("SPLASH", b.global_position + Vector2(0, -24), Color(0.6, 0.85, 1.0), 0.9)
	_wet[id] = true

## A fast prop pounding the bridge deck chips its supports; enough damage collapses it,
## turning the dry crossing into open water (denying the raiders their clean route).
func _bridge_pound(b: RigidBody2D) -> void:
	if _bridge_down:
		return
	if not BRIDGE.has_point(b.global_position):
		return
	if not b.is_in_group("props"):
		return
	var speed := b.linear_velocity.length()
	if speed < 230.0:
		return
	_bridge_hp -= speed * 0.05
	if _bridge_hp <= 0.0:
		_collapse_bridge()

func _collapse_bridge() -> void:
	_bridge_down = true
	Impact.popup("BRIDGE COLLAPSED", BRIDGE.get_center() + Vector2(0, -40), Color(1.0, 0.6, 0.3), 1.5)
	Audio.play("wall_crush", BRIDGE.get_center())
	Impact.impact_fx.emit(20.0)

func _maybe_spawn_log() -> void:
	if _won or _lost or _log_cd > 0.0:
		return
	if get_tree().get_nodes_in_group("logs").size() >= max_logs:
		_log_cd = log_interval
		return
	_log_cd = log_interval
	var log = LOG.instantiate()
	add_child(log)
	log.add_to_group("logs")
	log.global_position = Vector2(-880.0, randf_range(228.0, 308.0))   # upstream edge of the ford
	log.linear_velocity = Vector2(120.0, 0.0)                          # nudged into the current

func _on_arthur_died() -> void:
	if _won:
		return
	_lost = true
	hud.show_banner("ARTHUR HAS FALLEN", Color(0.95, 0.4, 0.4))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_arena"):
		get_tree().reload_current_scene()

# ── drawing ─────────────────────────────────────────────────────────────────

func _draw() -> void:
	var rect := Rect2(-HALF, HALF * 2.0)
	draw_rect(rect, Color(0.17, 0.16, 0.14))            # riverbank ground
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
	if _bridge_down:
		# Collapsed: the gap is open water with broken planks poking out.
		draw_rect(BRIDGE_GAP, Color(0.16, 0.34, 0.44, 0.78))
		for k in range(5):
			var bx := BRIDGE.position.x + 14.0 + k * 26.0
			draw_line(Vector2(bx, 250), Vector2(bx + 12, 285), Color(0.32, 0.22, 0.13), 4.0)
	else:
		# the wooden bridge — the dry choke across the ford, with a damage tint
		var dmg := clampf(1.0 - _bridge_hp / bridge_max_hp, 0.0, 1.0)
		draw_rect(BRIDGE, Color(0.42, 0.31, 0.19).lerp(Color(0.3, 0.18, 0.12), dmg))
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
	# the defence line + the allied banner Arthur is protecting
	draw_line(Vector2(-HALF.x, DEFENCE_Y), Vector2(HALF.x, DEFENCE_Y), Color(0.4, 0.6, 0.95, 0.4), 2.0)
	draw_line(GOAL_POS + Vector2(0, 20), GOAL_POS + Vector2(0, -34), Color(0.55, 0.45, 0.3), 4.0)
	draw_rect(Rect2(GOAL_POS.x, GOAL_POS.y - 34.0, 30.0, 20.0), Color(0.3, 0.55, 0.95))
	draw_rect(rect, Color(0.4, 0.36, 0.3), false, 6.0)  # boundary

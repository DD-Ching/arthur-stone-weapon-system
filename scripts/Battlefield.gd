extends Node2D
## Hold the Ford — Arthur (and a few allies) hold a river crossing against a raider
## warband that attacks in five escalating waves and tries to cross.
##
## This is a LEVEL: it assembles reusable modules and runs the level's own rules. The
## reusable parts live elsewhere — terrain is `TerrainZone`, spawning is `Spawner`,
## all force/scoring is `Impact`, every enemy is a config of `Enemy`. What stays here is
## level-specific: the layout, the 5-wave script, the breach lose / wave-clear win, the
## collapsible bridge, and the log hazards. Drop the same modules in a new scene + tune
## parameters to build a different battle.

const HALF := Vector2(900.0, 560.0)
const GRID_STEP := 100

## Static fences/obstacles (also drawn). World-space Rect2 (top-left + size).
const FENCES := [
	Rect2(-540, -260, 30, 360),   # left funnel wall
	Rect2(510, -260, 30, 360),    # right funnel wall
	Rect2(-300, -360, 220, 28),   # back-left fence behind the line
	Rect2(80, -360, 220, 28),     # back-right fence
]
## Terrain rects (drawn here; the matching TerrainZone rules are spawned over them).
const MUD := [ Rect2(-340, 60, 680, 90) ]
const RIVER := [
	Rect2(-900, 212, 830, 112),   # left of the bridge
	Rect2(70, 212, 830, 112),     # right of the bridge
]
const BRIDGE := Rect2(-70, 200, 140, 136)        ## dry deck (drawn; the gap in the river)
const BRIDGE_GAP := Rect2(-70, 212, 140, 112)    ## becomes deep water once the bridge falls
const MUD_DRAG := 0.86
const WATER_DRAG := 0.93
const CURRENT := Vector2(48.0, 0.0)              ## downstream push (left → right)

## Arthur's home bank: a raider that gets south of this line has broken through.
const DEFENCE_Y := 480.0
const GOAL_POS := Vector2(0.0, 528.0)            ## the allied banner the raiders march at
const CROSS_POS := Vector2(0.0, 268.0)           ## the bridge — the crossing NPCs aim for

# layer bits: arthur=2, enemies/allies=4, props=8
const MASK_UNITS_PROPS := 12     ## enemies + allies + props
const MASK_WITH_ARTHUR := 14     ## + Arthur (so the current shoves him too)

@export var max_breaches := 12        ## raiders allowed across before the ford falls
@export var bridge_max_hp := 200.0
## Army-size multiplier for BOTH sides — waves, the allied host, and the garrison all
## scale by this. Big battles cost framerate on the single-threaded web build; tune down
## if the demo chugs. 1.0 = the original army; 2.5 = a dense mass battle.
@export var density := 2.5
@export var wave_interval := 18.0     ## max seconds before the next wave is forced in
@export var wave_clear_threshold := 5 ## launch the next wave once the field thins to this (×density)
@export var log_interval := 7.0
@export var max_logs := 4

const LIGHT := preload("res://scenes/LightSoldier.tscn")
const SHIELD := preload("res://scenes/ShieldSoldier.tscn")
const SPEAR := preload("res://scenes/Spearman.tscn")
const CAVALRY := preload("res://scenes/Cavalry.tscn")
const CART := preload("res://scenes/WarCart.tscn")
const BANNER := preload("res://scenes/BannerBearer.tscn")
const HEAVY := preload("res://scenes/HeavyGuard.tscn")
const SKIRMISHER := preload("res://scenes/Skirmisher.tscn")  ## ranged kiter (javelin)
const BERSERKER := preload("res://scenes/Berserker.tscn")    ## fast pouncer (leap + slash)
const MARAUDER := preload("res://scenes/Marauder.tscn")      ## slow area brute (pound + bash)
const ALLY := preload("res://scenes/Ally.tscn")
const LOG := preload("res://scenes/Log.tscn")
const SHIELD_WALL := preload("res://scenes/formations/ShieldWall.tscn")
const SPEAR_PHALANX := preload("res://scenes/formations/SpearPhalanx.tscn")
const OFFICER_GUARD := preload("res://scenes/formations/OfficerGuard.tscn")
const ALLIED_HOST := preload("res://scenes/formations/AlliedHost.tscn")
const SCORE_SCREEN := preload("res://scenes/ui/ScoreScreen.tscn")
const PAUSE_MENU := preload("res://scenes/ui/PauseMenu.tscn")   ## Esc / mobile MENU → return-to-lobby

@onready var arthur = $Arthur
@onready var hud = $Hud
@onready var walls: StaticBody2D = $Walls

var _won := false
var _lost := false
var _scan_cd := 0.0
var _mud_bodies: Array = []   ## cached enemy+prop+ally list, refreshed periodically
var _waves: Array = []
var _wave := 0                ## waves spawned so far
var _wave_cd := 5.0           ## countdown to the next wave
var _breaches := 0
var _breached := {}           ## ids already counted as having crossed the line
var _bridge_hp := 0.0
var _bridge_down := false
var _bridge_zone: TerrainZone = null   ## deep water over the gap, enabled when the bridge falls
var _crossing: Node2D = null
var _log_cd := 6.0
var _objectives: ObjectiveManager = null   ## this level's win/lose, composed from modules
var _elapsed := 0.0                  ## battle time, frozen at the win/lose result
var _score_screen: CanvasLayer = null   ## end-of-battle KO + time overlay
var _pause: CanvasLayer = null       ## the reusable PauseMenu overlay (Esc / mobile MENU → lobby)

func _ready() -> void:
	Impact.reset()
	_bridge_hp = bridge_max_hp
	_build_fences()
	_build_goal()
	_build_terrain()
	# Waves 2/3/5 arrive as cohesive FORMATIONS (placeable modules); 1/4 are loose mobs.
	_waves = [
		{"name": "LIGHT RAIDERS", "col": Color(1.0, 0.82, 0.4), "spawns": [LIGHT, LIGHT, SKIRMISHER, LIGHT, BERSERKER, LIGHT]},
		{"name": "SHIELD WALL", "col": Color(0.72, 0.78, 0.9), "formation": SHIELD_WALL},
		{"name": "SPEAR PHALANX", "col": Color(0.8, 0.88, 0.7), "formation": SPEAR_PHALANX},
		{"name": "CAVALRY CHARGE", "col": Color(1.0, 0.55, 0.3), "spawns": [CAVALRY, CAVALRY, MARAUDER, CART]},
		{"name": "THE OFFICER", "col": Color(1.0, 0.5, 0.3), "formation": OFFICER_GUARD},
	]
	# Wake the pre-placed garrison (the type scenes ship AI-off so the sandbox stays calm).
	for e in get_tree().get_nodes_in_group("targets"):
		e.ai_enabled = true
	for s in $ShieldWall.get_children():
		s.add_to_group("shieldwall")
	_bulk_garrison()
	_spawn_allies()
	# Compose this level's win/lose from reusable objectives instead of hand-coding it:
	# repel every wave AND defeat the officer to win; lose if the line is breached.
	_objectives = ObjectiveManager.new()
	_objectives.add(RepelWavesObjective.new()) \
		.add(DefeatOfficerObjective.new()) \
		.add(HoldLineObjective.new())
	arthur.died.connect(_on_arthur_died)
	hud.bind(arthur)
	_score_screen = SCORE_SCREEN.instantiate()
	add_child(_score_screen)
	# The reusable pause overlay — Esc / mobile MENU → Resume / Restart / Return to Lobby. Same as
	# every BattleMap; the Ford is the original standalone level so it got wired here by hand.
	_pause = PAUSE_MENU.instantiate()
	add_child(_pause)
	Impact.popup("THE FORD OF THE STONE KING", arthur.global_position + Vector2(0, -120),
		Color(0.85, 0.8, 0.6), 1.4)
	_evaluate_objectives()
	queue_redraw()

func _build_fences() -> void:
	for r in FENCES:
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = r.size
		cs.shape = shape
		cs.position = r.position + r.size * 0.5
		walls.add_child(cs)

## The allied banner at Arthur's bank — the point the raiders march at — plus the bridge
## "crossing" marker that NPCs aim for when they refuse to wade the river.
func _build_goal() -> void:
	var goal := Node2D.new()
	goal.global_position = GOAL_POS
	goal.add_to_group("ford_goal")
	add_child(goal)
	_crossing = Node2D.new()
	_crossing.global_position = CROSS_POS
	_crossing.add_to_group("crossing")
	add_child(_crossing)

## Lay down the terrain RULES as reusable TerrainZones over the drawn rects. Place another
## river/mud anywhere and it behaves identically — this is the modular terrain.
func _build_terrain() -> void:
	for r in RIVER:
		_add_zone(r, WATER_DRAG, CURRENT, true, true, MASK_WITH_ARTHUR)   # deep ford: avoid + drown
	for r in MUD:
		_add_zone(r, MUD_DRAG, Vector2.ZERO, false, false, MASK_UNITS_PROPS)
	# The bridge gap is dry until collapse, then it becomes deep water (kept disabled now).
	_bridge_zone = _add_zone(BRIDGE_GAP, WATER_DRAG, CURRENT, true, true, MASK_WITH_ARTHUR)
	_bridge_zone.monitoring = false
	_bridge_zone.remove_from_group("danger_terrain")

func _add_zone(r: Rect2, drag: float, current: Vector2, dangerous: bool, drown: bool, mask: int) -> TerrainZone:
	var z := TerrainZone.new()
	z.drag = drag
	z.current = current
	z.dangerous = dangerous
	z.drowns_light = drown
	z.drown_mass_max = 0.7   # only the lightest raiders (≈0.55) sink; allies/shields wade out
	z.collision_layer = 0
	z.collision_mask = mask
	z.setup_rect(r)
	add_child(z)
	return z

## A real allied army: a shield + spear HOST led by a Knight champion (scaled by density),
## plus a line of buffed footmen across the bank.
func _spawn_allies() -> void:
	var host = ALLIED_HOST.instantiate()
	host.front_count = _scale(host.front_count)
	host.support_count = _scale(host.support_count)
	# Faces UP, so the rear ranks (knight commander) sit to the SOUTH; place the front high
	# enough that the rearmost rank (2×rank_gap back) still clears the bottom wall (~540).
	host.position = Vector2(0.0, 350.0)
	add_child(host)
	Spawner.spawn_count(self, ALLY, _scale(2), 445.0, -340.0, 340.0, false)

## Bulk the opening raider force up to `density`: the hand-placed garrison is the ×1 base,
## so add the remainder as extra loose raiders + a scaled shield wall at the back.
func _bulk_garrison() -> void:
	if density <= 1.05:
		return
	var extra := density - 1.0
	Spawner.spawn(self, _repeat([LIGHT, LIGHT, SPEAR, SHIELD, HEAVY, SKIRMISHER, BERSERKER, MARAUDER], int(round(8.0 * extra))),
		-HALF.y + 70.0, -380.0, 380.0, true)
	var f = SHIELD_WALL.instantiate()
	f.front_count = _scale(f.front_count)
	f.position = Vector2(0.0, -HALF.y + 100.0 + f.rank_gap * 2.0)
	add_child(f)

## density helpers — scale a count, and cycle a scene list to a scaled length.
func _scale(n: int) -> int:
	return maxi(1, int(round(n * density)))

func _repeat(scenes: Array, count: int) -> Array:
	var out: Array = []
	if scenes.is_empty():
		return out
	for i in count:
		out.append(scenes[i % scenes.size()])
	return out

func _physics_process(delta: float) -> void:
	if not (_won or _lost):
		_elapsed += delta
		_wave_cd -= delta
		_log_cd -= delta
	# Run the slow systems a few times a second — they change only on a spawn/defeat.
	_scan_cd -= delta
	if _scan_cd <= 0.0:
		_scan_cd = 0.15
		_mud_bodies = get_tree().get_nodes_in_group("targets") \
			+ get_tree().get_nodes_in_group("props") \
			+ get_tree().get_nodes_in_group("allies")
		_update_waves()
		_check_breaches()
		_evaluate_objectives()
		_maybe_spawn_log()
	# Terrain forces now live in the TerrainZones. The only per-body work left here is the
	# level-specific bridge pounding (a fast prop over the deck chips it).
	for b in _mud_bodies:
		if is_instance_valid(b) and b is RigidBody2D:
			_bridge_pound(b)

# ── waves ───────────────────────────────────────────────────────────────────

func _update_waves() -> void:
	if _won or _lost or _wave >= _waves.size():
		return
	var alive := get_tree().get_nodes_in_group("targets").size()
	# Launch the next wave once the field thins out (the threshold scales with density so a
	# denser battle keeps more bodies on the field), or patience runs out.
	if alive <= _scale(wave_clear_threshold) or _wave_cd <= 0.0:
		_spawn_wave(_wave)
		_wave += 1
		_wave_cd = wave_interval

func _spawn_wave(idx: int) -> void:
	var wave: Dictionary = _waves[idx]
	Impact.popup("WAVE %d / %d — %s" % [idx + 1, _waves.size(), wave["name"]],
		arthur.global_position + Vector2(0, -150), wave["col"], 1.5)
	Audio.play("cavalry_charge", arthur.global_position)   # a war-horn for the incoming wave
	if wave.has("formation"):
		# A cohesive formation marches in as a block, facing the ford. Scale its ranks by
		# density, and spawn it deep enough that its REAR ranks (support/commander sit up to
		# 2×rank_gap behind, to the north) still clear the top wall.
		var f = wave["formation"].instantiate()
		f.front_count = _scale(f.front_count)
		f.support_count = _scale(f.support_count)
		f.position = Vector2(randf_range(-300.0, 300.0), -HALF.y + 100.0 + f.rank_gap * 2.0)
		add_child(f)   # auto-spawns its ranks on _ready
	else:
		var roster: Array = _repeat(wave["spawns"], _scale(wave["spawns"].size()))
		Spawner.spawn(self, roster, -HALF.y + 70.0, -380.0, 380.0, true)

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
		# The lose decision belongs to the HoldLine objective, not this counter.

## Tick the composed objectives with the level's live state; they decide win/lose + HUD.
func _evaluate_objectives() -> void:
	if _won or _lost:
		return
	var ctx := {
		"breaches": _breaches, "max_breaches": max_breaches,
		"wave": _wave, "wave_count": _waves.size(),
		"alive": get_tree().get_nodes_in_group("targets").size(),
		"officers": get_tree().get_nodes_in_group("officers").size(),
	}
	_objectives.evaluate(ctx)
	hud.set_objective("HOLD THE FORD   " + _objectives.hud_line(ctx))
	if _objectives.lost:
		_defeat_ford()
	elif _objectives.won:
		_victory()

func _victory() -> void:
	if _won or _lost:
		return
	_won = true
	# Record the win in the campaign so the lobby marks the Ford CLEARED (guarded — the autoload
	# may be absent when the scene is booted standalone or under a headless test harness).
	var c := get_node_or_null("/root/Campaign")
	if c:
		c.mark_completed(scene_file_path)
	hud.show_banner("THE FORD HOLDS!", Color(0.5, 0.95, 0.55))
	Impact.popup("VICTORY — THE FORD IS YOURS", arthur.global_position + Vector2(0, -64),
		Color(1.0, 0.85, 0.3), 1.6)
	_show_score(true)

func _defeat_ford() -> void:
	if _won or _lost:
		return
	_lost = true
	hud.show_banner("THE FORD IS LOST", Color(0.95, 0.45, 0.4))
	_show_score(false)

## Reveal the end-of-battle result overlay and hand it the campaign context (the next battle to
## advance to + that battle's story beat), exactly as BattleMap._show_score does. Also locks the
## pause overlay — the result screen owns the Next / Retry / Return-to-Lobby choices now.
func _show_score(victory: bool) -> void:
	if _pause and _pause.has_method("lock"):
		_pause.lock()
	var next_path := ""
	var blurb := ""
	var c := get_node_or_null("/root/Campaign")
	if c:
		# On a win, advance to the next battle; on a loss the player retries THIS one.
		next_path = c.next_path(scene_file_path) if victory else ""
		blurb = c.blurb_for(next_path) if (victory and next_path != "") else c.blurb_for(scene_file_path)
	if _score_screen:
		_score_screen.show_result(victory, Impact.kills, _elapsed, next_path, blurb)

# ── bridge (a level-specific destructible) ──────────────────────────────────

## A fast prop pounding the bridge deck chips its supports; enough damage collapses it,
## turning the dry crossing into deep water — denying the raiders their clean route.
func _bridge_pound(b: RigidBody2D) -> void:
	if _bridge_down or not b.is_in_group("props"):
		return
	if not BRIDGE.has_point(b.global_position):
		return
	var speed := b.linear_velocity.length()
	if speed < 230.0:
		return
	_bridge_hp -= speed * 0.05
	if _bridge_hp <= 0.0:
		_collapse_bridge()

func _collapse_bridge() -> void:
	_bridge_down = true
	if _bridge_zone:
		_bridge_zone.monitoring = true
		_bridge_zone.add_to_group("danger_terrain")
	if _crossing:
		_crossing.remove_from_group("crossing")   # no dry crossing left — they must wade
	Impact.popup("BRIDGE COLLAPSED", BRIDGE.get_center() + Vector2(0, -40), Color(1.0, 0.6, 0.3), 1.5)
	Audio.play("wall_crush", BRIDGE.get_center())
	Impact.impact_fx.emit(20.0)

func _maybe_spawn_log() -> void:
	if _won or _lost or _log_cd > 0.0:
		return
	_log_cd = log_interval
	if get_tree().get_nodes_in_group("logs").size() >= max_logs:
		return
	var log = LOG.instantiate()
	add_child(log)
	log.add_to_group("logs")
	log.global_position = Vector2(-880.0, randf_range(228.0, 308.0))   # upstream edge
	log.linear_velocity = Vector2(120.0, 0.0)

func _on_arthur_died() -> void:
	if _won:
		return
	_lost = true
	hud.show_banner("ARTHUR HAS FALLEN", Color(0.95, 0.4, 0.4))
	_show_score(false)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_arena"):
		get_tree().reload_current_scene()

# ── drawing (the terrain VISUALS; the rules are the TerrainZones above) ──────

var _dapple: Array = []   ## cached deterministic ground dapple (built once)

func _draw() -> void:
	var rect := Rect2(-HALF, HALF * 2.0)
	if _dapple.is_empty():
		_dapple = GroundPaint.make_dapple(rect, 19940715)
	# A damp riverbank floor (value gradient + dapple) — no more graph-paper grid.
	GroundPaint.draw_floor(self, rect, Color(0.15, 0.19, 0.16), Color(0.19, 0.18, 0.13), _dapple)
	for r in RIVER:
		_draw_water(r)
	if _bridge_down:
		_draw_water(BRIDGE_GAP)
		for k in range(5):
			var bx := BRIDGE.position.x + 14.0 + k * 26.0
			draw_line(Vector2(bx, 250), Vector2(bx + 12, 285), Color(0.32, 0.22, 0.13), 4.0)
	else:
		var dmg := clampf(1.0 - _bridge_hp / bridge_max_hp, 0.0, 1.0)
		draw_rect(BRIDGE, Color(0.42, 0.31, 0.19).lerp(Color(0.3, 0.18, 0.12), dmg))
		for px in range(int(BRIDGE.position.x), int(BRIDGE.position.x + BRIDGE.size.x), 18):
			draw_line(Vector2(px, BRIDGE.position.y), Vector2(px, BRIDGE.position.y + BRIDGE.size.y),
				Color(0.3, 0.22, 0.13), 2.0)
		draw_rect(BRIDGE, Color(0.55, 0.42, 0.27), false, 3.0)
	for r in MUD:
		draw_rect(r, Color(0.26, 0.2, 0.12, 0.65))
		draw_rect(r, Color(0.32, 0.25, 0.15), false, 2.0)
	for r in FENCES:
		draw_rect(r, Color(0.34, 0.26, 0.18))
		draw_rect(r, Color(0.5, 0.4, 0.28), false, 3.0)
	# the defence line + the allied banner Arthur is protecting
	draw_line(Vector2(-HALF.x, DEFENCE_Y), Vector2(HALF.x, DEFENCE_Y), Color(0.4, 0.6, 0.95, 0.4), 2.0)
	draw_line(GOAL_POS + Vector2(0, 20), GOAL_POS + Vector2(0, -34), Color(0.55, 0.45, 0.3), 4.0)
	draw_rect(Rect2(GOAL_POS.x, GOAL_POS.y - 34.0, 30.0, 20.0), Color(0.3, 0.55, 0.95))
	draw_rect(rect, Color(0.4, 0.36, 0.3), false, 6.0)  # boundary

func _draw_water(r: Rect2) -> void:
	draw_rect(r, Color(0.16, 0.34, 0.44, 0.78))
	var midy: float = r.position.y + r.size.y * 0.5
	draw_line(Vector2(r.position.x, midy), Vector2(r.position.x + r.size.x, midy),
		Color(0.45, 0.7, 0.8, 0.35), 2.0)
	draw_rect(r, Color(0.3, 0.55, 0.65, 0.5), false, 2.0)

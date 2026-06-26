class_name BattleMap
extends Node2D
## Reusable Three-Kingdoms battle-map base (Dynasty-Warriors / Musou style).
##
## A concrete map is a THIN subclass that overrides the build hooks below (walls, terrain,
## decor, allies, objectives, waves, theme). The base owns the whole orchestration — it
## instantiates Arthur + the HUD + the score screen, drives a `WaveSpawner`, runs an
## `ObjectiveManager`, tracks KO + elapsed time + (optional) breaches, and resolves win/lose.
##
## Build once, reuse many: every shared system (Enemy / Impact / Formation / TerrainZone /
## Objective / Spawner / WaveSpawner) is COMPOSED here, never re-implemented per map. To add a
## battle you write a tiny script `extends BattleMap` that fills `_build_wave_spawner()` and a
## few theme hooks — no level loop, no copy-paste.

const ARTHUR := preload("res://scenes/Arthur.tscn")
const HUD := preload("res://scenes/Hud.tscn")
const SCORE_SCREEN := preload("res://scenes/ui/ScoreScreen.tscn")
const GENERAL_HEALTHBAR := preload("res://scenes/ui/GeneralHealthbar.tscn")
const PAUSE_MENU := preload("res://scenes/ui/PauseMenu.tscn")

@export_group("Battle Tuning")
@export var density := 2.0                 ## scales wave counts (web-framerate dial)
@export var wave_interval := 16.0          ## seconds before the next wave is forced in
@export var wave_clear_threshold := 7      ## spawn the next wave once raiders drop to this
@export var max_breaches := 0              ## 0 = no defence line; >0 = lose after this many cross
@export var defence_line_y := 360.0        ## y a raider must pass to count as a breach

var arthur = null                          ## the hero (CharacterBody2D), instanced in _ready
var hud = null                             ## the HUD (CanvasLayer)
var _walls: StaticBody2D = null
var _objectives: ObjectiveManager = null
var _waves: WaveSpawner = null
var _wave := 0
var _wave_cd := 4.0
var _elapsed := 0.0
var _scan_cd := 0.0
var _won := false
var _lost := false
var _started := false
var _breaches := 0
var _breached := {}
var _ward = null                           ## a protected unit (ProtectBanner); null = none
var _had_ward := false                      ## a live ward was once seen (so a vanished ward = fallen)
var _score_screen = null
var _pause = null                          ## the reusable PauseMenu overlay (return-to-lobby)

func _ready() -> void:
	Impact.reset()
	_walls = StaticBody2D.new()
	_walls.name = "Walls"
	_walls.collision_layer = 1   # "world"
	_walls.collision_mask = 0
	add_child(_walls)
	_build_walls()
	_build_terrain()
	_build_decor()
	_place_goal()
	arthur = ARTHUR.instantiate()
	add_child(arthur)
	arthur.global_position = _arthur_start()
	if arthur.has_signal("died"):
		arthur.died.connect(_on_arthur_died)
	hud = HUD.instantiate()
	add_child(hud)
	hud.bind(arthur)
	_score_screen = SCORE_SCREEN.instantiate()
	add_child(_score_screen)
	# A boss healthbar overlay that auto-tracks any named generals (武將) on the field.
	add_child(GENERAL_HEALTHBAR.instantiate())
	# The reusable pause overlay — Esc / mobile MENU → Resume / Restart / Return to Lobby. Every
	# map and room gets it for free; no per-map wiring (PauseMenu owns its own toggle).
	_pause = PAUSE_MENU.instantiate()
	add_child(_pause)
	_spawn_allies()
	_objectives = _compose_objectives()
	_waves = _build_wave_spawner()
	# Open the battle already populated (troops from the start, with a sense of an ongoing
	# fight) instead of an empty arena that waits for wave 1 to pop in.
	_spawn_standing_host()
	Impact.popup(_opening_banner(), arthur.global_position + Vector2(0.0, -130.0),
		Color(0.95, 0.86, 0.5), 1.6)
	_evaluate()
	queue_redraw()

# ── subclass hooks (override these to make a map) ────────────────────────────
func _map_title() -> String: return "BATTLE"
func _opening_banner() -> String: return "TO ARMS!"
func _arthur_start() -> Vector2: return Vector2(0.0, 300.0)
func _world_bounds() -> Rect2: return Rect2(-640.0, -440.0, 1280.0, 900.0)
func _build_walls() -> void: _frame_walls(_world_bounds())   ## default: a bounding frame
func _build_terrain() -> void: pass
func _build_decor() -> void: pass
func _spawn_allies() -> void: pass
## Pre-place a standing enemy host so the battle OPENS populated (troops from the start), not an
## empty arena. Default: drop the first wave onto its lane at t=0 and advance the wave counter, so
## every map reads as an ongoing fight with zero per-map code. A map may override to muster a
## larger garrison or skip it (e.g. a duel that should start empty).
func _spawn_standing_host() -> void:
	if _waves != null and _wave_count() > 0 and _wave < _wave_count():
		var units: Array = _waves.spawn_wave(self, _wave)
		_on_wave_spawned(_wave, units)
		_wave += 1
		_started = true
		_wave_cd = wave_interval
func _compose_objectives() -> ObjectiveManager:
	var mgr := ObjectiveManager.new()
	mgr.add(RepelWavesObjective.new())
	return mgr
func _build_wave_spawner() -> WaveSpawner:
	return WaveSpawner.new()   ## subclass MUST override with real waves
func _extra_context(_ctx: Dictionary) -> void: pass   ## subclass adds ward_alive / custom keys
func _on_wave_spawned(idx: int, _units: Array) -> void:
	if arthur:
		Impact.popup("WAVE %d / %d" % [idx + 1, _wave_count()],
			arthur.global_position + Vector2(0.0, -150.0), Color(0.95, 0.7, 0.4), 1.3)

# ── wave driving ─────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if not (_won or _lost):
		_elapsed += delta
		_wave_cd -= delta
	_scan_cd -= delta
	if _scan_cd <= 0.0:
		_scan_cd = 0.15
		_update_waves()
		if max_breaches > 0:
			_check_breaches()
		_evaluate()

func _wave_count() -> int:
	return _waves.wave_count() if _waves != null else 0

func _update_waves() -> void:
	if _won or _lost or _wave >= _wave_count():
		return
	var alive := get_tree().get_nodes_in_group("targets").size()
	if alive <= _scale(wave_clear_threshold) or _wave_cd <= 0.0:
		var units: Array = _waves.spawn_wave(self, _wave)
		_on_wave_spawned(_wave, units)
		_wave += 1
		_started = true
		_wave_cd = wave_interval

# ── breaches (optional defence line) ─────────────────────────────────────────
func _check_breaches() -> void:
	if _won or _lost:
		return
	for e in get_tree().get_nodes_in_group("targets"):
		if not is_instance_valid(e):
			continue
		if "_dead" in e and e._dead:
			continue
		if e.global_position.y <= defence_line_y:
			continue
		var id := e.get_instance_id()
		if _breached.has(id):
			continue
		if "_stun" in e and e._stun > 0.0:
			continue
		_breached[id] = true
		_breaches += 1
		Impact.popup("BREACH!", e.global_position + Vector2(0.0, -28.0), Color(1.0, 0.4, 0.35), 1.1)
		e.queue_free()

# ── objectives / win-lose ────────────────────────────────────────────────────
func _build_context() -> Dictionary:
	var alive := get_tree().get_nodes_in_group("targets").size()
	# Track ward survival robustly: once a LIVE ward has been seen, a ward that later goes invalid
	# (freed after its death fade) counts as FALLEN — don't let a vanished ward read as "no ward to
	# protect" (which would silently pass ProtectBanner). A map with no ward leaves _had_ward false.
	if _ward != null and is_instance_valid(_ward):
		_had_ward = true
	var ward_ok: bool = (not _had_ward) or (is_instance_valid(_ward) and not ("_dead" in _ward and _ward._dead))
	var ctx := {
		"breaches": _breaches, "max_breaches": max_breaches,
		"wave": _wave, "wave_count": _wave_count(),
		"alive": alive, "total": maxi(alive, 1),
		"officers": get_tree().get_nodes_in_group("officers").size(),
		"generals": get_tree().get_nodes_in_group("generals").size(),
		"started": _started,
		"ward_alive": ward_ok,
		"kos": Impact.kills, "time": _elapsed,
	}
	_extra_context(ctx)
	return ctx

func _evaluate() -> void:
	if _won or _lost or _objectives == null:
		return
	var ctx := _build_context()
	_objectives.evaluate(ctx)
	if hud:
		hud.set_objective(_map_title() + "   " + _objectives.hud_line(ctx))
	if _objectives.lost:
		_defeat()
	elif _objectives.won:
		_victory()

func _victory() -> void:
	if _won or _lost:
		return
	_won = true
	# Record the win in the campaign so the lobby unlocks the next battle + marks this CLEARED.
	var c := get_node_or_null("/root/Campaign")
	if c:
		c.mark_completed(scene_file_path)
	if hud:
		hud.show_banner(_map_title() + " — VICTORY!", Color(0.5, 0.95, 0.55))
	_show_score(true)

func _defeat() -> void:
	if _won or _lost:
		return
	_lost = true
	if hud:
		hud.show_banner(_map_title() + " — DEFEAT", Color(0.95, 0.45, 0.4))
	_show_score(false)

func _on_arthur_died() -> void:
	if _won:
		return
	_lost = true
	if hud:
		hud.show_banner("ARTHUR HAS FALLEN", Color(0.95, 0.4, 0.4))
	_show_score(false)

## Reveal the result overlay and hand it the campaign context (the next battle to advance to and
## the story beat for that battle). Also locks the pause overlay — the result screen owns the
## choices now (Next / Retry / Return to Lobby).
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

# ── helpers (use these in subclasses) ────────────────────────────────────────
func _place_goal() -> void:
	## A march goal so raider AI advances downfield (Enemy steers toward the "ford_goal" group).
	var goal := Node2D.new()
	goal.add_to_group("ford_goal")
	goal.global_position = Vector2(0.0, _world_bounds().end.y - 40.0)
	add_child(goal)
	## A symmetric muster marker near the ENEMY spawn lane (north) so pre-placed ALLIES advance
	## toward the front from frame 0 instead of standing idle until a raider wanders into range.
	var ally_goal := Node2D.new()
	ally_goal.add_to_group("ally_goal")
	ally_goal.global_position = Vector2(0.0, _world_bounds().position.y + 90.0)
	add_child(ally_goal)

## A placeable terrain rule (mirrors Battlefield's inline zones). drag<1 slows; current pushes;
## dangerous routes AI around it; drown removes light units; mask = layers it affects.
func _add_zone(r: Rect2, drag: float, current: Vector2, dangerous: bool, drown: bool, mask: int) -> TerrainZone:
	var z := TerrainZone.new()
	z.drag = drag
	z.current = current
	z.dangerous = dangerous
	z.drowns_light = drown
	z.drown_mass_max = 0.7
	z.collision_layer = 0
	z.collision_mask = mask
	z.setup_rect(r)
	add_child(z)
	return z

func _frame_walls(b: Rect2) -> void:
	var t := 24.0
	_wall(Rect2(b.position.x, b.position.y - t, b.size.x, t))   # top
	_wall(Rect2(b.position.x, b.end.y, b.size.x, t))            # bottom
	_wall(Rect2(b.position.x - t, b.position.y, t, b.size.y))   # left
	_wall(Rect2(b.end.x, b.position.y, t, b.size.y))            # right

func _wall(r: Rect2) -> void:
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	cs.position = r.position + r.size * 0.5
	_walls.add_child(cs)

func _scale(n: int) -> int:
	return maxi(1, int(round(n * density)))

func _draw() -> void:
	var b := _world_bounds()
	draw_rect(b, Color(0.14, 0.13, 0.16))
	for x in range(int(b.position.x), int(b.end.x) + 1, 80):
		draw_line(Vector2(x, b.position.y), Vector2(x, b.end.y), Color(1, 1, 1, 0.03), 1.0)
	for y in range(int(b.position.y), int(b.end.y) + 1, 80):
		draw_line(Vector2(b.position.x, y), Vector2(b.end.x, y), Color(1, 1, 1, 0.03), 1.0)

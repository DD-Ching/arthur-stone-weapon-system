class_name FireZone
extends Area2D
## A placeable BURNING-GROUND hazard you drop anywhere (a burning ship deck, a torched
## field, a wall of flame). ONE script, many fires via exports — the hazard sibling of
## TerrainZone: TerrainZone shapes movement, FireZone deals damage over time.
##
## Every `tick` seconds it BURNS each Enemy body overlapping it — a small scored hit through
## the shared `Enemy.apply_hit(...)` path, so a unit can actually be killed by standing in the
## flames (kills feed Impact's KO counter exactly like any other defeat). It is cheap and
## web-safe: a single accumulator (no per-body timers), the Area's own overlap for detection,
## and a code-drawn `_draw()` flicker — no textures, no threads.
##
## Detection is the Area's collision_mask. Enemy + ally bodies live on layer 3 ("enemies",
## bit 4), so a mask of 4 burns BOTH sides that wade into the fire (groups "targets"/"allies").

@export var burn_dmg := 4.0                ## damage applied to each overlapping unit per tick
@export var burn_strength := 60.0          ## tiny upward shove per tick (a flinch, never a launch)
@export var tick := 0.4                    ## seconds between burn ticks
@export var size := Vector2(160.0, 120.0)  ## the fire's extent (its CollisionShape2D rect)

var _accum := 0.0                          ## time banked toward the next tick (one shared timer)
var _t := 0.0                              ## animation clock for the flame flicker
var _redraw_cd := 0.0                      ## throttle so a static fire reshimmers ~15x/sec, not 60x

func _ready() -> void:
	add_to_group("hazard")
	monitoring = true
	# Make sure we have ONE rect shape: an editor-placed FireZone ships its own (adopt its size so
	# `_draw` matches); a code-spawned one with no shape yet gets one built from `size`. setup_rect()
	# may already have sized/positioned a shape, in which case this just adopts it — no duplicate.
	var existing := _rect_shape()
	if existing != null:
		size = existing.shape.size
	else:
		_make_rect_shape(size)

## Place a fire of a given world rect from code (mirrors TerrainZone.setup_rect): size + centre
## the shape so the Area sits where you asked. Reuses the authored shape if the scene shipped one
## (so an instanced FireZone.tscn isn't given a second, overlapping CollisionShape2D).
func setup_rect(world_rect: Rect2) -> void:
	size = world_rect.size
	global_position = world_rect.position + world_rect.size * 0.5
	var cs := _rect_shape()
	if cs != null:
		cs.shape.size = world_rect.size
	else:
		_make_rect_shape(world_rect.size)

func _make_rect_shape(s: Vector2) -> void:
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = s
	cs.shape = shape
	add_child(cs)

## The zone's RectangleShape2D CollisionShape2D child, or null. Found by TYPE (not name) so an
## editor-placed shape works whatever it's called — same convention as TerrainZone._cache_rect.
func _rect_shape() -> CollisionShape2D:
	for c in get_children():
		if c is CollisionShape2D and c.shape is RectangleShape2D:
			return c
	return null

func _physics_process(delta: float) -> void:
	if not monitoring:
		return
	_accum += delta
	if _accum < tick:
		return
	_accum -= tick
	# Burn every unit currently standing in the flames. apply_hit's shield maths/scoring are
	# reused — fire ignores facing (a straight-up shove), so it can finish a shielded unit too.
	for b in get_overlapping_bodies():
		if not is_instance_valid(b):
			continue
		if not (b.is_in_group("targets") or b.is_in_group("allies")):
			continue
		if not b.has_method("apply_hit"):
			continue
		if "_dead" in b and b._dead:
			continue
		b.apply_hit(Vector2.UP, burn_strength, 0.0, burn_dmg, 0.0)

func _process(delta: float) -> void:
	# Flicker, but THROTTLED: a static fire only needs to reshimmer ~15x/sec, not every frame, so
	# the web build isn't re-tessellating every flame polygon at 60fps for an effect the eye can't
	# resolve. `_t` still advances continuously so the next redraw shows a smoothly moved flame.
	_t += delta
	_redraw_cd -= delta
	if _redraw_cd <= 0.0:
		_redraw_cd = 1.0 / 15.0
		queue_redraw()

# ── drawing (code-only, no textures) ─────────────────────────────────────────
func _draw() -> void:
	var half := size * 0.5
	var rect := Rect2(-half, size)
	# A dim charred base so the footprint reads even between flame tongues.
	draw_rect(rect, Color(0.18, 0.06, 0.03, 0.35))
	# Flame tongues: a row of flickering triangles whose height pulses out of phase, drawn
	# back-to-front (dark red → orange → yellow core) so they layer into a sheet of fire.
	var cols := maxi(3, int(size.x / 26.0))
	for i in range(cols):
		var fx: float = lerpf(-half.x + 10.0, half.x - 10.0, float(i) / float(maxi(1, cols - 1)))
		var phase := _t * 7.0 + float(i) * 1.7
		var h := 26.0 + 16.0 * sin(phase) + 8.0 * sin(phase * 2.3)
		var base_y := half.y
		var w := 11.0 + 3.0 * sin(phase * 1.3)
		# outer (dark red), mid (orange), inner (yellow) tongues, each shorter than the last.
		_flame(Vector2(fx, base_y), w, h, Color(0.75, 0.18, 0.08, 0.85))
		_flame(Vector2(fx, base_y), w * 0.7, h * 0.78, Color(0.95, 0.45, 0.12, 0.9))
		_flame(Vector2(fx, base_y), w * 0.4, h * 0.5, Color(1.0, 0.85, 0.35, 0.95))

## One flame tongue: a triangle from a base of width `w` up to a flickering tip of height `h`.
func _flame(base_centre: Vector2, w: float, h: float, col: Color) -> void:
	var pts := PackedVector2Array([
		base_centre + Vector2(-w * 0.5, 0.0),
		base_centre + Vector2(w * 0.5, 0.0),
		base_centre + Vector2(0.0, -h),
	])
	draw_colored_polygon(pts, col)

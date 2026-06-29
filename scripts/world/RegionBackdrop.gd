class_name RegionBackdrop
extends Node2D
## A distant-scenery silhouette band that gives a top-down battlefield a SENSE OF PLACE — the far
## edge of the world reads as castle towers, standing stones, a treeline, a burning fleet, rolling
## hills, cairns, a chapel, or layered mist. ONE reusable Node2D, configured by `kind` + colours;
## a map drops one near the north (enemy) edge from its `_build_decor`.
##
## Pure code-drawn, web-safe: a static silhouette + a soft haze gradient, drawn ONCE (no per-frame
## work) unless `animate` is on (a gently breathing glow for fire/mist). Placed as a decor child so
## it draws behind the units (which are added later). Span is centred on the node's local x=0; the
## band descends from y=0 (place the node at the world's top-centre).

@export_enum("hills", "castle", "stones", "treeline", "ships", "cairns", "chapel", "mist", "moor") var kind := "hills"
@export var span := 1280.0                       ## band width (centre it on the world)
@export var band_h := 150.0                      ## how far the haze reaches down into the field
@export var silhouette := Color(0.10, 0.10, 0.14, 0.9)
@export var haze_top := Color(0.20, 0.22, 0.30, 0.5)
@export var haze_bottom := Color(0.20, 0.22, 0.30, 0.0)
@export var glow := Color(1.0, 0.5, 0.2, 0.0)    ## a warm pool (e.g. burning ships); alpha 0 = none
@export var animate := false                     ## breathe the glow / drift the mist

var _t := 0.0
var _seed := 0.0

func _ready() -> void:
	add_to_group("decor")
	z_index = -50               # firmly behind units/props
	_seed = float(int(span) % 97)   # deterministic per placement (no Math.random dependency)
	queue_redraw()

func _process(delta: float) -> void:
	if not animate:
		return
	_t += delta
	queue_redraw()

func _draw() -> void:
	var half := span * 0.5
	# (1) A soft haze gradient band so the far edge fades into atmosphere instead of a hard line.
	var bands := 10
	for i in bands:
		var f := float(i) / float(bands - 1)
		var y0 := band_h * float(i) / float(bands)
		draw_rect(Rect2(-half, y0, span, band_h / float(bands) + 1.0), haze_top.lerp(haze_bottom, f))
	# (2) An optional warm glow pool (burning fleet / camp fires beyond the field).
	if glow.a > 0.0:
		var breathe := 1.0 if not animate else (0.78 + 0.22 * sin(_t * 2.3 + _seed))
		var g := Color(glow.r, glow.g, glow.b, glow.a * breathe)
		draw_circle(Vector2(0.0, band_h * 0.35), span * 0.42, g)
	# (3) The silhouette itself, sitting on the band's baseline (y ~ band_h*0.62).
	var base := band_h * 0.62
	match kind:
		"castle": _castle(half, base)
		"stones": _stones(half, base)
		"treeline": _treeline(half, base)
		"ships": _ships(half, base)
		"cairns": _cairns(half, base)
		"chapel": _chapel(half, base)
		"mist": _mist(half, base)
		"moor": _moor(half, base)
		_: _hills(half, base)

# ── silhouette kinds (cheap polygons; dark, far-away shapes) ──────────────────
func _hills(half: float, base: float) -> void:
	# Two rolling overlapping mounds across the span.
	for s in [-1.0, 1.0]:
		var c := Vector2(s * half * 0.45, base)
		var pts := PackedVector2Array()
		for i in range(13):
			var f := float(i) / 12.0
			var x := c.x + lerpf(-half * 0.55, half * 0.55, f)
			var y := base - sin(f * PI) * (band_h * 0.5)
			pts.append(Vector2(x, y))
		pts.append(Vector2(c.x + half * 0.55, base + band_h))
		pts.append(Vector2(c.x - half * 0.55, base + band_h))
		draw_colored_polygon(pts, silhouette)

func _castle(half: float, base: float) -> void:
	# A curtain wall with crenellations + a few towers.
	var wall_h := band_h * 0.42
	draw_rect(Rect2(-half * 0.7, base - wall_h, half * 1.4, wall_h + band_h), silhouette)
	var merlon := 14.0
	var x := -half * 0.7
	while x < half * 0.7:
		draw_rect(Rect2(x, base - wall_h - 10.0, merlon, 10.0), silhouette)
		x += merlon * 2.0
	for tx in [-half * 0.55, -half * 0.18, half * 0.18, half * 0.55]:
		var tw := 46.0
		var th := wall_h + band_h * 0.5
		draw_rect(Rect2(tx - tw * 0.5, base - th, tw, th + band_h), silhouette)
		# tower crenellations + a conical roof
		var roof := PackedVector2Array([
			Vector2(tx - tw * 0.6, base - th), Vector2(tx + tw * 0.6, base - th),
			Vector2(tx, base - th - 30.0)])
		draw_colored_polygon(roof, silhouette)

func _stones(half: float, base: float) -> void:
	# A ring of standing megaliths. (Explicit float types: the loop var is a Variant from an array
	# literal, so := inference is order-dependent — type the locals so it can never fail.)
	for sx in [-half * 0.6, -half * 0.32, -half * 0.05, half * 0.22, half * 0.5]:
		var x: float = float(sx)
		var w: float = 26.0 + float(int(x) % 13)
		var h: float = band_h * 0.7 + float(int(x) % 30)
		draw_rect(Rect2(x - w * 0.5, base - h, w, h + band_h), silhouette)
	# a lintel across two of them
	draw_rect(Rect2(-half * 0.6, base - band_h * 0.7, half * 0.3, 16.0), silhouette)

func _treeline(half: float, base: float) -> void:
	var x: float = -half * 0.75
	while x < half * 0.75:
		var h: float = band_h * (0.5 + 0.35 * abs(sin(x * 0.013)))
		var w: float = 34.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - w, base + band_h), Vector2(x + w, base + band_h), Vector2(x, base - h)]),
			silhouette)
		x += 40.0

func _ships(half: float, base: float) -> void:
	# Longship hulls beyond the shore (pair with a warm `glow` for "burning fleet").
	for sx in [-half * 0.5, -half * 0.1, half * 0.3]:
		var hull := PackedVector2Array([
			Vector2(sx - 70.0, base), Vector2(sx + 70.0, base),
			Vector2(sx + 50.0, base + 22.0), Vector2(sx - 50.0, base + 22.0)])
		draw_colored_polygon(hull, silhouette)
		draw_line(Vector2(sx, base), Vector2(sx, base - band_h * 0.6), silhouette, 4.0)   # mast
		# a curled prow
		draw_line(Vector2(sx - 70.0, base), Vector2(sx - 86.0, base - 24.0), silhouette, 4.0)

func _cairns(half: float, base: float) -> void:
	for sx in [-half * 0.5, -half * 0.12, half * 0.22, half * 0.55]:
		var pts := PackedVector2Array([
			Vector2(sx - 50.0, base + band_h), Vector2(sx + 50.0, base + band_h),
			Vector2(sx, base - band_h * 0.55)])
		draw_colored_polygon(pts, silhouette)

func _chapel(half: float, base: float) -> void:
	# A small chapel (nave + steepled tower) flanked by two yews.
	draw_rect(Rect2(-60.0, base - band_h * 0.4, 120.0, band_h * 0.4 + band_h), silhouette)
	draw_rect(Rect2(40.0, base - band_h * 0.62, 36.0, band_h * 0.62 + band_h), silhouette)
	draw_colored_polygon(PackedVector2Array([
		Vector2(36.0, base - band_h * 0.62), Vector2(80.0, base - band_h * 0.62),
		Vector2(58.0, base - band_h * 0.95)]), silhouette)
	for yx in [-130.0, 150.0]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(yx - 34.0, base + band_h), Vector2(yx + 34.0, base + band_h),
			Vector2(yx, base - band_h * 0.5)]), silhouette)

func _mist(half: float, base: float) -> void:
	# Avalon: low layered hills lost in mist (soft, no hard silhouette).
	for layer in range(3):
		var a := silhouette.a * (0.5 - layer * 0.14)
		var col := Color(silhouette.r, silhouette.g, silhouette.b, maxf(a, 0.08))
		var yy := base - band_h * 0.2 + layer * 16.0
		var pts := PackedVector2Array()
		for i in range(17):
			var f := float(i) / 16.0
			pts.append(Vector2(lerpf(-half, half, f), yy - sin(f * PI * 2.0 + layer) * 14.0))
		pts.append(Vector2(half, base + band_h)); pts.append(Vector2(-half, base + band_h))
		draw_colored_polygon(pts, col)

func _moor(half: float, base: float) -> void:
	# A bleak tor with scattered crags.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-half * 0.35, base + band_h), Vector2(half * 0.15, base + band_h),
		Vector2(-half * 0.05, base - band_h * 0.7)]), silhouette)
	for sx in [-half * 0.6, half * 0.4, half * 0.62]:
		draw_rect(Rect2(sx - 18.0, base - band_h * 0.3, 36.0, band_h * 0.3 + band_h), silhouette)

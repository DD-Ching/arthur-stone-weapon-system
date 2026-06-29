class_name GroundPaint
## Shared ground painter — ONE place that turns a floor rect into a value-gradient + seeded dapple
## + soft edge darkening, so every level reads the same and NONE falls back to a graph-paper grid.
## Build-once-reuse-many: BattleMap regions, Hold the Ford, and the Arena all paint through this.
##
## Web-safe: pure static funcs, deterministic (seeded), no per-frame allocation. The draw_* calls
## are issued on the CALLER's CanvasItem during ITS _draw() (so `ci` is the node painting itself).

## A deterministic dapple — soft dark/light blobs (Array of Vector3 x,y,radius) for a rect. Build it
## once and cache on the caller (same every boot from the seed), then hand it to draw_floor().
static func make_dapple(rect: Rect2, seed_val: int, count := 150) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var out: Array = []
	for _i in count:
		out.append(Vector3(
			rng.randf_range(rect.position.x, rect.end.x),
			rng.randf_range(rect.position.y, rect.end.y),
			rng.randf_range(7.0, 26.0)))
	return out

## Paint the floor onto `ci`: a 14-band vertical value gradient (top -> bottom), the seeded dapple,
## and (optionally) a soft in-world edge darkening that settles the frame. Call from a node's _draw.
static func draw_floor(ci: CanvasItem, rect: Rect2, top: Color, bottom: Color, dapple: Array, edge := true) -> void:
	var bands := 14
	for i in bands:
		var y0 := rect.position.y + rect.size.y * float(i) / float(bands)
		ci.draw_rect(Rect2(rect.position.x, y0, rect.size.x, rect.size.y / float(bands) + 1.0),
			top.lerp(bottom, float(i) / float(bands - 1)))
	for j in dapple.size():
		var d: Vector3 = dapple[j]
		var c := Color(0.0, 0.0, 0.0, 0.06) if (j % 2 == 0) else Color(0.85, 0.8, 0.7, 0.03)
		ci.draw_circle(Vector2(d.x, d.y), d.z, c)
	if edge:
		var ec := Color(0.0, 0.0, 0.0, 0.16)
		var t := 56.0
		ci.draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, t), ec)
		ci.draw_rect(Rect2(rect.position.x, rect.end.y - t, rect.size.x, t), ec)
		ci.draw_rect(Rect2(rect.position.x, rect.position.y, t, rect.size.y), ec)
		ci.draw_rect(Rect2(rect.end.x - t, rect.position.y, t, rect.size.y), ec)

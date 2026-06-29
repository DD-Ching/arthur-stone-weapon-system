extends Control
## Worldmap — the MAP OF BRITAIN overworld. The game's boot scene + the "lobby" every battle
## returns to. Replaces the flat stage-select list with a CONNECTED JOURNEY: the ten legend regions
## are pins on a hand-inked parchment map, joined by a road that lights as you clear it, with
## Arthur's banner-marker standing at the region you've reached. This is the fix for "random
## separate levels / no sense of journey".
##
## Build once, reuse many: every node, position, link, and lock/clear state comes from the Campaign
## autoload (the single source of truth — Campaign.legend_stages()/map_pos_for()/links_for()/
## is_unlocked()/is_cleared()). Deploys through the shared Transition fade. The parchment floor uses
## the same GroundPaint painter as the battlefields. ASCII + colour only (web-font tofu gotcha).
##
## Public surface (driven by tests/worldmap_test.gd, kept stable):
##   `nodes`        — Array of the legend regions, in road order: {id,title,path,unlocked,cleared,lx,ly}.
##   `selected`     — index into `nodes` of the highlighted region.
##   `_move(dir)`   — wrapping navigation along the road.
##   `selected_path()` / `selected_unlocked()` — the chosen scene + whether it can be deployed.
##   `TITLE_TEXT`   — re-exposed (asserted Arthurian, never "三國").

const TRAINING_LIST := "res://scenes/ui/StageSelect.tscn"   # the full battle list / training yard
const TITLE_TEXT := "THE STONE KING — ARTHUR'S CAMPAIGN"
const SUBTITLE := "The Legend of King Arthur — choose where the road leads"
const HINT := "W/S or Up/Down to travel   ·   Space / Enter to ride out   ·   or TAP a region"

# --- parchment + ink palette -------------------------------------------------
const PARCH_TOP := Color(0.85, 0.78, 0.60)
const PARCH_BOTTOM := Color(0.74, 0.65, 0.46)
const SEA := Color(0.36, 0.46, 0.50, 1.0)
const INK := Color(0.26, 0.19, 0.12)
const ROAD_DONE := Color(0.80, 0.62, 0.24)        ## the walked road — gilded
const ROAD_OPEN := Color(0.34, 0.27, 0.17, 0.85)  ## the road ahead — faint ink
const PIN_CLEARED := Color(0.42, 0.62, 0.34)       ## a planted banner (green-gold)
const PIN_CURRENT := Color(0.95, 0.80, 0.32)       ## the region you've reached (glows)
const PIN_OPEN := Color(0.80, 0.66, 0.30)          ## unlocked, not yet your front
const PIN_LOCKED := Color(0.48, 0.44, 0.38)        ## sealed (beyond the road so far)
const LABEL := Color(0.20, 0.14, 0.09)
const TITLE_COL := Color(0.32, 0.22, 0.10)

var nodes: Array = []        ## [{id,title,path,unlocked,cleared,lx,ly}], in road order
var selected := 0
var _dapple: Array = []
var _t := 0.0
var _font: Font
var _deploy_btn: Button
var _train_btn: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = get_theme_default_font()
	_build_nodes()
	_build_footer()
	selected = _current_index()
	set_process(true)
	set_process_input(true)
	queue_redraw()

# --- data (from Campaign) ----------------------------------------------------
func _campaign():
	var tree := get_tree()
	if tree and tree.root and tree.root.has_node("Campaign"):
		return tree.root.get_node("Campaign")
	if typeof(Campaign) != TYPE_NIL:
		return Campaign
	return null

## Build the ordered region list from Campaign's legend, keeping only scenes that exist on disk.
## Untyped loop var: legend_stages() returns Dictionaries inside an Array (Variant) — `:=` would
## fail to infer (the GDScript 4.3 pitfall).
func _build_nodes() -> void:
	nodes = []
	var camp = _campaign()
	if camp == null:
		return
	var legend: Array = camp.legend_stages()
	for s in legend:
		var path: String = String(s.get("path", ""))
		if path == "" or not ResourceLoader.exists(path):
			continue
		var pos: Vector2 = camp.map_pos_for(path)
		nodes.append({
			"id": String(s.get("id", "")),
			"title": String(s.get("title", "")),
			"path": path,
			"unlocked": camp.is_unlocked(path),
			"cleared": camp.is_cleared(path),
			"lx": pos.x, "ly": pos.y,
		})

## The region the player has "reached": the first unlocked-but-uncleared node (their front), or the
## last cleared node if the legend is complete, or 0.
func _current_index() -> int:
	for i in nodes.size():
		if nodes[i]["unlocked"] and not nodes[i]["cleared"]:
			return i
	var last := 0
	for i in nodes.size():
		if nodes[i]["cleared"]:
			last = i
	return last

# --- screen mapping ----------------------------------------------------------
## The logical bounds of the map coordinates (from Campaign), padded a touch.
func _logical_bounds() -> Rect2:
	if nodes.is_empty():
		return Rect2(0, 0, 1, 1)
	var mn := Vector2(1.0e9, 1.0e9)
	var mx := Vector2(-1.0e9, -1.0e9)
	for n in nodes:
		mn.x = minf(mn.x, float(n["lx"]))
		mn.y = minf(mn.y, float(n["ly"]))
		mx.x = maxf(mx.x, float(n["lx"]))
		mx.y = maxf(mx.y, float(n["ly"]))
	var pad := 70.0
	return Rect2(mn - Vector2(pad, pad), (mx - mn) + Vector2(pad, pad) * 2.0)

## The on-screen rectangle the map is painted into (inset for the title band + footer).
func _map_area() -> Rect2:
	var s := size
	var top := 96.0
	var bottom := 84.0
	var side := 56.0
	return Rect2(side, top, maxf(s.x - side * 2.0, 1.0), maxf(s.y - top - bottom, 1.0))

func _screen_pos(lx: float, ly: float) -> Vector2:
	var lb := _logical_bounds()
	var area := _map_area()
	var fx := (lx - lb.position.x) / maxf(lb.size.x, 1.0)
	var fy := (ly - lb.position.y) / maxf(lb.size.y, 1.0)
	return area.position + Vector2(fx * area.size.x, fy * area.size.y)

func _node_screen(i: int) -> Vector2:
	return _screen_pos(float(nodes[i]["lx"]), float(nodes[i]["ly"]))

func _index_of_id(id: String) -> int:
	for i in nodes.size():
		if String(nodes[i]["id"]) == id:
			return i
	return -1

# --- footer (deploy + training yard) -----------------------------------------
func _build_footer() -> void:
	_deploy_btn = Button.new()
	_deploy_btn.text = "RIDE OUT"
	_deploy_btn.focus_mode = Control.FOCUS_NONE
	_deploy_btn.custom_minimum_size = Vector2(200, 50)
	_deploy_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_deploy_btn.offset_left = -224.0
	_deploy_btn.offset_top = -66.0
	_deploy_btn.offset_right = -24.0
	_deploy_btn.offset_bottom = -16.0
	_deploy_btn.add_theme_color_override("font_color", Color(0.98, 0.93, 0.80))
	_deploy_btn.add_theme_stylebox_override("normal", _flat(Color(0.55, 0.18, 0.16), Color(0.86, 0.40, 0.30)))
	_deploy_btn.add_theme_stylebox_override("hover", _flat(Color(0.68, 0.22, 0.20), Color(0.92, 0.46, 0.34)))
	_deploy_btn.add_theme_stylebox_override("pressed", _flat(Color(0.68, 0.22, 0.20), Color(0.92, 0.46, 0.34)))
	_deploy_btn.pressed.connect(_deploy)
	add_child(_deploy_btn)

	_train_btn = Button.new()
	_train_btn.text = "TRAINING YARD"
	_train_btn.focus_mode = Control.FOCUS_NONE
	_train_btn.custom_minimum_size = Vector2(190, 50)
	_train_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_train_btn.offset_left = 24.0
	_train_btn.offset_top = -66.0
	_train_btn.offset_right = 214.0
	_train_btn.offset_bottom = -16.0
	_train_btn.add_theme_color_override("font_color", Color(0.96, 0.90, 0.74))
	_train_btn.add_theme_stylebox_override("normal", _flat(Color(0.30, 0.24, 0.14), Color(0.55, 0.44, 0.24)))
	_train_btn.add_theme_stylebox_override("hover", _flat(Color(0.38, 0.30, 0.18), Color(0.70, 0.56, 0.30)))
	_train_btn.add_theme_stylebox_override("pressed", _flat(Color(0.38, 0.30, 0.18), Color(0.70, 0.56, 0.30)))
	_train_btn.pressed.connect(_open_training)
	add_child(_train_btn)

func _flat(fill: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	return sb

# --- navigation / deploy -----------------------------------------------------
## Move the highlighted region by `dir` along the road order, wrapping.
func _move(dir: int) -> void:
	if nodes.is_empty():
		return
	selected = wrapi(selected + dir, 0, nodes.size())
	queue_redraw()

func selected_path() -> String:
	if selected < 0 or selected >= nodes.size():
		return ""
	return String(nodes[selected]["path"])

func selected_unlocked() -> bool:
	if selected < 0 or selected >= nodes.size():
		return false
	return bool(nodes[selected]["unlocked"])

## Ride out to the highlighted region (only if its road is open). A sealed region just nudges.
func _deploy() -> void:
	if not selected_unlocked():
		return
	var path := selected_path()
	if path == "" or not ResourceLoader.exists(path):
		return
	_goto(path)

func _open_training() -> void:
	_goto(TRAINING_LIST)

func _goto(path: String) -> void:
	var tr := get_node_or_null("/root/Transition")
	if tr:
		tr.change_scene(path)
	else:
		get_tree().change_scene_to_file(path)

# --- input -------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if nodes.is_empty():
		return
	if event.is_action_pressed("move_down") or event.is_action_pressed("move_right"):
		_move(1); _consume()
	elif event.is_action_pressed("move_up") or event.is_action_pressed("move_left"):
		_move(-1); _consume()
	elif event.is_action_pressed("attack") or _is_enter(event):
		_deploy(); _consume()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pick(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_pick(event.position)

## A click/tap on a region pin selects it; tapping the already-selected (open) region rides out.
func _pick(p: Vector2) -> void:
	var hit := _pin_at(p)
	if hit < 0:
		return
	if hit == selected and bool(nodes[hit]["unlocked"]):
		_deploy()
	else:
		selected = hit
		queue_redraw()
	_consume()

func _pin_at(p: Vector2) -> int:
	for i in nodes.size():
		if _node_screen(i).distance_to(p) <= 24.0:
			return i
	return -1

func _consume() -> void:
	var vp := get_viewport()
	if vp:
		vp.set_input_as_handled()

func _is_enter(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER
	return false

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()   # the marker + current-pin pulse breathe; cheap on a static map screen

# --- drawing -----------------------------------------------------------------
func _draw() -> void:
	var s := size
	# (1) The sea behind everything, then the parchment landmass painted with the shared floor
	#     painter so the map reads like aged vellum, not a flat panel.
	draw_rect(Rect2(Vector2.ZERO, s), SEA)
	var area := _map_area()
	var land := area.grow(28.0)
	if _dapple.is_empty():
		_dapple = GroundPaint.make_dapple(land, 0x10C1E5)
	GroundPaint.draw_floor(self, land, PARCH_TOP, PARCH_BOTTOM, _dapple, false)
	# A torn ink coastline around the land.
	draw_rect(land, INK, false, 3.0)

	if nodes.is_empty():
		_text_centered("(no regions found)", Vector2(s.x * 0.5, s.y * 0.5), 22, LABEL)
		_draw_title()
		return

	# (2) The road of the legend — a line from each region to the ones it links to. Walked
	#     segments (the source region is cleared) are gilded + solid; the road ahead is faint ink.
	for i in nodes.size():
		var a := _node_screen(i)
		for lid in _links_of(i):
			var j := _index_of_id(lid)
			if j < 0:
				continue
			var b := _node_screen(j)
			if bool(nodes[i]["cleared"]):
				draw_line(a, b, ROAD_DONE, 5.0)
			else:
				_dashed(a, b, ROAD_OPEN, 3.0)

	# (3) The region pins, then the labels, then Arthur's marker on his current front.
	var cur := _current_index()
	for i in nodes.size():
		_draw_pin(i, i == cur)
	for i in nodes.size():
		var c := _node_screen(i)
		_text_centered(String(nodes[i]["title"]), c + Vector2(0.0, 30.0), 15, LABEL)
	if cur >= 0 and cur < nodes.size():
		_draw_marker(_node_screen(cur))

	# (4) The selection ring on the highlighted region.
	if selected >= 0 and selected < nodes.size():
		var sc := _node_screen(selected)
		draw_arc(sc, 22.0, 0.0, TAU, 28, Color(0.95, 0.30, 0.26), 3.0)

	_draw_title()

func _draw_pin(i: int, is_current: bool) -> void:
	var c := _node_screen(i)
	var cleared: bool = bool(nodes[i]["cleared"])
	var unlocked: bool = bool(nodes[i]["unlocked"])
	var col := PIN_LOCKED
	if cleared:
		col = PIN_CLEARED
	elif is_current:
		col = PIN_CURRENT
	elif unlocked:
		col = PIN_OPEN
	# A soft glow under the current/open pins.
	if unlocked:
		var pulse := 0.5 + 0.5 * sin(_t * 3.0)
		var glow_a := (0.22 if is_current else 0.10) * (0.6 + 0.4 * pulse)
		draw_circle(c, 26.0, Color(col.r, col.g, col.b, glow_a))
	draw_circle(c, 13.0, col)
	draw_arc(c, 13.0, 0.0, TAU, 22, INK, 2.0)
	if cleared:
		# a tiny planted banner to read "won"
		draw_line(c + Vector2(0, -6), c + Vector2(0, -20), INK, 2.0)
		draw_rect(Rect2(c + Vector2(0, -20), Vector2(12, 8)), PIN_CLEARED)
	elif not unlocked:
		# a sealed cross-bar (sealed road ahead) — ASCII-free, just two ink strokes
		draw_line(c + Vector2(-6, 0), c + Vector2(6, 0), INK.darkened(0.1), 3.0)

## Arthur's banner-marker: a pole + a small Pendragon-red pennant that bobs, standing on the front.
func _draw_marker(c: Vector2) -> void:
	var bob := sin(_t * 2.2) * 2.0
	var top := c + Vector2(2.0, -46.0 + bob)
	draw_line(c + Vector2(2.0, -10.0), top, Color(0.30, 0.24, 0.16), 3.0)
	var flag := PackedVector2Array([
		top, top + Vector2(26.0, 6.0), top + Vector2(24.0, 14.0), top + Vector2(0.0, 18.0)])
	draw_colored_polygon(flag, Color(0.70, 0.18, 0.18))
	draw_circle(top + Vector2(13.0, 10.0), 3.0, Color(0.95, 0.86, 0.5))

func _draw_title() -> void:
	var s := size
	_text_centered(TITLE_TEXT, Vector2(s.x * 0.5, 38.0), 32, TITLE_COL)
	_text_centered(SUBTITLE, Vector2(s.x * 0.5, 66.0), 15, Color(0.40, 0.30, 0.16))
	# progress + hint along the footer band
	var camp = _campaign()
	if camp != null and camp.has_method("cleared_count") and camp.has_method("total"):
		_text_left("Battles cleared: %d / %d" % [camp.cleared_count(), camp.total()],
			Vector2(232.0, s.y - 40.0), 14, Color(0.30, 0.42, 0.24))
	_text_centered(HINT, Vector2(s.x * 0.5, s.y - 38.0), 13, Color(0.40, 0.32, 0.20))

# --- draw helpers ------------------------------------------------------------
func _links_of(i: int) -> Array:
	var camp = _campaign()
	if camp == null:
		return []
	return camp.links_for(String(nodes[i]["path"]))

func _dashed(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var d := b - a
	var dist := d.length()
	if dist < 1.0:
		return
	var dir := d / dist
	var step := 18.0
	var t := 0.0
	while t < dist:
		var seg := minf(10.0, dist - t)
		draw_line(a + dir * t, a + dir * (t + seg), col, w)
		t += step

func _text_centered(txt: String, at: Vector2, fs: int, col: Color) -> void:
	if _font == null:
		return
	var sz := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(_font, at - Vector2(sz.x * 0.5, 0.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _text_left(txt: String, at: Vector2, fs: int, col: Color) -> void:
	if _font == null:
		return
	draw_string(_font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

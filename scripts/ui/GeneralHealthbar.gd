extends CanvasLayer
## GeneralHealthbar — a boss-style HP overlay for named generals (武將).
##
## A self-contained CanvasLayer that WATCHES the "generals" group (an Enemy joins it via
## its `is_general` export) and draws one boss health bar near the top of the screen for
## each live general: the general's `enemy_name`, a fill bar (`health / max_health`) tinted
## by the general's `faction_color()`. With no generals present it hides entirely.
##
## Reuse: a level/map just adds a `GeneralHealthbar` instance — it needs NO wiring. It owns
## no game state and never mutates a general; it only reads public fields. Cheap + web-safe:
## a single Control with one `_draw`, refreshed on a light timer (no per-frame allocations
## beyond rebuilding the small tracked list a few times a second). Supports 1–3 generals
## stacked; extra generals beyond the cap are ignored so the bar can't fill the screen.

const MAX_BARS := 3                      ## stack at most this many bars (1–3 supported)
const BAR_W := 520.0                     ## bar width in pixels
const BAR_H := 22.0                      ## fill height in pixels
const ROW_H := 52.0                      ## per-general row pitch (label + bar + gap)
const TOP := 34.0                        ## first row's top offset from the screen top
const REFRESH := 0.1                     ## seconds between tracked-list rebuilds (light timer)

var _root: Control                       ## full-rect host that does the drawing
var _accum := 0.0                        ## time since the last refresh
# Per-general snapshot rebuilt on the refresh tick (no per-frame group scans / allocations):
# each entry is {name:String, ratio:float, color:Color, id:int}. The test reads these.
var _bars: Array = []

func _ready() -> void:
	layer = 32                           # above the world + HUD (layer 1), below the score screen (64)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.draw.connect(_draw_bars)
	add_child(_root)
	_refresh()                           # seed immediately so a one-frame test sees state

func _process(delta: float) -> void:
	_accum += delta
	if _accum >= REFRESH:
		_accum = 0.0
		_refresh()

## Rebuild the small tracked-general snapshot from the "generals" group. Skips dead/invalid
## units, caps at MAX_BARS, and hides the overlay (no redraw cost) when nothing is tracked.
func _refresh() -> void:
	_bars.clear()
	for g in get_tree().get_nodes_in_group("generals"):
		if not is_instance_valid(g):
			continue
		# A general that has fallen (Enemy._dead) drops off the bar immediately, like the HUD.
		if "_dead" in g and g._dead:
			continue
		var mx: float = g.max_health if "max_health" in g else 0.0
		if mx <= 0.0:
			continue
		var cur: float = g.health if "health" in g else 0.0
		var nm: String = g.enemy_name if "enemy_name" in g else "GENERAL"
		var col := Color(0.8, 0.3, 0.3)
		if g.has_method("faction_color"):
			col = g.faction_color()
		_bars.append({
			"name": nm,
			"ratio": clampf(cur / mx, 0.0, 1.0),
			"color": col,
			"id": g.get_instance_id(),
		})
		if _bars.size() >= MAX_BARS:
			break
	visible = _bars.size() > 0
	if visible and _root:
		_root.queue_redraw()

func _draw_bars() -> void:
	var font := ThemeDB.fallback_font
	# Centre against the live VIEWPORT width, not the anchored Control's `size` — under the
	# project's "expand" stretch mode the latter can lag a resize or read 0 before first layout,
	# which would mis-centre or clip the bar. (TouchControls sources its layout the same way.)
	var screen_w: float = _root.get_viewport_rect().size.x
	var x := (screen_w - BAR_W) * 0.5
	for i in range(_bars.size()):
		var bar: Dictionary = _bars[i]
		var y := TOP + ROW_H * float(i)
		var accent: Color = bar["color"]
		var ratio: float = bar["ratio"]
		# Name above the bar, in the faction accent so the kingdom reads at a glance.
		_root.draw_string(font, Vector2(x, y - 4.0), str(bar["name"]),
			HORIZONTAL_ALIGNMENT_LEFT, BAR_W, 18, accent)
		var bar_y := y + 6.0
		# Track (dark backing) → frame → fill, in the ugly-but-clear HUD style.
		_root.draw_rect(Rect2(x - 3.0, bar_y - 3.0, BAR_W + 6.0, BAR_H + 6.0), Color(0.06, 0.06, 0.08, 0.85))
		_root.draw_rect(Rect2(x, bar_y, BAR_W, BAR_H), Color(0.18, 0.16, 0.18, 0.9))
		var fill := accent.lerp(Color(0.9, 0.2, 0.2), 0.25)
		_root.draw_rect(Rect2(x, bar_y, BAR_W * ratio, BAR_H), fill)
		_root.draw_rect(Rect2(x - 3.0, bar_y - 3.0, BAR_W + 6.0, BAR_H + 6.0), accent, false, 2.0)

# ── read-only API (for levels / the headless test) ──────────────────────────────

## How many generals the bar is currently tracking (0 → hidden).
func tracked_count() -> int:
	return _bars.size()

## The health ratio (0..1) of the i-th tracked general, or -1.0 if out of range.
func ratio_for(i: int) -> float:
	if i < 0 or i >= _bars.size():
		return -1.0
	return _bars[i]["ratio"]

## The displayed name of the i-th tracked general, or "" if out of range.
func name_for(i: int) -> String:
	if i < 0 or i >= _bars.size():
		return ""
	return str(_bars[i]["name"])

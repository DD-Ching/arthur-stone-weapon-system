extends CanvasLayer
## Vignette — a static, screen-space dark-edge frame that sits over the world.
##
## A subtle radial-ish edge darkening that frames every battle and makes the swarm pop. It is
## ONE reusable overlay: BattleMap instances it once in _ready, so every map AND every challenge
## room gets the same framing for free — no per-map art, no per-frame cost.
##
## Layering (build-once-reuse-many): the world draws on the default 2D canvas (layer 0) and the
## HUD is a CanvasLayer at layer 1, with GeneralHealthbar (32), ScoreScreen (64) and PauseMenu
## (80) above it. This vignette sits at layer 0 — an explicit CanvasLayer at layer 0 draws OVER
## the default world canvas but UNDER the HUD (layer 1) and every overlay above it. So the dark
## edges frame the battlefield without ever dimming the HUD bars, the pause menu, or the score
## screen.
##
## It is a single full-rect Control with mouse_filter IGNORE that draws in _draw() and only
## redraws on a viewport resize — static and cheap (no _process, no per-frame allocation).

## Corner darkness — the alpha of black at the very corners. Kept SUBTLE so the centre stays clear.
const CORNER_ALPHA := 0.35
## How many concentric translucent bands to stack from each edge inward. More = smoother falloff.
const BANDS := 7
## Fraction of the smaller screen dimension the darkening reaches inward from each edge.
const REACH := 0.42

var _frame: Control

func _ready() -> void:
	# Layer 0: over the default-canvas world, under the HUD (layer 1) + every overlay above it.
	layer = 0
	_frame = Control.new()
	_frame.name = "VignetteFrame"
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Anchored full-rect so it always spans the whole viewport.
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.draw.connect(_draw_vignette)
	add_child(_frame)
	# Redraw on resize only (static otherwise) — the rect changes, the look doesn't.
	var vp := get_viewport()
	if vp:
		vp.size_changed.connect(_frame.queue_redraw)
	_frame.queue_redraw()

## Draw the edge darkening as a stack of translucent black border bands that thicken toward the
## corners — concentric inset frames, each adding a hair of black, so the corners reach
## CORNER_ALPHA (most overlap) while the centre is left untouched. Pure screen-space, recomputed
## only on resize.
func _draw_vignette() -> void:
	var size := _frame.size
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var reach: float = minf(size.x, size.y) * REACH
	# Per-band alpha so the SUM across the overlapping outer bands approaches CORNER_ALPHA at a corner.
	var band_alpha: float = CORNER_ALPHA / float(BANDS)
	var col := Color(0.0, 0.0, 0.0, band_alpha)
	for i in BANDS:
		# Band i is the ring between inset f_out (outer) and f_in (inner). The outer bands overlap
		# the most near the edge, so the darkening is densest at the frame and fades smoothly inward.
		var f_out: float = reach * float(i) / float(BANDS)
		var f_in: float = reach * float(i + 1) / float(BANDS)
		var thick: float = f_in - f_out
		# Top strip (full width of the band).
		_frame.draw_rect(Rect2(f_out, f_out, size.x - f_out * 2.0, thick), col)
		# Bottom strip.
		_frame.draw_rect(Rect2(f_out, size.y - f_in, size.x - f_out * 2.0, thick), col)
		# Left strip (inset vertically so the corners stack with the top/bottom, not double-seam).
		_frame.draw_rect(Rect2(f_out, f_in, thick, size.y - f_in * 2.0), col)
		# Right strip.
		_frame.draw_rect(Rect2(size.x - f_in, f_in, thick, size.y - f_in * 2.0), col)

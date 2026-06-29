class_name CaptureBasesObjective
extends Objective
## Capture the depots: complete once every supply base on the map has been taken. Reusable
## for any "seize N points" battle (the Beacon-Forts' supply depots, but also any future map that
## scatters capturable bases). The map owns the COUNTING (it scans group "bases" and sets the
## ctx keys); this objective is the pure win-rule + HUD line on top of those numbers.
##
## ctx keys: bases_total (how many bases the map placed), bases_captured (how many are held).
## Guards the empty-first-frame case: with no bases it never "wins", so a map that hasn't built
## its depots yet can't instantly complete.

func _init(title_text := "Capture the depots") -> void:
	title = title_text
	required = true

func evaluate(ctx: Dictionary) -> void:
	var total := int(ctx.get("bases_total", 0))
	var held := int(ctx.get("bases_captured", 0))
	if total > 0 and held >= total:
		_done = true

func fragment(ctx: Dictionary) -> String:
	return "BASES %d/%d" % [int(ctx.get("bases_captured", 0)), int(ctx.get("bases_total", 0))]

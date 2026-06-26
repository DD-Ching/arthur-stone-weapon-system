class_name RepelWavesObjective
extends Objective
## Repel every wave: complete once all waves have been spawned AND the field is cleared —
## but NOT if the field only "cleared" because the line was overrun (half the breach
## budget spent). Reusable for any "survive N waves" level.

## Raiders left on the field at which the battle counts as "repelled" (after every wave spawned).
var clear_threshold := 2

func _init(title_text := "Repel every wave") -> void:
	title = title_text
	required = true

func evaluate(ctx: Dictionary) -> void:
	# Repelled once every wave is spawned AND the field is essentially clear. The `wave_count > 0`
	# guard kills the frame-0 instant win on a map/room with NO waves (where wave 0 >= wave_count 0
	# would otherwise read as "all waves repelled" against an empty field). The breach budget is
	# owned solely by the HoldLine constraint. Non-latching: a late straggler/boss re-opens it
	# rather than locking in a premature win.
	var wave := int(ctx.get("wave", 0))
	var wave_count := int(ctx.get("wave_count", 1))
	var alive := int(ctx.get("alive", 999))
	_done = wave_count > 0 and wave >= wave_count and alive <= clear_threshold

func fragment(ctx: Dictionary) -> String:
	return "WAVE %d/%d" % [mini(int(ctx.get("wave", 0)), int(ctx.get("wave_count", 0))),
		int(ctx.get("wave_count", 0))]

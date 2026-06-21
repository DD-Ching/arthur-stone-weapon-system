class_name RepelWavesObjective
extends Objective
## Repel every wave: complete once all waves have been spawned AND the field is cleared —
## but NOT if the field only "cleared" because the line was overrun (half the breach
## budget spent). Reusable for any "survive N waves" level.

func _init(title_text := "Repel every wave") -> void:
	title = title_text
	required = true

func evaluate(ctx: Dictionary) -> void:
	# Repelled once every wave is spawned and the field is essentially clear. The breach
	# budget is owned solely by the HoldLine constraint (one threshold, no dead band) — if
	# too many crossed you've already lost; otherwise clearing the field is a real hold.
	var wave := int(ctx.get("wave", 0))
	var wave_count := int(ctx.get("wave_count", 1))
	var alive := int(ctx.get("alive", 999))
	if wave >= wave_count and alive <= 2:
		_done = true

func fragment(ctx: Dictionary) -> String:
	return "WAVE %d/%d" % [mini(int(ctx.get("wave", 0)), int(ctx.get("wave_count", 0))),
		int(ctx.get("wave_count", 0))]

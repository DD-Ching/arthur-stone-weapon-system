class_name HoldLineObjective
extends Objective
## Hold the defence line: you LOSE if too many enemies cross it. A required objective
## whose failure ends the battle. Reusable for any "don't let N past" level.

func _init(title_text := "Hold the line") -> void:
	title = title_text
	required = true
	completable = false   # a constraint: it can only fail (→ lose), it's never "done"

func evaluate(ctx: Dictionary) -> void:
	if int(ctx.get("breaches", 0)) >= int(ctx.get("max_breaches", 1)):
		_failed = true

func fragment(ctx: Dictionary) -> String:
	return "BREACH %d/%d" % [int(ctx.get("breaches", 0)), int(ctx.get("max_breaches", 0))]

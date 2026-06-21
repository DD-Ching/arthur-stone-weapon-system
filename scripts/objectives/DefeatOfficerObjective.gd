class_name DefeatOfficerObjective
extends Objective
## Defeat the enemy officer: complete once every banner bearer that appeared has fallen.
## Reusable for any "kill the commander" level. Required by default — breaking the
## warband's morale is part of holding the ford.

var _seen := false   ## an officer has appeared (so "0 officers" at the start isn't a win)

func _init(title_text := "Defeat the officer") -> void:
	title = title_text
	required = true

func evaluate(ctx: Dictionary) -> void:
	var officers := int(ctx.get("officers", 0))
	if officers > 0:
		_seen = true
	# Recompute (don't latch): if a later wave brings a fresh officer, this re-opens until
	# that one also falls — so the win can't fire while the wave-5 commander is still alive.
	_done = _seen and officers == 0

func fragment(_ctx: Dictionary) -> String:
	return "OFFICER DOWN" if _done else "OFFICER ALIVE"

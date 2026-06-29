class_name DefeatGeneralObjective
extends Objective
## Defeat the named boss (a boss warlord): complete once every general that has appeared has fallen.
##
## This is the fix for "you could win WITHOUT beating the boss". Named bosses (Mordred, Cerdic,
## the Black Knight, Octa, …) join the "generals" group, which BattleMap surfaces as
## ctx["generals"]. It mirrors DefeatOfficerObjective exactly — same `_seen` latch so "0 generals"
## before the boss spawns isn't an instant win, and the same non-latching recompute so a fresh
## general re-opens it — but counts generals instead of officers. Required by default: no number
## of cleared waves wins the battle until the warlord himself is down.

var _seen := false   ## a general has appeared (so "0 generals" at the start isn't a win)

func _init(title_text := "Fell the warlord") -> void:
	title = title_text
	required = true

func evaluate(ctx: Dictionary) -> void:
	var generals := int(ctx.get("generals", 0))
	if generals > 0:
		_seen = true
	# Recompute (don't latch): a later wave bringing a fresh general re-opens this until that one
	# also falls — so the win can never fire while a named boss still stands.
	_done = _seen and generals == 0

func fragment(_ctx: Dictionary) -> String:
	return "BOSS DOWN" if _done else "BOSS ALIVE"

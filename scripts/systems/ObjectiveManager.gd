class_name ObjectiveManager
extends RefCounted
## Runs a level's list of Objectives. Tick it each scan with the level's state (ctx):
## you WIN when every required objective is complete; you LOSE the moment any required
## objective fails. A level composes its win/lose by `add()`-ing objectives instead of
## hand-coding the conditions — so a new level is a different list, not new logic.

var objectives: Array = []   ## Objective
var won := false
var lost := false

func add(o: Objective) -> ObjectiveManager:
	objectives.append(o)
	return self    # chainable: manager.add(a).add(b)

func evaluate(ctx: Dictionary) -> void:
	if won or lost:
		return
	for o in objectives:
		o.evaluate(ctx)
		if o.required and o.is_failed():
			lost = true
			return
	# Win when every COMPLETABLE required objective is done. Constraint objectives
	# (completable = false, e.g. "hold the line") only gate losing, never winning.
	for o in objectives:
		if o.required and o.completable and not o.is_done():
			return
	won = true

## The HUD status line — each objective's fragment, joined.
func hud_line(ctx: Dictionary) -> String:
	var parts: Array = []
	for o in objectives:
		var f: String = o.fragment(ctx)
		if f != "":
			parts.append(f)
	return "   ·   ".join(parts)

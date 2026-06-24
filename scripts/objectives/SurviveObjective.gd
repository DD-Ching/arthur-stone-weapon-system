class_name SurviveObjective
extends Objective
## Survive the horde: complete once you have held out long enough OR cut down enough of the
## mob. A reusable "endure" objective for survival levels (e.g. the Yellow Turban Rebellion):
## set `survive_seconds` and/or `ko_target`, and the battle is WON when EITHER bar fills —
## the elapsed clock reaches `survive_seconds`, or the KO count reaches `ko_target`.
##
## Reads ctx keys the BattleMap base already provides: `time` (elapsed seconds) and `kos`
## (Impact.kills). Required, completable — clearing it gates the win like any mission goal.

## Hold out this many seconds to win (a timed last-stand). <= 0 disables the time bar.
@export var survive_seconds := 60.0
## OR cut down this many of the mob to win (a body-count last-stand). <= 0 disables it.
@export var ko_target := 50

func _init(seconds := 60.0, kos := 50, title_text := "Survive the horde") -> void:
	survive_seconds = seconds
	ko_target = kos
	title = title_text
	required = true

func evaluate(ctx: Dictionary) -> void:
	var t := float(ctx.get("time", 0.0))
	var kos := int(ctx.get("kos", 0))
	if survive_seconds > 0.0 and t >= survive_seconds:
		_done = true
	elif ko_target > 0 and kos >= ko_target:
		_done = true

func fragment(ctx: Dictionary) -> String:
	var t := float(ctx.get("time", 0.0))
	var kos := int(ctx.get("kos", 0))
	var parts: Array = []
	if survive_seconds > 0.0:
		var left := maxf(0.0, survive_seconds - t)
		parts.append("SURVIVE %d:%02d" % [int(left) / 60, int(left) % 60])
	if ko_target > 0:
		parts.append("KO %d/%d" % [mini(kos, ko_target), ko_target])
	return "  ·  ".join(parts)

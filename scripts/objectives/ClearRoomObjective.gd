class_name ClearRoomObjective
extends Objective
## Clear the room: complete once every enemy that started the room has been defeated.
## Reusable for any "wipe out the placed enemies" challenge level (e.g. the Rock Launcher
## Room). Guards against the empty-first-frame case so a level that hasn't spawned its
## enemies yet doesn't instantly "win".
##
## ctx keys: alive (live enemies still up), total (how many the room placed), started
## (true once the room has actually spawned its enemies).

func _init(title_text := "Clear the room") -> void:
	title = title_text
	required = true

func evaluate(ctx: Dictionary) -> void:
	if not bool(ctx.get("started", false)):
		return
	if int(ctx.get("alive", 1)) <= 0:
		_done = true

func fragment(ctx: Dictionary) -> String:
	var total := int(ctx.get("total", 0))
	var down: int = total - int(ctx.get("alive", total))
	return "DEFEATED %d/%d" % [down, total]

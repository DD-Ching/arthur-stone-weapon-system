class_name Objective
extends RefCounted
## A reusable mission objective. A level builds a list of these and an `ObjectiveManager`
## ticks them with a context dict (the level's live state). Subclass and override
## `evaluate(ctx)` to set `_done` / `_failed`, and `fragment(ctx)` for the HUD line.
##
## A REQUIRED objective must be complete to win; if a required objective FAILS, you lose.
## A non-required objective is a bonus — tracked + shown, but it doesn't gate win/lose.
##
## ctx keys the Hold-the-Ford level provides: breaches, max_breaches, wave, wave_count,
## alive (live raiders), officers (live banner bearers).

var title := ""
var required := true       ## a required objective failing loses the battle
var completable := true    ## false = a CONSTRAINT (can fail → lose, but is never "done",
                           ## so it doesn't gate the win — e.g. "don't let the line break")
var _done := false
var _failed := false

func evaluate(_ctx: Dictionary) -> void:
	pass

## A short HUD fragment (e.g. "WAVE 2/5", "BREACH 1/12"); "" to show nothing.
func fragment(_ctx: Dictionary) -> String:
	return ""

func is_done() -> bool:
	return _done

func is_failed() -> bool:
	return _failed

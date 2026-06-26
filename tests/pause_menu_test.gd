extends Node2D
## Headless test for the reusable PauseMenu overlay (token PAUSE) — the return-to-lobby fix.
##
## Asserts: it runs while paused (process_mode ALWAYS) and registers in the "pause_menu" group so
## TouchControls can find it; it offers Resume / Restart / Return-to-Lobby; open() reveals it AND
## pauses the tree; close() hides it AND unpauses; lock() disables it (so the result screen can
## take over). All driven synchronously so the test's own frame isn't lost to the pause.
##
## Run: godot --headless --path . res://tests/PauseMenuTest.tscn --quit-after 600 — look for PAUSE_VERDICT.

const PAUSE_MENU := preload("res://scenes/ui/PauseMenu.tscn")

var _pm
var _frame := 0

func _ready() -> void:
	_pm = PAUSE_MENU.instantiate()
	add_child(_pm)

func _physics_process(_dt: float) -> void:
	_frame += 1
	if _frame < 2:
		return
	_report()

func _report() -> void:
	var always: bool = _pm.process_mode == Node.PROCESS_MODE_ALWAYS
	var grouped: bool = _pm.is_in_group("pause_menu")

	# The three core choices are present (ids), via the embedded MenuList.
	var ids: Array = []
	for it in _pm._list.items:
		ids.append(String(it["id"]))
	var has_choices: bool = ids.has("resume") and ids.has("restart") and ids.has("lobby")

	# open() reveals + pauses; close() hides + unpauses (done synchronously, no frame await).
	_pm.open()
	var opened: bool = _pm.visible and get_tree().paused
	_pm.close()
	var closed: bool = (not _pm.visible) and (not get_tree().paused)

	# lock() disables the overlay: a subsequent open() is a no-op.
	_pm.lock()
	_pm.open()
	var locked: bool = not _pm.visible

	get_tree().paused = false   # leave the tree running for a clean quit
	var ok: bool = always and grouped and has_choices and opened and closed and locked
	print("PAUSE_RESULT always=%s grouped=%s choices=%s opened=%s closed=%s locked=%s ids=%s" % [
		str(always), str(grouped), str(has_choices), str(opened), str(closed), str(locked), str(ids)])
	print("PAUSE_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

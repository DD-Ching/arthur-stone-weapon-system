extends CanvasLayer
## PauseMenu — the in-battle pause overlay (Resume / Restart / Return to Lobby), reusable on
## EVERY BattleMap and challenge room. This is the fix for "you could only refresh the page to
## leave a battle": press Escape (desktop) or the on-screen MENU button (mobile) to open it.
##
## It is `process_mode = ALWAYS` so it keeps running while it pauses the tree, owns the `pause`
## toggle itself (Escape both opens and closes it), reuses the shared MenuList for keyboard + tap
## navigation, and routes Restart -> reload_current_scene, Return to Lobby -> StageSelect. The
## owning BattleMap instances one and `lock()`s it once the battle is decided (the ScoreScreen,
## with its own Next/Retry/Lobby, takes over then). Found by other nodes via the "pause_menu"
## group (TouchControls' MENU button opens it through that group).

const STAGE_SELECT := "res://scenes/ui/Worldmap.tscn"   # the Map of Britain (lobby + journey hub)

var _root: Control
var _list: MenuList
var _title: Label
var _locked := false   ## true once the battle is decided — pause is disabled then

func _ready() -> void:
	add_to_group("pause_menu")
	layer = 80                              # above the HUD (1) and the ScoreScreen (64)
	process_mode = Node.PROCESS_MODE_ALWAYS  # run + accept input while the tree is paused
	visible = false
	_build()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.04, 0.06, 0.66)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	_title = Label.new()
	_title.text = "PAUSED"
	_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title.offset_top = 140.0
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 46)
	_title.add_theme_color_override("font_color", Color(0.96, 0.82, 0.42))
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_title)

	_list = MenuList.new()
	_list.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_list)
	_list.chosen.connect(_on_chosen)
	_list.set_items([
		{"id": "resume", "label": "Resume"},
		{"id": "restart", "label": "Restart Battle"},
		{"id": "lobby", "label": "Return to Map"},
	])
	_list.set_enabled(false)

func _unhandled_input(event: InputEvent) -> void:
	if _locked:
		return
	if event.is_action_pressed("pause"):
		toggle()
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func open() -> void:
	if _locked:
		return
	visible = true
	_list.set_enabled(true)
	get_tree().paused = true

func close() -> void:
	visible = false
	_list.set_enabled(false)
	get_tree().paused = false

func is_open() -> bool:
	return visible

## Disable the pause overlay for the rest of the battle (BattleMap calls this on win/lose so
## the result screen owns the choices instead).
func lock() -> void:
	_locked = true
	if visible:
		close()

func _on_chosen(id: String) -> void:
	match id:
		"resume":
			close()
		"restart":
			get_tree().paused = false
			get_tree().reload_current_scene()
		"lobby":
			get_tree().paused = false
			_goto(STAGE_SELECT)

## Leave via the shared scene-fade when the Transition autoload is present (it is process_mode
## ALWAYS, so the wipe still runs even though we just toggled the tree out of pause), else fall
## straight back to a hard cut so a build / headless run WITHOUT the autoload still navigates.
func _goto(path: String) -> void:
	var tr := get_node_or_null("/root/Transition")
	if tr:
		tr.change_scene(path)
	else:
		get_tree().change_scene_to_file(path)

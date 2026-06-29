extends Node2D
## Headless test for the Music autoload (token MUSIC) — the procedural looping battle/map beds that
## end the "silent battlefield". Headless has no audio device, so play() is a silent no-op; we verify
## the WIRING + state (the bed is built + assigned + loops; intensity swells the volume; switching
## beds works; re-asking the same bed is idempotent).
##
## Run: godot --headless --path . res://tests/MusicTest.tscn --quit-after 600 — look for MUSIC_VERDICT.

var _frame := 0

func _physics_process(_dt: float) -> void:
	_frame += 1
	if _frame >= 2:
		_report()

func _report() -> void:
	var checks := {}
	var m = get_node_or_null("/root/Music")
	checks["autoload"] = m != null
	if m != null:
		m.play_scene("battle")
		var bed = m._player.stream
		checks["battle_bed"] = bed != null and m.current_bed() == "battle"
		checks["loops"] = (bed is AudioStreamWAV) and bed.loop_mode == AudioStreamWAV.LOOP_FORWARD and bed.loop_end > 0
		m.set_intensity(1.0)
		var hi: float = m._player.volume_db
		m.set_intensity(0.0)
		var lo: float = m._player.volume_db
		checks["intensity_swells"] = hi > lo
		m.play_scene("map")
		checks["map_switch"] = m.current_bed() == "map" and m._player.stream != null
		var map_stream = m._player.stream
		m.play_scene("map")   # same kind again — must NOT restart / rebuild
		checks["idempotent"] = m.current_bed() == "map" and m._player.stream == map_stream

	var ok := true
	var parts: Array = []
	for k in checks:
		ok = ok and checks[k]
		parts.append("%s=%s" % [k, str(checks[k])])
	print("MUSIC_RESULT %s" % " ".join(parts))
	print("MUSIC_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

extends Node
## Music — a procedural, looping musical bed so the battlefield is never SILENT (the audit's biggest
## atmosphere gap). No audio assets: each "bed" is a synthesised looping AudioStreamWAV (a brooding
## drone chord, plus a war-drum pulse on the battle bed), played on one looping AudioStreamPlayer.
## A scene picks its bed via play_scene(); combat swells the mix via set_intensity(). Beds are built
## LAZILY (first use) so boot pays for only what it needs. Web-safe + headless-safe: no audio device
## → play() is a silent no-op, but the API + state still resolve so tests can verify the wiring.
##
## Registered as an autoload (see project.godot [autoload]). Scenes reach it as `Music` /
## get_node("/root/Music"): a BattleMap plays "battle", the Worldmap plays "map".

const RATE := 22050
const BASE_DB := -15.0      ## resting music volume (a bed, not a wall of sound)
const SWELL_DB := 8.0       ## how much louder a full-intensity battle swells

var _player: AudioStreamPlayer
var _beds := {}             ## name -> looping AudioStreamWAV (built on first use)
var _current := ""
var _intensity := 0.0

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.volume_db = BASE_DB
	add_child(_player)

## Play the bed for a scene kind ("battle" / "map" / "calm"); "" or unknown stops the music.
## Re-calling the SAME kind is a no-op, so re-entering a scene type never restarts the loop.
func play_scene(kind: String) -> void:
	if kind == _current:
		return
	_current = kind
	var key := "map" if kind == "calm" else kind
	if key != "battle" and key != "map":
		_player.stop()
		return
	if not _beds.has(key):
		_beds[key] = _make_bed(key == "battle")   # lazy: build the bed the first time it's needed
	_player.stream = _beds[key]
	_player.play()

## 0..1: swell the mix as the battle intensifies (louder bed). Cheap; called from a map's scan tick.
func set_intensity(x: float) -> void:
	_intensity = clampf(x, 0.0, 1.0)
	if _player:
		_player.volume_db = BASE_DB + SWELL_DB * _intensity

func is_playing() -> bool:
	return _player != null and _player.playing

func current_bed() -> String:
	return _current

## Build a seamless looping bed: a sustained minor-ish drone chord (root + fifth + octave) that
## slowly breathes, optionally with a low war-drum thud on each beat (accented on the downbeat).
## Length is an integer number of beats so the loop joins cleanly. One mono 16-bit PCM buffer.
func _make_bed(drums: bool) -> AudioStreamWAV:
	var beats := 8
	var beat := 0.5                       # 120 BPM
	var dur := float(beats) * beat
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var root := 98.0                      # ~G2 — a low, heroic-brooding pad
	var chord := [root, root * 1.5, root * 2.0]   # root, fifth, octave
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		# Drone pad: the chord, with a slow swell across the loop so it breathes.
		for fi in chord:
			var f := float(fi)
			s += sin(TAU * f * t)
		s *= 0.15 * (0.8 + 0.2 * sin(TAU * t / dur))
		if drums:
			var bt := fmod(t, beat)
			var thud := sin(TAU * 60.0 * bt) * exp(-18.0 * bt) * 0.6
			if int(t / beat) % 4 == 0:    # accent the downbeat
				thud *= 1.4
			s += thud
		var v := clampf(s, -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w

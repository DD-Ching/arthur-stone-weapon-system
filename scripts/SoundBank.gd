extends Node
## SoundBank — turns the Audio event bus into ACTUAL sound. There are still no asset
## files, so each named event maps to a short PROCEDURAL waveform, synthesised once at
## startup and played through a small pool of AudioStreamPlayers. This is the "real
## audio behind the hooks": a heavy thud for a swing, a clank for a shield, a noisy
## burst for a splash, a low creak for the wheel, a rising chime for Stone Flow.
##
## Registered as an autoload (after Audio). Connects to Audio.sfx. Headless has no audio
## device, so the players simply produce nothing — no errors, tests unaffected.

const RATE := 22050
const VOICES := 10

var _bank := {}
var _players: Array = []
var _next := 0

func _ready() -> void:
	for _i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	# event -> (base_hz, seconds, volume, decay, noise[0..1], hz_glide over the sound)
	_bank["heavy_swing"]       = _tone(150.0, 0.20, 0.55, 9.0, 0.35, -70.0)
	_bank["stone_scrape"]      = _tone(210.0, 0.16, 0.24, 6.0, 0.85, -20.0)
	_bank["wall_crush"]        = _tone(85.0, 0.32, 0.75, 7.0, 0.55, -35.0)
	_bank["shield_block"]      = _tone(540.0, 0.12, 0.40, 16.0, 0.35, 0.0)
	_bank["shield_break"]      = _tone(360.0, 0.24, 0.55, 9.0, 0.55, 140.0)
	_bank["enemy_launch"]      = _tone(300.0, 0.16, 0.42, 12.0, 0.20, 720.0)
	_bank["chain_impact"]      = _tone(440.0, 0.16, 0.45, 12.0, 0.25, 520.0)
	_bank["cavalry_charge"]    = _tone(110.0, 0.45, 0.50, 3.2, 0.45, 70.0)
	_bank["banner_down"]       = _tone(70.0, 0.50, 0.70, 4.0, 0.40, -45.0)
	_bank["water_splash"]      = _tone(680.0, 0.18, 0.32, 11.0, 0.90, -260.0)
	_bank["water_wheel_creak"] = _tone(130.0, 0.34, 0.22, 5.0, 0.55, 26.0)
	_bank["stone_flow_gain"]   = _tone(620.0, 0.26, 0.40, 7.0, 0.10, 320.0)
	# Big-moment stingers: a bright rising arpeggio on a win, a low somber knell on a loss.
	# Each is its OWN AudioStreamWAV so the win/loss event maps to a real voice like the rest.
	_bank["victory_fanfare"]   = _fanfare()
	_bank["defeat_knell"]      = _tone(70.0, 1.10, 0.62, 1.7, 0.10, -22.0)
	# Combat heft. "slam" is the headline fix — the SLAM finally lands audibly (a deep body
	# thud with a sharp rocky crack over it), wired up at the slam impact in StoneWeapon.
	# "big_swing" (a heavier whoosh) and "combo_tier" (a rising blip for a Stone-Flow
	# milestone) are registered voices ready for their call sites; the flow-milestone hook
	# lives in Impact, so combo_tier's trigger is deferred. All procedural, built like above.
	_bank["slam"]              = _slam_voice()
	_bank["big_swing"]         = _tone(95.0, 0.30, 0.50, 5.5, 0.70, 240.0)
	_bank["combo_tier"]        = _tone(660.0, 0.20, 0.42, 8.0, 0.06, 540.0)
	Audio.sfx.connect(_on_sfx)

func _on_sfx(event: StringName, _world_pos: Vector2) -> void:
	var stream = _bank.get(event)
	if stream == null:
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.play()

## Synthesise a short mono 16-bit PCM tone: a sine whose frequency glides by `glide` Hz
## over its length, an exponential amplitude decay, and a noise blend (0 = pure tone,
## 1 = pure noise) for crunch/splash textures.
func _tone(freq: float, dur: float, vol: float, decay: float, noise: float, glide: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := freq + glide * (t / dur)
		phase += TAU * f / RATE
		var env: float = exp(-decay * t)
		var sample: float = sin(phase) * (1.0 - noise) + (randf() * 2.0 - 1.0) * noise
		var v := clampf(sample * env * vol, -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

## A bright VICTORY fanfare: a rising major arpeggio (a triumphant chime climbing the
## chord) with a soft per-note attack + decay. Built the same way as `_tone` — one mono
## 16-bit PCM buffer — so it plays through the same voice pool with no special-casing.
func _fanfare() -> AudioStreamWAV:
	# Rising major arpeggio (C5 E5 G5 C6), each note held for `note_dur`.
	var notes := [523.25, 659.25, 783.99, 1046.50]
	var note_dur := 0.18
	var n := int(note_dur * RATE)
	var data := PackedByteArray()
	data.resize(notes.size() * n * 2)
	var idx := 0
	for ni in notes.size():
		var freq: float = notes[ni]
		var phase := 0.0
		for i in n:
			var t := float(i) / RATE
			# A quick attack then an exponential tail so each note rings, not clicks.
			var env: float = clampf(t / 0.012, 0.0, 1.0) * exp(-4.5 * t)
			phase += TAU * freq / RATE
			var v := clampf(sin(phase) * env * 0.55, -1.0, 1.0)
			data.encode_s16(idx * 2, int(v * 32767.0))
			idx += 1
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

## The SLAM voice: the heaviest move in a game about a heavy weapon. A deep BODY thud —
## a low sine that drops in pitch (~120 → ~45 Hz) under a slow decay so you FEEL the
## weight — with a short, sharp NOISE crack laid over the very front for the rocky impact
## (stone meeting ground). One mono 16-bit PCM buffer like every other voice, so it plays
## through the same pool with no special-casing.
func _slam_voice() -> AudioStreamWAV:
	var dur := 0.42
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		# Body: a low sine sagging from ~120 Hz down to ~45 Hz — a sinking heavy thud.
		var f: float = lerpf(120.0, 45.0, clampf(t / dur, 0.0, 1.0))
		phase += TAU * f / RATE
		var body: float = sin(phase) * exp(-5.5 * t)
		# Crack: a short, bright noise burst at the very front (the stone hitting rock),
		# gone within the first ~50 ms so it reads as an attack transient, not a hiss.
		var crack: float = (randf() * 2.0 - 1.0) * exp(-46.0 * t) * 0.7
		var v := clampf((body + crack) * 0.85, -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

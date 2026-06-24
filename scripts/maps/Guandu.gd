extends BattleMap
## Guandu (官渡) — the granary raid. Yuan Shao's 魏 Wei army holds three supply depots
## (granaries) across the field, each ringed by a garrison of raiders. Arthur and his
## 蜀 Shu / 吳 Wu allies must storm each depot and clear its garrison to CAPTURE it; take
## all the granaries and Cao Cao wins the campaign — the historical turning point where
## burning Yuan Shao's grain decided the war.
##
## A THIN BattleMap subclass: it places `Base` instances (the reusable capture mechanic) and
## spawns each garrison directly with the shared `Spawner`, then reports `bases_total` /
## `bases_captured` through `_extra_context` so the reusable `CaptureBasesObjective` can win.
## A small reinforcement wave keeps `_build_wave_spawner` honest (RepelWaves is optional).

const LIGHT := preload("res://scenes/LightSoldier.tscn")
const SHIELD := preload("res://scenes/ShieldSoldier.tscn")
const BASE := preload("res://scenes/Base.tscn")
const ALLY := preload("res://scenes/Ally.tscn")
const ALLY_SHIELD := preload("res://scenes/AllyShield.tscn")
const ALLY_SPEAR := preload("res://scenes/AllySpear.tscn")

## Centre of each depot (granary). 2–3 bases, spread across the field.
const DEPOTS: Array[Vector2] = [
	Vector2(-360.0, -140.0),
	Vector2(360.0, -140.0),
	Vector2(0.0, -360.0),
]
const DEPOT_RADIUS := 150.0

func _map_title() -> String:
	return "GUANDU (官渡)"

func _opening_banner() -> String:
	return "STORM THE GRANARIES!"

func _arthur_start() -> Vector2:
	return Vector2(0.0, 360.0)

func _world_bounds() -> Rect2:
	return Rect2(-680.0, -560.0, 1360.0, 1040.0)

# ── allies: a small 蜀/吳 retinue that fights for Arthur ──────────────────────
func _spawn_allies() -> void:
	# A short allied line just ahead of Arthur — they hunt the nearest garrison raider. The
	# shared Spawner takes a roster of SCENES (not instances) and lays them along the lane.
	var roster: Array = [ALLY_SHIELD, ALLY_SPEAR, ALLY, ALLY_SHIELD, ALLY_SPEAR]
	var line: Array = Spawner.spawn(self, roster, 260.0, -220.0, 220.0, false, true)
	# Stamp Three-Kingdoms colours so the retinue reads as 蜀 Shu green / 吳 Wu red.
	var i := 0
	for a in line:
		if not is_instance_valid(a):
			continue
		_tint_faction(a, "shu" if i % 2 == 0 else "wu")
		i += 1

## Tint an Enemy-backed unit with a Three-Kingdoms faction colour (魏/蜀/吳) — used by both the
## allied retinue and the depot garrisons, so the "set faction → recolour" step lives in one place.
func _tint_faction(unit, name: String) -> void:
	if not is_instance_valid(unit) or not ("faction" in unit):
		return
	unit.faction = name
	unit.base_color = unit.faction_color()

# ── depots + garrisons ───────────────────────────────────────────────────────
func _build_decor() -> void:
	# Place each capturable Base and ring it with a 魏 Wei garrison. Done in _build_decor so
	# the bases exist before the first objective evaluation (they're static field furniture).
	for idx in DEPOTS.size():
		_place_depot(DEPOTS[idx], idx)

func _place_depot(centre: Vector2, idx: int) -> void:
	var b := BASE.instantiate()
	add_child(b)
	b.global_position = centre
	if "radius" in b:
		b.radius = DEPOT_RADIUS
	if "label" in b:
		b.label = "DEPOT %d" % (idx + 1)
	# A garrison of raiders ringing the granary — they hold the depot until defeated. The
	# count scales with the map density dial (web framerate), like every other spawn site.
	var count: int = _scale(3)
	for i in count:
		var ang := TAU * float(i) / float(maxi(count, 1))
		var r := DEPOT_RADIUS * 0.55
		var pos := centre + Vector2(cos(ang), sin(ang)) * r
		var scene: PackedScene = SHIELD if (i % 3 == 0) else LIGHT
		var e = scene.instantiate()
		add_child(e)
		e.global_position = pos
		if "ai_enabled" in e:
			e.ai_enabled = true
		_tint_faction(e, "wei")          # Yuan Shao's depot guards — cosmetic 魏 blue
		# team stays "raiders" (the default) → they join "targets", so the Base counts them.

# ── objectives: capture every depot (waves are a bonus) ──────────────────────
func _compose_objectives() -> ObjectiveManager:
	var mgr := ObjectiveManager.new()
	mgr.add(CaptureBasesObjective.new("Capture the granaries"))
	return mgr

# ── a light reinforcement wave so the wave machinery is wired (RepelWaves not required) ──
func _build_wave_spawner() -> WaveSpawner:
	var ws := WaveSpawner.new()
	var w := Wave.new()
	var arr: Array[PackedScene] = [LIGHT]
	w.scenes = arr
	w.count = _scale(2)
	w.lane_y = _world_bounds().position.y + 40.0
	w.x_min = -200.0
	w.x_max = 200.0
	w.team = "raiders"
	w.label = "WEI RELIEF"
	ws.waves = [w]
	return ws

# ── report base capture to the objective layer ───────────────────────────────
func _extra_context(ctx: Dictionary) -> void:
	var total := 0
	var held := 0
	for b in get_tree().get_nodes_in_group("bases"):
		if not is_instance_valid(b):
			continue
		total += 1
		if b.has_method("is_captured") and b.is_captured():
			held += 1
	ctx["bases_total"] = total
	ctx["bases_captured"] = held

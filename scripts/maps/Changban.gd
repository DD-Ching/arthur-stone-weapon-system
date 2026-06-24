class_name ChangbanMap
extends BattleMap
## Changban (長坂坡) — an ESCORT / protect battle. Arthur shields a fleeing 蜀 Shu banner
## (the people of Changban) while wave after wave of 魏 Wei raiders crash down to cut it
## off. This is the mirror of Hold-the-Ford: there you held a line, here you keep ONE unit
## standing while it is hunted. Win by repelling every wave with the banner still alive;
## lose the instant the banner falls (the ProtectBanner constraint) — or if Arthur falls.
##
## A THIN subclass of BattleMap: all orchestration (Arthur, HUD, score screen, wave driving,
## objective ticking, win/lose) lives in the base. Here we only place the ward, script the
## escalating Wei waves, compose the two objectives, and theme the text. Build once, reuse many.

const ALLY_KNIGHT := preload("res://scenes/AllyKnight.tscn")
const LIGHT := preload("res://scenes/LightSoldier.tscn")
const SPEARMAN := preload("res://scenes/Spearman.tscn")
const SHIELD := preload("res://scenes/ShieldSoldier.tscn")
const BRUTE := preload("res://scenes/Brute.tscn")

# ── theme ────────────────────────────────────────────────────────────────────
func _map_title() -> String:
	return "CHANGBAN (長坂坡)"

func _opening_banner() -> String:
	return "PROTECT THE BANNER — 護民!"

func _arthur_start() -> Vector2:
	# Arthur stands just ahead of the ward, between it and the raiders pouring from the north.
	return Vector2(0.0, 200.0)

# ── allies: the one ward we must protect ─────────────────────────────────────
func _spawn_allies() -> void:
	# ONE allied ward — a 蜀 Shu knight escorting the fleeing people. The base watches it via
	# `_ward`: ctx `ward_alive` flips false the moment it dies, failing the ProtectBanner
	# constraint and losing the battle. It sits at the rally point behind Arthur.
	var ward = ALLY_KNIGHT.instantiate()
	add_child(ward)
	ward.global_position = Vector2(0.0, 320.0)
	if "faction" in ward:
		ward.faction = "shu"
	if "enemy_name" in ward:
		ward.enemy_name = "Banner Escort"
	_ward = ward

# ── objectives: protect the ward AND repel the assault ───────────────────────
func _compose_objectives() -> ObjectiveManager:
	var mgr := ObjectiveManager.new()
	# Constraint first: lose the instant the banner falls. (Order is cosmetic — the manager
	# checks every required objective each tick.)
	mgr.add(ProtectBannerObjective.new("Protect the fleeing banner"))
	mgr.add(RepelWavesObjective.new("Repel the Wei pursuit"))
	return mgr

# ── waves: an escalating 魏 Wei pursuit ───────────────────────────────────────
func _build_wave_spawner() -> WaveSpawner:
	var ws := WaveSpawner.new()
	ws.waves = [
		_make_wave([LIGHT], 5, "Wei Outriders"),                 # 1 — loose pursuers
		_make_wave([LIGHT, SPEARMAN], 8, "Wei Skirmish Line"),   # 2 — mixed, more of them
		_make_wave([SPEARMAN, SHIELD], 10, "Wei Shield Push"),   # 3 — spears + shields close in
		_make_wave([SHIELD, BRUTE, LIGHT], 12, "Wei Vanguard"),  # 4 — heavy vanguard
		_make_wave([BRUTE, SHIELD, SPEARMAN, LIGHT], 14, "Wei Host"),  # 5 — the full host
	]
	return ws

## Build one loose raider wave: a roster spread across the wide northern lane, scaled by the
## map density dial. The wave arrives well above Arthur and marches down toward the banner.
func _make_wave(roster: Array, n: int, label: String) -> Wave:
	var w := Wave.new()
	# A single-scene roster uses the Spawner "repeat one scene `count` times" shorthand; a
	# multi-type roster lists its units explicitly (the loose-mob path keys off scenes.size()>1),
	# duplicated to reach the wanted size. Both are scaled by the map density dial.
	if roster.size() == 1:
		var arr: Array[PackedScene] = [roster[0]]
		w.scenes = arr
		w.count = _scale(n)
	else:
		w.scenes = _fill_roster(roster, _scale(n))
		w.count = 0
	w.label = label
	w.lane_y = -300.0
	w.x_min = -360.0
	w.x_max = 360.0
	w.scatter = true
	w.team = "raiders"
	return w

## Repeat a roster until it holds `n` scenes (so a multi-type wave actually spawns `n` units,
## cycling through the listed types). Keeps the loose-mob path (scenes.size()>1) honest.
func _fill_roster(roster: Array, n: int) -> Array[PackedScene]:
	var out: Array[PackedScene] = []
	if roster.is_empty():
		return out
	for i in range(n):
		out.append(roster[i % roster.size()])
	return out

# ── theme each wave: tint the raiders 魏 Wei blue as they arrive ──────────────
func _on_wave_spawned(idx: int, units: Array) -> void:
	super(idx, units)   # keep the base "WAVE n / N" popup
	# Faction is pure colour flavour (Enemy.faction_color); stamp the pursuers Wei so the
	# three-kingdoms theme reads at a glance. No gameplay effect.
	for u in units:
		if is_instance_valid(u) and "faction" in u:
			u.faction = "wei"

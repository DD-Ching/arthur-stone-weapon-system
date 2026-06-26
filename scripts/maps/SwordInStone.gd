class_name SwordInStone
extends BattleMap
## The Sword in the Stone — Arthur's origin trial, built on the reusable BattleMap base.
##
## A churchyard/courtyard with the famous SWORD-IN-THE-STONE at its centre. Arthur has just
## lifted the WHOLE STONE; rival lords and knights refuse to believe a boy is king and ride in
## to challenge him. He stands by the stone with a small loyal retinue (Camelot gold) while
## escalating waves of doubting knights and lords (Mordred's rebels, purple) close in.
##
## This is a THIN subclass — it only overrides the build hooks (walls + the churchyard frame,
## decor for the anvil-stone, allies, waves, objectives, theme). All orchestration — Arthur,
## HUD, score, wave driving, win/lose — lives in BattleMap and is never re-implemented here.
##
## Build once, reuse many: the chapel ruins are plain `_wall()` rectangles; the waves are `Wave`
## resources composed in code (doubting knights → shields → spears+heavies → a rival lord's
## OfficerGuard); objectives are the shared RepelWaves + DefeatOfficer; every raider is tinted
## "rebel" as its wave lands.

const SHIELD_WALL := preload("res://scenes/formations/ShieldWall.tscn")
const SPEAR_PHALANX := preload("res://scenes/formations/SpearPhalanx.tscn")
const OFFICER_GUARD := preload("res://scenes/formations/OfficerGuard.tscn")
const SHIELD_SOLDIER := preload("res://scenes/ShieldSoldier.tscn")
const SPEARMAN := preload("res://scenes/Spearman.tscn")
const HEAVY_GUARD := preload("res://scenes/HeavyGuard.tscn")
const ALLY_KNIGHT := preload("res://scenes/AllyKnight.tscn")
const ALLY := preload("res://scenes/Ally.tscn")

const ANVIL_R := 64.0          ## radius of the round stone anvil at centre

# ── theme ─────────────────────────────────────────────────────────────────────
func _map_title() -> String:
	return "THE SWORD IN THE STONE"

func _opening_banner() -> String:
	return "PROVE YOU ARE KING!"

func _arthur_start() -> Vector2:
	# Just below the stone, facing the doubting knights who ride in from above.
	return Vector2(0.0, 150.0)

func _world_bounds() -> Rect2:
	return Rect2(-640.0, -440.0, 1280.0, 900.0)

# ── walls: a low churchyard frame + a couple of interior chapel/wall bits ──────
func _build_walls() -> void:
	var b := _world_bounds()
	_frame_walls(b)
	var t := 24.0
	# A ruined chapel back wall near the top with a central doorway gap the knights file through.
	var chapel_y := b.position.y + 130.0
	var door := 160.0
	var left_w: float = (-door * 0.5) - b.position.x
	_wall(Rect2(b.position.x, chapel_y, left_w, t))
	var right_x := door * 0.5
	_wall(Rect2(right_x, chapel_y, b.end.x - right_x, t))
	# Two short side buttresses lower in the courtyard, framing the duelling ground without
	# boxing Arthur in (the round-table feel: open centre, stone columns to the flanks).
	var col_y := -40.0
	_wall(Rect2(b.position.x + 150.0, col_y, t, 150.0))
	_wall(Rect2(b.end.x - 150.0 - t, col_y, t, 150.0))

# ── allies: a small loyal Camelot retinue rallies around the stone ────────────
func _spawn_allies() -> void:
	# A few loyal squires/knights of Camelot, gold-tinted, flanking the stone below Arthur.
	var spots := [
		Vector2(-120.0, 230.0), Vector2(120.0, 230.0),
		Vector2(-60.0, 290.0), Vector2(60.0, 290.0),
	]
	var roster := [ALLY_KNIGHT, ALLY, ALLY, ALLY_KNIGHT]
	for i in range(spots.size()):
		var scene: PackedScene = roster[i]
		var u = scene.instantiate()
		u.position = spots[i]
		add_child(u)
		if "faction" in u:
			u.faction = "camelot"

# ── objectives: repel every challenger, defeat the rival lord ─────────────────
func _compose_objectives() -> ObjectiveManager:
	var mgr := ObjectiveManager.new()
	mgr.add(RepelWavesObjective.new("Repel the doubting lords"))
	mgr.add(DefeatOfficerObjective.new("Defeat the rival lord"))
	return mgr

# ── waves: 5 escalating challenges of doubting knights, ending on a rival lord ─
func _build_wave_spawner() -> WaveSpawner:
	var ws := WaveSpawner.new()
	var lane: float = _world_bounds().position.y + 70.0   # spawn above the chapel, march down
	ws.waves = [
		_loose_wave("DOUBTING KNIGHTS", SHIELD_SOLDIER, _scale(5), lane),
		_formation_wave("SHIELD WALL", SHIELD_WALL, lane),
		_loose_wave("RIVAL CHALLENGERS", ALLY_KNIGHT, _scale(4), lane),
		_formation_wave("SPEARS & HEAVIES", SPEAR_PHALANX, lane),
		_formation_wave("THE RIVAL LORD'S GUARD", OFFICER_GUARD, lane),
	]
	return ws

func _loose_wave(label: String, scene: PackedScene, count: int, lane: float) -> Wave:
	var w := Wave.new()
	w.label = label
	var arr: Array[PackedScene] = [scene]
	w.scenes = arr
	w.count = count
	w.lane_y = lane
	# File in through the chapel doorway near the centre.
	w.x_min = -80.0
	w.x_max = 80.0
	w.team = "raiders"
	return w

func _formation_wave(label: String, formation: PackedScene, lane: float) -> Wave:
	var w := Wave.new()
	w.label = label
	w.formation = formation
	w.lane_y = lane
	w.x_min = -10.0
	w.x_max = 10.0
	w.team = "raiders"
	return w

# ── tint every challenger Mordred-rebel purple as their wave lands ────────────
func _on_wave_spawned(idx: int, units: Array) -> void:
	super._on_wave_spawned(idx, units)
	for u in units:
		if is_instance_valid(u) and "faction" in u:
			u.faction = "rebel"

# ── decor: the stone anvil + sword hilt at centre, low churchyard dressing ────
func _draw() -> void:
	super._draw()
	var b := _world_bounds()
	# The round stone anvil at the very centre of the courtyard.
	var c := Vector2.ZERO
	draw_circle(c, ANVIL_R + 8.0, Color(0.10, 0.10, 0.12))             # shadow base
	draw_circle(c, ANVIL_R, Color(0.46, 0.45, 0.48))                  # stone face
	draw_circle(c, ANVIL_R, Color(0.30, 0.30, 0.33), false, 5.0)      # rim
	draw_circle(c, ANVIL_R * 0.6, Color(0.38, 0.37, 0.40))            # inner anvil block
	# The famous SWORD jutting from the stone: a blade rising up, crossguard, pommel.
	var blade_top := c + Vector2(0.0, -ANVIL_R - 96.0)
	var blade_into := c + Vector2(0.0, -6.0)                          # sunk into the stone
	draw_line(blade_into, blade_top, Color(0.20, 0.18, 0.16), 11.0)   # blade outline
	draw_line(blade_into, blade_top, Color(0.82, 0.86, 0.92), 7.0)    # bright steel
	draw_line(blade_into, blade_top, Color(0.96, 0.98, 1.0), 2.0)     # highlight
	var guard_y := c.y - ANVIL_R - 30.0                              # crossguard above the stone
	draw_line(Vector2(-26.0, guard_y), Vector2(26.0, guard_y), Color(0.86, 0.72, 0.34), 8.0)
	var grip_top := Vector2(0.0, guard_y - 26.0)
	draw_line(Vector2(0.0, guard_y), grip_top, Color(0.30, 0.22, 0.16), 7.0)  # grip
	draw_circle(grip_top, 8.0, Color(0.90, 0.76, 0.36))              # pommel
	# A faint inscription ring on the stone (the legend: who draws it is king).
	draw_arc(c, ANVIL_R + 18.0, 0.0, TAU, 48, Color(0.85, 0.78, 0.45, 0.18), 2.0)
	# Low churchyard / chapel dressing: a ruined back wall outline + a Camelot gold banner over
	# the doorway (our side) and faint flagstone seams across the courtyard.
	var chapel_y := b.position.y + 130.0
	var stone := Color(0.24, 0.22, 0.22)
	draw_rect(Rect2(b.position.x + 20.0, chapel_y - 26.0, 60.0, 26.0), stone)
	draw_rect(Rect2(b.end.x - 80.0, chapel_y - 26.0, 60.0, 26.0), stone)
	var gold := Color(0.92, 0.78, 0.30)
	draw_rect(Rect2(-14.0, chapel_y - 60.0, 28.0, 42.0), gold)        # Camelot banner over the door
	# A couple of churchyard headstones flanking the duelling ground.
	for hx in [-260.0, 240.0]:
		draw_rect(Rect2(hx - 12.0, 60.0, 24.0, 40.0), Color(0.30, 0.30, 0.33))
		draw_rect(Rect2(hx - 16.0, 96.0, 32.0, 8.0), Color(0.22, 0.22, 0.24))

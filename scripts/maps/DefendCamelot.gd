class_name DefendCamelot
extends BattleMap
## Defend Camelot — a SIEGE of the castle, built on the reusable BattleMap base.
##
## Arthur and the castle garrison (Camelot gold) hold the GATE of Camelot while a Saxon /
## Mordred-rebel host storms it. The besiegers pour through a single GATE gap cut into the
## south-facing castle wall (a chokepoint funnel, like Hu Lao Gate — but a castle gate with
## corner towers); a raider that pushes past the courtyard DEFENCE LINE has breached the
## castle, and too many breaches lose it. Hold the gate, repel every wave, and fell Mordred's
## siege commander to win.
##
## A THIN BattleMap subclass: it only overrides the build hooks (walls + the gate funnel +
## towers, decor/banners, garrison allies, escalating siege waves, objectives, theme). All
## orchestration — Arthur, HUD, score, wave driving, breaches, win/lose — lives in BattleMap
## and is never re-implemented here.

const SHIELD_WALL := preload("res://scenes/formations/ShieldWall.tscn")
const SPEAR_PHALANX := preload("res://scenes/formations/SpearPhalanx.tscn")
const CHARGE_GROUP := preload("res://scenes/formations/ChargeGroup.tscn")
const OFFICER_GUARD := preload("res://scenes/formations/OfficerGuard.tscn")
const ALLIED_HOST := preload("res://scenes/formations/AlliedHost.tscn")
const LIGHT_SOLDIER := preload("res://scenes/LightSoldier.tscn")
const BRUTE := preload("res://scenes/Brute.tscn")
const ALLY := preload("res://scenes/Ally.tscn")
const ALLY_SHIELD := preload("res://scenes/AllyShield.tscn")
const BLACK_KNIGHT := preload("res://scenes/villains/BlackKnight.tscn")
# Reusable props placed in _build_decor (placement + config, no new scenes).
const GATE_POST := preload("res://scenes/decor/GatePost.tscn")
const FENCE := preload("res://scenes/terrain/Fence.tscn")
const CRATE := preload("res://scenes/Crate.tscn")
const WAR_CART := preload("res://scenes/WarCart.tscn")
const FACTION_BANNER := preload("res://scenes/decor/FactionBanner.tscn")
const WAR_DRUM := preload("res://scenes/decor/WarDrum.tscn")
# Region-identity decor for the castle courtyard (placement + config, no new scenes).
const CAMELOT_BANNER := preload("res://scenes/decor/CamelotBanner.tscn")
const TORCH := preload("res://scenes/decor/Torch.tscn")
const BRAZIER := preload("res://scenes/decor/Brazier.tscn")
const ROUND_TABLE := preload("res://scenes/decor/RoundTable.tscn")

const GATE_GAP := 160.0          ## width of the castle-gate gap the besiegers pour through
const WALL_Y_OFFSET := 150.0     ## how far below the top frame the castle wall sits
const TOWER := 64.0              ## side of each square corner tower block
const STREET_HALF := 130.0       ## half-width of the MAIN STREET lane (kept > GATE_GAP*0.5 so it never narrows the gate)
const STREET_T := 22.0           ## thickness of each MAIN STREET kerb wall
const STREET_END_Y := 130.0      ## y where the street walls stop — well short of the allies/goal so the lane stays open
const ALLEY_GAP := 120.0         ## width of the side-alley break cut into the right kerb

# ── theme ─────────────────────────────────────────────────────────────────────
## Castle courtyard at a golden torch-dusk: warm flagstone floor under a gentle gold mood. Runs
## FIRST in _ready so the floor + tint are themed from frame 0. region_mood is kept SUBTLE (each
## channel well above 0.6) so unit readability is never hurt.
func _theme() -> void:
	ground_top = Color(0.22, 0.21, 0.23)      # flagstone, lit edge
	ground_bottom = Color(0.17, 0.16, 0.17)   # flagstone, shadowed
	region_mood = Color(0.98, 0.86, 0.66)     # golden dusk wash

func _map_title() -> String:
	return "DEFEND CAMELOT"

func _opening_banner() -> String:
	return "HOLD THE GATE!"

func _arthur_start() -> Vector2:
	# Arthur stands in the gateway mouth, the last man between the breach and the courtyard.
	return Vector2(0.0, 250.0)

func _world_bounds() -> Rect2:
	return Rect2(-640.0, -440.0, 1280.0, 900.0)

# ── walls: bounding frame + the CASTLE WALL with a central GATE + corner towers ─
func _build_walls() -> void:
	var b := _world_bounds()
	_frame_walls(b)
	var t := 28.0
	var wall_y := b.position.y + WALL_Y_OFFSET     # the castle's south wall line
	var half_gap := GATE_GAP * 0.5
	# Left and right curtain walls, leaving GATE_GAP open in the centre (the gate).
	var left_w: float = (-half_gap) - b.position.x
	_wall(Rect2(b.position.x, wall_y, left_w, t))
	var right_x := half_gap
	var right_w: float = b.end.x - right_x
	_wall(Rect2(right_x, wall_y, right_w, t))
	# Inner gate jambs that taper the gate mouth into the courtyard (the funnel throat).
	var jamb_h := 96.0
	_wall(Rect2(-half_gap - t, wall_y, t, jamb_h))
	_wall(Rect2(half_gap, wall_y, t, jamb_h))
	# Two corner towers — solid square blocks anchoring the curtain wall at the bounds corners.
	_wall(Rect2(b.position.x, wall_y - TOWER * 0.5, TOWER, TOWER))
	_wall(Rect2(b.end.x - TOWER, wall_y - TOWER * 0.5, TOWER, TOWER))
	# ── MAIN STREET: two parallel kerb walls running the gate INTO the courtyard. ──
	# The lane is STREET_HALF*2 = 260 wide — WIDER than GATE_GAP (160) so it never pinches
	# the gate, and it stops at STREET_END_Y (well above the allies/defence-line/ford_goal) so
	# the raider march to ford_goal is never sealed. The street begins just below the gate jambs.
	var street_top := wall_y + jamb_h          # connect to the funnel throat
	var street_h: float = STREET_END_Y - street_top
	# Left kerb: one solid run.
	_wall(Rect2(-STREET_HALF - STREET_T, street_top, STREET_T, street_h))
	# Right kerb: a SIDE-ALLEY gap breaks it into two segments (a flanking side-street the
	# besiegers can peel into), but the central lane stays open straight to the goal.
	var alley_top: float = street_top + (street_h - ALLEY_GAP) * 0.5
	var upper_h: float = alley_top - street_top
	_wall(Rect2(STREET_HALF, street_top, STREET_T, upper_h))
	var lower_top: float = alley_top + ALLEY_GAP
	_wall(Rect2(STREET_HALF, lower_top, STREET_T, STREET_END_Y - lower_top))

func _build_terrain() -> void:
	# Churned siege mud just inside the gate mouth slows the storming rush (drag < 1). It only
	# affects the raider/ally body layer (4) — Arthur (a different layer) passes through freely.
	var b := _world_bounds()
	var mud := Rect2(-GATE_GAP * 0.7, b.position.y + WALL_Y_OFFSET + 110.0, GATE_GAP * 1.4, 120.0)
	_add_zone(mud, 0.6, Vector2.ZERO, false, false, 4)

# ── decor: dress the gate, the street, and the muster with reusable props ─────
# Pure PLACEMENT + CONFIG of existing scenes — gate posts, a fence barricade, courtyard cover
# (a hurlable crate + an inert war-cart hulk), and a faction banner + war drum at the muster.
func _build_decor() -> void:
	var b := _world_bounds()
	_scatter_battlefield_props()   # smashable barrels/pots/hay + a fire-barrel down the courtyard flanks
	var wall_y := b.position.y + WALL_Y_OFFSET
	var half_gap := GATE_GAP * 0.5
	# ── region identity: a distant castle skyline + faint embers on the dusk air ──
	var bd := RegionBackdrop.new()
	bd.kind = "castle"
	bd.span = b.size.x
	bd.silhouette = Color(0.10, 0.10, 0.12, 0.95)
	add_child(bd)
	bd.position = Vector2((b.position.x + b.end.x) * 0.5, b.position.y)
	var ad := AmbientDrift.new()
	ad.kind = "embers"
	ad.count = 40
	ad.area = b
	ad.tint = Color(1.0, 0.7, 0.3, 0.35)      # faint warm embers from the gate fires
	add_child(ad)
	# The Round Table — Camelot's court — in a safe corner well off the main lane.
	var table := ROUND_TABLE.instantiate()
	table.position = Vector2(-400.0, 300.0)
	add_child(table)
	# Camelot's royal standards flanking the gate (gold Pendragon pennants), the defenders' colour.
	for bx in [-1.0, 1.0]:
		var cb := CAMELOT_BANNER.instantiate()
		cb.faction = "camelot"
		cb.position = Vector2((half_gap + 56.0) * bx, wall_y + 44.0)
		add_child(cb)
	# A courtyard standard rallying the garrison (off-centre so the central lane stays clear).
	var court_banner := CAMELOT_BANNER.instantiate()
	court_banner.faction = "camelot"
	court_banner.position = Vector2(-60.0, 372.0)
	add_child(court_banner)
	# A row of wall-mounted torches lining the curtain wall, left and right of the gate.
	for tx in [b.position.x + 120.0, b.position.x + 280.0, -half_gap - 60.0,
			half_gap + 60.0, b.end.x - 280.0, b.end.x - 120.0]:
		var torch := TORCH.instantiate()
		torch.position = Vector2(tx, wall_y - 4.0)
		add_child(torch)
	# Braziers at the gate mouth — the fires that light the breach.
	for brx in [-1.0, 1.0]:
		var bz := BRAZIER.instantiate()
		bz.position = Vector2((half_gap - 28.0) * brx, wall_y + 78.0)
		add_child(bz)
	# Flank the gate gap with a pair of solid stone gate posts (one per jamb side).
	for sx in [-1.0, 1.0]:
		var gp := GATE_POST.instantiate()
		gp.position = Vector2((half_gap + 24.0) * sx, wall_y + 30.0)
		add_child(gp)
	# A timber barricade ACROSS the main street, split to leave a central gap the storm must
	# funnel through. Two short fence segments, each with its own shape (never mutate a shared one).
	var barricade_y := wall_y + 220.0
	var fence_seg := 150.0
	var fence_gap := 110.0
	for sx2 in [-1.0, 1.0]:
		var fn := FENCE.instantiate()
		_resize_fence(fn, Vector2(fence_seg, 26.0))
		fn.position = Vector2((fence_gap * 0.5 + fence_seg * 0.5) * sx2, barricade_y)
		add_child(fn)
	# Cover in the open courtyard below the street kerbs (kerbs end at STREET_END_Y), clear of the
	# lane and the garrison: a light CRATE Arthur can actually fling (it is a "props"-group prop the
	# stone launches), and a heavy WAR-CART hulk to fight around — AI-off and team-neutralised so it
	# is an inert barricade body, never a live besieger that joins "targets" / a wave / the test.
	var cover_y := STREET_END_Y + 70.0
	var crate = CRATE.instantiate()
	crate.position = Vector2(-200.0, cover_y)
	add_child(crate)
	var cart = WAR_CART.instantiate()
	cart.team = "neutral"   # inert hulk: out of "targets", never wave/objective-counted
	cart.ai_enabled = false
	cart.position = Vector2(200.0, cover_y)
	add_child(cart)
	# The besiegers' MUSTER up by the spawn lane (north): a faction banner + a war drum.
	var lane_y := b.position.y + 70.0
	var banner := FACTION_BANNER.instantiate()
	banner.faction = "neutral"
	banner.position = Vector2(-200.0, lane_y)
	add_child(banner)
	var drum := WAR_DRUM.instantiate()
	drum.faction = "neutral"
	drum.position = Vector2(200.0, lane_y)
	add_child(drum)

## Give a Fence its OWN RectangleShape2D sized to `size` (the .tscn ships a shared sub-resource;
## mutating that in place would resize every fence). The Fence draws itself to its shape.
func _resize_fence(fence, size: Vector2) -> void:
	for c in fence.get_children():
		if c is CollisionShape2D:
			var shape := RectangleShape2D.new()
			shape.size = size
			c.shape = shape
			return

# ── allies: the castle garrison holds the courtyard ───────────────────────────
func _spawn_allies() -> void:
	# The main garrison host, formed up behind the gate facing the breach.
	var host = ALLIED_HOST.instantiate()
	host.position = Vector2(0.0, 340.0)
	host.face = Vector2.UP
	add_child(host)
	for u in (host.units if "units" in host else []):
		_tint(u, "camelot")
	# A few loose men-at-arms flanking the gateway so the garrison reads as a real defence.
	var roster: Array = [ALLY_SHIELD, ALLY, ALLY_SHIELD, ALLY]
	var line: Array = Spawner.spawn(self, roster, 300.0, -230.0, 230.0, false, true)
	for a in line:
		_tint(a, "camelot")

## Tint a unit with a faction colour (pure readability flavour — team/groups unchanged).
func _tint(unit, faction_name: String) -> void:
	if is_instance_valid(unit) and "faction" in unit:
		unit.faction = faction_name

# ── objectives: hold the gate, repel the siege, fell the commander ────────────
func _compose_objectives() -> ObjectiveManager:
	# A raider past the courtyard line has breached the castle; 12 breaches lose it.
	max_breaches = 12
	defence_line_y = 430.0
	var mgr := ObjectiveManager.new()
	mgr.add(RepelWavesObjective.new("Repel the siege"))
	mgr.add(DefeatOfficerObjective.new("Fell the siege commander"))
	# Gate the win on the named boss: the Black Knight (final wave, is_general) must fall.
	mgr.add(DefeatGeneralObjective.new("Fell the Black Knight"))
	mgr.add(HoldLineObjective.new("Hold the gate"))
	return mgr

# ── waves: escalating siege assaults pouring through the gate gap ──────────────
func _build_wave_spawner() -> WaveSpawner:
	var ws := WaveSpawner.new()
	var lane: float = _world_bounds().position.y + 70.0   # spawn above the wall, march down
	ws.waves = [
		_loose_wave("SAXON RAIDERS", LIGHT_SOLDIER, _scale(6), lane),
		_formation_wave("SHIELD WALL", SHIELD_WALL, lane),
		_formation_wave("SPEAR PHALANX", SPEAR_PHALANX, lane),
		_loose_wave("BATTERING BRUTES", BRUTE, _scale(4), lane),
		_formation_wave("CAVALRY CHARGE", CHARGE_GROUP, lane),
		_formation_wave("MORDRED'S GUARD", OFFICER_GUARD, lane),
		_loose_wave("THE BLACK KNIGHT", BLACK_KNIGHT, 1, lane),
	]
	return ws

func _loose_wave(label: String, scene: PackedScene, count: int, lane: float) -> Wave:
	var w := Wave.new()
	w.label = label
	var arr: Array[PackedScene] = [scene]
	w.scenes = arr
	w.count = count
	w.lane_y = lane
	# Spread along the gate mouth so they enter through the gap, not into a jamb.
	w.x_min = -GATE_GAP * 0.5 + 20.0
	w.x_max = GATE_GAP * 0.5 - 20.0
	w.team = "raiders"
	return w

func _formation_wave(label: String, formation: PackedScene, lane: float) -> Wave:
	var w := Wave.new()
	w.label = label
	w.formation = formation
	w.lane_y = lane
	# Centre the formation on the gate gap.
	w.x_min = -10.0
	w.x_max = 10.0
	w.team = "raiders"
	return w

# ── theme each besieger wave: Saxon moss-green, with Mordred's guard the rebels ─
func _on_wave_spawned(idx: int, units: Array) -> void:
	super._on_wave_spawned(idx, units)
	# The final commander wave is Mordred's rebels (black-purple); the rest are Saxons.
	var fac := "rebel" if idx >= _wave_count() - 1 else "saxon"
	for u in units:
		_tint(u, fac)

# ── ground motif: flagstone courtyard seams over the base floor, behind the units ─
func _paint_region(b: Rect2) -> void:
	# A subtle grid of warm-grey stone joints turns the floor into a flagged courtyard. Drawn once
	# (static), kept faint so it reads as paving without fighting unit readability.
	var seam := Color(0.42, 0.40, 0.38, 0.16)
	var step := 96.0
	var x := b.position.x + step
	while x < b.end.x:
		draw_line(Vector2(x, b.position.y), Vector2(x, b.end.y), seam, 2.0)
		x += step
	var y := b.position.y + step
	while y < b.end.y:
		draw_line(Vector2(b.position.x, y), Vector2(b.end.x, y), seam, 2.0)
		y += step

# ── castle dressing on top of the base grid ───────────────────────────────────
func _draw() -> void:
	super._draw()
	var b := _world_bounds()
	var wall_y := b.position.y + WALL_Y_OFFSET
	var t := 28.0
	var half_gap := GATE_GAP * 0.5
	var stone := Color(0.30, 0.29, 0.33)
	var stone_dark := Color(0.20, 0.19, 0.23)
	# Curtain-wall stone facing over the collision rects, left and right of the gate.
	draw_rect(Rect2(b.position.x, wall_y, (-half_gap) - b.position.x, t), stone)
	draw_rect(Rect2(half_gap, wall_y, b.end.x - half_gap, t), stone)
	# Crenellations (merlons) along the top of each curtain section.
	_draw_crenellations(b.position.x, -half_gap, wall_y, stone_dark)
	_draw_crenellations(half_gap, b.end.x, wall_y, stone_dark)
	# Corner towers, drawn over their collision blocks, with a darker crenellated cap.
	for tx in [b.position.x, b.end.x - TOWER]:
		var tr := Rect2(tx, wall_y - TOWER * 0.5, TOWER, TOWER)
		draw_rect(tr, stone)
		draw_rect(Rect2(tr.position.x, tr.position.y, tr.size.x, 8.0), stone_dark)
	# Gate posts framing the gap.
	var post := Color(0.18, 0.16, 0.18)
	var post_w := 18.0
	draw_rect(Rect2(-half_gap - post_w, wall_y - 20.0, post_w, t + 40.0), post)
	draw_rect(Rect2(half_gap, wall_y - 20.0, post_w, t + 40.0), post)
	# (The Pendragon standards over the gate + the courtyard rally standard are now real
	#  CamelotBanner decor props placed in _build_decor, not inline gold rects.)
	# The courtyard defence line, drawn faintly so the held line reads.
	draw_line(Vector2(b.position.x, defence_line_y), Vector2(b.end.x, defence_line_y),
		Color(0.85, 0.3, 0.3, 0.18), 2.0)

## A row of crenellation merlons along the top edge of a curtain-wall span [x0, x1].
func _draw_crenellations(x0: float, x1: float, wall_y: float, col: Color) -> void:
	var merlon_w := 18.0
	var step := 32.0
	var x := x0 + 4.0
	while x + merlon_w <= x1:
		draw_rect(Rect2(x, wall_y - 12.0, merlon_w, 12.0), col)
		x += step

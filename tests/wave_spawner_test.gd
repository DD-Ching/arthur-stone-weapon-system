extends Node2D
## Headless test for the data-driven WaveSpawner (#9). It proves a battle's waves can live as
## a Resource and be materialized by REUSING the shared Spawner / Formation modules:
##   - SampleWaves.tres loads and reports 2 waves;
##   - spawn_wave(parent, 0) drops 5 loose LightSoldiers on the raider team (Spawner path);
##   - spawn_wave(parent, 1) marches in a ShieldWall formation of 5 shields, raiders;
##   - a code-built wave with team="allies" re-tags loose units onto the ally side (team wiring);
##   - re-teaming a SUPPORT unit (banner) off the raiders also clears the raiders-only "officers"
##     group, so a flipped-side banner isn't miscounted as a live enemy officer.
##
## Run: godot --headless --path . res://tests/WaveSpawnerTest.tscn --quit-after 600
## Look for WAVESPAWN_VERDICT.

const LIGHT := preload("res://scenes/LightSoldier.tscn")
const BANNER := preload("res://scenes/BannerBearer.tscn")

var _data: WaveSpawner
var _loose: Array = []
var _form: Array = []
var _ally: Array = []
var _banner: Array = []
var _count := 0
var _frame := 0

func _ready() -> void:
	# 1) The saved resource: a real WaveSpawner with two sample waves.
	_data = load("res://scenes/data/SampleWaves.tres")
	_count = _data.wave_count() if _data != null else -1
	if _data != null:
		_loose = _data.spawn_wave(self, 0)   # 5 loose LightSoldiers (Spawner path)
		_form = _data.spawn_wave(self, 1)    # ShieldWall formation (Formation path)

	# 2) A code-built WaveSpawner exercising the loose path with a NON-default team. Spawner
	#    instances units as "raiders" (the scene default); the wave re-tags them to "allies".
	var ally_wave := Wave.new()
	ally_wave.scenes = [LIGHT]
	ally_wave.count = 3
	ally_wave.team = "allies"
	ally_wave.lane_y = 300.0
	var coded := WaveSpawner.new()
	coded.waves = [ally_wave]
	_ally = coded.spawn_wave(self, 0)

	# 3) A SUPPORT unit (banner) re-teamed off the raiders must leave the raiders-only "officers"
	#    group, or the DefeatOfficer objective would count a phantom enemy officer forever.
	var banner_wave := Wave.new()
	banner_wave.scenes = [BANNER]
	banner_wave.team = "allies"
	banner_wave.lane_y = 320.0
	var coded2 := WaveSpawner.new()
	coded2.waves = [banner_wave]
	_banner = coded2.spawn_wave(self, 0)

func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame >= 4:
		_report()

func _report() -> void:
	# Wave 0 — 5 loose LightSoldiers, raider team (in the "targets" + "raiders" groups).
	var loose_raiders := 0
	for u in _loose:
		if is_instance_valid(u) and u.team == "raiders" \
				and u.is_in_group("targets") and u.is_in_group("raiders"):
			loose_raiders += 1
	var loose_ok: bool = _loose.size() == 5 and loose_raiders == 5

	# Wave 1 — a ShieldWall formation: 5 shield units, raiders, returned via the formation's units.
	var form_shields := 0
	for u in _form:
		if is_instance_valid(u) and u.look == "shield" and u.is_in_group("raiders"):
			form_shields += 1
	var form_ok: bool = _form.size() == 5 and form_shields == 5

	# Team wiring — the ally wave's 3 units land on the ally side, NOT in "targets".
	var allied := 0
	for u in _ally:
		if is_instance_valid(u) and u.team == "allies" \
				and u.is_in_group("allies") and not u.is_in_group("targets"):
			allied += 1
	var ally_ok: bool = _ally.size() == 3 and allied == 3

	# Re-teamed banner — on the ally side, and NOT lingering in the raiders-only "officers" group.
	var banner_ok := false
	if _banner.size() == 1 and is_instance_valid(_banner[0]):
		var b = _banner[0]
		banner_ok = b.team == "allies" and b.is_in_group("allies") \
			and not b.is_in_group("officers") and not b.is_in_group("targets")

	var count_ok: bool = _count == 2

	print("WAVESPAWN_RESULT waves=%d loose=%d/%d form=%d/%d ally=%d/%d banner_ok=%s count_ok=%s loose_ok=%s form_ok=%s ally_ok=%s"
		% [_count, loose_raiders, _loose.size(), form_shields, _form.size(),
			allied, _ally.size(), str(banner_ok), str(count_ok), str(loose_ok), str(form_ok), str(ally_ok)])
	var ok: bool = count_ok and loose_ok and form_ok and ally_ok and banner_ok
	print("WAVESPAWN_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

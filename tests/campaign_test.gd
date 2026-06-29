extends Node2D
## Headless test for the Campaign autoload (the story-progression backbone, token CAMPAIGN).
##
## Asserts: the ordered stage table is non-empty and leads with the Arthurian legend; the legend
## unlocks IN ORDER (the second region is locked until the first is cleared) while the Training
## Yard is always open; mark_completed persists a clear + unlocks the next region; next_path
## advances along the legend road and returns "" at the end; reset wipes progress; every stage
## carries a story blurb; and the overworld geography (region/map_pos/links) is populated.
##
## Run: godot --headless --path . res://tests/CampaignTest.tscn --quit-after 600 — look for CAMPAIGN_VERDICT.

const SWORD := "res://scenes/maps/SwordInStone.tscn"
const MARCHES := "res://scenes/maps/HuLaoGate.tscn"   # reskinned region #2 "The Marches"
const LAKE := "res://scenes/maps/LadyOfLake.tscn"
const HOLD_FORD := "res://scenes/Battlefield.tscn"     # a Training Yard stage (always open)

var _frame := 0

func _physics_process(_dt: float) -> void:
	_frame += 1
	if _frame < 2:
		return
	_report()

func _report() -> void:
	Campaign.reset()   # deterministic start (ignore any saved progress)

	var has_stages: bool = Campaign.stages().size() >= 10
	var leads_arthur: bool = String(Campaign.stages()[0]["section"]) == Campaign.SEC_ARTHUR

	# First legend region is open; the next is LOCKED until it's cleared; the Training Yard is open.
	var sword_open: bool = Campaign.is_unlocked(SWORD)
	var marches_locked: bool = not Campaign.is_unlocked(MARCHES)
	var trials_open: bool = Campaign.is_unlocked(HOLD_FORD)

	# Clearing the sword unlocks the next region (The Marches) and records the clear.
	Campaign.mark_completed(SWORD)
	var sword_cleared: bool = Campaign.is_cleared(SWORD)
	var marches_unlocked: bool = Campaign.is_unlocked(MARCHES)

	# next_path advances along the legend, and is "" at the end (the Lady of the Lake is last).
	var next_ok: bool = true
	if ResourceLoader.exists(MARCHES):
		next_ok = Campaign.next_path(SWORD) == MARCHES
	var lake_is_last: bool = Campaign.next_path(LAKE) == ""

	var has_blurb: bool = Campaign.blurb_for(SWORD) != ""

	# Overworld geography is populated for the legend (region id + a placed map position + a road).
	var geo_ok: bool = Campaign.region_for(SWORD) != "" \
		and Campaign.map_pos_for(SWORD) != Vector2.ZERO \
		and Campaign.links_for(SWORD).size() >= 1 \
		and Campaign.legend_stages().size() >= 10

	# reset wipes the clear.
	Campaign.reset()
	var reset_ok: bool = not Campaign.is_cleared(SWORD)

	var ok: bool = has_stages and leads_arthur and sword_open and marches_locked and trials_open \
		and sword_cleared and marches_unlocked and next_ok and lake_is_last and has_blurb \
		and geo_ok and reset_ok
	print("CAMPAIGN_RESULT stages=%s lead=%s sword_open=%s marches_locked=%s trials_open=%s cleared=%s unlocked=%s next=%s lake_last=%s blurb=%s geo=%s reset=%s" % [
		str(has_stages), str(leads_arthur), str(sword_open), str(marches_locked), str(trials_open),
		str(sword_cleared), str(marches_unlocked), str(next_ok), str(lake_is_last), str(has_blurb), str(geo_ok), str(reset_ok)])
	print("CAMPAIGN_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

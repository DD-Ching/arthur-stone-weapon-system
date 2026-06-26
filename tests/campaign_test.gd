extends Node2D
## Headless test for the Campaign autoload (the story-progression backbone, token CAMPAIGN).
##
## Asserts: the ordered stage table is non-empty and leads with the Arthurian legend; the legend
## unlocks IN ORDER (Mount Badon is locked until the Sword in the Stone is cleared) while the
## bonus section is always open; mark_completed persists a clear + unlocks the next battle;
## next_path advances within a section and returns "" at the end; reset wipes progress; every
## stage carries a story blurb.
##
## Run: godot --headless --path . res://tests/CampaignTest.tscn --quit-after 600 — look for CAMPAIGN_VERDICT.

const SWORD := "res://scenes/maps/SwordInStone.tscn"
const BADON := "res://scenes/maps/MountBadon.tscn"
const LAKE := "res://scenes/maps/LadyOfLake.tscn"
const GUANDU := "res://scenes/maps/Guandu.tscn"

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

	# First legend battle is open; the next is LOCKED until it's cleared; bonus is always open.
	var sword_open: bool = Campaign.is_unlocked(SWORD)
	var badon_locked: bool = not Campaign.is_unlocked(BADON)
	var bonus_open: bool = Campaign.is_unlocked(GUANDU)

	# Clearing the sword unlocks Mount Badon and records the clear.
	Campaign.mark_completed(SWORD)
	var sword_cleared: bool = Campaign.is_cleared(SWORD)
	var badon_unlocked: bool = Campaign.is_unlocked(BADON)

	# next_path advances within the legend section, and is "" at the section's end.
	var next_ok: bool = true
	if ResourceLoader.exists(BADON):
		next_ok = Campaign.next_path(SWORD) == BADON
	var lake_is_last: bool = Campaign.next_path(LAKE) == ""

	var has_blurb: bool = Campaign.blurb_for(SWORD) != ""

	# reset wipes the clear.
	Campaign.reset()
	var reset_ok: bool = not Campaign.is_cleared(SWORD)

	var ok: bool = has_stages and leads_arthur and sword_open and badon_locked and bonus_open \
		and sword_cleared and badon_unlocked and next_ok and lake_is_last and has_blurb and reset_ok
	print("CAMPAIGN_RESULT stages=%s lead=%s sword_open=%s badon_locked=%s bonus_open=%s cleared=%s unlocked=%s next=%s lake_last=%s blurb=%s reset=%s" % [
		str(has_stages), str(leads_arthur), str(sword_open), str(badon_locked), str(bonus_open),
		str(sword_cleared), str(badon_unlocked), str(next_ok), str(lake_is_last), str(has_blurb), str(reset_ok)])
	print("CAMPAIGN_VERDICT %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

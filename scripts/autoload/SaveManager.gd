## Save Manager — Autoload Singleton
## Handles local JSON persistence with a versioned save schema.
## All save/load operations go through this singleton.
class_name SaveManagerClass
extends Node


## Current save schema version.
const SAVE_VERSION: int = 1

## Path to the save file on disk.
const SAVE_FILE_PATH: String = "user://tastyblast_save.json"

## Emitted after save data is successfully loaded.
signal save_loaded()

## Emitted after save data is successfully written.
signal save_written()

## Emitted when player progression data is reset.
signal progress_reset()

## Emitted when a new cuisine region is unlocked.
signal region_unlocked(region_id: String)

## Emitted when debug developer state changes (e.g. debug unlock all).
signal debug_state_changed()


## In-memory save data, populated on load.
var save_data: Dictionary = {}

## Alias for save_data for direct access convenience.
var current_save: Dictionary:
	get:
		return save_data
	set(value):
		save_data = value

## Restaurant progress core model instance.
var restaurant_progress: RestaurantProgress = RestaurantProgress.new()


func _ready() -> void:
	load_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		save_game()


## Load save data from disk. Creates default save if file doesn't exist or is corrupted.
func load_game() -> void:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		_create_default_save()
		return

	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file == null:
		push_warning("SaveManager: Could not open save file, creating default.")
		_create_default_save()
		return

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK or not (json.data is Dictionary):
		push_warning("SaveManager: Failed to parse save file or invalid JSON, creating default.")
		_create_default_save()
		return

	save_data = SaveSchema.migrate(json.data)
	
	if not SaveSchema.validate(save_data):
		push_warning("SaveManager: Save data failed validation after migration, resetting to default.")
		_create_default_save()
		return

	_apply_haptics_setting()
	save_loaded.emit()


## Write current save data to disk.
func save_game() -> void:
	save_data["save_version"] = SAVE_VERSION

	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Could not open save file for writing.")
		return

	var json_string := JSON.stringify(save_data, "\t")
	file.store_string(json_string)
	file.close()
	save_written.emit()


## Get the player's high score.
func get_high_score() -> int:
	return save_data.get("high_score", 0)


## Update high score if the given score is higher.
func try_update_high_score(score: int) -> bool:
	if score > get_high_score():
		save_data["high_score"] = score
		save_game()
		return true
	return false


## Get player's total accumulated score across all games.
func get_total_accumulated_score() -> int:
	var scores: Dictionary = get_all_region_scores()
	var total: int = 0
	for r_id in scores:
		total += int(scores[r_id])
	return total


## Get current score for a specific cuisine region.
func get_region_score(region_id: String) -> int:
	var scores: Dictionary = save_data.get("region_scores", {})
	return int(scores.get(region_id, 0))


## Get scores for all cuisine regions as a Dictionary.
func get_all_region_scores() -> Dictionary:
	var default_scores: Dictionary = {
		"italy": 0,
		"france": 0,
		"mexico": 0,
		"japan": 0,
		"india": 0,
		"turkey": 0
	}
	var scores: Dictionary = save_data.get("region_scores", {})
	for key in default_scores:
		if not scores.has(key):
			scores[key] = default_scores[key]
	return scores


## Add score to a specific region's cumulative score and check for sequential region unlocks.
## Returns an array of newly unlocked region IDs (e.g. ["france"]).
func add_region_score(region_id: String, amount: int) -> Array[String]:
	if amount <= 0:
		return []

	var scores: Dictionary = get_all_region_scores()
	var current_region_score: int = int(scores.get(region_id, 0)) + amount
	scores[region_id] = current_region_score
	save_data["region_scores"] = scores

	var current_total: int = 0
	for r_id in scores:
		current_total += int(scores[r_id])
	save_data["total_accumulated_score"] = current_total

	var unlocked_list: Array = get_unlocked_regions()
	var new_unlock: String = restaurant_progress.check_region_unlock(region_id, current_region_score, unlocked_list)

	var new_unlocks: Array[String] = []
	if not new_unlock.is_empty() and not (new_unlock in unlocked_list):
		unlocked_list.append(new_unlock)
		save_data["unlocked_regions"] = unlocked_list

		# Mark newly unlocked region with is_new = true for NEW! badge lifecycle
		if not save_data.has("new_regions"):
			save_data["new_regions"] = {}
		save_data["new_regions"][new_unlock] = true

		region_unlocked.emit(new_unlock)
		new_unlocks.append(new_unlock)
		save_game()

	return new_unlocks


## Add score to the player's total accumulated score (defaults to active region) and check for new region unlocks.
func add_accumulated_score(score_to_add: int) -> Array[String]:
	if score_to_add <= 0:
		return []
	var region: String = get_active_region()
	return add_region_score(region, score_to_add)


## Get the list of unlocked cuisine region IDs.
func get_unlocked_regions() -> Array:
	return save_data.get("unlocked_regions", ["italy"])


## Check if a specific region ID is unlocked.
func is_region_unlocked(region_id: String) -> bool:
	return region_id in get_unlocked_regions()


## Check if a cuisine region has the "is_new" status flag (unlocked but not yet played).
func is_region_new(region_id: String) -> bool:
	if not is_region_unlocked(region_id) or region_id == "italy":
		return false
	var new_map: Dictionary = save_data.get("new_regions", {})
	return bool(new_map.get(region_id, false))


## Clear the "is_new" status flag when player enters gameplay scene for that region.
func mark_region_visited(region_id: String) -> void:
	if not save_data.has("new_regions"):
		save_data["new_regions"] = {}
	if save_data["new_regions"].get(region_id, false) == true:
		save_data["new_regions"][region_id] = false
		save_game()


## Explicitly unlock a cuisine region by ID.
func unlock_region(region_id: String) -> void:
	var regions: Array = get_unlocked_regions()
	if not (region_id in regions):
		regions.append(region_id)
		save_data["unlocked_regions"] = regions
		if not save_data.has("new_regions"):
			save_data["new_regions"] = {}
		if region_id != "italy":
			save_data["new_regions"][region_id] = true
		region_unlocked.emit(region_id)
		save_game()


## Get the last played region stored in persistent save data.
func get_last_played_region() -> String:
	return save_data.get("last_played_region", "italy")


## Set and persist the last played region to save data on disk.
func set_last_played_region(region_id: String) -> void:
	save_data["last_played_region"] = region_id
	save_game()


## Currently active session region ID.
var active_region: String = "italy"


## Get current active region ID for this session.
func get_active_region() -> String:
	if active_region.is_empty() or active_region == "italy":
		active_region = get_last_played_region()
	return active_region


## Set current active region ID for this session and persist as last played region.
func set_active_region(region_id: String) -> void:
	active_region = region_id
	set_last_played_region(region_id)


## Get a settings value by key with a default fallback.
func get_setting(key: String, default_value: Variant = null) -> Variant:
	var settings: Dictionary = save_data.get("settings", {})
	return settings.get(key, default_value)


## Set a settings value by key.
func set_setting(key: String, value: Variant) -> void:
	if not save_data.has("settings"):
		save_data["settings"] = {}
	save_data["settings"][key] = value
	if key == "haptics" or key == "haptics_enabled":
		save_data["settings"]["haptics"] = value
		save_data["settings"]["haptics_enabled"] = value
		_apply_haptics_setting()
	save_game()


## Apply the saved haptics preference to the HapticsManager singleton.
func _apply_haptics_setting() -> void:
	var is_on: bool = bool(get_setting("haptics", get_setting("haptics_enabled", true)))
	var haptics_mgr = get_node_or_null("/root/HapticsManager")
	if haptics_mgr:
		haptics_mgr.enabled = is_on


## Reset all gameplay progression data (scores, unlocks, region progress)
## while strictly preserving player settings (audio, haptics, language, etc.).
func reset_all_data() -> void:
	# 1. Preserve existing user settings
	var current_settings: Dictionary = save_data.get("settings", {}).duplicate(true)

	# 2. Reset gameplay progression to defaults in sequential order
	save_data["high_score"] = 0
	save_data["total_accumulated_score"] = 0
	save_data["region_scores"] = {
		"italy": 0,
		"france": 0,
		"mexico": 0,
		"japan": 0,
		"india": 0,
		"turkey": 0
	}
	save_data["new_regions"] = {
		"italy": false,
		"france": false,
		"mexico": false,
		"japan": false,
		"india": false,
		"turkey": false
	}
	save_data["unlocked_regions"] = ["italy"]
	save_data["last_played_region"] = "italy"
	active_region = "italy"

	# 3. Retain preserved settings
	save_data["settings"] = current_settings

	# 4. Write reset state to disk
	save_game()

	# 5. Notify all active UI listeners
	progress_reset.emit()


## Convenience alias for reset_all_data.
func reset_progress() -> void:
	reset_all_data()


## Debug-only developer tool: instantly unlocks all cuisine regions and sets their
## cumulative scores to their required thresholds dynamically from configuration.
## Strictly protected to only execute in debug builds / editor.
func debug_unlock_all_regions() -> void:
	if not OS.is_debug_build():
		return

	var regions: Array = restaurant_progress.get_all_regions()
	var all_unlocked_ids: Array[String] = []
	var total_score: int = 0

	if not save_data.has("region_scores"):
		save_data["region_scores"] = {}
	if not save_data.has("new_regions"):
		save_data["new_regions"] = {}

	for r in regions:
		var reg_id: String = r.get("id", "")
		if reg_id.is_empty():
			continue

		all_unlocked_ids.append(reg_id)
		var threshold: int = int(r.get("unlock_score_threshold", 0))
		# For regions without explicit successor threshold (e.g. final region Turkey), use 300,000
		if threshold <= 0:
			threshold = 300000
		save_data["region_scores"][reg_id] = threshold
		save_data["new_regions"][reg_id] = false
		total_score += threshold

	save_data["unlocked_regions"] = all_unlocked_ids
	save_data["visited_regions"] = all_unlocked_ids.duplicate()
	save_data["total_accumulated_score"] = total_score
	if not all_unlocked_ids.is_empty():
		var last_id: String = all_unlocked_ids[all_unlocked_ids.size() - 1]
		save_data["last_played_region"] = last_id
		active_region = last_id

	save_game()
	progress_reset.emit()
	debug_state_changed.emit()


## Create a fresh default save file.
func _create_default_save() -> void:
	save_data = SaveSchema.create_default()
	_apply_haptics_setting()
	save_game()
	save_loaded.emit()

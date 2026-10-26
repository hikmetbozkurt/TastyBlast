## Save Schema — Utility
## Defines the versioned save data structure and provides migration
## functions for upgrading old save formats.
class_name SaveSchema
extends RefCounted


## Current schema version.
const CURRENT_VERSION: int = 1


## Create a default save data dictionary.
static func create_default() -> Dictionary:
	return {
		"save_version": CURRENT_VERSION,
		"high_score": 0,
		"total_accumulated_score": 0,
		"region_scores": {
			"italy": 0,
			"france": 0,
			"mexico": 0,
			"japan": 0,
			"india": 0,
			"turkey": 0
		},
		"new_regions": {
			"italy": false,
			"france": false,
			"mexico": false,
			"japan": false,
			"india": false,
			"turkey": false
		},
		"unlocked_regions": ["italy"],
		"last_played_region": "italy",
		"settings": {
			"music_enabled": true,
			"sfx_enabled": true,
			"haptics": true,
			"haptics_enabled": true,
			"music_volume": 70.0,
		},
	}


## Validate that a save data dictionary has all required fields.
static func validate(data: Dictionary) -> bool:
	if not (data is Dictionary):
		return false
	if not data.has("save_version"):
		return false
	if not data.has("high_score"):
		return false
	if not data.has("unlocked_regions"):
		return false
	if not data.has("settings"):
		return false
	return true


## Migrate save data from an older version to the current version.
## Returns the migrated data.
static func migrate(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("save_version", 0))

	if version < 1:
		data = _migrate_v0_to_v1(data)

	if not data.has("settings"):
		data["settings"] = {
			"music_enabled": true,
			"sfx_enabled": true,
			"haptics": true,
			"haptics_enabled": true,
			"music_volume": 70.0,
		}
	else:
		var settings: Dictionary = data["settings"]
		if not settings.has("haptics"):
			settings["haptics"] = settings.get("haptics_enabled", true)
		if not settings.has("haptics_enabled"):
			settings["haptics_enabled"] = settings.get("haptics", true)
		if not settings.has("music_volume"):
			settings["music_volume"] = 70.0
		data["settings"] = settings

	if not data.has("region_scores"):
		data = _migrate_region_scores(data)
	else:
		var scores: Dictionary = data["region_scores"]
		var default_keys: Dictionary = {
			"italy": 0,
			"france": 0,
			"mexico": 0,
			"japan": 0,
			"india": 0,
			"turkey": 0
		}
		for key in default_keys:
			if not scores.has(key):
				scores[key] = default_keys[key]
		data["region_scores"] = scores

	if not data.has("new_regions"):
		var default_new: Dictionary = {
			"italy": false,
			"france": false,
			"mexico": false,
			"japan": false,
			"india": false,
			"turkey": false
		}
		data["new_regions"] = default_new
	else:
		var new_map: Dictionary = data["new_regions"]
		var default_keys: Dictionary = {
			"italy": false,
			"france": false,
			"mexico": false,
			"japan": false,
			"india": false,
			"turkey": false
		}
		for key in default_keys:
			if not new_map.has(key):
				new_map[key] = default_keys[key]
		data["new_regions"] = new_map

	if not data.has("last_played_region"):
		data["last_played_region"] = "italy"

	return data


## Migration from v0 (pre-versioning) to v1.
static func _migrate_v0_to_v1(data: Dictionary) -> Dictionary:
	if not data.has("high_score"):
		data["high_score"] = 0
	if not data.has("total_accumulated_score"):
		data["total_accumulated_score"] = data.get("high_score", 0)
	if not data.has("unlocked_regions"):
		data["unlocked_regions"] = ["italy"]
	if not data.has("new_regions"):
		data["new_regions"] = {
			"italy": false,
			"france": false,
			"mexico": false,
			"japan": false,
			"india": false,
			"turkey": false
		}
	if not data.has("settings"):
		data["settings"] = {
			"music_enabled": true,
			"sfx_enabled": true,
			"haptics": true,
			"haptics_enabled": true,
			"music_volume": 70.0,
		}

	data["save_version"] = 1
	return data


## Initialize region_scores for older save files that lack per-region tracking.
static func _migrate_region_scores(data: Dictionary) -> Dictionary:
	var default_scores: Dictionary = {
		"italy": data.get("total_accumulated_score", data.get("high_score", 0)),
		"france": 0,
		"mexico": 0,
		"japan": 0,
		"india": 0,
		"turkey": 0
	}
	data["region_scores"] = default_scores
	return data

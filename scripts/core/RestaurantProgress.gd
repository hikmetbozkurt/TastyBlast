## Restaurant Progress — Core Data Model
## Handles sequential cuisine region definitions, unlock score thresholds, and region progress tracking.
## Region data is loaded from assets/data/cuisine_regions.json.
class_name RestaurantProgress
extends RefCounted


## Path to cuisine regions JSON configuration.
const REGIONS_FILE_PATH: String = "res://assets/data/cuisine_regions.json"

## All loaded region definitions in strict sequential order.
var _regions: Array = []

## Color family mapping.
var _color_families: Dictionary = {}

## Ingredient to color family map.
var _ingredient_color_map: Dictionary = {}


func _init() -> void:
	load_region_data()


## Load region and color configuration from JSON.
func load_region_data() -> void:
	if not FileAccess.file_exists(REGIONS_FILE_PATH):
		push_error("RestaurantProgress: Regions data file not found: %s" % REGIONS_FILE_PATH)
		return

	var file := FileAccess.open(REGIONS_FILE_PATH, FileAccess.READ)
	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		push_error("RestaurantProgress: Failed to parse cuisine_regions.json.")
		return

	var data: Dictionary = json.data
	_regions = data.get("regions", [])
	_color_families = data.get("color_families", {})
	_ingredient_color_map = data.get("ingredient_color_map", {})


## Get all region definitions in sequential progression order.
func get_all_regions() -> Array:
	return _regions


## Get a region definition by ID.
func get_region_by_id(region_id: String) -> Dictionary:
	for r in _regions:
		if r.get("id", "") == region_id:
			return r
	return {}


## Get the score threshold needed in this region to unlock its next successor.
func get_region_threshold(region_id: String) -> int:
	var r := get_region_by_id(region_id)
	return int(r.get("unlock_score_threshold", 0))


## Get the immediate successor region ID unlocked by this region.
func get_next_region_id(region_id: String) -> String:
	var r := get_region_by_id(region_id)
	return r.get("next_region", "")


const FLAG_TEXTURE_PATHS: Dictionary = {
	"italy": "res://assets/art/ui/flags/flag_it.svg",
	"france": "res://assets/art/ui/flags/flag_fr.svg",
	"mexico": "res://assets/art/ui/flags/flag_mx.svg",
	"japan": "res://assets/art/ui/flags/flag_jp.svg",
	"india": "res://assets/art/ui/flags/flag_in.svg",
	"turkey": "res://assets/art/ui/flags/flag_tr.svg",
	"türkiye": "res://assets/art/ui/flags/flag_tr.svg",
}


## Get the Texture2D SVG flag resource for a region ID.
static func get_flag_texture(region_id: String) -> Texture2D:
	var path: String = FLAG_TEXTURE_PATHS.get(region_id.to_lower(), "")
	if not path.is_empty() and ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


## Get the SVG flag resource path for a region ID.
static func get_flag_texture_path(region_id: String) -> String:
	return FLAG_TEXTURE_PATHS.get(region_id.to_lower(), "")


## Get the country flag emoji for a region.
func get_region_flag(region_id: String) -> String:
	var r := get_region_by_id(region_id)
	return r.get("flag", "🍽️")


## Get the display name for a region (e.g. "Türkiye").
func get_region_name(region_id: String) -> String:
	var r := get_region_by_id(region_id)
	return r.get("name", region_id.capitalize())


## Check if a region has reached its score threshold to unlock its successor.
func is_region_completed(region_id: String, region_score: int) -> bool:
	var threshold := get_region_threshold(region_id)
	if threshold <= 0:
		return false
	return region_score >= threshold


## Check if a region's cumulative score unlocks its immediate successor region.
## Returns the newly unlocked region ID or empty string if none.
func check_region_unlock(region_id: String, region_score: int, currently_unlocked: Array) -> String:
	var r := get_region_by_id(region_id)
	if r.is_empty():
		return ""

	var threshold: int = int(r.get("unlock_score_threshold", 0))
	var next_region: String = r.get("next_region", "")

	if threshold > 0 and not next_region.is_empty():
		if region_score >= threshold and not (next_region in currently_unlocked):
			return next_region

	return ""


## Get the playing scene file path for a region by ID.
func get_playing_scene_path(region_id: String) -> String:
	var region := get_region_by_id(region_id)
	if region.has("playing_scene"):
		return region.get("playing_scene", "res://scenes/main/Game.tscn")
	match region_id:
		"france":
			return "res://scenes/main/FrancePlayingScreen.tscn"
		"mexico":
			return "res://scenes/main/MexicoPlayingScreen.tscn"
		"japan":
			return "res://scenes/main/JapanPlayingScreen.tscn"
		"india":
			return "res://scenes/main/IndiaPlayingScreen.tscn"
		"turkey":
			return "res://scenes/main/TurkeyPlayingScreen.tscn"
		_:
			return "res://scenes/main/Game.tscn"


## Legacy backwards compatibility check.
func check_new_unlocks(cumulative_score: int, currently_unlocked: Array) -> Array[String]:
	var newly_unlocked: Array[String] = []
	for r in _regions:
		var rid: String = r.get("id", "")
		var threshold: int = int(r.get("unlock_score_threshold", 0))
		if cumulative_score >= threshold and not (rid in currently_unlocked):
			newly_unlocked.append(rid)
	return newly_unlocked

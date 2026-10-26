## Ingredient Theme — Resource Script
## Maps logical ingredient IDs to sprite paths. The single file to update
## when swapping placeholder art for real Flow-generated PNGs.
class_name IngredientTheme
extends Resource


## Current mode: "placeholder" uses color-family squares, "themed" uses real art.
@export var active_mode: String = "themed"

## Current active cuisine region ID (e.g. "italy", "france")
@export var active_region: String = "italy"

## Color family names indexed by color index (1-7).
const COLOR_FAMILIES: Array[String] = [
	"", "red", "orange", "yellow", "green", "blue", "purple", "brown"
]

## Color index to ingredient mapping by region
const REGION_COLOR_INDEX_MAP: Dictionary = {
	"italy": ["", "tomato", "pepper", "cheese", "basil", "olive", "eggplant", "cheese"],
	"france": ["", "strawberry", "macaron", "butter", "mushroom", "grape", "baguette", "macaron"],
	"japan": ["", "salmon", "matcha", "rice", "wasabi", "nori", "radish", "salmon"],
	"mexico": ["", "jalapeno", "redonion", "corn", "lime", "avocado", "beans", "corn"],
	"turkey": ["", "tea", "simit", "egg", "cucumber", "olive", "yoghurt", "simit"],
	"india": ["", "chili", "curry", "turmeric", "coriander", "coconut", "mango", "curry"]
}

## Color index to Italy ingredient mapping for themed mode (legacy fallback)
const COLOR_INDEX_TO_INGREDIENT: Array[String] = [
	"", "tomato", "pepper", "cheese", "basil", "olive", "eggplant", "cheese"
]

## Regional themed sprites.
const REGION_THEMED_SPRITES: Dictionary = {
	"italy": {
		"tomato": "res://assets/art/ingredients/italy/italy_tomato.png",
		"pepper": "res://assets/art/ingredients/italy/italy_pepper.png",
		"cheese": "res://assets/art/ingredients/italy/italy_cheese.png",
		"basil": "res://assets/art/ingredients/italy/italy_basil.png",
		"olive": "res://assets/art/ingredients/italy/italy_olive.png",
		"eggplant": "res://assets/art/ingredients/italy/italy_eggplant.png"
	},
	"france": {
		"strawberry": "res://assets/art/ingredients/france/france_strawberry.png",
		"macaron": "res://assets/art/ingredients/france/france_macaron.png",
		"butter": "res://assets/art/ingredients/france/france_butter.png",
		"mushroom": "res://assets/art/ingredients/france/france_mushroom.png",
		"grape": "res://assets/art/ingredients/france/france_grape.png",
		"baguette": "res://assets/art/ingredients/france/france_baguette.png"
	},
	"japan": {
		"nori": "res://assets/art/ingredients/japan/japan_nori.png",
		"radish": "res://assets/art/ingredients/japan/japan_radish.png",
		"rice": "res://assets/art/ingredients/japan/japan_rice.png",
		"salmon": "res://assets/art/ingredients/japan/japan_salmon.png",
		"matcha": "res://assets/art/ingredients/japan/japan_matcha.png",
		"wasabi": "res://assets/art/ingredients/japan/japan_wasabi.png"
	},
	"mexico": {
		"jalapeno": "res://assets/art/ingredients/mexico/mexico_jalapeno.png",
		"avocado": "res://assets/art/ingredients/mexico/mexico_avacado.png",
		"corn": "res://assets/art/ingredients/mexico/mexico_corn.png",
		"lime": "res://assets/art/ingredients/mexico/mexico_lime.png",
		"redonion": "res://assets/art/ingredients/mexico/mexico_redonion.png",
		"beans": "res://assets/art/ingredients/mexico/mexico_beans.png"
	},
	"turkey": {
		"tea": "res://assets/art/ingredients/turkey/turkey_tea.png",
		"simit": "res://assets/art/ingredients/turkey/turkey_simit.png",
		"egg": "res://assets/art/ingredients/turkey/turkey_egg.png",
		"cucumber": "res://assets/art/ingredients/turkey/turkey_cucumber.png",
		"olive": "res://assets/art/ingredients/turkey/turkey_olive.png",
		"yoghurt": "res://assets/art/ingredients/turkey/turkey_yoghurt.png"
	},
	"india": {
		"chili": "res://assets/art/ingredients/india/indian_chili.png",
		"coconut": "res://assets/art/ingredients/india/indian_coconaut.png",
		"coriander": "res://assets/art/ingredients/india/indian_coriander.png",
		"curry": "res://assets/art/ingredients/india/indian_curry_bowl.png",
		"mango": "res://assets/art/ingredients/india/indian_mango.png",
		"turmeric": "res://assets/art/ingredients/india/indian_turmeric.png"
	}
}

## Placeholder sprites keyed by color family name.
@export var placeholder_sprites: Dictionary = {
	"red": "res://assets/art/ingredients/_placeholder/red.png",
	"orange": "res://assets/art/ingredients/_placeholder/orange.png",
	"yellow": "res://assets/art/ingredients/_placeholder/yellow.png",
	"green": "res://assets/art/ingredients/_placeholder/green.png",
	"blue": "res://assets/art/ingredients/_placeholder/blue.png",
	"purple": "res://assets/art/ingredients/_placeholder/purple.png",
	"brown": "res://assets/art/ingredients/_placeholder/brown.png",
}

## Themed sprites keyed by ingredient ID.
@export var themed_sprites: Dictionary = {
	"tomato": "res://assets/art/ingredients/italy/italy_tomato.png",
	"pepper": "res://assets/art/ingredients/italy/italy_pepper.png",
	"cheese": "res://assets/art/ingredients/italy/italy_cheese.png",
	"basil": "res://assets/art/ingredients/italy/italy_basil.png",
	"olive": "res://assets/art/ingredients/italy/italy_olive.png",
	"eggplant": "res://assets/art/ingredients/italy/italy_eggplant.png"
}

## Texture cache.
static var _texture_cache: Dictionary = {}
static var _active_theme_resource: IngredientTheme = null


## Load active theme resource from assets/data/ingredient_theme.tres.
static func get_active_theme() -> IngredientTheme:
	if _active_theme_resource == null:
		var path := "res://assets/data/ingredient_theme.tres"
		if ResourceLoader.exists(path):
			_active_theme_resource = load(path) as IngredientTheme
		if _active_theme_resource == null:
			_active_theme_resource = IngredientTheme.new()
	return _active_theme_resource


## Set active region (e.g. "italy", "france")
func set_active_region(region_id: String) -> void:
	if not region_id.is_empty():
		active_region = region_id


## Get the texture for a color index (1-7), respecting active_mode ("themed" or "placeholder").
static func get_texture_for_color_index(color_index: int) -> Texture2D:
	var theme: IngredientTheme = get_active_theme()
	return theme.get_texture_by_color_index(color_index)


## Instance method: Get texture by color index.
func get_texture_by_color_index(color_index: int) -> Texture2D:
	if active_mode == "themed":
		var region_map: Array = REGION_COLOR_INDEX_MAP.get(active_region, COLOR_INDEX_TO_INGREDIENT)
		var ingredient_id: String = region_map[posmod(color_index, region_map.size())]
		var region_sprites: Dictionary = REGION_THEMED_SPRITES.get(active_region, themed_sprites)
		if not ingredient_id.is_empty() and region_sprites.has(ingredient_id):
			var path: String = region_sprites[ingredient_id]
			var tex: Texture2D = get_texture_from_path(path)
			if tex != null:
				return tex

	# Fallback to placeholder color family
	var family_idx: int = posmod(color_index, COLOR_FAMILIES.size())
	var family: String = COLOR_FAMILIES[family_idx]
	if family.is_empty():
		family = "red"
	
	var placeholder_path: String = placeholder_sprites.get(family, "res://assets/art/ingredients/_placeholder/red.png")
	return get_texture_from_path(placeholder_path)


## Helper: Load and cache texture from path.
func get_texture_from_path(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]

	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path) as Texture2D
		_texture_cache[path] = tex
		return tex

	_texture_cache[path] = null
	return null

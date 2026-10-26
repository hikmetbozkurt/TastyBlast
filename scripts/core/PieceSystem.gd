## Piece System — Core Logic
## Piece shape definitions, tray generation, and shape loading from data file.
## Shapes are loaded from piece_shapes.json, never hardcoded in logic.
class_name PieceSystem
extends RefCounted


## Path to the piece shapes data file.
const SHAPES_FILE_PATH: String = "res://assets/data/piece_shapes.json"

## All loaded shape definitions.
var _shapes: Array = []

## Random number generator for weighted selection.
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## Load shape definitions from the JSON data file.
func load_shapes() -> void:
	if not FileAccess.file_exists(SHAPES_FILE_PATH):
		push_error("PieceSystem: Shapes file not found: %s" % SHAPES_FILE_PATH)
		return

	var file := FileAccess.open(SHAPES_FILE_PATH, FileAccess.READ)
	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		push_error("PieceSystem: Failed to parse shapes file.")
		return

	var data: Dictionary = json.data
	var raw_shapes: Array = data.get("shapes", [])
	_shapes = []

	# Filter out any shape with a dimension (width or height) >= 5 cells
	for shape in raw_shapes:
		var cells: Array = shape.get("cells", [])
		var dim: Vector2i = _get_shape_dimensions(cells)
		if dim.x <= 4 and dim.y <= 4:
			_shapes.append(shape)


## Calculate width and height of a shape definition in cells.
func _get_shape_dimensions(cells: Array) -> Vector2i:
	if cells.is_empty():
		return Vector2i.ZERO
	var min_x := int(cells[0][0])
	var max_x := min_x
	var min_y := int(cells[0][1])
	var max_y := min_y
	for c in cells:
		var x := int(c[0])
		var y := int(c[1])
		min_x = mini(min_x, x)
		max_x = maxi(max_x, x)
		min_y = mini(min_y, y)
		max_y = maxi(max_y, y)
	return Vector2i(max_x - min_x + 1, max_y - min_y + 1)


## Get all loaded shape definitions.
func get_all_shapes() -> Array:
	return _shapes


## Get a shape definition by its ID.
func get_shape_by_id(shape_id: String) -> Dictionary:
	for shape in _shapes:
		if shape.get("id", "") == shape_id:
			return shape
	return {}


## Select a random shape using weighted probability.
func pick_random_shape() -> Dictionary:
	if _shapes.is_empty():
		push_error("PieceSystem: No shapes loaded.")
		return {}

	var total_weight: float = 0.0
	for shape in _shapes:
		total_weight += float(shape.get("weight", 1))

	var roll: float = _rng.randf() * total_weight
	var cumulative: float = 0.0

	for shape in _shapes:
		cumulative += float(shape.get("weight", 1))
		if roll <= cumulative:
			return shape

	# Fallback (shouldn't reach here)
	return _shapes[_shapes.size() - 1]


## Generate a tray of pieces (default 3). Returns an array of shape dicts.
func generate_tray(tray_size: int = 3) -> Array:
	var tray: Array = []
	for i in range(tray_size):
		tray.append(pick_random_shape())
	return tray


## Get the cell offsets for a shape definition.
func get_shape_cells(shape: Dictionary) -> Array:
	return shape.get("cells", [])


## Seed the random number generator for reproducible results (useful for testing).
func set_seed(seed_value: int) -> void:
	_rng.seed = seed_value

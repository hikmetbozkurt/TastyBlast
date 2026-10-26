## Grid System — Core Logic
## Pure grid occupancy logic, decoupled from rendering.
## No Node dependencies where feasible, making it unit-testable.
class_name GridSystem
extends RefCounted


## Emitted when one or more lines (rows or columns) are cleared.
signal lines_cleared(count: int, cleared_cells: Array)

## Emitted when a piece is placed on the grid.
signal piece_placed(cells: Array)


## Grid dimensions.
var width: int = 8
var height: int = 8

## The grid occupancy array. Each cell is either empty (0) or occupied (ingredient color index).
## Access: _grid[y][x] where y is row, x is column.
var _grid: Array = []


## Initialize the grid with the given dimensions, all cells empty.
func initialize(grid_width: int, grid_height: int) -> void:
	width = grid_width
	height = grid_height
	_grid = []
	for y in range(height):
		var row: Array = []
		for x in range(width):
			row.append(0)
		_grid.append(row)


## Check if a position is within grid bounds.
func is_within_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height


## Check if a specific cell is empty.
func is_cell_empty(x: int, y: int) -> bool:
	if not is_within_bounds(x, y):
		return false
	return _grid[y][x] == 0


## Get the value at a cell (0 = empty, other = ingredient color index).
func get_cell(x: int, y: int) -> int:
	if not is_within_bounds(x, y):
		return -1
	return _grid[y][x]


## Set a cell value directly. Used internally and by tests.
func set_cell(x: int, y: int, value: int) -> void:
	if is_within_bounds(x, y):
		_grid[y][x] = value


## Check if a piece (list of cell offsets) can be placed at position (origin_x, origin_y).
func can_place_piece(origin_x: int, origin_y: int, piece_cells: Array) -> bool:
	for cell in piece_cells:
		var x: int = origin_x + int(cell[0])
		var y: int = origin_y + int(cell[1])
		if not is_cell_empty(x, y):
			return false
	return true


## Place a piece on the grid. Returns false if placement is invalid.
func place_piece(origin_x: int, origin_y: int, piece_cells: Array, color_index: int) -> bool:
	if not can_place_piece(origin_x, origin_y, piece_cells):
		return false

	var placed_cells: Array = []
	for cell in piece_cells:
		var x: int = origin_x + int(cell[0])
		var y: int = origin_y + int(cell[1])
		_grid[y][x] = color_index
		placed_cells.append(Vector2i(x, y))

	piece_placed.emit(placed_cells)
	return true


## Check for completed rows and columns. Returns a dictionary with
## "rows" (array of row indices) and "cols" (array of column indices).
func find_completed_lines() -> Dictionary:
	var completed_rows: Array = []
	var completed_cols: Array = []

	# Check rows
	for y in range(height):
		var row_full := true
		for x in range(width):
			if _grid[y][x] == 0:
				row_full = false
				break
		if row_full:
			completed_rows.append(y)

	# Check columns
	for x in range(width):
		var col_full := true
		for y in range(height):
			if _grid[y][x] == 0:
				col_full = false
				break
		if col_full:
			completed_cols.append(x)

	return {"rows": completed_rows, "cols": completed_cols}


## Collect info (coordinates and color indices) of cells that will be cleared.
func get_cleared_cells_info() -> Array:
	var lines := find_completed_lines()
	var cleared_info: Array = []
	var cells_to_clear: Dictionary = {}

	for y in lines["rows"]:
		for x in range(width):
			cells_to_clear[Vector2i(x, y)] = true

	for x in lines["cols"]:
		for y in range(height):
			cells_to_clear[Vector2i(x, y)] = true

	for cell_pos in cells_to_clear.keys():
		cleared_info.append({
			"x": cell_pos.x,
			"y": cell_pos.y,
			"color_index": _grid[cell_pos.y][cell_pos.x]
		})

	return cleared_info


## Clear completed lines and return the list of cleared cell positions.
func clear_completed_lines() -> Array:
	var lines := find_completed_lines()
	var cleared_cells: Array = []

	# Collect all cells to clear (avoid double-counting intersections)
	var cells_to_clear: Dictionary = {}

	for y in lines["rows"]:
		for x in range(width):
			var key := Vector2i(x, y)
			cells_to_clear[key] = true

	for x in lines["cols"]:
		for y in range(height):
			var key := Vector2i(x, y)
			cells_to_clear[key] = true

	# Clear the cells
	for cell_pos in cells_to_clear.keys():
		_grid[cell_pos.y][cell_pos.x] = 0
		cleared_cells.append(cell_pos)

	var total_lines: int = lines["rows"].size() + lines["cols"].size()
	if total_lines > 0:
		lines_cleared.emit(total_lines, cleared_cells)

	return cleared_cells


## Check if any piece from a list of shapes can be placed anywhere on the grid.
## Used for game-over detection.
func can_any_piece_fit(piece_shapes: Array) -> bool:
	for shape in piece_shapes:
		if can_piece_fit_anywhere(shape):
			return true
	return false


## Check if a single piece shape can be placed anywhere on the grid.
func can_piece_fit_anywhere(piece_cells: Array) -> bool:
	for y in range(height):
		for x in range(width):
			if can_place_piece(x, y, piece_cells):
				return true
	return false


## Get the full grid state as a 2D array (for serialization/debugging).
func get_grid_state() -> Array:
	return _grid.duplicate(true)


## Restore grid state from a 2D array.
func set_grid_state(state: Array) -> void:
	_grid = state.duplicate(true)

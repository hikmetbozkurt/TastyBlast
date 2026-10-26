## Grid View — Gameplay Scene Script
## Visual representation of the grid. Instantiates GridCell scenes,
## handles line clear animations, particle bursts, screen shake, and placement previews.
class_name GridView
extends Node2D


## PackedScenes
@export var grid_cell_scene: PackedScene = preload("res://scenes/gameplay/GridCell.tscn")

## Reference to the logical grid system.
var grid_system: GridSystem = null

## Cell size in pixels for rendering.
@export var cell_size: float = 64.0

## Grid dimensions.
var width: int = 8
var height: int = 8

## 2D Array of GridCell node instances: _cells[y][x]
var _cells: Array = []

## Default position stored for screen shake recovery.
var _default_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	_default_position = position


## Initialize and create the visual grid cells.
func setup(grid_sys: GridSystem, c_size: float = 64.0) -> void:
	grid_system = grid_sys
	cell_size = c_size
	width = grid_sys.width
	height = grid_sys.height
	_default_position = position
	_build_grid()


## Rebuild the visual grid cells.
func _build_grid() -> void:
	for child in get_children():
		child.queue_free()

	_cells.clear()

	for y in range(height):
		var row: Array = []
		for x in range(width):
			var cell_instance: GridCell = grid_cell_scene.instantiate() as GridCell
			add_child(cell_instance)
			cell_instance.setup(x, y, cell_size)
			row.append(cell_instance)
		_cells.append(row)

	refresh_display()


## Rebuild the visual grid state from the GridSystem data model.
func refresh_display() -> void:
	if not grid_system:
		return

	for y in range(height):
		for x in range(width):
			var val: int = grid_system.get_cell(x, y)
			var cell: GridCell = _cells[y][x]
			if val > 0:
				cell.set_ingredient(val)
			else:
				cell.set_empty()


## Refresh logical display immediately, then animate presentation-only snapshots.
func animate_cleared_cells(cleared_cells: Array) -> void:
	var snapshots: Array[Sprite2D] = []
	for cell_position in cleared_cells:
		var grid_position := Vector2i(int(cell_position.x), int(cell_position.y))
		if not grid_system.is_within_bounds(grid_position.x, grid_position.y):
			continue
		var cell := _cells[grid_position.y][grid_position.x] as GridCell
		var snapshot := cell.create_visual_snapshot()
		if snapshot:
			add_child(snapshot)
			snapshots.append(snapshot)

	refresh_display()

	for index in range(snapshots.size()):
		var delay := minf(float(index) * 0.012, 0.12)
		AnimationManager.play_pop_and_free(snapshots[index], delay)


## Trigger screen shake / grid jiggle for visual feedback.
func trigger_shake(intensity: float = 8.0, duration: float = 0.25) -> void:
	AnimationManager.play_shake(self, _default_position, intensity, duration)


## Convert a global screen position to grid cell coordinates (x, y).
func screen_to_grid(global_pos: Vector2) -> Vector2i:
	var local_pos: Vector2 = to_local(global_pos)
	var x: int = floori(local_pos.x / cell_size)
	var y: int = floori(local_pos.y / cell_size)
	return Vector2i(x, y)


## Highlight cells for a potential placement preview.
func show_placement_preview(origin_x: int, origin_y: int, piece_cells: Array, valid: bool) -> void:
	clear_placement_preview()
	for cell_offset in piece_cells:
		var gx: int = origin_x + int(cell_offset[0])
		var gy: int = origin_y + int(cell_offset[1])
		if grid_system.is_within_bounds(gx, gy):
			var cell: GridCell = _cells[gy][gx]
			cell.set_highlight(valid)


## Clear all active placement previews on the grid.
func clear_placement_preview() -> void:
	for y in range(height):
		for x in range(width):
			var cell: GridCell = _cells[y][x]
			cell.clear_highlight()

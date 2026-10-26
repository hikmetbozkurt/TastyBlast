## Grid Cell — Gameplay Scene Script
## A single cell in the visual grid. Displays the food ingredient sprite or
## empty state. Handles highlight states for placement preview.
class_name GridCell
extends Node2D


## The grid coordinates of this cell.
var grid_x: int = 0
var grid_y: int = 0

## Size of the cell in pixels.
var cell_size: float = 96.0

## Current occupant color/ingredient index (0 = empty).
var color_index: int = 0

## Highlight state: 0 = none, 1 = valid preview (green), 2 = invalid preview (red).
var highlight_state: int = 0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _background: ColorRect = $Background
@onready var _highlight: ColorRect = $Highlight

## Grid separator lines (warm cream with 30% opacity)
var _line_right: ColorRect = null
var _line_bottom: ColorRect = null
var _line_left: ColorRect = null
var _line_top: ColorRect = null

const GRID_LINE_COLOR := Color(0.96, 0.89, 0.8, 0.3)


func _ready() -> void:
	_create_grid_lines()
	_update_visuals()


## Set cell position and coordinates.
func setup(x: int, y: int, size: float) -> void:
	grid_x = x
	grid_y = y
	cell_size = size
	position = Vector2(x * size, y * size)
	
	if is_inside_tree():
		_update_size()


## Set the cell to display an ingredient (index 1-7).
func set_ingredient(c_index: int) -> void:
	color_index = c_index
	_update_visuals()


## Set the cell to empty state.
func set_empty() -> void:
	color_index = 0
	_update_visuals()


func create_visual_snapshot() -> Sprite2D:
	if color_index <= 0 or not _sprite or not _sprite.visible or not _sprite.texture:
		return null
	var snapshot := Sprite2D.new()
	snapshot.texture = _sprite.texture
	snapshot.position = position + _sprite.position
	snapshot.scale = _sprite.scale
	snapshot.rotation = _sprite.rotation
	snapshot.modulate = _sprite.modulate
	snapshot.z_index = 20
	snapshot.add_to_group("clear_snapshot")
	return snapshot


## Show a placement preview highlight (valid = green, invalid = red).
func set_highlight(valid: bool) -> void:
	highlight_state = 1 if valid else 2
	_update_highlight()


## Clear the highlight state.
func clear_highlight() -> void:
	highlight_state = 0
	_update_highlight()


func _create_grid_lines() -> void:
	if not _line_right:
		_line_right = ColorRect.new()
		_line_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_line_right.color = GRID_LINE_COLOR
		add_child(_line_right)
	if not _line_bottom:
		_line_bottom = ColorRect.new()
		_line_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_line_bottom.color = GRID_LINE_COLOR
		add_child(_line_bottom)
	if grid_x == 0 and not _line_left:
		_line_left = ColorRect.new()
		_line_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_line_left.color = GRID_LINE_COLOR
		add_child(_line_left)
	if grid_y == 0 and not _line_top:
		_line_top = ColorRect.new()
		_line_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_line_top.color = GRID_LINE_COLOR
		add_child(_line_top)


func _update_size() -> void:
	if _background:
		_background.visible = false
		_background.size = Vector2(cell_size, cell_size)
	if _highlight:
		_highlight.size = Vector2(cell_size - 2, cell_size - 2)
		_highlight.position = Vector2(1, 1)

	_create_grid_lines()
	if _line_right:
		_line_right.position = Vector2(cell_size - 1, 0)
		_line_right.size = Vector2(1, cell_size)
	if _line_bottom:
		_line_bottom.position = Vector2(0, cell_size - 1)
		_line_bottom.size = Vector2(cell_size, 1)
	if _line_left:
		_line_left.position = Vector2(0, 0)
		_line_left.size = Vector2(1, cell_size)
	if _line_top:
		_line_top.position = Vector2(0, 0)
		_line_top.size = Vector2(cell_size, 1)


func _update_visuals() -> void:
	if not is_inside_tree():
		return
		
	_update_size()

	if color_index == 0:
		_sprite.visible = false
	else:
		_sprite.visible = true
		var tex: Texture2D = IngredientTheme.get_texture_for_color_index(color_index)
		if tex:
			_sprite.texture = tex
			var tex_size: Vector2 = tex.get_size()
			_sprite.scale = Vector2((cell_size - 6) / tex_size.x, (cell_size - 6) / tex_size.y)
			_sprite.position = Vector2(cell_size / 2.0, cell_size / 2.0)

	_update_highlight()


func _update_highlight() -> void:
	if not _highlight:
		return

	match highlight_state:
		0:
			_highlight.visible = false
		1:
			_highlight.visible = true
			_highlight.color = Color(0.2, 0.9, 0.2, 0.45) # Green
		2:
			_highlight.visible = true
			_highlight.color = Color(0.9, 0.2, 0.2, 0.45) # Red

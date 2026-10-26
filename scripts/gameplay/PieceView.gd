## Piece View — Gameplay Scene Script
## Visual representation of a draggable piece in the tray or during drag.
## Handles rendering of polyomino shapes using food ingredient sprites via IngredientTheme.
class_name PieceView
extends Node2D


## The shape data dictionary for this piece.
var shape_data: Dictionary = {}

## The color/ingredient index assigned to this piece (1-7).
var color_index: int = 1

## Cell rendering size in pixels (canonical 96px).
var cell_size: float = 96.0

## Dedicated visual container node so visual scaling never affects logical coordinates/root scale.
var visual_root: Node2D = null


func _ready() -> void:
	_ensure_visual_root()


func _ensure_visual_root() -> void:
	if visual_root == null or not is_instance_valid(visual_root):
		visual_root = get_node_or_null("VisualRoot") as Node2D
		if visual_root == null:
			visual_root = Node2D.new()
			visual_root.name = "VisualRoot"
			add_child(visual_root)


## Set the visual scale of the ingredient sprites (does not affect canonical PieceView root scale).
func set_visual_scale(scale_factor: float) -> void:
	_ensure_visual_root()
	visual_root.scale = Vector2(scale_factor, scale_factor)


## Get the current visual scale of the ingredient sprites.
func get_visual_scale() -> float:
	_ensure_visual_root()
	return visual_root.scale.x


## Get the VisualRoot Node2D instance (useful for Tweens).
func get_visual_root() -> Node2D:
	_ensure_visual_root()
	return visual_root


## Initialize this piece view with a shape definition, color index, and cell size.
func setup(shape: Dictionary, color_idx: int, c_size: float = 96.0) -> void:
	shape_data = shape
	color_index = color_idx
	cell_size = c_size
	scale = Vector2.ONE
	_build_piece_visuals()


## Get the cell offsets for this piece's shape.
func get_cells() -> Array:
	return shape_data.get("cells", [])


## Calculate the cell bounds (min_x, max_x, min_y, max_y) of this piece in canonical units.
func get_cell_bounds() -> Rect2i:
	var cells: Array = get_cells()
	if cells.is_empty():
		return Rect2i(0, 0, 0, 0)
		
	var min_x: int = int(cells[0][0])
	var max_x: int = min_x
	var min_y: int = int(cells[0][1])
	var max_y: int = min_y

	for c in cells:
		var cx: int = int(c[0])
		var cy: int = int(c[1])
		min_x = mini(min_x, cx)
		max_x = maxi(max_x, cx)
		min_y = mini(min_y, cy)
		max_y = maxi(max_y, cy)

	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


## Calculate pixel dimensions of this piece shape in canonical pixels.
func get_pixel_size() -> Vector2:
	var bounds: Rect2i = get_cell_bounds()
	return Vector2(bounds.size.x * cell_size, bounds.size.y * cell_size)


## Get the canonical offset from origin (0,0) to center of piece in local space.
func get_center_offset() -> Vector2:
	var bounds: Rect2i = get_cell_bounds()
	var center_x: float = (bounds.position.x + bounds.size.x / 2.0) * cell_size
	var center_y: float = (bounds.position.y + bounds.size.y / 2.0) * cell_size
	return Vector2(center_x, center_y)


## Build child Sprite2D nodes for each cell in the shape inside VisualRoot.
func _build_piece_visuals() -> void:
	_ensure_visual_root()
	for child in visual_root.get_children():
		child.queue_free()

	var center_offset: Vector2 = get_center_offset()
	visual_root.position = center_offset

	var tex: Texture2D = IngredientTheme.get_texture_for_color_index(color_index)

	for c in get_cells():
		var cx: int = int(c[0])
		var cy: int = int(c[1])

		if tex:
			var sprite := Sprite2D.new()
			sprite.texture = tex
			var tex_size: Vector2 = tex.get_size()
			sprite.scale = Vector2((cell_size - 4) / tex_size.x, (cell_size - 4) / tex_size.y)
			# Position sprite relative to visual_root center
			var canonical_pos := Vector2((cx + 0.5) * cell_size, (cy + 0.5) * cell_size)
			sprite.position = canonical_pos - center_offset
			visual_root.add_child(sprite)


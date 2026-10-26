## Tray Slot — Gameplay Scene Script
## One of the tray slots holding a polyomino piece for the player to drag.
class_name TraySlot
extends Control


## Emitted when the player starts dragging the piece from this slot.
signal piece_drag_started(slot: TraySlot, piece_view: PieceView, initial_touch_pos: Vector2)

## The PieceView instance currently in this slot (null if empty/used).
var piece_view: PieceView = null

## Whether this slot has been used in the current tray round.
var is_used: bool = false

## Target visual preview cell size in idle tray (~102px, ~1.0625 of canonical 96px grid cell).
const TARGET_PREVIEW_CELL_SIZE: float = 102.0

## Slot internal margin padding (px).
const SLOT_PADDING: float = 12.0

## Current calculated idle visual scale for the piece in this slot.
var current_idle_scale: float = 1.0625


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resized.connect(_on_resized)


func _on_resized() -> void:
	if piece_view and is_instance_valid(piece_view):
		current_idle_scale = calculate_idle_scale(piece_view)
		piece_view.set_visual_scale(current_idle_scale)
		_center_piece()


## Calculate adaptive idle visual scale so shapes fit comfortably without overflowing slot bounds.
func calculate_idle_scale(piece: PieceView) -> float:
	if not piece:
		return 1.0625
	var bounds: Rect2i = piece.get_cell_bounds()
	var cells_w: float = maxf(float(bounds.size.x), 1.0)
	var cells_h: float = maxf(float(bounds.size.y), 1.0)

	var effective_slot_size: Vector2 = size if (size.x > 0 and size.y > 0) else custom_minimum_size
	if effective_slot_size.x <= 0 or effective_slot_size.y <= 0:
		effective_slot_size = Vector2(330, 360)

	var avail_w: float = maxf(effective_slot_size.x - SLOT_PADDING * 2.0, 1.0)
	var avail_h: float = maxf(effective_slot_size.y - SLOT_PADDING * 2.0, 1.0)

	var max_cell_w: float = avail_w / cells_w
	var max_cell_h: float = avail_h / cells_h

	var fitted_cell_size: float = minf(TARGET_PREVIEW_CELL_SIZE, minf(max_cell_w, max_cell_h))
	return fitted_cell_size / piece.cell_size



## Assign a new piece to this slot, with optional smooth return animation.
func set_piece(piece: PieceView, animated: bool = false) -> void:
	clear_slot()
	piece_view = piece
	is_used = false

	if piece_view:
		add_child(piece_view)
		piece_view.scale = Vector2.ONE  # Canonical logical scale is always ONE
		current_idle_scale = calculate_idle_scale(piece_view)
		_center_piece()

		if animated:
			var vr: Node2D = piece_view.get_visual_root()
			if vr:
				var tween := create_tween()
				tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tween.tween_property(vr, "scale", Vector2(current_idle_scale, current_idle_scale), 0.10)
		else:
			piece_view.set_visual_scale(current_idle_scale)


func play_spawn(delay: float = 0.0) -> void:
	if not piece_view or not is_instance_valid(piece_view):
		return
	var visual_root := piece_view.get_visual_root()
	var final_scale := Vector2(current_idle_scale, current_idle_scale)
	var start_rotation := deg_to_rad(-2.0 if get_index() % 2 == 0 else 2.0)
	AnimationManager.play_spawn(visual_root, final_scale, delay, start_rotation)


func finish_spawn_animation() -> void:
	if not piece_view or not is_instance_valid(piece_view):
		return
	var visual_root := piece_view.get_visual_root()
	AnimationManager.stop_channel(visual_root, &"spawn")
	visual_root.scale = Vector2(current_idle_scale, current_idle_scale)
	visual_root.rotation = 0.0
	piece_view.scale = Vector2.ONE


## Clear piece from this slot.
func clear_slot() -> void:
	if piece_view and is_instance_valid(piece_view):
		piece_view.queue_free()
	piece_view = null
	is_used = false


## Mark this slot as used (piece successfully placed on grid).
func mark_used() -> void:
	is_used = true
	if piece_view and is_instance_valid(piece_view):
		piece_view.visible = false
		piece_view.queue_free()
		piece_view = null


## Remove piece ownership without destroying node (when drag starts).
func detach_piece() -> PieceView:
	finish_spawn_animation()
	var p: PieceView = piece_view
	if p and is_instance_valid(p):
		remove_child(p)
	piece_view = null
	return p


## Check if this slot holds an available piece.
func has_piece() -> bool:
	return not is_used and piece_view != null and is_instance_valid(piece_view)


## Center the piece inside the Control bounds.
func _center_piece() -> void:
	if not piece_view:
		return
	var slot_center: Vector2 = (size if size.x > 0 and size.y > 0 else custom_minimum_size) / 2.0
	var center_offset: Vector2 = piece_view.get_center_offset()
	# Position PieceView origin so that its visual_root (located at center_offset) aligns with slot_center
	piece_view.position = slot_center - center_offset


func _gui_input(event: InputEvent) -> void:
	if not has_piece():
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		piece_drag_started.emit(self, piece_view, get_global_mouse_position())
	elif event is InputEventScreenTouch and event.pressed:
		piece_drag_started.emit(self, piece_view, global_position + event.position)

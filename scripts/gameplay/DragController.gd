## Drag Controller — Gameplay Scene Script
## Handles touch and mouse drag-and-drop for placing polyomino pieces on the grid.
## Features vertical finger offset so finger/thumb does not obscure the piece.
class_name DragController
extends Node


## Emitted when a piece is successfully placed on the grid.
signal piece_placed_success(slot: TraySlot, origin_x: int, origin_y: int, piece_cells: Array, color_index: int)

## Emitted when a drag is cancelled.
signal drag_cancelled()


## References passed during setup.
var grid_view: GridView = null
var grid_system: GridSystem = null
var drag_overlay_container: Node2D = null

## Active dragging state.
var is_dragging: bool = false
var active_slot: TraySlot = null
var active_piece: PieceView = null

## Centralized configurable upward drag lift offset (reference pixels at 1080x1920).
## Tuning this single constant adjusts real-device drag offset across the entire game.
const DRAG_FINGER_OFFSET_Y: float = -180.0

## Sensible clamp bounds for responsive drag lift offset (in pixels).
const DRAG_OFFSET_MIN_Y: float = -140.0
const DRAG_OFFSET_MAX_Y: float = -220.0

## Usable viewport height ratio (180px / 1920px = 0.09375 = ~9.375%).
const DRAG_OFFSET_VIEWPORT_RATIO: float = 0.09375

## Finger offset so thumb/finger doesn't block piece view (in pixels).
## Defaults to centralized DRAG_FINGER_OFFSET_Y (-180.0).
@export var finger_y_offset: float = DRAG_FINGER_OFFSET_Y

## Grid snapping target coordinates.
var current_grid_pos: Vector2i = Vector2i(-1, -1)
var is_current_pos_valid: bool = false


## Drag visual enlargement target scale (1.15 = ~110.4px cell size vs 96px canonical).
const DRAG_TARGET_SCALE: float = 1.15

## Duration of the smooth drag-start enlargement animation (seconds).
const DRAG_SCALE_TWEEN_DURATION: float = 0.10


## Active scale tween.
var _scale_tween: Tween = null


## Calculate responsive upward drag offset based on usable viewport height.
## Clamped between DRAG_OFFSET_MIN_Y (-140) and DRAG_OFFSET_MAX_Y (-220).
static func calculate_responsive_drag_offset(viewport_height: float = 1920.0) -> float:
	var target_lift: float = viewport_height * DRAG_OFFSET_VIEWPORT_RATIO
	var clamped_lift: float = clampf(target_lift, absf(DRAG_OFFSET_MIN_Y), absf(DRAG_OFFSET_MAX_Y))
	return -clamped_lift


func setup(g_view: GridView, g_sys: GridSystem, overlay_node: Node2D) -> void:
	grid_view = g_view
	grid_system = g_sys
	drag_overlay_container = overlay_node

	# Dynamically tune upward drag offset for current device viewport if running in tree
	if is_inside_tree() and get_viewport():
		var vp_h: float = get_viewport().get_visible_rect().size.y
		if vp_h > 0.0:
			finger_y_offset = calculate_responsive_drag_offset(vp_h)


## Start dragging a piece from a tray slot.
func start_drag(slot: TraySlot, piece: PieceView, global_touch_pos: Vector2) -> void:
	if is_dragging or not piece:
		return

	is_dragging = true
	active_slot = slot
	slot.finish_spawn_animation()
	active_piece = slot.detach_piece()

	# Logical root is always canonical Vector2.ONE
	active_piece.scale = Vector2.ONE

	# Determine guaranteed valid global touch coordinates
	var touch_pos: Vector2 = global_touch_pos
	if touch_pos == Vector2.ZERO and slot:
		touch_pos = slot.get_global_mouse_position()

	# Derive adjusted pointer position with upward drag lift offset
	var adjusted_drag_position: Vector2 = touch_pos + Vector2(0, finger_y_offset)
	var center_offset: Vector2 = active_piece.get_center_offset()
	var initial_global_pos: Vector2 = adjusted_drag_position - center_offset

	# Add to overlay container and set global position immediately
	if drag_overlay_container:
		drag_overlay_container.add_child(active_piece)
	else:
		grid_view.add_child(active_piece)

	active_piece.global_position = initial_global_pos

	# Smoothly enlarge visual layer from tray scale to full 1.0 (96px) scale
	var vr: Node2D = active_piece.get_visual_root()
	if vr:
		if _scale_tween and _scale_tween.is_valid():
			_scale_tween.kill()
		_scale_tween = create_tween()
		_scale_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_scale_tween.tween_property(vr, "scale", Vector2(DRAG_TARGET_SCALE, DRAG_TARGET_SCALE), DRAG_SCALE_TWEEN_DURATION)

	_update_drag_position(touch_pos)




## Global input hook: receives all mouse motion and touch drag events continuously.
func _input(event: InputEvent) -> void:
	if not is_dragging or not active_piece:
		return

	if event is InputEventMouseMotion:
		_update_drag_position(event.global_position)
	elif event is InputEventScreenDrag:
		_update_drag_position(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_end_drag(event.global_position)
	elif event is InputEventScreenTouch and not event.pressed:
		_end_drag(event.position)


## Update piece position and grid preview based on touch/mouse position.
func _update_drag_position(global_touch_pos: Vector2) -> void:
	if not active_piece or not is_instance_valid(active_piece):
		return

	# Derive adjusted pointer position with upward drag lift offset
	var adjusted_drag_position: Vector2 = global_touch_pos + Vector2(0, finger_y_offset)
	
	# Center piece on adjusted drag position
	var center_offset: Vector2 = active_piece.get_center_offset()
	active_piece.global_position = adjusted_drag_position - center_offset

	# Check grid snapping position based on cell (0,0) center position
	var origin_cell_center: Vector2 = active_piece.global_position + Vector2(grid_view.cell_size / 2.0, grid_view.cell_size / 2.0)
	current_grid_pos = grid_view.screen_to_grid(origin_cell_center)
	
	var cells: Array = active_piece.get_cells()
	is_current_pos_valid = grid_system.can_place_piece(current_grid_pos.x, current_grid_pos.y, cells)

	# Show placement preview
	grid_view.show_placement_preview(current_grid_pos.x, current_grid_pos.y, cells, is_current_pos_valid)


## Attempt to place piece on release, or return to tray if invalid.
func _end_drag(_global_touch_pos: Vector2) -> void:
	if not is_dragging or not active_piece:
		return

	grid_view.clear_placement_preview()

	var cells: Array = active_piece.get_cells()
	var color_idx: int = active_piece.color_index

	if is_current_pos_valid and current_grid_pos.x >= 0 and current_grid_pos.y >= 0:
		# Success! Place piece in GridSystem
		var success: bool = grid_system.place_piece(current_grid_pos.x, current_grid_pos.y, cells, color_idx)
		if success:
			active_slot.mark_used()
			active_piece.queue_free()
			piece_placed_success.emit(active_slot, current_grid_pos.x, current_grid_pos.y, cells, color_idx)
		else:
			_cancel_drag()
	else:
		_cancel_drag()

	is_dragging = false
	active_slot = null
	active_piece = null


func _cancel_drag() -> void:
	if active_piece and is_instance_valid(active_piece):
		if active_piece.get_parent():
			active_piece.get_parent().remove_child(active_piece)
		if active_slot and is_instance_valid(active_slot):
			active_slot.set_piece(active_piece, true)
	is_dragging = false
	active_slot = null
	active_piece = null
	drag_cancelled.emit()

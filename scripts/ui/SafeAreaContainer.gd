class_name SafeAreaContainer
extends Control


@export var base_margins: Vector4 = Vector4.ZERO

var _safe_rect_override: Rect2 = Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var viewport := get_viewport()
	if viewport and not viewport.size_changed.is_connected(_refresh_layout):
		viewport.size_changed.connect(_refresh_layout)
	_refresh_layout.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED:
		_refresh_layout.call_deferred()


func apply_safe_rect_override(safe_rect: Rect2) -> void:
	_safe_rect_override = safe_rect
	_refresh_layout()


func clear_safe_rect_override() -> void:
	_safe_rect_override = Rect2()
	_refresh_layout()


static func screen_rect_to_viewport_rect(screen_rect: Rect2, screen_transform: Transform2D, viewport_rect: Rect2) -> Rect2:
	if screen_rect.size.x <= 0.0 or screen_rect.size.y <= 0.0:
		return viewport_rect
	var inverse := screen_transform.affine_inverse()
	var mapped_start := inverse * screen_rect.position
	var mapped_end := inverse * screen_rect.end
	var mapped_position := Vector2(minf(mapped_start.x, mapped_end.x), minf(mapped_start.y, mapped_end.y))
	var mapped_size := Vector2(absf(mapped_end.x - mapped_start.x), absf(mapped_end.y - mapped_start.y))
	var mapped := Rect2(mapped_position, mapped_size).intersection(viewport_rect)
	return viewport_rect if mapped.size.x <= 0.0 or mapped.size.y <= 0.0 else mapped


static func calculate_offsets(viewport_rect: Rect2, safe_rect: Rect2, margins: Vector4) -> Vector4:
	var left := safe_rect.position.x - viewport_rect.position.x + margins.x
	var top := safe_rect.position.y - viewport_rect.position.y + margins.y
	var right := -(viewport_rect.end.x - safe_rect.end.x + margins.z)
	var bottom := -(viewport_rect.end.y - safe_rect.end.y + margins.w)
	return Vector4(left, top, right, bottom)


func _resolve_safe_rect(viewport: Viewport, viewport_rect: Rect2) -> Rect2:
	if _safe_rect_override.size.x > 0.0 and _safe_rect_override.size.y > 0.0:
		var overridden := _safe_rect_override.intersection(viewport_rect)
		return viewport_rect if overridden.size.x <= 0.0 or overridden.size.y <= 0.0 else overridden
	if not OS.has_feature("mobile"):
		return viewport_rect
	var native_safe := DisplayServer.get_display_safe_area()
	return screen_rect_to_viewport_rect(
		Rect2(Vector2(native_safe.position), Vector2(native_safe.size)),
		viewport.get_screen_transform(),
		viewport_rect
	)


func _refresh_layout() -> void:
	var viewport := get_viewport()
	if not viewport:
		return
	var viewport_rect := viewport.get_visible_rect()
	var safe_rect := _resolve_safe_rect(viewport, viewport_rect)
	var safe_offsets := calculate_offsets(viewport_rect, safe_rect, base_margins)
	offset_left = safe_offsets.x
	offset_top = safe_offsets.y
	offset_right = safe_offsets.z
	offset_bottom = safe_offsets.w

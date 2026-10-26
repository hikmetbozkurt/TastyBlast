class_name VisualAnimationManager
extends Node


var animations_enabled: bool = true

var _active_tweens: Dictionary = {}


func _channel_key(target: Node, channel: StringName) -> String:
	return "%d:%s" % [target.get_instance_id(), String(channel)]


func stop_channel(target: Node, channel: StringName) -> void:
	if not is_instance_valid(target):
		return
	var key := _channel_key(target, channel)
	var tween := _active_tweens.get(key) as Tween
	if tween and tween.is_valid():
		tween.kill()
	_active_tweens.erase(key)


func _begin_channel(target: Node, channel: StringName) -> Tween:
	stop_channel(target, channel)
	var key := _channel_key(target, channel)
	var tween := target.create_tween()
	_active_tweens[key] = tween
	tween.finished.connect(func() -> void:
		if _active_tweens.get(key) == tween:
			_active_tweens.erase(key)
	)
	return tween


func _prune_invalid_tweens() -> void:
	for key in _active_tweens.keys():
		var tween := _active_tweens.get(key) as Tween
		if not tween or not tween.is_valid():
			_active_tweens.erase(key)


func play_spawn(target: Node, final_scale: Vector2, delay: float = 0.0, start_rotation: float = 0.0) -> Tween:
	if not is_instance_valid(target):
		return null
	stop_channel(target, &"spawn")
	if not animations_enabled:
		target.set("scale", final_scale)
		target.set("rotation", 0.0)
		return null
	target.set("scale", final_scale * 0.85)
	target.set("rotation", start_rotation)
	var tween := _begin_channel(target, &"spawn")
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(target, "scale", final_scale * 1.05, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(target, "rotation", 0.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "scale", final_scale, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return tween


func play_scale_punch(target: Node, peak_scale: Vector2, duration: float = 0.16, channel: StringName = &"scale_punch") -> Tween:
	if not is_instance_valid(target):
		return null
	stop_channel(target, channel)
	if not animations_enabled:
		target.set("scale", Vector2.ONE)
		return null
	target.set("scale", Vector2.ONE)
	var tween := _begin_channel(target, channel)
	tween.tween_property(target, "scale", peak_scale, duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "scale", Vector2.ONE, duration * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween


func play_pop_and_free(target: Node, delay: float = 0.0) -> Tween:
	if not is_instance_valid(target):
		return null
	stop_channel(target, &"clear_pop")
	if not animations_enabled:
		target.queue_free()
		return null
	var base_scale: Vector2 = target.get("scale")
	target.set("modulate", Color.WHITE)
	var tween := _begin_channel(target, &"clear_pop")
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(target, "scale", base_scale * 1.12, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "scale", Vector2.ZERO, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(target, "modulate:a", 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		if is_instance_valid(target):
			target.queue_free()
	)
	return tween


func play_float_and_free(target: Control, rise: float = 70.0, duration: float = 0.85) -> Tween:
	if not is_instance_valid(target):
		return null
	stop_channel(target, &"float")
	if not animations_enabled:
		target.queue_free()
		return null
	target.scale = Vector2(0.5, 0.5)
	target.modulate.a = 1.0
	var destination_y := target.position.y - rise
	var tween := _begin_channel(target, &"float").set_parallel(true)
	tween.tween_property(target, "scale", Vector2(1.2, 1.2), 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "position:y", destination_y, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "modulate:a", 0.0, 0.35).set_delay(maxf(duration - 0.35, 0.0))
	tween.chain().tween_callback(func() -> void:
		if is_instance_valid(target):
			target.queue_free()
	)
	return tween


func count_label(label: Label, start_value: float, end_value: float, duration: float, formatter: Callable, value_sink: Callable = Callable()) -> Tween:
	if not is_instance_valid(label):
		return null
	stop_channel(label, &"count")
	if not animations_enabled:
		label.text = formatter.call(int(round(end_value)))
		if value_sink.is_valid():
			value_sink.call(end_value)
		return null
	var tween := _begin_channel(label, &"count")
	tween.tween_method(func(value: float) -> void:
		if is_instance_valid(label):
			label.text = formatter.call(int(round(value)))
		if value_sink.is_valid():
			value_sink.call(value)
	, start_value, end_value, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return tween


func play_shake(target: Node2D, base_position: Vector2, intensity: float = 8.0, duration: float = 0.25) -> Tween:
	if not is_instance_valid(target):
		return null
	stop_channel(target, &"shake")
	target.position = base_position
	if not animations_enabled:
		return null
	var tween := _begin_channel(target, &"shake")
	var step_duration := duration / 6.0
	for _index in range(5):
		var offset := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tween.tween_property(target, "position", base_position + offset, step_duration)
	tween.tween_property(target, "position", base_position, step_duration)
	return tween


func get_active_tween_count() -> int:
	_prune_invalid_tweens()
	return _active_tweens.size()

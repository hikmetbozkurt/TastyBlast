## Combo Banner — UI Component Script
## Displays animated combo callouts ("2x COMBO!", "SUPER CLEAR!") with scale bounce & fade.
class_name ComboBannerUI
extends Label


func setup(lines_cleared: int, multiplier: float) -> void:
	if lines_cleared >= 3:
		text = "MEGA COMBO! (%.1fx)" % multiplier
		modulate = Color(1.0, 0.4, 0.2, 1.0)
	elif lines_cleared == 2:
		text = "DOUBLE CLEAR! (%.1fx)" % multiplier
		modulate = Color(0.3, 0.9, 0.4, 1.0)
	else:
		text = "COMBO! (%.1fx)" % multiplier
		modulate = Color(0.9, 0.8, 0.2, 1.0)

	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	custom_minimum_size = Vector2(400, 80)
	pivot_offset = Vector2(200, 40)

	var intensity := clampf((float(lines_cleared) - 1.0) * 0.12 + maxf(multiplier - 1.0, 0.0) * 0.08, 0.0, 0.35)
	var peak := Vector2.ONE * (1.12 + intensity)
	rotation = deg_to_rad(-2.0 - intensity * 4.0)
	AnimationManager.play_scale_punch(self, peak, 0.22, &"combo_punch")

	var destination_y := position.y - 50.0
	var motion_tween := create_tween()
	motion_tween.tween_property(self, "position:y", destination_y, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	motion_tween.tween_property(self, "modulate:a", 0.0, 0.4)
	motion_tween.tween_callback(func() -> void:
		if is_instance_valid(self):
			queue_free()
	)

## Floating Score Popup — UI Component Script
## Displays floating point text "+150" at clear location, animating upward and fading out.
class_name ScorePopupUI
extends Label


func setup(points: int, text_prefix: String = "+") -> void:
	text = "%s%d" % [text_prefix, points]
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	custom_minimum_size = Vector2(240, 72)
	pivot_offset = Vector2(120, 36)
	AnimationManager.play_float_and_free(self, 70.0, 0.85)

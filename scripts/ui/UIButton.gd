## UI Button — Helper script for reusable themed button components.
## Handles label text synchronization and refined tactile press/release juice animations.
class_name UIButton
extends Button


@export var text_label: String = "":
	set(val):
		text_label = val
		_update_label_text()

@onready var _label_node: Label = get_node_or_null("Label") as Label

var _press_tween: Tween = null


func _ready() -> void:
	_update_label_text()
	_setup_tactile_juice()


## Set button label text programmatically.
func set_button_text(new_text: String) -> void:
	text_label = new_text


func _update_label_text() -> void:
	if _label_node != null and not text_label.is_empty():
		_label_node.text = text_label


func _setup_tactile_juice() -> void:
	pivot_offset = custom_minimum_size / 2.0 if custom_minimum_size != Vector2.ZERO else size / 2.0

	button_down.connect(func():
		AudioManager.play_sfx("ui_click")
		HapticsManager.light()
		if _press_tween and _press_tween.is_running():
			_press_tween.kill()
		_press_tween = create_tween()
		_press_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_press_tween.tween_property(self, "scale", Vector2(0.96, 0.96), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)

	button_up.connect(func():
		if _press_tween and _press_tween.is_running():
			_press_tween.kill()
		_press_tween = create_tween()
		_press_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_press_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)

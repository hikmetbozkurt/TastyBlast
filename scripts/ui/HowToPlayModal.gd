## How To Play Modal — Reusable UI Component
## Displays instructional information for TastyBlast gameplay, progression, and the World Map.
## Visually modeled on the Settings Credits modal with identical dimensions, palette, and animations.
class_name HowToPlayModal
extends Control

signal closed

@export var modal_box_path: NodePath = "ModalBox"
@export var close_button_path: NodePath = "ModalBox/MarginContainer/ModalVBox/CloseButtonAnchor/CloseButton"
@export var backdrop_path: NodePath = "Backdrop"
@export var scroll_container_path: NodePath = ""

@onready var modal_box: Control = get_node_or_null(modal_box_path) as Control
@onready var close_button: Button = get_node_or_null(close_button_path) as Button
@onready var backdrop: Control = get_node_or_null(backdrop_path) as Control
@onready var scroll_container: ScrollContainer = (get_node_or_null(scroll_container_path) as ScrollContainer) if not scroll_container_path.is_empty() else null

var _tween: Tween = null


func _ready() -> void:
	visible = false
	z_index = 20

	if close_button:
		close_button.pressed.connect(close)
		_attach_button_juice(close_button)

	if backdrop:
		backdrop.gui_input.connect(_on_backdrop_gui_input)


func _exit_tree() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
		_tween = null


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()
	elif event is InputEventScreenTouch and event.pressed:
		close()


func open() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	AudioManager.play_sfx("button_tap")
	HapticsManager.light()

	visible = true
	modulate.a = 0.0

	if scroll_container:
		scroll_container.scroll_vertical = 0

	var panel: Control = modal_box if modal_box else self
	panel.pivot_offset = panel.size / 2.0 if panel.size != Vector2.ZERO else panel.custom_minimum_size / 2.0
	panel.scale = Vector2(0.92, 0.92)

	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	if not visible:
		return

	if _tween and _tween.is_valid():
		_tween.kill()

	AudioManager.play_sfx("button_tap")
	HapticsManager.light()

	var panel: Control = modal_box if modal_box else self

	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(panel, "scale", Vector2(0.94, 0.94), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.finished.connect(func():
		visible = false
		modulate.a = 1.0
		panel.scale = Vector2.ONE
		closed.emit()
	)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and visible:
		close()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _attach_button_juice(btn: Button) -> void:
	btn.pivot_offset = btn.custom_minimum_size / 2.0
	btn.button_down.connect(func():
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2(0.94, 0.94), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	btn.button_up.connect(func():
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)

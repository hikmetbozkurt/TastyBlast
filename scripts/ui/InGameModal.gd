## In-Game Modal — Universal Modal System & Pause/Settings Controller
## Manages distinct Pause and In-Game Settings states, full-screen dim overlay,
## centered modal panel (panel_modal.png), audio/vibration toggles,
## smooth pop-in/fade transitions, and game pause synchronization.
class_name InGameModal
extends CanvasLayer


@export var dim_overlay_path: NodePath = "DimOverlay"
@export var modal_panel_path: NodePath = "SafeArea/ModalPanel"
@export var pause_container_path: NodePath = "SafeArea/ModalPanel/PauseContainer"
@export var settings_container_path: NodePath = "SafeArea/ModalPanel/SettingsContainer"

@export var resume_button_path: NodePath = "SafeArea/ModalPanel/PauseContainer/ButtonsVBox/ResumeButton"
@export var menu_button_path: NodePath = "SafeArea/ModalPanel/PauseContainer/ButtonsVBox/MenuButton"

@export var music_toggle_path: NodePath = "SafeArea/ModalPanel/SettingsContainer/ControlsVBox/MusicRow/MusicToggle"
@export var music_volume_slider_path: NodePath = "SafeArea/ModalPanel/SettingsContainer/ControlsVBox/MusicVolumeRow/MusicVolumeSlider"
@export var music_volume_label_path: NodePath = "SafeArea/ModalPanel/SettingsContainer/ControlsVBox/MusicVolumeRow/MusicVolumeValueLabel"
@export var sfx_toggle_path: NodePath = "SafeArea/ModalPanel/SettingsContainer/ControlsVBox/SFXRow/SFXToggle"
@export var haptics_toggle_path: NodePath = "SafeArea/ModalPanel/SettingsContainer/ControlsVBox/HapticsRow/HapticsToggle"
@export var done_button_path: NodePath = "SafeArea/ModalPanel/SettingsContainer/ControlsVBox/DoneButton"

@onready var dim_overlay: ColorRect = get_node_or_null(dim_overlay_path) as ColorRect
@onready var modal_panel: Control = get_node_or_null(modal_panel_path) as Control
@onready var pause_container: Control = get_node_or_null(pause_container_path) as Control
@onready var settings_container: Control = get_node_or_null(settings_container_path) as Control

@onready var resume_button: Button = get_node_or_null(resume_button_path) as Button
@onready var menu_button: Button = get_node_or_null(menu_button_path) as Button

@onready var music_toggle: CheckButton = get_node_or_null(music_toggle_path) as CheckButton
@onready var music_volume_slider: HSlider = get_node_or_null(music_volume_slider_path) as HSlider
@onready var music_volume_label: Label = get_node_or_null(music_volume_label_path) as Label
@onready var sfx_toggle: CheckButton = get_node_or_null(sfx_toggle_path) as CheckButton
@onready var haptics_toggle: CheckButton = get_node_or_null(haptics_toggle_path) as CheckButton
@onready var done_button: Button = get_node_or_null(done_button_path) as Button

var _modal_tween: Tween = null
var _is_closing: bool = false


func _ready() -> void:
	# Guarantee modal processes while SceneTree is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	_init_pause_buttons()
	_init_toggles()
	_init_settings_buttons()

	# Initially hidden
	visible = false


func _init_pause_buttons() -> void:
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)


func _init_settings_buttons() -> void:
	if done_button:
		done_button.pressed.connect(_on_done_pressed)


func _init_toggles() -> void:
	if music_toggle:
		var is_on: bool = SaveManager.get_setting("music_enabled", true)
		music_toggle.button_pressed = is_on
		_update_toggle_visual(music_toggle, is_on, false)
		music_toggle.toggled.connect(_on_music_toggled)

	if music_volume_slider:
		var saved_volume: float = float(SaveManager.get_setting("music_volume", 70.0))
		music_volume_slider.value = saved_volume
		if music_volume_label:
			music_volume_label.text = str(int(saved_volume))
		music_volume_slider.value_changed.connect(_on_music_volume_changed)

	if sfx_toggle:
		var is_on: bool = SaveManager.get_setting("sfx_enabled", true)
		sfx_toggle.button_pressed = is_on
		_update_toggle_visual(sfx_toggle, is_on, false)
		sfx_toggle.toggled.connect(_on_sfx_toggled)

	if haptics_toggle:
		var is_on: bool = SaveManager.get_setting("haptics", SaveManager.get_setting("haptics_enabled", true))
		haptics_toggle.button_pressed = is_on
		_update_toggle_visual(haptics_toggle, is_on, false)
		haptics_toggle.toggled.connect(_on_haptics_toggled)


func _refresh_toggles() -> void:
	if music_toggle:
		var is_on: bool = SaveManager.get_setting("music_enabled", true)
		music_toggle.button_pressed = is_on
		_update_toggle_visual(music_toggle, is_on, false)

	if music_volume_slider:
		var saved_volume: float = float(SaveManager.get_setting("music_volume", 70.0))
		music_volume_slider.value = saved_volume
		if music_volume_label:
			music_volume_label.text = str(int(saved_volume))

	if sfx_toggle:
		var is_on: bool = SaveManager.get_setting("sfx_enabled", true)
		sfx_toggle.button_pressed = is_on
		_update_toggle_visual(sfx_toggle, is_on, false)

	if haptics_toggle:
		var is_on: bool = SaveManager.get_setting("haptics", SaveManager.get_setting("haptics_enabled", true))
		haptics_toggle.button_pressed = is_on
		_update_toggle_visual(haptics_toggle, is_on, false)


func _update_toggle_visual(toggle_btn: CheckButton, is_on: bool, animate: bool) -> void:
	if not toggle_btn:
		return
	var bg_panel := toggle_btn.get_node_or_null("BgPanel") as Panel
	var knob := toggle_btn.get_node_or_null("Knob") as Panel
	if not bg_panel or not knob:
		return

	var horizontal_padding: float = 6.0
	var target_x: float = toggle_btn.size.x - knob.size.x - horizontal_padding if is_on else horizontal_padding
	var target_bg_color: Color = Color(0.30, 0.72, 0.36, 1.0) if is_on else Color(0.72, 0.64, 0.56, 1.0)

	var current_style := bg_panel.get_theme_stylebox("panel")
	var bg_style: StyleBoxFlat = null
	if current_style is StyleBoxFlat:
		bg_style = current_style.duplicate() as StyleBoxFlat
	else:
		bg_style = StyleBoxFlat.new()
		bg_style.corner_radius_top_left = 22
		bg_style.corner_radius_top_right = 22
		bg_style.corner_radius_bottom_right = 22
		bg_style.corner_radius_bottom_left = 22
		bg_style.border_width_left = 3
		bg_style.border_width_top = 3
		bg_style.border_width_right = 3
		bg_style.border_width_bottom = 3
		bg_style.border_color = Color(0.36, 0.22, 0.13, 1.0)

	if animate:
		var tween := create_tween().set_parallel(true)
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(knob, "position:x", target_x, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(bg_style, "bg_color", target_bg_color, 0.15)
		bg_panel.add_theme_stylebox_override("panel", bg_style)
	else:
		knob.position.x = target_x
		bg_style.bg_color = target_bg_color
		bg_panel.add_theme_stylebox_override("panel", bg_style)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_back_request()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_handle_back_request()
		get_viewport().set_input_as_handled()


## Handle system Back button or Escape key input.
func _handle_back_request() -> void:
	if visible:
		resume_game()
	elif GameManager.current_state == GameManager.GameState.PLAYING:
		show_pause_state()


## Play pop-in opening transition for modal panel and dim overlay.
func _play_open_animation() -> void:
	if not modal_panel:
		return

	_is_closing = false
	if _modal_tween and _modal_tween.is_running():
		_modal_tween.kill()

	modal_panel.pivot_offset = modal_panel.size / 2.0 if modal_panel.size != Vector2.ZERO else modal_panel.custom_minimum_size / 2.0
	modal_panel.scale = Vector2(0.88, 0.88)
	modal_panel.modulate.a = 0.0

	if dim_overlay:
		dim_overlay.modulate.a = 0.0

	_modal_tween = create_tween().set_parallel(true)
	_modal_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	if dim_overlay:
		_modal_tween.tween_property(dim_overlay, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Sequential bounce: 0.88 -> 1.03 (0.15s) -> 1.00 (0.10s)
	var scale_seq := create_tween().set_parallel(false)
	scale_seq.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	scale_seq.tween_property(modal_panel, "scale", Vector2(1.03, 1.03), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	scale_seq.tween_property(modal_panel, "scale", Vector2(1.0, 1.0), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	_modal_tween.tween_property(modal_panel, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Play fade/scale-out closing transition before executing on_complete callback.
func _play_close_animation(on_complete: Callable) -> void:
	if not modal_panel or not visible:
		on_complete.call()
		return

	if _is_closing:
		return
	_is_closing = true

	if _modal_tween and _modal_tween.is_running():
		_modal_tween.kill()

	_modal_tween = create_tween().set_parallel(true)
	_modal_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_modal_tween.tween_property(modal_panel, "scale", Vector2(0.95, 0.95), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_modal_tween.tween_property(modal_panel, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if dim_overlay:
		_modal_tween.tween_property(dim_overlay, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	_modal_tween.finished.connect(func():
		_is_closing = false
		on_complete.call()
	)


## Display the Pause Menu state and pause the SceneTree.
func show_pause_state() -> void:
	SaveManager.save_game()
	get_tree().paused = true
	GameManager.pause_game()

	if pause_container:
		pause_container.visible = true
	if settings_container:
		settings_container.visible = false

	visible = true
	_play_open_animation()


## Display the In-Game Settings state and pause the SceneTree.
func show_settings_state() -> void:
	SaveManager.save_game()
	get_tree().paused = true
	GameManager.pause_game()

	_refresh_toggles()

	if pause_container:
		pause_container.visible = false
	if settings_container:
		settings_container.visible = true

	visible = true
	_play_open_animation()


## Alias for backwards compatibility.
func show_pause_menu() -> void:
	show_pause_state()


## Resume the gameplay, unpause the SceneTree, and hide the modal after animation.
func resume_game() -> void:
	_play_close_animation(func():
		get_tree().paused = false
		GameManager.resume_game()
		visible = false
	)


func _on_resume_pressed() -> void:
	AudioManager.play_sfx("button_tap")
	resume_game()


func _on_menu_pressed() -> void:
	AudioManager.play_sfx("button_tap")
	SaveManager.save_game()
	_play_close_animation(func():
		get_tree().paused = false
		GameManager.go_to_menu()
		get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")
	)


func _on_done_pressed() -> void:
	AudioManager.play_sfx("button_tap")
	resume_game()


func _on_music_toggled(toggled_on: bool) -> void:
	AudioManager.play_sfx("button_tap")
	AudioManager.set_music_mute(not toggled_on)
	_update_toggle_visual(music_toggle, toggled_on, true)


func _on_music_volume_changed(value: float) -> void:
	if music_volume_label:
		music_volume_label.text = str(int(value))
	AudioManager.set_music_volume(value)


func _on_sfx_toggled(toggled_on: bool) -> void:
	AudioManager.set_sfx_mute(not toggled_on)
	AudioManager.play_sfx("button_tap")
	_update_toggle_visual(sfx_toggle, toggled_on, true)


func _on_haptics_toggled(toggled_on: bool) -> void:
	AudioManager.play_sfx("button_tap")
	HapticsManager.enabled = toggled_on
	SaveManager.set_setting("haptics", toggled_on)
	SaveManager.set_setting("haptics_enabled", toggled_on)
	SaveManager.save_game()
	_update_toggle_visual(haptics_toggle, toggled_on, true)
	if toggled_on:
		HapticsManager.light()

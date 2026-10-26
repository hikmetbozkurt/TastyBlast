## Settings UI — UI Script
## Manages user preferences: music toggle, SFX toggle, haptics, language,
## credits modal, privacy policy external link, and reset progress confirmation dialog.
class_name SettingsUI
extends Control


const PRIVACY_POLICY_URL: String = "https://hikmetbozkurt.github.io/tastyblast-privacy/"

@export var music_toggle_path: NodePath = "SafeArea/MainVBox/SettingsPanel/PanelMargin/PanelVBox/AudioContainer/MusicRow/MusicToggle"
@export var music_volume_slider_path: NodePath = "SafeArea/MainVBox/SettingsPanel/PanelMargin/PanelVBox/AudioContainer/MusicVolumeRow/MusicVolumeSlider"
@export var music_volume_label_path: NodePath = "SafeArea/MainVBox/SettingsPanel/PanelMargin/PanelVBox/AudioContainer/MusicVolumeRow/MusicVolumeValueLabel"
@export var sfx_toggle_path: NodePath = "SafeArea/MainVBox/SettingsPanel/PanelMargin/PanelVBox/AudioContainer/SFXRow/SFXToggle"
@export var haptics_toggle_path: NodePath = "SafeArea/MainVBox/SettingsPanel/PanelMargin/PanelVBox/GameplayContainer/HapticsRow/HapticsToggle"

@export var language_value_label_path: NodePath = "SafeArea/MainVBox/SettingsPanel/PanelMargin/PanelVBox/LanguageContainer/LanguageRow/LanguageValueLabel"

@export var how_to_play_button_path: NodePath = "SafeArea/MainVBox/SettingsPanel/PanelMargin/PanelVBox/OtherContainer/OtherButtonsVBox/HowToPlayButton"
@export var credits_button_path: NodePath = "SafeArea/MainVBox/SettingsPanel/PanelMargin/PanelVBox/OtherContainer/OtherButtonsVBox/CreditsButton"
@export var privacy_button_path: NodePath = "SafeArea/MainVBox/SettingsPanel/PanelMargin/PanelVBox/OtherContainer/OtherButtonsVBox/PrivacyButton"
@export var reset_button_path: NodePath = "SafeArea/MainVBox/SettingsPanel/PanelMargin/PanelVBox/OtherContainer/OtherButtonsVBox/ResetButton"

@export var back_button_path: NodePath = "SafeArea/MainVBox/BackButtonAnchor/BackButton"

@export var reset_dialog_path: NodePath = "ResetConfirmDialog"
@export var reset_cancel_button_path: NodePath = "ResetConfirmDialog/DialogBox/MarginContainer/DialogVBox/ActionsHBox/CancelButton"
@export var reset_confirm_button_path: NodePath = "ResetConfirmDialog/DialogBox/MarginContainer/DialogVBox/ActionsHBox/ConfirmResetButton"

@export var credits_modal_path: NodePath = "CreditsModal"
@export var credits_close_button_path: NodePath = "CreditsModal/ModalBox/MarginContainer/ModalVBox/CloseButtonAnchor/CloseButton"
@export var credits_rich_text_path: NodePath = "CreditsModal/ModalBox/MarginContainer/ModalVBox/ScrollContainer/CreditsRichText"
@export var credits_scroll_container_path: NodePath = "CreditsModal/ModalBox/MarginContainer/ModalVBox/ScrollContainer"
@export var how_to_play_modal_path: NodePath = "HowToPlayModal"


@onready var music_toggle: CheckButton = get_node_or_null(music_toggle_path) as CheckButton
@onready var music_volume_slider: HSlider = get_node_or_null(music_volume_slider_path) as HSlider
@onready var music_volume_label: Label = get_node_or_null(music_volume_label_path) as Label
@onready var sfx_toggle: CheckButton = get_node_or_null(sfx_toggle_path) as CheckButton
@onready var haptics_toggle: CheckButton = get_node_or_null(haptics_toggle_path) as CheckButton

@onready var language_value_label: Label = get_node_or_null(language_value_label_path) as Label

@onready var how_to_play_button: Button = get_node_or_null(how_to_play_button_path) as Button
@onready var credits_button: Button = get_node_or_null(credits_button_path) as Button
@onready var privacy_button: Button = get_node_or_null(privacy_button_path) as Button
@onready var reset_button: Button = get_node_or_null(reset_button_path) as Button

@onready var back_button: Button = get_node_or_null(back_button_path) as Button

@onready var reset_dialog: Control = get_node_or_null(reset_dialog_path) as Control
@onready var reset_cancel_button: Button = get_node_or_null(reset_cancel_button_path) as Button
@onready var reset_confirm_button: Button = get_node_or_null(reset_confirm_button_path) as Button

@onready var credits_modal: Control = get_node_or_null(credits_modal_path) as Control
@onready var credits_close_button: Button = get_node_or_null(credits_close_button_path) as Button
@onready var credits_rich_text: RichTextLabel = get_node_or_null(credits_rich_text_path) as RichTextLabel
@onready var credits_scroll_container: ScrollContainer = get_node_or_null(credits_scroll_container_path) as ScrollContainer
@onready var how_to_play_modal: Control = get_node_or_null(how_to_play_modal_path) as Control


func _ready() -> void:
	AudioManager.play_music("main_menu")
	_init_toggles()
	_init_buttons()
	_init_language()
	_init_modals()


func _init_modals() -> void:
	if reset_dialog:
		reset_dialog.visible = false

	if credits_modal:
		credits_modal.visible = false

	if credits_rich_text:
		credits_rich_text.meta_clicked.connect(_on_credits_link_clicked)


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


func _init_buttons() -> void:
	if how_to_play_button:
		how_to_play_button.pressed.connect(_on_how_to_play_pressed)
		_attach_button_juice(how_to_play_button)

	if credits_button:
		credits_button.pressed.connect(_on_credits_pressed)
		_attach_button_juice(credits_button)

	if privacy_button:
		privacy_button.pressed.connect(_on_privacy_policy_pressed)
		_attach_button_juice(privacy_button)

	if reset_button:
		reset_button.pressed.connect(_on_reset_progress_pressed)
		_attach_button_juice(reset_button)

	if back_button:
		back_button.pressed.connect(_on_back_pressed)
		_attach_button_juice(back_button)

	if reset_cancel_button:
		reset_cancel_button.pressed.connect(_on_reset_cancel_pressed)
		_attach_button_juice(reset_cancel_button)

	if reset_confirm_button:
		reset_confirm_button.pressed.connect(_on_reset_confirm_pressed)
		_attach_button_juice(reset_confirm_button)

	if credits_close_button:
		credits_close_button.pressed.connect(_on_credits_close_pressed)
		_attach_button_juice(credits_close_button)


func _init_language() -> void:
	if language_value_label:
		var current_lang: String = SaveManager.get_setting("language", "English")
		language_value_label.text = current_lang


func _attach_button_juice(button: Button) -> void:
	if not button:
		return
	button.pivot_offset = button.custom_minimum_size / 2.0
	button.button_down.connect(func():
		var tween := create_tween()
		tween.tween_property(button, "scale", Vector2(0.95, 0.95), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	button.button_up.connect(func():
		var tween := create_tween()
		tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)


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
		tween.tween_property(knob, "position:x", target_x, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(bg_style, "bg_color", target_bg_color, 0.15)
		bg_panel.add_theme_stylebox_override("panel", bg_style)
	else:
		knob.position.x = target_x
		bg_style.bg_color = target_bg_color
		bg_panel.add_theme_stylebox_override("panel", bg_style)


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


func _on_how_to_play_pressed() -> void:
	if how_to_play_modal:
		how_to_play_modal.open()


func _on_credits_pressed() -> void:
	AudioManager.play_sfx("button_tap")
	if credits_scroll_container:
		credits_scroll_container.scroll_vertical = 0
	if credits_modal:
		_animate_modal_open(credits_modal)


func _on_credits_close_pressed() -> void:
	AudioManager.play_sfx("button_tap")
	if credits_modal:
		_animate_modal_close(credits_modal)


func _on_credits_link_clicked(meta: Variant) -> void:
	var url := str(meta).strip_edges()
	if url.begins_with("https://"):
		var err := OS.shell_open(url)
		if err != OK:
			push_warning("SettingsUI: Failed to open external URL: %s (code %d)" % [url, err])
	else:
		push_warning("SettingsUI: Refused non-HTTPS URL: %s" % url)


func _on_privacy_policy_pressed() -> void:
	AudioManager.play_sfx("button_tap")
	if PRIVACY_POLICY_URL.begins_with("https://"):
		var err := OS.shell_open(PRIVACY_POLICY_URL)
		if err != OK:
			push_warning("SettingsUI: Failed to open Privacy Policy: %s (code %d)" % [PRIVACY_POLICY_URL, err])
	else:
		push_warning("SettingsUI: Invalid privacy policy URL scheme")


func _on_reset_progress_pressed() -> void:
	AudioManager.play_sfx("button_tap")
	if reset_dialog:
		_animate_modal_open(reset_dialog)


func _on_reset_cancel_pressed() -> void:
	AudioManager.play_sfx("button_tap")
	if reset_dialog:
		_animate_modal_close(reset_dialog)


func _on_reset_confirm_pressed() -> void:
	AudioManager.play_sfx("button_tap")
	if reset_dialog:
		_animate_modal_close(reset_dialog)
	SaveManager.reset_all_data()


func _animate_modal_open(modal_root: Control) -> void:
	if not modal_root:
		return
	modal_root.visible = true
	modal_root.modulate.a = 0.0
	var panel: Control = modal_root.get_child(1) if modal_root.get_child_count() > 1 else modal_root
	panel.pivot_offset = panel.size / 2.0 if panel.size != Vector2.ZERO else panel.custom_minimum_size / 2.0
	panel.scale = Vector2(0.92, 0.92)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(modal_root, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _animate_modal_close(modal_root: Control) -> void:
	if not modal_root:
		return
	var panel: Control = modal_root.get_child(1) if modal_root.get_child_count() > 1 else modal_root
	var tween := create_tween().set_parallel(true)
	tween.tween_property(modal_root, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "scale", Vector2(0.94, 0.94), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(func():
		modal_root.visible = false
		modal_root.modulate.a = 1.0
		panel.scale = Vector2.ONE
	)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_back_request()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_handle_back_request()
		get_viewport().set_input_as_handled()


func _handle_back_request() -> void:
	if how_to_play_modal and how_to_play_modal.visible:
		how_to_play_modal.close()
		return
	if credits_modal and credits_modal.visible:
		_on_credits_close_pressed()
		return
	if reset_dialog and reset_dialog.visible:
		_on_reset_cancel_pressed()
		return
	_on_back_pressed()


func _on_back_pressed() -> void:
	AudioManager.play_sfx("button_tap")
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")

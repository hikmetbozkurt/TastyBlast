## Main Menu — UI Script
## Handles main menu navigation, high score display, screen transitions,
## logo breathing idle loop, and main CTA button pulse animation.
class_name MainMenuUI
extends Control


@export var game_logo_path: NodePath = "SafeArea/GameLogo"
@export var high_score_label_path: NodePath = "SafeArea/VBox/HighScoreLabel"
@export var play_button_path: NodePath = "SafeArea/VBox/PlayButton"
@export var world_map_button_path: NodePath = "SafeArea/VBox/WorldMapButton"
@export var settings_button_path: NodePath = "SafeArea/VBox/SettingsButton"

@onready var game_logo: TextureRect = get_node_or_null(game_logo_path) as TextureRect
@onready var high_score_label: Label = get_node_or_null(high_score_label_path) as Label
@onready var play_button: Button = get_node_or_null(play_button_path) as Button
@onready var world_map_button: Button = get_node_or_null(world_map_button_path) as Button
@onready var settings_button: Button = get_node_or_null(settings_button_path) as Button

var _logo_tween: Tween = null
var _play_pulse_tween: Tween = null
var _button_juice_tweens: Dictionary = {}


func _ready() -> void:
	GameManager.change_state(GameManager.GameState.MENU)
	
	SaveManager.progress_reset.connect(update_ui)
	update_ui()

	if play_button:
		play_button.pressed.connect(_on_play_pressed)
		_setup_play_button_interaction()
	if world_map_button:
		world_map_button.pressed.connect(_on_world_map_pressed)
		_attach_button_juice(world_map_button)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
		_attach_button_juice(settings_button)

	# Start subtle idle animations
	_start_logo_breathing()
	_start_play_button_pulse()

	# Play menu music theme
	AudioManager.play_music("main_menu")


## Update UI elements reflecting current save data.
func update_ui() -> void:
	if high_score_label:
		high_score_label.text = "High Score: %d" % SaveManager.get_high_score()


## Subtle continuous breathing animation for game logo: 1.00 -> 1.02 -> 1.00 over 1.4s each way.
func _start_logo_breathing() -> void:
	if not game_logo:
		return

	game_logo.pivot_offset = game_logo.size / 2.0 if game_logo.size != Vector2.ZERO else game_logo.custom_minimum_size / 2.0
	game_logo.scale = Vector2(1.0, 1.0)

	if _logo_tween and _logo_tween.is_running():
		_logo_tween.kill()

	_logo_tween = create_tween().set_loops()
	_logo_tween.tween_property(game_logo, "scale", Vector2(1.02, 1.02), 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_logo_tween.tween_property(game_logo, "scale", Vector2(1.0, 1.0), 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Continuous soft pulse animation exclusively for the primary "PLAY" button.
func _start_play_button_pulse() -> void:
	if not play_button:
		return

	play_button.pivot_offset = play_button.size / 2.0 if play_button.size != Vector2.ZERO else play_button.custom_minimum_size / 2.0

	if _play_pulse_tween and _play_pulse_tween.is_running():
		_play_pulse_tween.kill()

	_play_pulse_tween = create_tween().set_loops()
	_play_pulse_tween.tween_property(play_button, "scale", Vector2(1.015, 1.015), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_play_pulse_tween.tween_property(play_button, "scale", Vector2(1.0, 1.0), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _setup_play_button_interaction() -> void:
	if not play_button:
		return

	play_button.pivot_offset = play_button.size / 2.0 if play_button.size != Vector2.ZERO else play_button.custom_minimum_size / 2.0

	play_button.button_down.connect(func():
		if _play_pulse_tween and _play_pulse_tween.is_running():
			_play_pulse_tween.kill()
		_animate_button_scale(play_button, Vector2(0.96, 0.96), 0.08)
	)

	play_button.button_up.connect(func():
		var release_tween := _animate_button_scale(play_button, Vector2.ONE, 0.08)
		release_tween.finished.connect(func():
			_start_play_button_pulse()
		)
	)


func _animate_button_scale(button: Control, target_scale: Vector2, duration: float) -> Tween:
	var key := button.get_instance_id()
	var previous := _button_juice_tweens.get(key) as Tween
	if previous and previous.is_valid():
		previous.kill()
	var tween := button.create_tween()
	_button_juice_tweens[key] = tween
	tween.tween_property(button, "scale", target_scale, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void:
		if _button_juice_tweens.get(key) == tween:
			_button_juice_tweens.erase(key)
	)
	return tween


func _attach_button_juice(button: Button) -> void:
	if not button:
		return

	button.pivot_offset = button.size / 2.0 if button.size != Vector2.ZERO else button.custom_minimum_size / 2.0

	button.button_down.connect(func():
		_animate_button_scale(button, Vector2(0.96, 0.96), 0.08)
	)

	button.button_up.connect(func():
		_animate_button_scale(button, Vector2.ONE, 0.08)
	)


func _on_play_pressed() -> void:
	AudioManager.play_sfx("button_tap")
	var target_region: String = SaveManager.get_last_played_region()
	SaveManager.set_active_region(target_region)
	var progress := RestaurantProgress.new()
	var scene_path: String = progress.get_playing_scene_path(target_region)
	get_tree().change_scene_to_file(scene_path)


func _on_world_map_pressed() -> void:
	AudioManager.play_sfx("button_tap")
	get_tree().change_scene_to_file("res://scenes/main/RestaurantProgress.tscn")


func _on_settings_pressed() -> void:
	AudioManager.play_sfx("button_tap")
	get_tree().change_scene_to_file("res://scenes/main/Settings.tscn")

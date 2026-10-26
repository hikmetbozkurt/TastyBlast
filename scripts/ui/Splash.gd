## Splash Screen — UI Script
## Displays initial game logo with smooth scale/fade animation and transitions to Main Menu.
class_name SplashUI
extends Control


@export var logo_path: NodePath = "Logo"
@export var loading_label_path: NodePath = "LoadingLabel"
@export var transition_delay: float = 1.8

@onready var logo: TextureRect = get_node_or_null(logo_path) as TextureRect
@onready var loading_label: Label = get_node_or_null(loading_label_path) as Label

var _has_transitioned: bool = false


func _ready() -> void:
	GameManager.change_state(GameManager.GameState.SPLASH)
	AudioManager.play_music("main_menu")

	# Initial hidden/scaled state for entrance animation
	if logo:
		logo.modulate.a = 0.0
		logo.scale = Vector2(0.8, 0.8)
		logo.pivot_offset = logo.custom_minimum_size / 2.0

	if loading_label:
		loading_label.modulate.a = 0.0

	_start_splash_animation()


func _start_splash_animation() -> void:
	var tween := create_tween()

	# Animate logo fade-in and subtle scale-up
	if logo:
		tween.tween_property(logo, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(logo, "scale", Vector2(1.0, 1.0), 1.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Fade in loading indicator slightly after logo starts
	if loading_label:
		tween.parallel().tween_property(loading_label, "modulate:a", 0.85, 0.6).set_delay(0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# After presentation delay, transition smoothly to Main Menu
	var wait_time: float = max(0.5, transition_delay - 1.1)
	tween.tween_interval(wait_time)
	tween.tween_callback(_transition_to_main_menu)


func _transition_to_main_menu() -> void:
	if _has_transitioned:
		return
	_has_transitioned = true
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")

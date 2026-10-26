## Pause Menu — UI Script
## Manages game pause overlay, resume, and return to menu navigation.
class_name PauseMenuUI
extends Control


@export var resume_button_path: NodePath = "VBox/ResumeButton"
@export var menu_button_path: NodePath = "VBox/MenuButton"

@onready var resume_button: Button = get_node_or_null(resume_button_path) as Button
@onready var menu_button: Button = get_node_or_null(menu_button_path) as Button


func _ready() -> void:
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)


func _on_resume_pressed() -> void:
	AudioManager.play_sfx("button_tap")
	GameManager.resume_game()
	queue_free()


func _on_menu_pressed() -> void:
	AudioManager.play_sfx("button_tap")
	GameManager.go_to_menu()
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")

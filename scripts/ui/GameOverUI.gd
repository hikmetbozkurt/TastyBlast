## Game Over UI — UI Script
## Displays final score with count-up animation, high score status,
## cumulative region progress towards next cuisine unlock,
## pop-in title animation, and navigation using reusable UIButton components.
class_name GameOverUI
extends Control


@export var title_path: NodePath = "SafeArea/ContentScroll/CenterContainer/ContentVBox/Title"
@export var score_value_path: NodePath = "SafeArea/ContentScroll/CenterContainer/ContentVBox/ScoreCard/Margin/CardVBox/FinalScoreBox/FinalScoreValue"
@export var high_score_value_path: NodePath = "SafeArea/ContentScroll/CenterContainer/ContentVBox/ScoreCard/Margin/CardVBox/HighScoreBox/HighScoreValue"
@export var new_high_score_badge_path: NodePath = "SafeArea/ContentScroll/CenterContainer/ContentVBox/ScoreCard/Margin/CardVBox/NewHighScoreBadge"
@export var region_progress_value_path: NodePath = "SafeArea/ContentScroll/CenterContainer/ContentVBox/ScoreCard/Margin/CardVBox/RegionProgressBox/HeaderHBox/RegionProgressValue"
@export var region_progress_bar_path: NodePath = "SafeArea/ContentScroll/CenterContainer/ContentVBox/ScoreCard/Margin/CardVBox/RegionProgressBox/RegionProgressBar"
@export var play_again_button_path: NodePath = "SafeArea/ContentScroll/CenterContainer/ContentVBox/ButtonsVBox/PlayAgainButton"
@export var menu_button_path: NodePath = "SafeArea/ContentScroll/CenterContainer/ContentVBox/ButtonsVBox/MenuButton"

@onready var title_label: Label = get_node_or_null(title_path) as Label
@onready var score_value_label: Label = get_node_or_null(score_value_path) as Label
@onready var high_score_value_label: Label = get_node_or_null(high_score_value_path) as Label
@onready var new_high_score_badge: Control = get_node_or_null(new_high_score_badge_path) as Control
@onready var region_progress_value_label: Label = get_node_or_null(region_progress_value_path) as Label
@onready var region_progress_bar: ProgressBar = get_node_or_null(region_progress_bar_path) as ProgressBar
@onready var play_again_button: Button = get_node_or_null(play_again_button_path) as Button
@onready var menu_button: Button = get_node_or_null(menu_button_path) as Button

## Count-up animation state
var _score_tween: Tween = null


func _ready() -> void:
	var final_score: int = GameManager.current_score
	var high_score: int = SaveManager.get_high_score()
	var active_region_id: String = SaveManager.get_active_region()
	var progress := RestaurantProgress.new()
	var threshold: int = progress.get_region_threshold(active_region_id)
	var cumulative_score: int = SaveManager.get_region_score(active_region_id)

	# 1. Animate Title pop-in
	_animate_title_pop_in()

	# 2. Check if new high score achieved
	var is_new_high: bool = final_score >= high_score and final_score > 0
	if new_high_score_badge:
		new_high_score_badge.visible = is_new_high
		if is_new_high:
			_animate_badge_pop()

	# 3. High Score display
	if high_score_value_label:
		high_score_value_label.text = _format_number(high_score)

	# 4. Regional Progress display
	if threshold <= 0 or cumulative_score >= threshold:
		if region_progress_value_label:
			region_progress_value_label.text = "COMPLETE"
			region_progress_value_label.add_theme_color_override("font_color", Color(0.20, 0.65, 0.25, 1.0))
		if region_progress_bar:
			region_progress_bar.max_value = 1
			region_progress_bar.value = 1
	else:
		if region_progress_value_label:
			region_progress_value_label.text = "%s / %s" % [_format_number(cumulative_score), _format_number(threshold)]
			region_progress_value_label.add_theme_color_override("font_color", Color(0.42, 0.28, 0.16, 1.0))
		if region_progress_bar:
			region_progress_bar.max_value = max(1, threshold)
			region_progress_bar.value = clampf(cumulative_score, 0, threshold)

	# 5. Final Score count-up interpolation over 1.0s
	_animate_score_count_up(final_score)

	# 6. Connect buttons
	if play_again_button:
		play_again_button.pressed.connect(_on_play_again_pressed)

	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)


## Pop-in Tween animation for "GAME OVER" title (scale 0.5 -> 1.0 with TRANS_BACK)
func _animate_title_pop_in() -> void:
	if not title_label:
		return

	title_label.pivot_offset = Vector2(430, 40)
	title_label.scale = Vector2(0.5, 0.5)
	title_label.modulate.a = 0.0

	var tween := create_tween().set_parallel(true)
	tween.tween_property(title_label, "scale", Vector2(1.0, 1.0), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(title_label, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Pop-in scale bounce for NEW HIGH SCORE badge
func _animate_badge_pop() -> void:
	if not new_high_score_badge:
		return

	new_high_score_badge.pivot_offset = new_high_score_badge.custom_minimum_size / 2.0
	new_high_score_badge.scale = Vector2(0.3, 0.3)

	var tween := create_tween()
	tween.tween_interval(0.25)
	tween.tween_property(new_high_score_badge, "scale", Vector2(1.15, 1.15), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(new_high_score_badge, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Count up (interpolate) score number from 0 to final_score over 1.0 second
func _animate_score_count_up(target_score: int) -> void:
	if not score_value_label:
		return
	AnimationManager.count_label(score_value_label, 0.0, float(target_score), 1.0, _format_number)


## Format number with comma separators (e.g. 12500 -> "12,500")
func _format_number(number: int) -> String:
	var string_val: String = str(number)
	var result: String = ""
	var length: int = string_val.length()
	for i in range(length):
		if i > 0 and (length - i) % 3 == 0:
			result += ","
		result += string_val[i]
	return result


func _on_play_again_pressed() -> void:
	AudioManager.play_sfx("button_tap")
	GameManager.start_new_game()
	var active_region: String = SaveManager.get_active_region()
	var scene_path: String = RestaurantProgress.new().get_playing_scene_path(active_region)
	get_tree().change_scene_to_file(scene_path)


func _on_menu_pressed() -> void:
	AudioManager.play_sfx("button_tap")
	GameManager.go_to_menu()
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")

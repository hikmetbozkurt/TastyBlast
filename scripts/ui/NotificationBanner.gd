## Notification Banner — Reusable In-Game UI Component
## Displays an enterprise, non-blocking animated notification toast when a new cuisine region is unlocked.
## All Controls strictly ignore mouse/touch input except CloseButton so active gameplay is never blocked.
class_name NotificationBanner
extends CanvasLayer


# Centralized configuration constants
const DISPLAY_DURATION: float = 8.0
const ENTER_DURATION: float = 0.25
const EXIT_DURATION: float = 0.20
const BANNER_WIDTH: float = 780.0
const BANNER_HEIGHT: float = 180.0
const CLOSE_TOUCH_SIZE: float = 96.0

enum State { HIDDEN, ENTERING, VISIBLE, EXITING }

signal banner_dismissed(region_id: String)

@export var banner_container_path: NodePath = "SafeArea/BannerContainer"
@export var banner_texture_path: NodePath = "SafeArea/BannerContainer/BannerTexture"
@export var header_label_path: NodePath = "SafeArea/BannerContainer/ContentMargin/VBox/HeaderHBox/HeaderLabel"
@export var flag_texture_path: NodePath = "SafeArea/BannerContainer/ContentMargin/VBox/HeaderHBox/FlagTexture"
@export var region_label_path: NodePath = "SafeArea/BannerContainer/ContentMargin/VBox/RegionLabel"
@export var close_button_path: NodePath = "SafeArea/BannerContainer/CloseButton"

@onready var banner_container: Control = get_node_or_null(banner_container_path) as Control
@onready var banner_texture: TextureRect = get_node_or_null(banner_texture_path) as TextureRect
@onready var header_label: Label = get_node_or_null(header_label_path) as Label
@onready var flag_texture: TextureRect = get_node_or_null(flag_texture_path) as TextureRect
@onready var region_label: Label = get_node_or_null(region_label_path) as Label
@onready var close_button: Button = get_node_or_null(close_button_path) as Button

var current_state: State = State.HIDDEN
var active_region_id: String = ""
var _active_tween: Tween = null
var _display_timer: SceneTreeTimer = null


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_set_mouse_filter_recursive(self)

	if not header_label:
		header_label = get_node_or_null("SafeArea/BannerContainer/ContentMargin/VBox/HeaderLabel") as Label
	if not flag_texture:
		flag_texture = get_node_or_null("SafeArea/BannerContainer/ContentMargin/VBox/HeaderHBox/FlagTexture") as TextureRect

	if close_button:
		close_button.mouse_filter = Control.MOUSE_FILTER_STOP
		if not close_button.pressed.is_connected(_on_close_button_pressed):
			close_button.pressed.connect(_on_close_button_pressed)


func _exit_tree() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		_active_tween = null


## Ensure every Control node in the hierarchy ignores mouse/touch inputs, except CloseButton.
func _set_mouse_filter_recursive(node: Node) -> void:
	if node is Control:
		if node == close_button or node.name == "CloseButton":
			node.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_filter_recursive(child)


func _on_close_button_pressed() -> void:
	AudioManager.play_sfx("button_tap")
	HapticsManager.light()
	dismiss()


## Trigger slide-in notification toast placed at target_y.
## Stays visible for DISPLAY_DURATION (8.0s) without pausing active gameplay, then slides out.
func show_unlock_notification(region_name: String, flag_emoji: String, target_y: float = -1.0, region_id: String = "") -> void:
	active_region_id = region_id

	HapticsManager.strong()
	AudioManager.play_sfx("unlock_map")

	var r_id: String = region_id if not region_id.is_empty() else region_name.to_lower()
	var flag_tex: Texture2D = RestaurantProgress.get_flag_texture(r_id)

	if header_label:
		header_label.text = "%s UNLOCKED!" % region_name.to_upper()
	if flag_texture:
		flag_texture.texture = flag_tex
		flag_texture.visible = (flag_tex != null)
	if region_label:
		region_label.text = "%s is now available on the World Map." % region_name

	if not banner_container:
		return

	# Determine resting target_y: defaults to 384.0 (immediately below header) if unspecified
	var resting_y: float = target_y if target_y >= 0.0 else 384.0

	# Responsive adaptation: check screen / viewport height for compact device fallback
	var vp_size: Vector2 = get_viewport().get_visible_rect().size if get_viewport() else Vector2(1080, 1920)
	var margin_c := banner_container.get_node_or_null("ContentMargin") as MarginContainer
	if vp_size.y <= 1920.0:
		# Compact screen fallback: reduce padding and height to ensure board/grid protection
		banner_container.custom_minimum_size.y = 150.0
		if margin_c:
			margin_c.add_theme_constant_override("margin_left", 70)
			margin_c.add_theme_constant_override("margin_right", 104)
			margin_c.add_theme_constant_override("margin_top", 20)
			margin_c.add_theme_constant_override("margin_bottom", 16)
		if header_label:
			header_label.add_theme_font_size_override("font_size", 34)
		if flag_texture:
			flag_texture.custom_minimum_size = Vector2(34, 34)
		if region_label:
			region_label.add_theme_font_size_override("font_size", 24)
	else:
		banner_container.custom_minimum_size.y = BANNER_HEIGHT
		if margin_c:
			margin_c.add_theme_constant_override("margin_left", 80)
			margin_c.add_theme_constant_override("margin_right", 114)
			margin_c.add_theme_constant_override("margin_top", 28)
			margin_c.add_theme_constant_override("margin_bottom", 24)
		if header_label:
			header_label.add_theme_font_size_override("font_size", 36)
		if flag_texture:
			flag_texture.custom_minimum_size = Vector2(36, 36)
		if region_label:
			region_label.add_theme_font_size_override("font_size", 26)

	current_state = State.ENTERING
	banner_container.position.y = resting_y - 25.0
	banner_container.modulate.a = 0.0
	banner_container.scale = Vector2(0.96, 0.96)
	banner_container.pivot_offset = banner_container.size / 2.0

	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

	var tween := create_tween()
	_active_tween = tween
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	# 1. Slide in from resting_y - 25px, fade-in, and scale settle
	tween.set_parallel(true)
	tween.tween_property(banner_container, "position:y", resting_y, ENTER_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(banner_container, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(banner_container, "scale", Vector2.ONE, ENTER_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tween.finished.connect(func():
		if current_state == State.ENTERING:
			current_state = State.VISIBLE
			_start_display_timer()
	)


func _start_display_timer() -> void:
	_display_timer = get_tree().create_timer(DISPLAY_DURATION)
	_display_timer.timeout.connect(func():
		if current_state == State.VISIBLE:
			dismiss()
	)


## Dismiss the notification immediately via smooth exit animation.
## Guaranteed single execution: duplicate calls during EXITING or HIDDEN are safely ignored.
func dismiss() -> void:
	if current_state == State.EXITING or current_state == State.HIDDEN:
		return

	current_state = State.EXITING

	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

	var exit_tween := create_tween()
	_active_tween = exit_tween
	exit_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	exit_tween.set_parallel(true)

	if banner_container:
		var exit_target_y: float = banner_container.position.y - 20.0
		exit_tween.tween_property(banner_container, "position:y", exit_target_y, EXIT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		exit_tween.tween_property(banner_container, "modulate:a", 0.0, EXIT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		exit_tween.tween_property(banner_container, "scale", Vector2(0.98, 0.98), EXIT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	exit_tween.finished.connect(func():
		current_state = State.HIDDEN
		banner_dismissed.emit(active_region_id)
		queue_free()
	)


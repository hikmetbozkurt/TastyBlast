## Game UI / Scene Controller — Gameplay Script
## Main orchestrator for gameplay loop with full feedback & juicing:
## 1. GridSystem setup & rendering.
## 2. Solvability-guaranteed Tray Generation (3 pieces).
## 3. Drag-and-drop placement with valid/invalid highlighting.
## 5. Tray management and Pause/Game Over flow.
class_name GameUI
extends Control


@export var kitchen_background_path: NodePath = "KitchenBackground"
@export var board_frame_path: NodePath = "PlayingArea/BoardRoot/BoardFrame"
@export var grid_view_path: NodePath = "PlayingArea/BoardRoot/GridContainer/GridView"
@export var tray_container_path: NodePath = "SafeArea/TrayContainer"
@export var pizza_icon_path: NodePath = "SafeArea/HeaderContainer/HeaderBar/PizzaIcon"
@export var score_label_path: NodePath = "SafeArea/HeaderContainer/ScoreLabel"
@export var flying_layer_path: NodePath = "FlyingLayer"
@export var pause_button_path: NodePath = "SafeArea/HeaderContainer/HeaderBar/PauseButton"
@export var settings_button_path: NodePath = "SafeArea/HeaderContainer/HeaderBar/SettingsButton"
@export var drag_overlay_path: NodePath = "DragOverlay"
@export var active_region_id: String = "italy"

## PackedScenes for feedback UI
var tray_slot_scene: PackedScene = preload("res://scenes/gameplay/TraySlot.tscn")
var piece_view_scene: PackedScene = preload("res://scenes/gameplay/PieceView.tscn")
var score_popup_scene: PackedScene = preload("res://scenes/ui_components/ScorePopup.tscn")
var combo_banner_scene: PackedScene = preload("res://scenes/ui_components/ComboBanner.tscn")
var in_game_modal_scene: PackedScene = preload("res://scenes/ui_components/InGameModal.tscn")
var in_game_modal: InGameModal = null
var ingredient_pop_scene: PackedScene = preload("res://scenes/gameplay/IngredientPopFX.tscn")
var mega_explosion_scene: PackedScene = preload("res://scenes/gameplay/MegaFoodExplosionFX.tscn")

## Approved Food Base Palette Colors (HDR intensity for WorldEnvironment Glow)
const FOOD_PALETTE_COLORS: Array[Color] = [
	Color(1, 1, 1, 1),
	Color(1.92, 0.50, 0.44, 1.0),  # 1: Tomato Red
	Color(1.96, 1.16, 0.32, 1.0),  # 2: Pepper Orange
	Color(1.96, 1.72, 0.44, 1.0),  # 3: Cheese Yellow
	Color(0.56, 1.72, 0.76, 1.0),  # 4: Basil Green
	Color(0.76, 0.96, 1.84, 1.0),  # 5: Olive Blue
	Color(1.36, 0.56, 1.76, 1.0),  # 6: Eggplant Dark Purple
	Color(1.72, 1.16, 0.64, 1.0)   # 7: Pizza Golden-Brown
]

const MAX_INGREDIENT_POP_BURSTS: int = 24
const MAX_FLYING_INGREDIENTS: int = 12
const MAX_FLOATING_SCORE_NODES: int = 8

## Core systems (RefCounted)
var grid_system: GridSystem = GridSystem.new()
var piece_system: PieceSystem = PieceSystem.new()
var score_system: ScoreSystem = ScoreSystem.new()
var solvability_checker: SolvabilityChecker = SolvabilityChecker.new()

## Scene node references
@onready var kitchen_background: TextureRect = (get_node_or_null(kitchen_background_path) if has_node(kitchen_background_path) else find_child("KitchenBackground", true, false)) as TextureRect
@onready var board_frame: TextureRect = (get_node_or_null(board_frame_path) if has_node(board_frame_path) else find_child("BoardFrame", true, false)) as TextureRect
@onready var grid_view: GridView = (get_node_or_null(grid_view_path) if has_node(grid_view_path) else find_child("GridView", true, false)) as GridView
@onready var tray_container: HBoxContainer = (get_node_or_null(tray_container_path) if has_node(tray_container_path) else find_child("TrayContainer", true, false)) as HBoxContainer
@onready var pizza_icon: TextureRect = (get_node_or_null(pizza_icon_path) if has_node(pizza_icon_path) else find_child("PizzaIcon", true, false)) as TextureRect
@onready var score_label: Label = (get_node_or_null(score_label_path) if has_node(score_label_path) else find_child("ScoreLabel", true, false)) as Label
@onready var flying_layer: CanvasLayer = (get_node_or_null(flying_layer_path) if has_node(flying_layer_path) else find_child("FlyingLayer", true, false)) as CanvasLayer
@onready var pause_button: TextureButton = (get_node_or_null(pause_button_path) if has_node(pause_button_path) else find_child("PauseButton", true, false)) as TextureButton
@onready var settings_button: TextureButton = (get_node_or_null(settings_button_path) if has_node(settings_button_path) else find_child("SettingsButton", true, false)) as TextureButton
@onready var drag_overlay: Node2D = (get_node_or_null(drag_overlay_path) if has_node(drag_overlay_path) else find_child("DragOverlay", true, false)) as Node2D

var drag_controller: DragController = DragController.new()
var tray_slots: Array[TraySlot] = []

## Track color family assignment cycle for variety
var _color_cycle_index: int = 1

## Score rolling counter animation variables
var _displayed_score: float = 0.0
var _score_tween: Tween = null
var _header_button_tweens: Dictionary = {}

## In-Game Notification component references & FIFO queue
var notification_host: Control = null
var _unlock_queue: Array[String] = []
var _active_banner: NotificationBanner = null


func _ready() -> void:
	# Center pizza icon pivot for scale bounce animation
	if pizza_icon:
		pizza_icon.pivot_offset = pizza_icon.size / 2.0

	# Load balance configuration
	var balance_config_path := "res://assets/data/balance_config.tres"
	if ResourceLoader.exists(balance_config_path):
		var config := load(balance_config_path) as BalanceConfig
		if config:
			score_system.setup_from_config(config)

	# Load piece definitions from JSON
	piece_system.load_shapes()

	# Initialize grid system (8x8)
	grid_system.initialize(8, 8)
	score_system.reset()
	_displayed_score = 0.0

	# Connect score system signals for juice
	score_system.combo_triggered.connect(_on_combo_triggered)

	# Attach DragController
	add_child(drag_controller)
	drag_controller.setup(grid_view, grid_system, drag_overlay)
	drag_controller.piece_placed_success.connect(_on_piece_placed)
	drag_controller.drag_cancelled.connect(_on_drag_cancelled)

	# Connect Pause & Settings buttons with tactile juice feedback
	if pause_button:
		pause_button.pressed.connect(_on_pause_pressed)
		_attach_button_juice(pause_button)
	if settings_button:
		settings_button.pressed.connect(_on_settings_button_pressed)
		_attach_button_juice(settings_button)

	# Instantiate and attach InGameModal overlay
	if in_game_modal_scene:
		in_game_modal = in_game_modal_scene.instantiate() as InGameModal
		add_child(in_game_modal)

	# Setup GridView (8x8 with 96px cells = 768x768 total inner grid size)
	grid_view.setup(grid_system, 96.0)

	# Initialize active cuisine region from SaveManager or Scene export
	if active_region_id.is_empty() or active_region_id == "italy":
		active_region_id = SaveManager.get_active_region()
	else:
		SaveManager.set_active_region(active_region_id)

	SaveManager.set_last_played_region(active_region_id)
	SaveManager.mark_region_visited(active_region_id)

	var progress := RestaurantProgress.new()
	var region_data := progress.get_region_by_id(active_region_id)
	if region_data.is_empty():
		region_data = progress.get_region_by_id("italy")
	if not region_data.is_empty():
		set_region(region_data)

	# Play regional background music
	AudioManager.play_music(active_region_id)

	# Setup Tray
	_setup_tray_slots()
	_generate_new_tray()

	# Display cumulative regional score on HUD
	var initial_cumulative: int = SaveManager.get_region_score(active_region_id)
	_displayed_score = float(initial_cumulative)
	if score_label:
		score_label.text = _format_number(initial_cumulative)

	# Initialize dedicated NotificationHost under SafeArea
	_setup_notification_host()

	# Listen to authoritative region unlock signal
	if not SaveManager.region_unlocked.is_connected(_on_region_unlocked_event):
		SaveManager.region_unlocked.connect(_on_region_unlocked_event)

	# Change GameManager state to PLAYING
	GameManager.change_state(GameManager.GameState.PLAYING)


## Set region visuals (background texture, board frame, counter icon & plate tint).
func set_region(region_data: Dictionary) -> void:
	var region_id: String = region_data.get("id", active_region_id)
	active_region_id = region_id

	# Notify IngredientTheme singleton of active region
	IngredientTheme.get_active_theme().set_active_region(region_id)

	if region_data.has("background") and kitchen_background:
		var bg_path: String = region_data.get("background", "")
		if ResourceLoader.exists(bg_path):
			kitchen_background.texture = load(bg_path) as Texture2D
	if region_data.has("board_frame") and board_frame:
		var frame_path: String = region_data.get("board_frame", "")
		if ResourceLoader.exists(frame_path):
			board_frame.texture = load(frame_path) as Texture2D
	if region_data.has("counter_icon") and pizza_icon:
		var icon_path: String = region_data.get("counter_icon", "")
		if ResourceLoader.exists(icon_path):
			pizza_icon.texture = load(icon_path) as Texture2D
	if region_data.has("plate_tint") and board_frame:
		var tint_str: String = region_data.get("plate_tint", "")
		if not tint_str.is_empty():
			board_frame.modulate = Color(tint_str)


## Initialize the 3 tray slots.
func _setup_tray_slots() -> void:
	for child in tray_container.get_children():
		child.queue_free()
	tray_slots.clear()

	for i in range(3):
		var slot: TraySlot = tray_slot_scene.instantiate() as TraySlot
		tray_container.add_child(slot)
		slot.piece_drag_started.connect(_on_tray_slot_drag_started)
		tray_slots.append(slot)


## Generate a new set of 3 tray pieces with solvability guarantee.
func _generate_new_tray() -> void:
	var shapes: Array = solvability_checker.generate_solvable_tray(grid_system, piece_system, 3)

	for i in range(3):
		if i < shapes.size():
			var shape_def: Dictionary = shapes[i]
			var piece: PieceView = piece_view_scene.instantiate() as PieceView
			
			_color_cycle_index = randi_range(1, 7)
			piece.setup(shape_def, _color_cycle_index, 96.0)

			tray_slots[i].set_piece(piece)
			tray_slots[i].play_spawn(float(i) * 0.04)


## Called when player starts dragging a piece from a tray slot.
func _on_tray_slot_drag_started(slot: TraySlot, piece: PieceView, global_touch_pos: Vector2) -> void:
	drag_controller.start_drag(slot, piece, global_touch_pos)


func _on_drag_cancelled() -> void:
	AudioManager.play_sfx("fail")
	HapticsManager.light()


## Called when a piece is successfully placed on the grid.
func _on_piece_placed(_slot: TraySlot, _origin_x: int, _origin_y: int, _piece_cells: Array, _color_index: int) -> void:
	AudioManager.play_sfx("success")
	HapticsManager.light()
	grid_view.refresh_display()

	# Get cleared cells info BEFORE clearing them for flying animations
	var cleared_info: Array = grid_system.get_cleared_cells_info()
	var completed_lines: Dictionary = grid_system.find_completed_lines()
	var lines_cleared_count: int = completed_lines["rows"].size() + completed_lines["cols"].size()
	var cleared_cells: Array = grid_system.clear_completed_lines()

	# Detect Mega-Match condition (10+ cells cleared or multi-line clear)
	var is_mega_match: bool = cleared_cells.size() >= 10 or lines_cleared_count >= 2

	if cleared_cells.size() > 0:
		# Juicing: Particles, Sound, Score popup, Shake & Haptics
		grid_view.animate_cleared_cells(cleared_cells)

		var cluster_center := _calculate_clear_cluster_center(cleared_cells)

		if is_mega_match:
			# Trigger Grand Finale Mega-Match Explosion
			var mega_fx: MegaFoodExplosionFX = mega_explosion_scene.instantiate() as MegaFoodExplosionFX
			add_child(mega_fx)
			mega_fx.global_position = cluster_center
			grid_view.trigger_shake(16.0, 0.45)
			AudioManager.play_sfx("success_combo")
			HapticsManager.strong()

		# Spawn Juicy Pop particle explosions and flying ingredient sprites
		for index in range(cleared_info.size()):
			var info: Dictionary = cleared_info[index]
			var color_index := int(info.get("color_index", 1))
			var cell_x: int = int(info.get("x", 0))
			var cell_y: int = int(info.get("y", 0))
			var local_center := Vector2((cell_x + 0.5) * 96.0, (cell_y + 0.5) * 96.0)
			var start_position: Vector2 = grid_view.to_global(local_center)

			if index < MAX_INGREDIENT_POP_BURSTS:
				var pop_fx := ingredient_pop_scene.instantiate() as IngredientPopFX
				add_child(pop_fx)
				pop_fx.global_position = start_position
				pop_fx.setup_color(color_index)

			if index < MAX_FLYING_INGREDIENTS:
				var texture := IngredientTheme.get_texture_for_color_index(color_index)
				spawn_flying_ingredient(texture, start_position, color_index)

		if not is_mega_match:
			if lines_cleared_count > 1:
				AudioManager.play_sfx("success_combo")
				grid_view.trigger_shake(12.0, 0.35)
				HapticsManager.strong()
			else:
				AudioManager.play_sfx("success_combo")
				grid_view.trigger_shake(5.0, 0.18)
				HapticsManager.medium()

		var points_earned: int = score_system.add_clear_score(lines_cleared_count, cleared_cells.size())
		_spawn_score_popup(points_earned, cluster_center)

		if points_earned > 0:
			var new_unlocks: Array[String] = SaveManager.add_region_score(active_region_id, points_earned)
			for unlocked_id in new_unlocks:
				_spawn_unlock_notification(unlocked_id)
	else:
		score_system.on_placement_no_clear()

	# Sync current run score with GameManager for high score comparison
	GameManager.current_score = score_system.score

	# Animate HUD with cumulative region score
	var current_cumulative: int = SaveManager.get_region_score(active_region_id)
	_update_score_ui_animated(current_cumulative)

	# Check if all 3 tray slots have been used
	var all_used: bool = true
	for slot in tray_slots:
		if slot.has_piece():
			all_used = false
			break

	if all_used:
		_generate_new_tray()

	# Check game-over condition
	_check_game_over()


## Spawn a flying ingredient sprite that arcs from start_pos into the Header Pizza Icon.
## Attaches trailing particles derived strictly from the approved food color palette.
func spawn_flying_ingredient(texture: Texture2D, start_pos: Vector2, color_index: int = 1) -> void:
	if not texture:
		return

	var sprite := Sprite2D.new()
	sprite.texture = texture
	var tex_size: Vector2 = texture.get_size()
	if tex_size.x > 0 and tex_size.y > 0:
		sprite.scale = Vector2(60.0 / tex_size.x, 60.0 / tex_size.y)
	else:
		sprite.scale = Vector2(0.6, 0.6)

	sprite.global_position = start_pos

	# Add trailing particles stream adhering strictly to food palette
	var trail := CPUParticles2D.new()
	trail.amount = 16
	trail.lifetime = 0.35
	trail.one_shot = false
	trail.explosiveness = 0.0
	trail.local_coords = false
	trail.direction = Vector2(0, 1)
	trail.spread = 30.0
	trail.gravity = Vector2(0, 80)
	trail.initial_velocity_min = 20.0
	trail.initial_velocity_max = 50.0
	trail.scale_amount_min = 4.0
	trail.scale_amount_max = 8.0
	var c_idx: int = posmod(color_index, FOOD_PALETTE_COLORS.size())
	trail.color = FOOD_PALETTE_COLORS[c_idx]
	sprite.add_child(trail)

	if flying_layer:
		flying_layer.add_child(sprite)
	else:
		add_child(sprite)

	# Target center of Pizza icon
	var target_pos: Vector2 = Vector2(540, 75)
	if pizza_icon and is_instance_valid(pizza_icon):
		target_pos = pizza_icon.global_position + (pizza_icon.size / 2.0)

	var flight_dur: float = randf_range(0.5, 0.6)
	var apex_y: float = minf(start_pos.y, target_pos.y) - randf_range(60.0, 120.0)

	var main_tween := sprite.create_tween().set_parallel(true)
	# Parabolic flight: Linear X
	main_tween.tween_property(sprite, "global_position:x", target_pos.x, flight_dur).set_trans(Tween.TRANS_LINEAR)
	# Scale down to 0.4 of initial size
	var target_scale := sprite.scale * 0.4
	main_tween.tween_property(sprite, "scale", target_scale, flight_dur)
	# Random rotation during flight
	var rot_amount: float = randf_range(-4.0, 4.0)
	main_tween.tween_property(sprite, "rotation", rot_amount, flight_dur)

	# Parabolic flight: Upward toss then fall to target Y
	var y_tween := sprite.create_tween().set_parallel(false)
	y_tween.tween_property(sprite, "global_position:y", apex_y, flight_dur * 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	y_tween.tween_property(sprite, "global_position:y", target_pos.y, flight_dur * 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# On impact with Pizza icon
	main_tween.finished.connect(func() -> void:
		if is_instance_valid(sprite):
			sprite.queue_free()
		if is_inside_tree():
			_on_ingredient_impact()
	)


## Impact feedback on Pizza icon when flying ingredient arrives.
func _on_ingredient_impact() -> void:
	if pizza_icon:
		pizza_icon.pivot_offset = pizza_icon.size / 2.0
		AnimationManager.play_scale_punch(pizza_icon, Vector2(1.20, 1.20), 0.24, &"counter_impact")


func _on_combo_triggered(lines_cleared: int, multiplier: float) -> void:
	HapticsManager.strong()
	var banner: ComboBannerUI = combo_banner_scene.instantiate() as ComboBannerUI
	if flying_layer:
		flying_layer.add_child(banner)
	else:
		add_child(banner)
	var screen_w: float = get_viewport_rect().size.x
	banner.position = Vector2((screen_w - 240.0) / 2.0, 220.0)
	banner.setup(lines_cleared, multiplier)


func _calculate_clear_cluster_center(cleared_cells: Array) -> Vector2:
	if cleared_cells.is_empty() or not grid_view:
		return get_viewport_rect().size * 0.5
	var cluster_center := Vector2.ZERO
	for cell_position in cleared_cells:
		var local_center := Vector2((float(cell_position.x) + 0.5) * grid_view.cell_size, (float(cell_position.y) + 0.5) * grid_view.cell_size)
		cluster_center += grid_view.to_global(local_center)
	return cluster_center / float(cleared_cells.size())


func _spawn_score_popup(points: int, screen_position: Vector2) -> void:
	var existing := get_tree().get_nodes_in_group("floating_score")
	if existing.size() >= MAX_FLOATING_SCORE_NODES:
		var oldest := existing.front() as Node
		if is_instance_valid(oldest):
			var oldest_parent := oldest.get_parent()
			if oldest_parent:
				oldest_parent.remove_child(oldest)
			oldest.queue_free()
	var popup: ScorePopupUI = score_popup_scene.instantiate() as ScorePopupUI
	popup.add_to_group("floating_score")
	if flying_layer:
		flying_layer.add_child(popup)
	else:
		add_child(popup)
	popup.global_position = screen_position - Vector2(120, 36)
	popup.setup(points, "+")


func _trigger_haptic_feedback() -> void:
	HapticsManager.medium()


## Calculate line count cleared based on cleared cells.
func _get_lines_cleared_count(cleared_cells: Array) -> int:
	if cleared_cells.is_empty():
		return 0
	var completed := grid_system.find_completed_lines()
	return completed["rows"].size() + completed["cols"].size()


## Check if none of the remaining pieces in the tray fit on the grid.
func _check_game_over() -> void:
	var remaining_shapes: Array = []
	for slot in tray_slots:
		if slot.has_piece():
			remaining_shapes.append(slot.piece_view.shape_data)

	if remaining_shapes.is_empty():
		return

	if solvability_checker.is_game_over(grid_system, remaining_shapes):
		# 1. Disable all gameplay inputs (drag/drop interactions)
		if drag_controller:
			drag_controller.is_dragging = false
			drag_controller.process_mode = Node.PROCESS_MODE_DISABLED
		if pause_button:
			pause_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if settings_button:
			settings_button.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# 2. Fetch the Run Final Score
		var final_run_score: int = score_system.score
		GameManager.current_score = final_run_score

		# 3. Check and save High Score persistently
		var is_new_high: bool = SaveManager.try_update_high_score(final_run_score)
		if is_new_high:
			print("New High Score achieved: %d!" % final_run_score)

		SaveManager.save_game()

		AudioManager.play_sfx("game_over")
		GameManager.trigger_game_over()

		# 4. Display the Game Over Screen
		var timer: SceneTreeTimer = get_tree().create_timer(0.6)
		timer.timeout.connect(_transition_to_game_over)


## Setup dedicated NotificationHost positioned between header and cutting board.
func _setup_notification_host() -> void:
	var safe_area := get_node_or_null("SafeArea") as Control
	if not safe_area:
		return

	notification_host = safe_area.get_node_or_null("NotificationHost") as Control
	if not notification_host:
		notification_host = Control.new()
		notification_host.name = "NotificationHost"
		notification_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		notification_host.layout_mode = 1
		notification_host.anchors_preset = Control.PRESET_TOP_WIDE
		notification_host.offset_left = 0.0
		notification_host.offset_top = 384.0
		notification_host.offset_right = 0.0
		notification_host.offset_bottom = 570.0
		safe_area.add_child(notification_host)


func _on_region_unlocked_event(unlocked_region_id: String) -> void:
	_spawn_unlock_notification(unlocked_region_id)


## Enqueue an unlock notification to be displayed sequentially without stacking.
func _spawn_unlock_notification(unlocked_region_id: String) -> void:
	if unlocked_region_id.is_empty():
		return

	# Deduplication: do not enqueue if already queued or currently showing
	if unlocked_region_id in _unlock_queue:
		return
	if _active_banner and is_instance_valid(_active_banner) and _active_banner.active_region_id == unlocked_region_id:
		return

	_unlock_queue.append(unlocked_region_id)
	_process_unlock_queue()


## Process the FIFO unlock notification queue.
func _process_unlock_queue() -> void:
	if (_active_banner and is_instance_valid(_active_banner)) or _unlock_queue.is_empty():
		return

	var region_id: String = _unlock_queue.pop_front()
	var banner_scene: PackedScene = preload("res://scenes/ui_components/NotificationBanner.tscn")
	if not banner_scene:
		return

	var banner := banner_scene.instantiate() as NotificationBanner
	_active_banner = banner
	add_child(banner)

	var progress := RestaurantProgress.new()
	var region_info := progress.get_region_by_id(region_id)
	var reg_name: String = region_info.get("name", region_id.capitalize())
	var reg_flag: String = region_info.get("flag", "🍽️")

	# Calculate responsive target_y
	var target_y: float = _calculate_notification_target_y()

	banner.banner_dismissed.connect(func(_dismissed_id: String):
		if _active_banner == banner:
			_active_banner = null
		# Process next notification in queue if any
		_process_unlock_queue.call_deferred()
	)

	banner.show_unlock_notification(reg_name, reg_flag, target_y, region_id)


## Calculate responsive target_y for notification banner between header and board.
func _calculate_notification_target_y() -> float:
	var header := get_node_or_null("SafeArea/HeaderContainer") as Control
	var header_bottom: float = header.offset_bottom if header else 384.0

	if notification_host:
		return notification_host.position.y

	return header_bottom


func _transition_to_game_over() -> void:
	get_tree().change_scene_to_file("res://scenes/main/GameOver.tscn")


func _update_score_ui() -> void:
	var current_cumulative: int = SaveManager.get_region_score(active_region_id)
	if score_label:
		score_label.text = _format_number(current_cumulative)
		_displayed_score = float(current_cumulative)


## Update score with smooth rolling number animation (0.3s).
func _update_score_ui_animated(target_score: int) -> void:
	var start_value := _displayed_score
	if not score_label:
		_displayed_score = float(target_score)
		return
	AnimationManager.count_label(
		score_label,
		start_value,
		float(target_score),
		0.30,
		_format_number,
		func(value: float) -> void: _displayed_score = value
	)
	AnimationManager.play_scale_punch(score_label, Vector2(1.08, 1.08), 0.16, &"score_punch")


## Format integer with comma thousands separators.
func _format_number(number: int) -> String:
	var string_val: String = str(number)
	var result: String = ""
	var length: int = string_val.length()
	for i in range(length):
		if i > 0 and (length - i) % 3 == 0:
			result += ","
		result += string_val[i]
	return result


func _tween_header_button(button: TextureButton, target_scale: Vector2, duration: float) -> void:
	var key := button.get_instance_id()
	var previous := _header_button_tweens.get(key) as Tween
	if previous and previous.is_valid():
		previous.kill()
	var tween := button.create_tween()
	_header_button_tweens[key] = tween
	tween.tween_property(button, "scale", target_scale, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void:
		if _header_button_tweens.get(key) == tween:
			_header_button_tweens.erase(key)
	)


func _attach_button_juice(button: TextureButton) -> void:
	if not button:
		return
	button.pivot_offset = button.custom_minimum_size / 2.0
	button.button_down.connect(func() -> void:
		_tween_header_button(button, Vector2(0.9, 0.9), 0.08)
	)
	button.button_up.connect(func() -> void:
		_tween_header_button(button, Vector2.ONE, 0.15)
	)


func _on_pause_pressed() -> void:
	AudioManager.play_sfx("button_tap")
	if in_game_modal:
		in_game_modal.show_pause_state()


func _on_settings_button_pressed() -> void:
	AudioManager.play_sfx("button_tap")
	if in_game_modal:
		in_game_modal.show_settings_state()



## Handle debug button tap: adds +10,000 points through the authentic progression pipeline.
func _on_debug_add_score_pressed() -> void:
	if not OS.is_debug_build():
		return

	var points: int = 10000
	var new_unlocks: Array[String] = SaveManager.add_region_score(active_region_id, points)
	for unlocked_id in new_unlocks:
		_spawn_unlock_notification(unlocked_id)

	# Ensure score is saved to disk
	SaveManager.save_game()

	# Animate HUD with new cumulative region score
	var current_cumulative: int = SaveManager.get_region_score(active_region_id)
	_update_score_ui_animated(current_cumulative)

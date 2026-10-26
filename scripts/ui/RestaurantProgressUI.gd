## Restaurant Progress UI — UI Script
## Displays the Culinary World Tour map with sequential regional progression cards,
## unlock statuses, progress bars towards next cuisine, "COMPLETE" tags, and "NEW!" badges.
class_name RestaurantProgressUI
extends Control


@export var region_container_path: NodePath = "SafeArea/MainVBox/ScrollContainer/RegionList"
@export var regional_scores_grid_path: NodePath = "SafeArea/MainVBox/HeaderContainer/RegionalScoresGrid"
@export var back_button_path: NodePath = "SafeArea/MainVBox/BackButtonAnchor/BackButton"
@export var help_button_path: NodePath = "SafeArea/MainVBox/HeaderContainer/TitleHBox/HelpButton"
@export var how_to_play_modal_path: NodePath = "HowToPlayModal"

@onready var region_container: VBoxContainer = get_node_or_null(region_container_path) as VBoxContainer
@onready var regional_scores_grid: GridContainer = get_node_or_null(regional_scores_grid_path) as GridContainer
@onready var back_button: Button = get_node_or_null(back_button_path) as Button
@onready var help_button: Button = get_node_or_null(help_button_path) as Button
@onready var how_to_play_modal: Control = get_node_or_null(how_to_play_modal_path) as Control

var restaurant_progress: RestaurantProgress = RestaurantProgress.new()
var font_fredoka: Font = preload("res://assets/fonts/Fredoka-SemiBold.ttf")

## Currently active/implemented regions in sequential order
const ACTIVE_REGIONS: Array[String] = ["italy", "france", "mexico", "japan", "india", "turkey"]

## Regional visual accent colors
const REGION_ACCENTS: Dictionary = {
	"italy": Color(0.88, 0.26, 0.20, 1.0),    # Tomato Red
	"france": Color(0.45, 0.48, 0.78, 1.0),   # Lavender Blue
	"mexico": Color(0.88, 0.32, 0.18, 1.0),   # Chili Red
	"japan": Color(0.92, 0.35, 0.35, 1.0),    # Coral Red
	"india": Color(0.92, 0.55, 0.15, 1.0),    # Saffron Orange
	"turkey": Color(0.82, 0.28, 0.20, 1.0),   # Terracotta Red
}

## Regional short codes for circular badge
const REGION_CODES: Dictionary = {
	"italy": "IT",
	"france": "FR",
	"mexico": "MX",
	"japan": "JP",
	"india": "IN",
	"turkey": "TR",
}


func _get_save_mgr() -> Node:
	if is_inside_tree() and get_tree() and get_tree().root and get_tree().root.has_node("SaveManager"):
		return get_tree().root.get_node("SaveManager")
	return null


func _get_audio_mgr() -> Node:
	if is_inside_tree() and get_tree() and get_tree().root and get_tree().root.has_node("AudioManager"):
		return get_tree().root.get_node("AudioManager")
	return null



func _ready() -> void:
	var audio := _get_audio_mgr()
	if audio:
		audio.play_music("world_map")

	var save_mgr := _get_save_mgr()
	if save_mgr:
		save_mgr.progress_reset.connect(refresh_progress)

	resized.connect(_update_content_aware_layout)

	if back_button:
		back_button.pressed.connect(_on_back_pressed)
		_attach_button_juice(back_button)

	if help_button:
		help_button.pressed.connect(_on_help_pressed)
		_attach_help_button_juice(help_button)

	refresh_progress()


## Bottom safety margin inside ScrollContainer for card shadow, border, and rounded corners.
const REGION_CARD_MIN_HEIGHT: float = 224.0
const TURKEY_CARD_MIN_HEIGHT: float = 224.0
const MINI_SCORE_CARD_MIN_HEIGHT: float = 76.0
const BOTTOM_CONTENT_PADDING: float = 16.0


## Content-aware ScrollContainer sizing:
## When cards fit within available height: ScrollContainer height = content height (compact, no dead space)
## When cards exceed available height: ScrollContainer height = available height (scrolls cleanly)
func _update_content_aware_layout() -> void:
	if not region_container:
		return
	var scroll: ScrollContainer = region_container.get_parent() as ScrollContainer
	if not scroll:
		return

	var main_vbox: VBoxContainer = scroll.get_parent() as VBoxContainer
	var header: Control = get_node_or_null("SafeArea/MainVBox/HeaderContainer") as Control
	var back_anchor: Control = get_node_or_null("SafeArea/MainVBox/BackButtonAnchor") as Control
	var safe_area: Control = get_node_or_null("SafeArea") as Control

	var viewport_h: float = size.y if size.y > 0 else (get_viewport_rect().size.y if is_inside_tree() else 1920.0)
	if viewport_h <= 0.0:
		viewport_h = 1920.0

	var safe_area_h: float = safe_area.size.y if (safe_area and safe_area.size.y > 0) else (viewport_h - 70.0)
	var header_h: float = header.get_combined_minimum_size().y if (header and header.get_combined_minimum_size().y > 0) else 210.0
	var back_h: float = back_anchor.get_combined_minimum_size().y if (back_anchor and back_anchor.get_combined_minimum_size().y > 0) else 110.0
	var v_sep: float = float(main_vbox.get_theme_constant("separation")) if main_vbox else 16.0

	var available_h: float = maxf(safe_area_h - header_h - back_h - (v_sep * 2.0), 100.0)

	# Compute exact minimum content height required by the 6 country cards plus bottom margin
	var card_count: int = region_container.get_child_count()
	var list_sep: float = float(region_container.get_theme_constant("separation")) if region_container else 16.0
	var country_content_h: float = region_container.get_combined_minimum_size().y
	if country_content_h <= 0.0 or country_content_h < float(card_count * 100):
		# Fallback based on each card's minimum height plus list separation
		country_content_h = (maxf(float(card_count - 1), 0.0) * REGION_CARD_MIN_HEIGHT + TURKEY_CARD_MIN_HEIGHT) + maxf(float(card_count - 1), 0.0) * list_sep

	# Add safety margin so bottom shadow, border, and rounded corners of the last card (Türkiye) are never clipped
	country_content_h += BOTTOM_CONTENT_PADDING

	var desired_h: float = minf(country_content_h, available_h)

	scroll.custom_minimum_size.y = desired_h
	if country_content_h > available_h:
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		scroll.size_flags_vertical = Control.SIZE_SHRINK_CENTER




## Refresh region progress list and regional score grid header.
func refresh_progress() -> void:
	var scroll: ScrollContainer = region_container.get_parent() as ScrollContainer if region_container else null
	var saved_scroll_y: int = scroll.scroll_vertical if scroll else 0

	var save_mgr := _get_save_mgr()

	if regional_scores_grid:
		for child in regional_scores_grid.get_children():
			child.queue_free()

		var regions: Array = restaurant_progress.get_all_regions()
		for r in regions:
			var region_id: String = r.get("id", "")
			if region_id in ACTIVE_REGIONS:
				var icon_path: String = r.get("counter_icon", "res://assets/art/ui/pizza_counter.png")
				var score: int = save_mgr.get_region_score(region_id) if save_mgr else 0
				var mini_card: Control = _create_mini_score_card(icon_path, score)
				regional_scores_grid.add_child(mini_card)

	if not region_container:
		return

	for child in region_container.get_children():
		child.queue_free()

	var regions: Array = restaurant_progress.get_all_regions()
	var unlocked_ids: Array = save_mgr.get_unlocked_regions() if save_mgr else ["italy"]

	for r in regions:
		var region_card: Control = _create_region_card(r, unlocked_ids)
		region_container.add_child(region_card)

	_update_content_aware_layout.call_deferred()
	if scroll and saved_scroll_y > 0:
		_restore_scroll_position.call_deferred(saved_scroll_y)


## Restore scroll position stably after container sorting completes.
func _restore_scroll_position(saved_scroll: int) -> void:
	if not region_container:
		return
	var scroll: ScrollContainer = region_container.get_parent() as ScrollContainer
	if not scroll:
		return
	var v_bar := scroll.get_v_scroll_bar()
	if v_bar and v_bar.max_value > 0.0:
		var max_scroll: int = int(maxf(v_bar.max_value - v_bar.page, 0.0))
		scroll.scroll_vertical = clampi(saved_scroll, 0, max_scroll)
	else:
		scroll.scroll_vertical = saved_scroll




## Create a compact mini score card for the RegionalScoresGrid header.
func _create_mini_score_card(icon_path: String, score: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, MINI_SCORE_CARD_MIN_HEIGHT)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.98, 0.94, 0.86, 0.95)
	card_style.border_color = Color(0.42, 0.26, 0.14, 1.0)
	card_style.border_width_left = 3
	card_style.border_width_top = 3
	card_style.border_width_right = 3
	card_style.border_width_bottom = 3
	card_style.corner_radius_top_left = 16
	card_style.corner_radius_top_right = 16
	card_style.corner_radius_bottom_right = 16
	card_style.corner_radius_bottom_left = 16
	card_style.shadow_size = 4
	card_style.shadow_color = Color(0, 0, 0, 0.1)

	panel.add_theme_stylebox_override("panel", card_style)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(46, 46)
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(icon_path):
		icon_rect.texture = load(icon_path) as Texture2D
	hbox.add_child(icon_rect)

	var score_lbl := Label.new()
	score_lbl.text = _format_number(score)
	score_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_lbl.add_theme_font_override("font", font_fredoka)
	score_lbl.add_theme_font_size_override("font_size", 30)
	score_lbl.add_theme_color_override("font_color", Color(0.28, 0.16, 0.08, 1.0))
	hbox.add_child(score_lbl)

	return panel


## Create a region card node matching sequential regional progression.
func _create_region_card(region_data: Dictionary, unlocked_ids: Array) -> Control:
	var save_mgr := _get_save_mgr()
	var region_id: String = region_data.get("id", "")
	var name_str: String = region_data.get("name", "")
	var flag_str: String = region_data.get("flag", "")
	var desc: String = region_data.get("description", "")
	var threshold: int = int(region_data.get("unlock_score_threshold", 0))
	var next_region_id: String = region_data.get("next_region", "")

	var region_score: int = save_mgr.get_region_score(region_id) if save_mgr else 0
	var is_unlocked: bool = region_id in unlocked_ids

	# Determine if this region has completed its unlock requirement for its successor
	var is_completed: bool = false
	if is_unlocked and region_id != "turkey":
		if not next_region_id.is_empty() and next_region_id in unlocked_ids:
			is_completed = true
		elif threshold > 0 and region_score >= threshold:
			is_completed = true

	# Standardized NEW! badge lifecycle: persists until region is played
	var is_brand_new: bool = save_mgr.is_region_new(region_id) if save_mgr else false


	# Container-driven Card Root (PanelContainer) ensures deterministic height and prevents child overlap
	var card_panel := PanelContainer.new()
	card_panel.name = "Card_%s" % region_id
	var card_h: float = TURKEY_CARD_MIN_HEIGHT if region_id == "turkey" else REGION_CARD_MIN_HEIGHT
	card_panel.custom_minimum_size = Vector2(0, card_h)
	card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var card_style := StyleBoxFlat.new()
	card_style.corner_radius_top_left = 18
	card_style.corner_radius_top_right = 18
	card_style.corner_radius_bottom_right = 18
	card_style.corner_radius_bottom_left = 18
	card_style.border_width_left = 3
	card_style.border_width_top = 3
	card_style.border_width_right = 3
	card_style.border_width_bottom = 3

	if is_unlocked:
		card_style.bg_color = Color(0.99, 0.95, 0.88, 1.0)
		card_style.border_color = Color(0.42, 0.26, 0.14, 1.0)
		card_style.shadow_size = 6
		card_style.shadow_color = Color(0, 0, 0, 0.12)
	else:
		card_style.bg_color = Color(0.90, 0.86, 0.80, 0.95)
		card_style.border_color = Color(0.55, 0.48, 0.40, 1.0)
		card_style.shadow_size = 4
		card_style.shadow_color = Color(0, 0, 0, 0.08)

	card_panel.add_theme_stylebox_override("panel", card_style)

	# Margin Container
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 14)
	card_panel.add_child(margin)

	# Main HBox
	var main_hbox := HBoxContainer.new()
	main_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_hbox.add_theme_constant_override("separation", 18)
	margin.add_child(main_hbox)

	# 1. Left Regional Accent Badge (64x64 circle)
	var accent_color: Color = REGION_ACCENTS.get(region_id, Color(0.85, 0.45, 0.20, 1.0))
	var badge_panel := PanelContainer.new()
	badge_panel.custom_minimum_size = Vector2(64, 64)
	badge_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var badge_style := StyleBoxFlat.new()
	badge_style.corner_radius_top_left = 32
	badge_style.corner_radius_top_right = 32
	badge_style.corner_radius_bottom_right = 32
	badge_style.corner_radius_bottom_left = 32
	badge_style.border_width_left = 2
	badge_style.border_width_top = 2
	badge_style.border_width_right = 2
	badge_style.border_width_bottom = 2
	badge_style.border_color = Color(1, 1, 1, 0.8)
	badge_style.bg_color = accent_color if is_unlocked else accent_color.darkened(0.3)
	badge_panel.add_theme_stylebox_override("panel", badge_style)

	var flag_tex := RestaurantProgress.get_flag_texture(region_id)
	if flag_tex:
		var flag_rect := TextureRect.new()
		flag_rect.texture = flag_tex
		flag_rect.custom_minimum_size = Vector2(44, 44)
		flag_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		flag_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		flag_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		flag_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		flag_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_panel.add_child(flag_rect)
	else:
		var badge_label := Label.new()
		badge_label.text = REGION_CODES.get(region_id, name_str.left(2).to_upper())
		badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_label.add_theme_font_override("font", font_fredoka)
		badge_label.add_theme_font_size_override("font_size", 24)
		badge_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		badge_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.4))
		badge_label.add_theme_constant_override("outline_size", 4)
		badge_panel.add_child(badge_label)
	main_hbox.add_child(badge_panel)

	# 2. Middle Text Container
	var text_vbox := VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	text_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_vbox.add_theme_constant_override("separation", 4)
	main_hbox.add_child(text_vbox)

	# Region Name Title HBox (Title + Brand New Tag)
	var title_hbox := HBoxContainer.new()
	title_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_hbox.add_theme_constant_override("separation", 10)
	text_vbox.add_child(title_hbox)

	var title_lbl := Label.new()
	title_lbl.text = name_str
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_lbl.add_theme_font_override("font", font_fredoka)
	title_lbl.add_theme_font_size_override("font_size", 36)
	title_lbl.add_theme_color_override("font_color", Color(0.25, 0.14, 0.06, 1.0) if is_unlocked else Color(0.45, 0.36, 0.28, 1.0))
	title_hbox.add_child(title_lbl)

	# NEW! tag with looping pulse (persists as long as region is_new)
	if is_brand_new:
		var new_tag := Label.new()
		new_tag.text = "NEW!"
		new_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		new_tag.add_theme_font_override("font", font_fredoka)
		new_tag.add_theme_font_size_override("font_size", 20)
		new_tag.add_theme_color_override("font_color", Color(0.92, 0.30, 0.15, 1.0))
		new_tag.add_theme_color_override("font_outline_color", Color(1, 0.95, 0.85, 1.0))
		new_tag.add_theme_constant_override("outline_size", 4)
		title_hbox.add_child(new_tag)
		_animate_new_tag_pulse(new_tag)

	# Description Text
	var desc_lbl := Label.new()
	desc_lbl.text = desc
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_lbl.add_theme_font_override("font", font_fredoka)
	desc_lbl.add_theme_font_size_override("font_size", 28)
	desc_lbl.add_theme_color_override("font_color", Color(0.42, 0.28, 0.16, 1.0) if is_unlocked else Color(0.55, 0.46, 0.38, 1.0))
	text_vbox.add_child(desc_lbl)

	# Stable Bottom Info Container (deterministic 48px space across all card states)
	var info_container := VBoxContainer.new()
	info_container.custom_minimum_size = Vector2(0, 48)
	info_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_container.alignment = BoxContainer.ALIGNMENT_CENTER
	info_container.add_theme_constant_override("separation", 2)
	text_vbox.add_child(info_container)

	# Progress / Threshold Section inside stable info container
	if is_unlocked:
		if region_id == "turkey":
			# Special handling for Türkiye (Final Destination):
			var turkey_vbox := VBoxContainer.new()
			turkey_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
			turkey_vbox.add_theme_constant_override("separation", 2)

			var dest_lbl := Label.new()
			dest_lbl.text = "🏆 FINAL DESTINATION"
			dest_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dest_lbl.add_theme_font_override("font", font_fredoka)
			dest_lbl.add_theme_font_size_override("font_size", 20)
			dest_lbl.add_theme_color_override("font_color", Color(0.82, 0.28, 0.20, 1.0))
			turkey_vbox.add_child(dest_lbl)

			var hs_lbl := Label.new()
			hs_lbl.text = "High Score: %s pts" % _format_number(region_score)
			hs_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hs_lbl.add_theme_font_override("font", font_fredoka)
			hs_lbl.add_theme_font_size_override("font_size", 19)
			hs_lbl.add_theme_color_override("font_color", Color(0.42, 0.28, 0.16, 1.0))
			turkey_vbox.add_child(hs_lbl)

			info_container.add_child(turkey_vbox)
		elif is_completed:
			var comp_lbl := Label.new()
			comp_lbl.text = "Cumulative Score: %s pts (Goal Met)" % _format_number(region_score)
			comp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			comp_lbl.add_theme_font_override("font", font_fredoka)
			comp_lbl.add_theme_font_size_override("font_size", 19)
			comp_lbl.add_theme_color_override("font_color", Color(0.20, 0.58, 0.24, 1.0))
			info_container.add_child(comp_lbl)
		elif threshold > 0:
			var progress_vbox := VBoxContainer.new()
			progress_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
			progress_vbox.add_theme_constant_override("separation", 4)

			var pbar := ProgressBar.new()
			pbar.custom_minimum_size = Vector2(0, 18)
			pbar.show_percentage = false
			pbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pbar.max_value = float(threshold)
			pbar.value = float(clampf(region_score, 0, threshold))

			var bg_style := StyleBoxFlat.new()
			bg_style.bg_color = Color(0.25, 0.16, 0.10, 1.0)
			bg_style.corner_radius_top_left = 9
			bg_style.corner_radius_top_right = 9
			bg_style.corner_radius_bottom_right = 9
			bg_style.corner_radius_bottom_left = 9

			var fill_style := StyleBoxFlat.new()
			fill_style.bg_color = Color(0.92, 0.55, 0.15, 1.0)
			fill_style.corner_radius_top_left = 9
			fill_style.corner_radius_top_right = 9
			fill_style.corner_radius_bottom_right = 9
			fill_style.corner_radius_bottom_left = 9

			pbar.add_theme_stylebox_override("background", bg_style)
			pbar.add_theme_stylebox_override("fill", fill_style)
			progress_vbox.add_child(pbar)

			var ptext_lbl := Label.new()
			var next_info := restaurant_progress.get_region_by_id(next_region_id)
			var next_name: String = next_info.get("name", "Next Region")
			var next_flag: String = next_info.get("flag", "")
			ptext_lbl.text = "%s / %s pts  (Unlocks %s %s)" % [_format_number(region_score), _format_number(threshold), next_name, next_flag]
			ptext_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ptext_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ptext_lbl.add_theme_font_override("font", font_fredoka)
			ptext_lbl.add_theme_font_size_override("font_size", 19)
			ptext_lbl.add_theme_color_override("font_color", Color(0.52, 0.36, 0.22, 1.0))
			progress_vbox.add_child(ptext_lbl)

			info_container.add_child(progress_vbox)
	else:
		# Locked Region
		var prev_region_name: String = "Previous Region"
		for prev in restaurant_progress.get_all_regions():
			if prev.get("next_region", "") == region_id:
				prev_region_name = prev.get("name", "Previous Region")
				break

		var req_lbl := Label.new()
		req_lbl.text = "🔒 Unlocks via %s" % prev_region_name
		req_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		req_lbl.add_theme_font_override("font", font_fredoka)
		req_lbl.add_theme_font_size_override("font_size", 19)
		req_lbl.add_theme_color_override("font_color", Color(0.60, 0.42, 0.30, 1.0))
		info_container.add_child(req_lbl)

	# 3. Right Status Container (at least 64x64 touch/status target)
	var status_vbox := VBoxContainer.new()
	status_vbox.custom_minimum_size = Vector2(72, 72)
	status_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	status_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_vbox.add_theme_constant_override("separation", 6)
	main_hbox.add_child(status_vbox)

	# Transparent overlay Button covering card_panel for click/touch interaction
	var card_btn := Button.new()
	card_btn.flat = true
	card_btn.focus_mode = Control.FOCUS_NONE
	card_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty_style := StyleBoxEmpty.new()
	card_btn.add_theme_stylebox_override("normal", empty_style)
	card_btn.add_theme_stylebox_override("hover", empty_style)
	card_btn.add_theme_stylebox_override("pressed", empty_style)
	card_btn.add_theme_stylebox_override("disabled", empty_style)
	card_btn.add_theme_stylebox_override("focus", empty_style)
	card_panel.add_child(card_btn)

	if is_unlocked:
		var status_badge := PanelContainer.new()
		status_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var badge_bg := StyleBoxFlat.new()
		badge_bg.border_width_left = 2
		badge_bg.border_width_top = 2
		badge_bg.border_width_right = 2
		badge_bg.border_width_bottom = 2
		badge_bg.corner_radius_top_left = 12
		badge_bg.corner_radius_top_right = 12
		badge_bg.corner_radius_bottom_right = 12
		badge_bg.corner_radius_bottom_left = 12

		if is_completed or region_id == "turkey":
			badge_bg.bg_color = Color(0.88, 0.96, 0.88, 1.0)
			badge_bg.border_color = Color(0.25, 0.65, 0.30, 1.0)
		else:
			badge_bg.bg_color = Color(1.0, 0.95, 0.86, 1.0)
			badge_bg.border_color = Color(0.85, 0.50, 0.15, 1.0)

		status_badge.add_theme_stylebox_override("panel", badge_bg)

		var badge_margin := MarginContainer.new()
		badge_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_margin.add_theme_constant_override("margin_left", 12)
		badge_margin.add_theme_constant_override("margin_top", 4)
		badge_margin.add_theme_constant_override("margin_right", 12)
		badge_margin.add_theme_constant_override("margin_bottom", 4)
		status_badge.add_child(badge_margin)

		var status_lbl := Label.new()
		if region_id == "turkey":
			status_lbl.text = "UNLOCKED"
			status_lbl.add_theme_color_override("font_color", Color(0.18, 0.50, 0.22, 1.0))
		elif is_completed:
			status_lbl.text = "COMPLETE"
			status_lbl.add_theme_color_override("font_color", Color(0.18, 0.50, 0.22, 1.0))
		else:
			status_lbl.text = "PLAY"
			status_lbl.add_theme_color_override("font_color", Color(0.75, 0.35, 0.10, 1.0))

		status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		status_lbl.add_theme_font_override("font", font_fredoka)
		status_lbl.add_theme_font_size_override("font_size", 24)
		badge_margin.add_child(status_lbl)
		status_vbox.add_child(status_badge)

		var arrow_lbl := Label.new()
		arrow_lbl.text = "➔"
		arrow_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		arrow_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arrow_lbl.add_theme_font_override("font", font_fredoka)
		arrow_lbl.add_theme_font_size_override("font_size", 30)
		arrow_lbl.add_theme_color_override("font_color", Color(0.42, 0.26, 0.14, 1.0))
		status_vbox.add_child(arrow_lbl)

		card_btn.pressed.connect(func():
			var audio := _get_audio_mgr()
			if audio:
				audio.play_sfx("button_tap")
			var sm := _get_save_mgr()
			if sm:
				sm.set_active_region(region_id)
				sm.set_last_played_region(region_id)
			var target_scene: String = restaurant_progress.get_playing_scene_path(region_id)
			get_tree().change_scene_to_file(target_scene)
		)

	else:
		var lock_lbl := Label.new()
		lock_lbl.text = "🔒"
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock_lbl.add_theme_font_size_override("font_size", 32)
		status_vbox.add_child(lock_lbl)

		var status_badge := PanelContainer.new()
		status_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var badge_bg := StyleBoxFlat.new()
		badge_bg.bg_color = Color(0.92, 0.88, 0.84, 1.0)
		badge_bg.border_width_left = 1
		badge_bg.border_width_top = 1
		badge_bg.border_width_right = 1
		badge_bg.border_width_bottom = 1
		badge_bg.border_color = Color(0.60, 0.52, 0.44, 1.0)
		badge_bg.corner_radius_top_left = 10
		badge_bg.corner_radius_top_right = 10
		badge_bg.corner_radius_bottom_right = 10
		badge_bg.corner_radius_bottom_left = 10

		status_badge.add_theme_stylebox_override("panel", badge_bg)

		var badge_margin := MarginContainer.new()
		badge_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_margin.add_theme_constant_override("margin_left", 10)
		badge_margin.add_theme_constant_override("margin_top", 4)
		badge_margin.add_theme_constant_override("margin_right", 10)
		badge_margin.add_theme_constant_override("margin_bottom", 4)
		status_badge.add_child(badge_margin)

		var status_lbl := Label.new()
		status_lbl.text = "LOCKED"
		status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		status_lbl.add_theme_font_override("font", font_fredoka)
		status_lbl.add_theme_font_size_override("font_size", 24)
		status_lbl.add_theme_color_override("font_color", Color(0.55, 0.46, 0.38, 1.0))
		badge_margin.add_child(status_lbl)
		status_vbox.add_child(status_badge)

		card_btn.pressed.connect(func():
			var audio := _get_audio_mgr()
			if audio:
				audio.play_sfx("button_tap")
			_shake_card(card_panel)
		)

	_attach_card_juice(card_panel, card_btn)
	return card_panel


## Subtle looping pulse animation for NEW! tag (scale 1.0 -> 1.025 -> 1.0).
func _animate_new_tag_pulse(tag: Label) -> void:
	tag.resized.connect(func():
		tag.pivot_offset = tag.size / 2.0
	)
	tag.pivot_offset = tag.size / 2.0
	var tween := create_tween().set_loops()
	tween.tween_property(tag, "scale", Vector2(1.025, 1.025), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(tag, "scale", Vector2(1.0, 1.0), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _attach_card_juice(card_panel: Control, button: Button) -> void:
	if not card_panel or not button:
		return
	card_panel.resized.connect(func():
		card_panel.pivot_offset = card_panel.size / 2.0
	)
	button.button_down.connect(func():
		card_panel.pivot_offset = card_panel.size / 2.0
		var tween := create_tween()
		tween.tween_property(card_panel, "scale", Vector2(0.985, 0.985), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	button.button_up.connect(func():
		card_panel.pivot_offset = card_panel.size / 2.0
		var tween := create_tween()
		tween.tween_property(card_panel, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)


func _shake_card(card: Control) -> void:
	var orig_x: float = card.position.x
	var tween := create_tween()
	tween.tween_property(card, "position:x", orig_x - 8.0, 0.04)
	tween.tween_property(card, "position:x", orig_x + 8.0, 0.04)
	tween.tween_property(card, "position:x", orig_x - 4.0, 0.04)
	tween.tween_property(card, "position:x", orig_x + 4.0, 0.04)
	tween.tween_property(card, "position:x", orig_x, 0.04)


func _attach_button_juice(button: Button) -> void:
	if not button:
		return
	button.resized.connect(func():
		button.pivot_offset = button.size / 2.0
	)
	button.button_down.connect(func():
		button.pivot_offset = button.size / 2.0
		var tween := create_tween()
		tween.tween_property(button, "scale", Vector2(0.96, 0.96), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	button.button_up.connect(func():
		button.pivot_offset = button.size / 2.0
		var tween := create_tween()
		tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)



func _format_number(number: int) -> String:
	var string_val: String = str(number)
	var result: String = ""
	var length: int = string_val.length()
	for i in range(length):
		if i > 0 and (length - i) % 3 == 0:
			result += ","
		result += string_val[i]
	return result


func _on_help_pressed() -> void:
	if how_to_play_modal:
		how_to_play_modal.open()


func _attach_help_button_juice(btn: Button) -> void:
	btn.pivot_offset = btn.custom_minimum_size / 2.0
	btn.button_down.connect(func():
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2(0.90, 0.90), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	btn.button_up.connect(func():
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)


func _on_back_pressed() -> void:
	if how_to_play_modal and how_to_play_modal.visible:
		how_to_play_modal.close()
		return
	var audio := _get_audio_mgr()
	if audio:
		audio.play_sfx("button_tap")
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if how_to_play_modal and how_to_play_modal.visible:
			how_to_play_modal.close()
			get_viewport().set_input_as_handled()
			return
		_on_back_pressed()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if how_to_play_modal and how_to_play_modal.visible:
			how_to_play_modal.close()
			get_viewport().set_input_as_handled()
			return
		_on_back_pressed()

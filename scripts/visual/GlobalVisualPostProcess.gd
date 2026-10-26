class_name VisualPostProcessController
extends CanvasLayer


@export var config: VisualPolishConfig = preload("res://assets/data/visual_polish_config.tres")

@onready var back_buffer_copy: BackBufferCopy = $BackBufferCopy
@onready var color_rect: ColorRect = $ColorRect


func _ready() -> void:
	reset_to_config()


func set_visual_boost_enabled(enabled: bool) -> void:
	if config:
		config.visual_boost_enabled = enabled
	back_buffer_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT if enabled else BackBufferCopy.COPY_MODE_DISABLED
	color_rect.visible = enabled
	var shader_material := color_rect.material as ShaderMaterial
	if shader_material:
		shader_material.set_shader_parameter("visual_boost_enabled", enabled)


func set_color_values(new_brightness: float, new_contrast: float, new_saturation: float) -> void:
	var safe_brightness := clampf(new_brightness, 0.8, 1.2)
	var safe_contrast := clampf(new_contrast, 0.8, 1.2)
	var safe_saturation := clampf(new_saturation, 0.8, 1.3)
	if config:
		config.brightness = safe_brightness
		config.contrast = safe_contrast
		config.saturation = safe_saturation
	var shader_material := color_rect.material as ShaderMaterial
	if shader_material:
		shader_material.set_shader_parameter("brightness", safe_brightness)
		shader_material.set_shader_parameter("contrast", safe_contrast)
		shader_material.set_shader_parameter("saturation", safe_saturation)


func reset_to_config() -> void:
	if not config:
		return
	set_color_values(config.brightness, config.contrast, config.saturation)
	set_visual_boost_enabled(config.visual_boost_enabled)

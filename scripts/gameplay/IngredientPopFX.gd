## Ingredient Pop FX — Gameplay Visual Juicing Script
## Handles one-shot particle burst colored to match cleared ingredient type.
class_name IngredientPopFX
extends Node2D


@onready var particles: GPUParticles2D = $GPUParticles2D

## Color mapping per ingredient color index (1-7)
const COLOR_INDEX_COLORS: Array[Color] = [
	Color(1, 1, 1, 1),
	Color(0.96, 0.28, 0.22, 1.0),  # 1: Red (Tomato)
	Color(0.98, 0.58, 0.16, 1.0),  # 2: Orange (Pepper)
	Color(0.98, 0.86, 0.22, 1.0),  # 3: Yellow (Cheese)
	Color(0.28, 0.86, 0.38, 1.0),  # 4: Green (Basil)
	Color(0.38, 0.48, 0.92, 1.0),  # 5: Blue (Olive)
	Color(0.68, 0.28, 0.88, 1.0),  # 6: Purple (Eggplant)
	Color(0.86, 0.58, 0.32, 1.0)   # 7: Brown
]


func _ready() -> void:
	if particles:
		particles.emitting = true
		particles.restart()

	# Self-destruct after particle emission & lifetime complete (0.4s + 0.1s buffer)
	var timer: SceneTreeTimer = get_tree().create_timer(0.5)
	timer.timeout.connect(queue_free)


## Setup particle tint based on ingredient color index (1-7).
func setup_color(color_index: int) -> void:
	var idx: int = posmod(color_index, COLOR_INDEX_COLORS.size())
	modulate = COLOR_INDEX_COLORS[idx]


## Setup particle tint with a custom Color.
func setup_custom_color(col: Color) -> void:
	modulate = col

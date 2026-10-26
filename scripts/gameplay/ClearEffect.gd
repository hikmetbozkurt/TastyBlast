## Clear Effect — Gameplay Visual Juicing
## Plays particle burst and scale pulse when cells or lines clear.
class_name ClearEffect
extends Node2D


@onready var particles: CPUParticles2D = $CPUParticles2D


func setup(color: Color = Color(1.0, 0.85, 0.3, 1.0)) -> void:
	if particles:
		particles.color = color
		particles.emitting = true

	# Self destruct after particles finish
	var timer: SceneTreeTimer = get_tree().create_timer(1.0)
	timer.timeout.connect(queue_free)

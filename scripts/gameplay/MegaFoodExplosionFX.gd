## Mega Food Explosion FX — Grand Finale Mega-Match Explosion
## Triggers a high-density starburst of HDR food-colored particles, light rays & expanding shockwave ring.
## Uses CanvasItemMaterial Additive Blend Mode and WorldEnvironment Glow.
class_name MegaFoodExplosionFX
extends Node2D


@onready var starburst: GPUParticles2D = $StarburstParticles
@onready var sparkles: GPUParticles2D = $SparkleRays
@onready var shockwave: Sprite2D = $ShockwaveRing


func _ready() -> void:
	if starburst:
		starburst.emitting = true
		starburst.restart()
	if sparkles:
		sparkles.emitting = true
		sparkles.restart()

	# Animate expanding hollow shockwave ring with additive glow fade
	if shockwave:
		shockwave.scale = Vector2(0.1, 0.1)
		shockwave.modulate.a = 1.0
		var ring_tween := create_tween().set_parallel(true)
		ring_tween.tween_property(shockwave, "scale", Vector2(7.5, 7.5), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ring_tween.tween_property(shockwave, "modulate:a", 0.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Self destruct after burst completes
	var timer: SceneTreeTimer = get_tree().create_timer(0.85)
	timer.timeout.connect(queue_free)

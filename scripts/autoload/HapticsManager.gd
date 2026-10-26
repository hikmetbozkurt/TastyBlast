## Haptics Manager — Autoload Singleton
## Centralized manager for native device vibration (haptics) using Godot's built-in Input API.
class_name HapticsManagerClass
extends Node


## State variable controlling whether haptics are enabled globally.
var enabled: bool = true


## Light haptic feedback: 15ms duration, 0.25 amplitude.
## Used for subtle tactile events such as piece placement and invalid placement drop.
func light() -> void:
	if not enabled:
		return
	Input.vibrate_handheld(15, 0.25)


## Medium haptic feedback: 35ms duration, 0.50 amplitude.
## Used for standard milestones such as single line clears.
func medium() -> void:
	if not enabled:
		return
	Input.vibrate_handheld(35, 0.5)


## Strong haptic feedback: 60ms duration, 0.80 amplitude.
## Used for major achievements: multi-line clears, big combos, and new cuisine region unlocks.
func strong() -> void:
	if not enabled:
		return
	Input.vibrate_handheld(60, 0.8)

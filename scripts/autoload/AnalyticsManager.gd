## Analytics Manager — Autoload Singleton
## Event logging behind a clean interface. The analytics backend (Firebase,
## etc.) can be swapped without touching gameplay code.
## Currently a stub that prints events to the console.
class_name AnalyticsManagerClass
extends Node


## Whether analytics logging is enabled.
var _enabled: bool = true


func _ready() -> void:
	print("AnalyticsManager: Initialized (stub mode)")


## Log an analytics event with optional parameters.
func log_event(event_name: String, params: Dictionary = {}) -> void:
	if not _enabled:
		return

	# TODO: Phase 6 — Route to Firebase Analytics or alternative
	if params.is_empty():
		print("Analytics: %s" % event_name)
	else:
		print("Analytics: %s | %s" % [event_name, str(params)])


## Log a session start event.
func log_session_start() -> void:
	log_event("session_start")


## Log a session end event.
func log_session_end() -> void:
	log_event("session_end")


## Log a game start event.
func log_game_start() -> void:
	log_event("game_start")


## Log a game over event with the final score.
func log_game_over(score: int) -> void:
	log_event("game_over", {"score": score})


## Log when a cuisine region is unlocked.
func log_region_unlocked(region_id: String) -> void:
	log_event("region_unlocked", {"region_id": region_id})


## Enable or disable analytics logging.
func set_enabled(enabled: bool) -> void:
	_enabled = enabled

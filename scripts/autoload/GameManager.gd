## Game Manager — Autoload Singleton
## Controls the game state machine: menu, playing, paused, game over.
## Other systems listen to state_changed to react to transitions.
class_name GameManagerClass
extends Node


## Emitted whenever the game state changes.
signal state_changed(old_state: GameState, new_state: GameState)

## Emitted when a new game is requested.
signal game_started()

## Emitted when the current game ends.
signal game_ended(final_score: int)


## All possible game states.
enum GameState {
	SPLASH,
	MENU,
	PLAYING,
	PAUSED,
	GAME_OVER,
}


## The current game state.
var current_state: GameState = GameState.SPLASH

## The score for the current game session (reset on new game).
var current_score: int = 0


func _ready() -> void:
	# Connect analytics & save signals
	game_started.connect(func(): AnalyticsManager.log_game_start())
	game_ended.connect(func(score: int): AnalyticsManager.log_game_over(score))
	SaveManager.region_unlocked.connect(func(id: String): AnalyticsManager.log_region_unlocked(id))
	AnalyticsManager.log_session_start()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		AnalyticsManager.log_session_end()


## Transition to a new game state. Validates the transition and emits state_changed.
func change_state(new_state: GameState) -> void:
	if new_state == current_state:
		return

	var old_state := current_state
	current_state = new_state
	state_changed.emit(old_state, new_state)

	if new_state == GameState.PLAYING and old_state != GameState.PAUSED:
		current_score = 0
		game_started.emit()
	elif new_state == GameState.GAME_OVER:
		SaveManager.save_game()
		game_ended.emit(current_score)


## Add points to the current game score.
func add_score(points: int) -> void:
	current_score += points


## Convenience: start a new game from any state.
func start_new_game() -> void:
	change_state(GameState.PLAYING)


## Convenience: pause the current game.
func pause_game() -> void:
	if current_state == GameState.PLAYING:
		change_state(GameState.PAUSED)


## Convenience: resume from pause.
func resume_game() -> void:
	if current_state == GameState.PAUSED:
		change_state(GameState.PLAYING)


## Convenience: trigger game over.
func trigger_game_over() -> void:
	change_state(GameState.GAME_OVER)


## Convenience: go to main menu.
func go_to_menu() -> void:
	change_state(GameState.MENU)

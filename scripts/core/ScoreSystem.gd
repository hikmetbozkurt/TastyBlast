## Score System — Core Logic
## Scoring, combo multipliers, and streak tracking.
## All tunable values are read from BalanceConfig resource.
class_name ScoreSystem
extends RefCounted


## Emitted when score changes.
signal score_changed(new_score: int, points_added: int)

## Emitted when a combo is triggered (2+ lines cleared in single placement).
signal combo_triggered(lines_cleared: int, multiplier: float)

## Emitted when the streak counter changes (consecutive placements that clear).
signal streak_changed(streak_count: int)


## Current total score in active game session.
var score: int = 0

## Current streak count (consecutive placements that clear at least one line).
var streak_count: int = 0

## --- Tunable values (configured via BalanceConfig resource) ---
var points_per_cell: int = 10
var base_line_clear_bonus: int = 50
var combo_multipliers: Array[float] = [1.0, 2.5, 4.0, 6.0, 8.0, 10.0]
var streak_bonus_per_step: int = 25
var max_streak_multiplier: float = 5.0


## Configure tunable parameters from a BalanceConfig resource.
func setup_from_config(config: BalanceConfig) -> void:
	if not config:
		return
	points_per_cell = config.points_per_cell
	base_line_clear_bonus = config.base_line_clear_bonus
	combo_multipliers = config.combo_multipliers
	streak_bonus_per_step = config.streak_bonus_per_step
	max_streak_multiplier = config.max_streak_multiplier


## Reset score and streak for a new game.
func reset() -> void:
	score = 0
	streak_count = 0


## Calculate and add score for a placement that cleared lines.
## Returns the total points earned from this placement.
func add_clear_score(lines_cleared: int, cells_cleared: int) -> int:
	if lines_cleared <= 0:
		_break_streak()
		return 0

	# Base points: cells cleared × points per cell
	var base_points: int = cells_cleared * points_per_cell

	# Line clear bonus
	var line_bonus: int = lines_cleared * base_line_clear_bonus

	# Combo multiplier (multiple simultaneous line clears)
	var combo_index: int = mini(lines_cleared - 1, combo_multipliers.size() - 1)
	var combo_mult: float = combo_multipliers[combo_index]

	# Streak bonus (consecutive placements that clear)
	streak_count += 1
	var streak_bonus: int = streak_count * streak_bonus_per_step
	var streak_mult: float = minf(1.0 + (streak_count - 1) * 0.5, max_streak_multiplier)

	streak_changed.emit(streak_count)

	if lines_cleared > 1:
		combo_triggered.emit(lines_cleared, combo_mult)

	# Total calculation
	var total: int = int((base_points + line_bonus + streak_bonus) * combo_mult * streak_mult)
	score += total
	score_changed.emit(score, total)

	return total


## Call when a piece is placed but no lines are cleared.
func on_placement_no_clear() -> void:
	_break_streak()


## Break the current streak.
func _break_streak() -> void:
	if streak_count > 0:
		streak_count = 0
		streak_changed.emit(0)


## Get the current combo multiplier for a given number of simultaneous clears.
func get_combo_multiplier(lines_cleared: int) -> float:
	if lines_cleared <= 0:
		return 1.0
	var index: int = mini(lines_cleared - 1, combo_multipliers.size() - 1)
	return combo_multipliers[index]

## Balance Config — Resource Script
## Typed resource for all gameplay-tunable values.
## Loaded from assets/data/balance_config.tres.
class_name BalanceConfig
extends Resource


## Grid dimensions.
@export var grid_width: int = 8
@export var grid_height: int = 8

## Number of pieces in the tray.
@export var tray_size: int = 3

## Base points awarded per cleared cell.
@export var points_per_cell: int = 10

## Bonus points per line cleared.
@export var base_line_clear_bonus: int = 50

## Combo multipliers indexed by (simultaneous_line_clears - 1).
@export var combo_multipliers: Array[float] = [1.0, 2.5, 4.0, 6.0, 8.0, 10.0]

## Points added per streak step.
@export var streak_bonus_per_step: int = 25

## Maximum streak multiplier cap.
@export var max_streak_multiplier: float = 5.0

## Minimum cells in a generated piece.
@export var min_piece_cells: int = 1

## Maximum cells in a generated piece.
@export var max_piece_cells: int = 5

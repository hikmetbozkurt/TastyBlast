## Solvability Checker — Core Logic
## Verifies that a generated tray has at least one legally placeable piece.
## This is a correctness requirement per CLAUDE.md §2: "No unwinnable trays."
class_name SolvabilityChecker
extends RefCounted


## Check if at least one piece in the tray can be placed somewhere on the grid.
## Returns true if the tray is solvable (at least one piece fits).
func is_tray_solvable(grid: GridSystem, tray_shapes: Array) -> bool:
	for shape in tray_shapes:
		var cells: Array = shape.get("cells", [])
		if grid.can_piece_fit_anywhere(cells):
			return true
	return false


## Generate a solvable tray. Re-rolls if the initially generated tray has
## no placeable pieces. Has a maximum retry count to prevent infinite loops
## on nearly-full grids.
func generate_solvable_tray(grid: GridSystem, piece_system: PieceSystem, tray_size: int = 3, max_retries: int = 100) -> Array:
	for attempt in range(max_retries):
		var tray: Array = piece_system.generate_tray(tray_size)
		if is_tray_solvable(grid, tray):
			return tray
		# Tray was unsolvable, re-roll

	# If we exhausted retries, the grid is likely too full for any piece.
	# Return the last generated tray — game-over detection will handle it.
	push_warning("SolvabilityChecker: Could not generate solvable tray after %d attempts." % max_retries)
	return piece_system.generate_tray(tray_size)


## Check if the game is over: none of the tray pieces can fit anywhere.
func is_game_over(grid: GridSystem, tray_shapes: Array) -> bool:
	return not is_tray_solvable(grid, tray_shapes)

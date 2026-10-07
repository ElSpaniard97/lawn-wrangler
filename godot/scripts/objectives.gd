class_name Objectives
extends RefCounted
## The checklist on screen: cut the front, side and back yards, and trim
## the edges the mower cannot reach. Each goal counts its own cells of the
## lawn and ticks off once nearly all of them are cut.

const NAMES := ["Cut the front yard", "Cut the side yard", "Cut the back yard", "Trim around objects"]
const FRONT := 0
const SIDE := 1
const BACK := 2
const TRIM := 3
## A goal is done at this share of its cells, so a stray blade of grass
## does not hold it back. Finishing the lawn still needs 99% overall.
const DONE_PERCENT := 97.0
## Cells this close (in cells) to the fence or anything blocked are edges.
const EDGE_CELLS := 2

var totals := [0, 0, 0, 0]
var cuts := [0, 0, 0, 0]
## Goal bits for each cell: its yard (1 << zone) and 1 << TRIM for edges.
var _goals := PackedByteArray()
var _columns := 0


## `side_from` and `side_to` are the z (in metres) where the side yard
## starts and ends; less is the back yard and more the front.
func setup(lawn: LawnGrid, side_from: float, side_to: float) -> void:
	_columns = lawn.columns
	_goals.resize(lawn.columns * lawn.rows)
	_goals.fill(0)
	for z in lawn.rows:
		var metres := (z + 0.5) * lawn.cell_size
		var zone := BACK if metres < side_from else (SIDE if metres <= side_to else FRONT)
		for x in lawn.columns:
			var value := lawn.cell(x, z)
			if value == LawnGrid.BLOCKED:
				continue
			var bits := 1 << zone
			if _near_edge(lawn, x, z):
				bits |= 1 << TRIM
			_goals[z * _columns + x] = bits
			for goal in 4:
				if bits & (1 << goal):
					totals[goal] += 1
					if value != LawnGrid.TALL:
						cuts[goal] += 1
	lawn.cell_cut.connect(_on_cell_cut)


func _near_edge(lawn: LawnGrid, x: int, z: int) -> bool:
	for dz in range(-EDGE_CELLS, EDGE_CELLS + 1):
		for dx in range(-EDGE_CELLS, EDGE_CELLS + 1):
			var nx := x + dx
			var nz := z + dz
			if nx < 0 or nz < 0 or nx >= lawn.columns or nz >= lawn.rows:
				return true
			if lawn.cell(nx, nz) == LawnGrid.BLOCKED:
				return true
	return false


func _on_cell_cut(x: int, z: int, _stripe: int) -> void:
	var bits := _goals[z * _columns + x]
	for goal in 4:
		if bits & (1 << goal):
			cuts[goal] += 1


func percent(goal: int) -> float:
	return 100.0 * cuts[goal] / totals[goal] if totals[goal] > 0 else 100.0


func done(goal: int) -> bool:
	return percent(goal) >= DONE_PERCENT


## Whether each goal is done, in the order of NAMES.
func states() -> Array:
	return [done(FRONT), done(SIDE), done(BACK), done(TRIM)]

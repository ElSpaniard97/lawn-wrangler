class_name LawnGrid
extends Node3D
## The one source of truth for which grass is cut. Cutting, the ground
## texture, the grass clumps and the progress bar all read from here.
## Origin is the yard's ground corner; +X is columns, +Z is rows.

signal cell_cut(x: int, z: int, stripe: int)

const TALL := 0
const STRIPE_A := 1
const STRIPE_B := 2
const BLOCKED := 3

@export var columns := 80
@export var rows := 80
@export var cell_size := 0.25

var cells := PackedByteArray()
var total := 0
var cut_count := 0


func _init() -> void:
	reset()


## Which stripe shade a pass leaves. Like a real lawn, going one way along
## a line and coming back the other way leave a light and a dark stripe.
static func stripe_for(direction: Vector3) -> int:
	var lead := direction.x if absf(direction.x) >= absf(direction.z) else direction.z
	return STRIPE_A if lead >= 0.0 else STRIPE_B


## Clears every cell to tall grass. Mark blocked cells, then call seal_layout().
func reset() -> void:
	cells.resize(columns * rows)
	cells.fill(TALL)
	total = 0
	cut_count = 0


func block_circle(center_x: float, center_z: float, radius: float) -> void:
	for z in rows:
		for x in columns:
			var cx := (x + 0.5) * cell_size - center_x
			var cz := (z + 0.5) * cell_size - center_z
			if cx * cx + cz * cz <= radius * radius:
				cells[z * columns + x] = BLOCKED


## Counts the cells that can be cut. Blocked cells never count toward 100%.
func seal_layout() -> void:
	total = 0
	cut_count = 0
	for value in cells:
		if value != BLOCKED:
			total += 1
		if value == STRIPE_A or value == STRIPE_B:
			cut_count += 1


## Cuts tall grass within radius of a world position. Already-cut and
## blocked cells are skipped, so calling this twice never counts twice.
func cut_at(world: Vector3, radius: float, stripe: int) -> int:
	var local := to_local(world) if is_inside_tree() else world
	var lo_x := maxi(0, floori((local.x - radius) / cell_size))
	var hi_x := mini(columns - 1, floori((local.x + radius) / cell_size))
	var lo_z := maxi(0, floori((local.z - radius) / cell_size))
	var hi_z := mini(rows - 1, floori((local.z + radius) / cell_size))
	var stripe_value := clampi(stripe, STRIPE_A, STRIPE_B)
	var newly_cut := 0
	for z in range(lo_z, hi_z + 1):
		for x in range(lo_x, hi_x + 1):
			var i := z * columns + x
			if cells[i] != TALL:
				continue
			var dx := (x + 0.5) * cell_size - local.x
			var dz := (z + 0.5) * cell_size - local.z
			if dx * dx + dz * dz <= radius * radius:
				cells[i] = stripe_value
				cut_count += 1
				newly_cut += 1
				cell_cut.emit(x, z, stripe_value)
	return newly_cut


## Cuts along the path from one blade position to the next, so a fast
## mower or a slow frame never leaves uncut gaps between steps.
func cut_segment(from: Vector3, to: Vector3, radius: float, stripe: int) -> int:
	var steps := maxi(1, ceili(from.distance_to(to) / (cell_size * 0.5)))
	var newly_cut := 0
	for i in range(1, steps + 1):
		newly_cut += cut_at(from.lerp(to, float(i) / steps), radius, stripe)
	return newly_cut


func cell(x: int, z: int) -> int:
	return cells[z * columns + x]


func percent_cut() -> float:
	return 100.0 * cut_count / total if total > 0 else 0.0

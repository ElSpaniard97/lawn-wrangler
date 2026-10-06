class_name Mower
extends CharacterBody3D
## Arcade riding mower. Forward is local -Z. Cuts the LawnGrid under its
## deck while someone is driving, the blades are on and it is moving.
## The blade is narrower than the body, so the strip of grass right
## against the fence and around beds is left for the weed eater.

@export var max_speed := 4.0
@export var reverse_speed := 1.5
@export var acceleration := 3.0
@export var braking := 6.0
@export var turn_rate := 1.6
@export var cut_radius := 0.4

const ORANGE := Color(0.95, 0.35, 0.05)
const DARK := Color(0.12, 0.12, 0.13)

var lawn: LawnGrid
var driving := true
var blades_on := true
var speed := 0.0
## Ground speed from actual movement, so a mower pushing a fence reads 0.
var measured_speed := 0.0
var blade_offset := Vector3(0, 0, -0.15)
var wheels: Array[Node3D] = []
var blade_disc: MeshInstance3D
var driver: Node3D
var clippings: CPUParticles3D
var last_blade := Vector3.ZERO
var has_last_blade := false


func _ready() -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.1, 0.8, 1.5)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.45
	add_child(collider)
	_build_visual()


func _physics_process(delta: float) -> void:
	var throttle := Input.get_axis("reverse", "accelerate") if driving else 0.0
	var steer := Input.get_axis("steer_left", "steer_right") if driving else 0.0
	var target := throttle * (max_speed if throttle >= 0.0 else reverse_speed)
	var rate := acceleration if absf(target) > absf(speed) and signf(target) != -signf(speed) else braking
	speed = move_toward(speed, target, rate * delta)

	var steering_gain := clampf(absf(speed) / 1.5, 0.0, 1.0)
	rotate_y(-steer * turn_rate * steering_gain * signf(speed) * delta)

	var before := global_position
	var forward := -global_basis.z
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()
	var moved := global_position - before
	measured_speed = Vector2(moved.x, moved.z).length() / delta if delta > 0.0 else 0.0

	for wheel in wheels:
		wheel.rotate_object_local(Vector3.UP, -speed * delta / 0.2)
	var cutting := driving and blades_on
	blade_disc.visible = cutting

	var newly_cut := 0
	if cutting and lawn and measured_speed > 0.05:
		# Mowing along X and along Z leaves the two stripe shades.
		var stripe := LawnGrid.STRIPE_A if absf(forward.x) >= absf(forward.z) else LawnGrid.STRIPE_B
		var blade := to_global(blade_offset)
		newly_cut = lawn.cut_segment(last_blade if has_last_blade else blade, blade, cut_radius, stripe)
		last_blade = blade
		has_last_blade = true
	else:
		has_last_blade = false
	clippings.emitting = newly_cut > 0


func toggle_blades() -> void:
	blades_on = not blades_on


func set_driving(value: bool) -> void:
	driving = value
	driver.visible = value


## A zero-turn style mower: wide cutting deck in front, big drive wheels
## and the engine at the back, a high-back seat, lap bars and a roll bar.
func _build_visual() -> void:
	var orange := Models.material(ORANGE, 0.45)
	var dark := Models.material(DARK, 0.8)
	var black := Models.material(Color(0.05, 0.05, 0.05), 0.6)
	var steel := Models.material(Color(0.62, 0.63, 0.65), 0.35)
	var rubber := Models.material(Color(0.07, 0.07, 0.07), 0.95)

	# Frame and cutting deck with its skirt and side discharge chute.
	Models.add_box(self, Vector3(0.62, 0.1, 1.35), Vector3(0, 0.3, 0.02), dark)
	Models.add_box(self, Vector3(1.06, 0.13, 0.66), Vector3(0, 0.24, -0.33), orange)
	Models.add_box(self, Vector3(1.1, 0.05, 0.7), Vector3(0, 0.16, -0.33), dark)
	for x in [-0.33, 0.0, 0.33]:
		Models.add_cylinder(self, 0.07, 0.05, Vector3(x, 0.32, -0.33), dark) # spindle caps
	Models.add_box(self, Vector3(0.18, 0.12, 0.3), Vector3(0.6, 0.2, -0.3), dark, Vector3(0, 0, -12))

	# Footrest and front panel with headlights.
	Models.add_box(self, Vector3(0.56, 0.04, 0.34), Vector3(0, 0.42, -0.52), dark)
	Models.add_box(self, Vector3(0.56, 0.2, 0.05), Vector3(0, 0.52, -0.7), orange)
	for x in [-0.18, 0.18]:
		Models.add_cylinder(self, 0.045, 0.03, Vector3(x, 0.55, -0.73), Models.glow(Color(1.0, 0.95, 0.75), 1.5), Vector3(90, 0, 0))

	# Seat on a pedestal, high back.
	Models.add_box(self, Vector3(0.3, 0.3, 0.3), Vector3(0, 0.5, 0.1), dark)
	Models.add_box(self, Vector3(0.52, 0.1, 0.46), Vector3(0, 0.71, 0.06), black)
	Models.add_box(self, Vector3(0.5, 0.48, 0.1), Vector3(0, 0.98, 0.3), black, Vector3(-10, 0, 0))

	# Engine, fuel tanks over the fenders and the muffler.
	Models.add_box(self, Vector3(0.5, 0.36, 0.34), Vector3(0, 0.56, 0.55), dark)
	Models.add_box(self, Vector3(0.42, 0.12, 0.28), Vector3(0, 0.8, 0.55), orange)
	Models.add_cylinder(self, 0.05, 0.42, Vector3(0, 0.5, 0.74), steel, Vector3(0, 0, 90))
	for side in [-1, 1]:
		Models.add_box(self, Vector3(0.28, 0.05, 0.62), Vector3(0.58 * side, 0.64, 0.4), orange)
		Models.add_box(self, Vector3(0.2, 0.12, 0.26), Vector3(0.36 * side, 0.74, 0.12), orange) # fuel tank
		Models.add_cylinder(self, 0.035, 0.03, Vector3(0.36 * side, 0.81, 0.12), black)

	# Lap bars the driver holds, and the roll bar behind the seat.
	for side in [-1, 1]:
		Models.add_rod(self, Vector3(0.36 * side, 0.6, -0.08), Vector3(0.36 * side, 0.96, -0.28), 0.022, steel)
		Models.add_rod(self, Vector3(0.36 * side, 0.96, -0.28), Vector3(0.1 * side, 0.96, -0.36), 0.026, black)
		Models.add_rod(self, Vector3(0.42 * side, 0.66, 0.36), Vector3(0.42 * side, 1.62, 0.36), 0.03, dark)
	Models.add_rod(self, Vector3(-0.42, 1.62, 0.36), Vector3(0.42, 1.62, 0.36), 0.03, dark)

	# Wheels: each is a pivot whose local Y is the axle, so it spins in place.
	for spec in [[-0.6, 0.4, 0.28, 0.22], [0.6, 0.4, 0.28, 0.22], [-0.42, -0.62, 0.13, 0.1], [0.42, -0.62, 0.13, 0.1]]:
		var wheel := Node3D.new()
		wheel.position = Vector3(spec[0], spec[2], spec[1])
		wheel.rotation.z = PI / 2.0
		add_child(wheel)
		Models.add_cylinder(wheel, spec[2], spec[3], Vector3.ZERO, rubber, Vector3.ZERO, 20)
		Models.add_cylinder(wheel, spec[2] * 0.55, spec[3] + 0.02, Vector3.ZERO, steel)
		Models.add_box(wheel, Vector3(spec[2] * 1.1, spec[3] + 0.03, 0.04), Vector3.ZERO, dark) # spoke so it reads as turning
		wheels.append(wheel)
		if spec[1] < 0.0:
			Models.add_box(self, Vector3(0.04, 0.2, 0.05), Vector3(spec[0], spec[2] + 0.12, spec[1]), dark) # caster fork

	var disc := CylinderMesh.new()
	disc.top_radius = cut_radius
	disc.bottom_radius = cut_radius
	disc.height = 0.01
	disc.material = Models.material(Color(1, 1, 1, 0.12), 1.0, true)
	blade_disc = Models.add_mesh(self, disc, Vector3(blade_offset.x, 0.03, blade_offset.z))

	clippings = Models.clippings(cut_radius)
	clippings.position = Vector3(blade_offset.x, 0.1, blade_offset.z)
	add_child(clippings)

	# The seated person's hips sit at this node's origin, on the cushion.
	driver = Node3D.new()
	driver.position = Vector3(0, 0.77, 0.12)
	driver.add_child(Models.person(true))
	add_child(driver)

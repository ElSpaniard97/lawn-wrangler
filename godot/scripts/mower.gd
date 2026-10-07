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
		var stripe := LawnGrid.stripe_for(forward)
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


## A commercial zero-turn mower, modelled on the reference photo: a wide
## orange cutting deck, an orange frame that wraps round the back, big
## treaded drive tires under black fenders, a black high-back seat with lap
## bars, and the engine with its round air-filter cover behind the seat.
func _build_visual() -> void:
	var orange := Models.material(ORANGE, 0.42)
	var dark := Models.material(DARK, 0.75)
	var black := Models.material(Color(0.035, 0.035, 0.04), 0.55)
	var plastic := Models.material(Color(0.06, 0.06, 0.065), 0.45)
	var steel := Models.material(Color(0.55, 0.56, 0.58), 0.35)
	var exhaust := Models.material(Color(0.22, 0.22, 0.23), 0.5)
	var rubber := Models.material(Color(0.045, 0.045, 0.045), 0.95)

	# Cutting deck: orange housing with a black skirt, spindle covers, a
	# belt shield and the side discharge chute.
	Models.add_box(self, Vector3(1.3, 0.16, 0.72), Vector3(0, 0.24, -0.36), orange)
	Models.add_box(self, Vector3(1.34, 0.05, 0.76), Vector3(0, 0.14, -0.36), dark)
	for x in [-0.36, 0.0, 0.36]:
		Models.add_cylinder(self, 0.09, 0.04, Vector3(x, 0.3, -0.38), dark) # spindle covers
	Models.add_box(self, Vector3(0.9, 0.03, 0.4), Vector3(0, 0.3, -0.32), black) # belt shield
	Models.add_box(self, Vector3(0.22, 0.14, 0.34), Vector3(0.74, 0.2, -0.34), plastic, Vector3(0, 0, -14))

	# Orange frame: two rails from the front casters back to a U-shaped rear
	# bumper under the engine, like the reference.
	for side in [-1, 1]:
		Models.add_box(self, Vector3(0.07, 0.1, 1.5), Vector3(0.36 * side, 0.36, 0.02), orange)
		Models.add_box(self, Vector3(0.07, 0.24, 0.07), Vector3(0.42 * side, 0.34, -0.66), orange) # caster mount
	Models.add_box(self, Vector3(0.8, 0.22, 0.08), Vector3(0, 0.36, 0.82), orange) # rear bumper
	for side in [-1, 1]:
		Models.add_box(self, Vector3(0.08, 0.22, 0.3), Vector3(0.36 * side, 0.36, 0.7), orange)
		Models.add_box(self, Vector3(0.05, 0.2, 0.5), Vector3(0.33 * side, 0.52, 0.3), orange) # side plate under the seat

	# Footplate and front body pan.
	Models.add_box(self, Vector3(0.66, 0.04, 0.42), Vector3(0, 0.42, -0.5), black)
	Models.add_box(self, Vector3(0.66, 0.16, 0.05), Vector3(0, 0.49, -0.72), black)
	Models.add_box(self, Vector3(0.62, 0.14, 0.62), Vector3(0, 0.46, 0.08), dark) # body under the seat

	# Black fenders over the drive tires, with control towers in front.
	for side in [-1, 1]:
		Models.add_box(self, Vector3(0.36, 0.05, 0.7), Vector3(0.6 * side, 0.68, 0.38), plastic)
		Models.add_box(self, Vector3(0.36, 0.2, 0.05), Vector3(0.6 * side, 0.58, 0.04), plastic, Vector3(-25, 0, 0))
		Models.add_box(self, Vector3(0.16, 0.34, 0.26), Vector3(0.38 * side, 0.68, -0.12), plastic) # control tower
		Models.add_cylinder(self, 0.05, 0.08, Vector3(0.38 * side, 0.89, -0.06), black) # cup holder / knob
		# Lap bars: up from the tower, over towards the driver, with grips.
		Models.add_rod(self, Vector3(0.38 * side, 0.82, -0.2), Vector3(0.38 * side, 1.02, -0.32), 0.022, black)
		Models.add_rod(self, Vector3(0.38 * side, 1.02, -0.32), Vector3(0.12 * side, 1.02, -0.36), 0.03, black)

	# High-back seat with side bolsters.
	Models.add_box(self, Vector3(0.3, 0.16, 0.3), Vector3(0, 0.6, 0.12), dark)
	Models.add_box(self, Vector3(0.54, 0.1, 0.48), Vector3(0, 0.72, 0.08), black)
	Models.add_box(self, Vector3(0.52, 0.4, 0.11), Vector3(0, 0.94, 0.32), black, Vector3(-8, 0, 0))
	for side in [-1, 1]:
		Models.add_box(self, Vector3(0.07, 0.3, 0.13), Vector3(0.25 * side, 0.92, 0.3), black, Vector3(-8, 0, 0))
	Models.add_box(self, Vector3(0.22, 0.04, 0.02), Vector3(0, 1.04, 0.38), Models.material(Color(0.25, 0.25, 0.27), 0.6), Vector3(-8, 0, 0))

	# Engine behind the seat: block, cooling shroud, the round air-filter
	# cover with a grille, the muffler and a fuel tank on each side.
	Models.add_box(self, Vector3(0.56, 0.32, 0.36), Vector3(0, 0.58, 0.6), dark)
	Models.add_box(self, Vector3(0.5, 0.12, 0.32), Vector3(0, 0.8, 0.6), black)
	Models.add_cylinder(self, 0.15, 0.1, Vector3(0, 0.9, 0.6), plastic, Vector3.ZERO, 20)
	Models.add_cylinder(self, 0.12, 0.11, Vector3(0, 0.9, 0.6), Models.material(Color(0.14, 0.14, 0.15), 0.8), Vector3.ZERO, 20)
	for i in 5:
		Models.add_box(self, Vector3(0.22, 0.12, 0.012), Vector3(0, 0.9, 0.53 + i * 0.035), black)
	Models.add_cylinder(self, 0.06, 0.4, Vector3(0, 0.46, 0.8), exhaust, Vector3(0, 0, 90)) # muffler
	for side in [-1, 1]:
		Models.add_box(self, Vector3(0.18, 0.2, 0.3), Vector3(0.36 * side, 0.82, 0.52), plastic) # fuel tank
		Models.add_cylinder(self, 0.04, 0.04, Vector3(0.36 * side, 0.94, 0.48), Models.material(Color(0.85, 0.2, 0.1), 0.5))

	# Wheels: each is a pivot whose local Y is the axle, so it spins in place.
	# Drive tires get chevron tread lugs and an orange-trimmed hub.
	for spec in [[-0.62, 0.42, 0.3, 0.27], [0.62, 0.42, 0.3, 0.27], [-0.44, -0.66, 0.12, 0.09], [0.44, -0.66, 0.12, 0.09]]:
		var radius: float = spec[2]
		var width: float = spec[3]
		var wheel := Node3D.new()
		wheel.position = Vector3(spec[0], radius, spec[1])
		wheel.rotation.z = PI / 2.0
		add_child(wheel)
		Models.add_cylinder(wheel, radius - 0.02, width, Vector3.ZERO, rubber, Vector3.ZERO, 24)
		Models.add_cylinder(wheel, radius * 0.55, width + 0.02, Vector3.ZERO, steel)
		Models.add_cylinder(wheel, radius * 0.22, width + 0.04, Vector3.ZERO, dark)
		if radius > 0.2:
			for i in 18:
				var angle := i * TAU / 18.0
				for half in [-1, 1]:
					var lug := Models.add_box(wheel, Vector3(0.035, width * 0.46, 0.05),
						Vector3(cos(angle), 0, sin(angle)) * (radius - 0.01) + Vector3(0, half * width * 0.25, 0), rubber)
					lug.rotation = Vector3(0, -angle, 0)
					lug.rotate_object_local(Vector3.RIGHT, deg_to_rad(22 * half))
		else:
			Models.add_box(wheel, Vector3(radius * 1.1, width + 0.03, 0.04), Vector3.ZERO, dark) # spoke so it reads as turning
			Models.add_box(self, Vector3(0.04, 0.2, 0.05), Vector3(spec[0], radius + 0.12, spec[1]), dark) # caster fork
		wheels.append(wheel)

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
	driver.position = Vector3(0, 0.69, 0.1) # the 1.1x person lifts the hips back to the cushion
	var person := Models.person(true)
	person.scale = Vector3.ONE * 1.1
	driver.add_child(person)
	add_child(driver)

	# Fewer draw calls: one mesh for the body, one per wheel, one for the driver.
	Models.bake(self, wheels + [blade_disc, driver])
	for wheel in wheels:
		Models.bake(wheel)
	Models.bake(driver)

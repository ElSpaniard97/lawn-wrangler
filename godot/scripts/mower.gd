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


func _build_visual() -> void:
	var orange := Models.material(ORANGE, 0.45)
	var dark := Models.material(DARK, 0.8)
	var seat := Models.material(Color(0.08, 0.08, 0.08), 0.6)

	Models.add_box(self, Vector3(1.1, 0.18, 1.0), Vector3(0, 0.32, -0.15), orange) # cutting deck
	Models.add_box(self, Vector3(0.62, 0.3, 0.75), Vector3(0, 0.55, 0.35), orange) # engine body
	Models.add_box(self, Vector3(0.5, 0.08, 0.45), Vector3(0, 0.74, 0.05), seat) # seat base
	Models.add_box(self, Vector3(0.5, 0.4, 0.08), Vector3(0, 0.95, 0.27), seat) # seat back
	Models.add_box(self, Vector3(0.06, 0.45, 0.06), Vector3(-0.32, 0.85, -0.2), dark) # lap bars
	Models.add_box(self, Vector3(0.06, 0.45, 0.06), Vector3(0.32, 0.85, -0.2), dark)

	for spec in [[-0.6, 0.4, 0.28, 0.24], [0.6, 0.4, 0.28, 0.24], [-0.45, -0.6, 0.15, 0.12], [0.45, -0.6, 0.15, 0.12]]:
		var tire := CylinderMesh.new()
		tire.top_radius = spec[2]
		tire.bottom_radius = spec[2]
		tire.height = spec[3]
		tire.material = dark
		var wheel := Models.add_mesh(self, tire, Vector3(spec[0], spec[2], spec[1]))
		wheel.rotation.z = PI / 2.0
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

	driver = Models.person(true)
	driver.position = Vector3(0, 0.78, 0.08)
	add_child(driver)

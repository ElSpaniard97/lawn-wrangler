class_name Mower
extends CharacterBody3D
## Arcade riding mower. Forward is local -Z. Cuts the LawnGrid under its
## deck while the blades are on and it is moving.

@export var max_speed := 4.0
@export var reverse_speed := 1.5
@export var acceleration := 3.0
@export var braking := 6.0
@export var turn_rate := 1.6
@export var cut_radius := 0.6

const ORANGE := Color(0.95, 0.35, 0.05)
const DARK := Color(0.12, 0.12, 0.13)

var lawn: LawnGrid
var blades_on := true
var speed := 0.0
## Ground speed from actual movement, so a mower pushing a fence reads 0.
var measured_speed := 0.0
var blade_offset := Vector3(0, 0, -0.15)
var wheels: Array[Node3D] = []
var blade_disc: MeshInstance3D


func _ready() -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 0.8, 1.5)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.45
	add_child(collider)
	_build_visual()


func _physics_process(delta: float) -> void:
	var throttle := Input.get_axis("reverse", "accelerate")
	var target := throttle * (max_speed if throttle >= 0.0 else reverse_speed)
	var rate := acceleration if absf(target) > absf(speed) and signf(target) != -signf(speed) else braking
	speed = move_toward(speed, target, rate * delta)

	var steer := Input.get_axis("steer_left", "steer_right")
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
	blade_disc.visible = blades_on

	if blades_on and lawn and measured_speed > 0.05:
		# Mowing along X and along Z leaves the two stripe shades.
		var stripe := LawnGrid.STRIPE_A if absf(forward.x) >= absf(forward.z) else LawnGrid.STRIPE_B
		lawn.cut_at(to_global(blade_offset), cut_radius, stripe)


func toggle_blades() -> void:
	blades_on = not blades_on


func _build_visual() -> void:
	var orange := _material(ORANGE, 0.45)
	var dark := _material(DARK, 0.8)
	var seat := _material(Color(0.08, 0.08, 0.08), 0.6)

	_box(Vector3(1.0, 0.18, 1.0), Vector3(0, 0.32, -0.15), orange) # cutting deck
	_box(Vector3(0.62, 0.3, 0.75), Vector3(0, 0.55, 0.35), orange) # engine body
	_box(Vector3(0.5, 0.08, 0.45), Vector3(0, 0.74, 0.05), seat) # seat base
	_box(Vector3(0.5, 0.4, 0.08), Vector3(0, 0.95, 0.27), seat) # seat back
	_box(Vector3(0.06, 0.45, 0.06), Vector3(-0.32, 0.85, -0.2), dark) # lap bars
	_box(Vector3(0.06, 0.45, 0.06), Vector3(0.32, 0.85, -0.2), dark)

	for spec in [[-0.55, 0.4, 0.28, 0.24], [0.55, 0.4, 0.28, 0.24], [-0.42, -0.6, 0.15, 0.12], [0.42, -0.6, 0.15, 0.12]]:
		var tire := CylinderMesh.new()
		tire.top_radius = spec[2]
		tire.bottom_radius = spec[2]
		tire.height = spec[3]
		tire.material = dark
		var wheel := MeshInstance3D.new()
		wheel.mesh = tire
		wheel.rotation.z = PI / 2.0
		wheel.position = Vector3(spec[0], spec[2], spec[1])
		add_child(wheel)
		wheels.append(wheel)

	var disc := CylinderMesh.new()
	disc.top_radius = cut_radius
	disc.bottom_radius = cut_radius
	disc.height = 0.01
	disc.material = _material(Color(1, 1, 1, 0.12), 1.0, true)
	blade_disc = MeshInstance3D.new()
	blade_disc.mesh = disc
	blade_disc.position = Vector3(blade_offset.x, 0.03, blade_offset.z)
	add_child(blade_disc)

	# Driver: torso, head, cap and headset.
	var shirt := _material(Color(0.25, 0.27, 0.30), 0.9)
	var skin := _material(Color(0.78, 0.58, 0.44), 0.8)
	var torso := CapsuleMesh.new()
	torso.radius = 0.2
	torso.height = 0.7
	torso.material = shirt
	_mesh(torso, Vector3(0, 1.12, 0.1))
	var head := SphereMesh.new()
	head.radius = 0.13
	head.height = 0.26
	head.material = skin
	_mesh(head, Vector3(0, 1.58, 0.08))
	_box(Vector3(0.28, 0.08, 0.3), Vector3(0, 1.68, 0.06), dark) # cap
	_box(Vector3(0.32, 0.1, 0.08), Vector3(0, 1.58, 0.08), _material(Color(0.6, 0.15, 0.1), 0.6)) # headset


func _box(size: Vector3, at: Vector3, material: Material) -> void:
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	_mesh(box, at)


func _mesh(mesh: Mesh, at: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	add_child(instance)


func _material(color: Color, roughness: float, transparent := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

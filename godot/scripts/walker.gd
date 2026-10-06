class_name Walker
extends CharacterBody3D
## The landscaper on foot with a weed eater. Steers like the mower (A/D
## turn, W/S walk) so the chase camera stays behind. The trimmer head runs
## the whole time you are on foot and cuts a small circle in front of you,
## which is how you reach grass along the fence and around beds.

@export var walk_speed := 2.2
@export var back_speed := 1.2
@export var turn_rate := 2.6
@export var cut_radius := 0.3

var lawn: LawnGrid
var active := false
var measured_speed := 0.0
var tip_offset := Vector3(0.15, 0.05, -0.85)
var trimmer_head: Node3D
var swath: MeshInstance3D


func _ready() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.25
	shape.height = 1.7
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.85
	add_child(collider)
	_build_visual()


func _physics_process(delta: float) -> void:
	if not active:
		return
	var throttle := Input.get_axis("reverse", "accelerate")
	var steer := Input.get_axis("steer_left", "steer_right")
	rotate_y(-steer * turn_rate * delta)
	var forward := -global_basis.z
	var speed := throttle * (walk_speed if throttle >= 0.0 else back_speed)
	var before := global_position
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()
	var moved := global_position - before
	measured_speed = Vector2(moved.x, moved.z).length() / delta if delta > 0.0 else 0.0
	trimmer_head.rotate_y(40.0 * delta)
	if lawn:
		var stripe := LawnGrid.STRIPE_A if absf(forward.x) >= absf(forward.z) else LawnGrid.STRIPE_B
		lawn.cut_at(tip_position(), cut_radius, stripe)


func tip_position() -> Vector3:
	return to_global(tip_offset)


func set_active(value: bool) -> void:
	active = value
	visible = value
	measured_speed = 0.0
	# A parked walker must not block the mower, so collisions follow it.
	process_mode = Node.PROCESS_MODE_PAUSABLE if value else Node.PROCESS_MODE_DISABLED
	collision_layer = 1 if value else 0


func _build_visual() -> void:
	add_child(Models.person(false))
	var metal := Models.material(Color(0.7, 0.7, 0.72), 0.4)
	var orange := Models.material(Color(0.95, 0.35, 0.05), 0.5)
	# Shaft from the hands down to the head in front of the feet.
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.02
	shaft.bottom_radius = 0.02
	shaft.height = 1.25
	shaft.material = metal
	var shaft_instance := Models.add_mesh(self, shaft, Vector3(0.15, 0.6, -0.45))
	shaft_instance.rotation.x = deg_to_rad(-38)
	Models.add_box(self, Vector3(0.14, 0.14, 0.2), Vector3(0.15, 1.05, -0.05), orange) # motor
	trimmer_head = Node3D.new()
	trimmer_head.position = tip_offset
	add_child(trimmer_head)
	var spool := CylinderMesh.new()
	spool.top_radius = 0.07
	spool.bottom_radius = 0.07
	spool.height = 0.06
	spool.material = orange
	Models.add_mesh(trimmer_head, spool, Vector3.ZERO)
	var line := BoxMesh.new()
	line.size = Vector3(cut_radius * 2.0, 0.01, 0.015)
	line.material = Models.material(Color(0.95, 0.9, 0.3), 0.5)
	Models.add_mesh(trimmer_head, line, Vector3.ZERO)
	var disc := CylinderMesh.new()
	disc.top_radius = cut_radius
	disc.bottom_radius = cut_radius
	disc.height = 0.01
	disc.material = Models.material(Color(1, 1, 1, 0.12), 1.0, true)
	swath = Models.add_mesh(self, disc, Vector3(tip_offset.x, 0.03, tip_offset.z))

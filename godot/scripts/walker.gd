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
var person: Node3D
var stride := 0.0
var swath: MeshInstance3D
var clippings: CPUParticles3D
var last_tip := Vector3.ZERO
var has_last_tip := false


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
	var pace := clampf(measured_speed / walk_speed, 0.0, 1.0)
	stride = fmod(stride + measured_speed * delta * 4.5, TAU) if pace > 0.05 else 0.0
	Models.animate_walk(person, stride, pace, true)
	if lawn:
		var stripe := LawnGrid.STRIPE_A if absf(forward.x) >= absf(forward.z) else LawnGrid.STRIPE_B
		var tip := tip_position()
		var newly_cut := lawn.cut_segment(last_tip if has_last_tip else tip, tip, cut_radius, stripe)
		last_tip = tip
		has_last_tip = true
		clippings.emitting = newly_cut > 0


func tip_position() -> Vector3:
	return to_global(tip_offset)


func set_active(value: bool) -> void:
	active = value
	visible = value
	measured_speed = 0.0
	has_last_tip = false
	if clippings:
		clippings.emitting = false
	# A parked walker must not block the mower, so collisions follow it.
	process_mode = Node.PROCESS_MODE_PAUSABLE if value else Node.PROCESS_MODE_DISABLED
	collision_layer = 1 if value else 0


## The landscaper holding a straight-shaft weed eater: motor at the back,
## a rear grip and a raised front handle, and a guarded spinning head.
func _build_visual() -> void:
	person = Models.person(false)
	add_child(person)
	# Hands on the grips: right on the rear grip, left on the front handle.
	person.get_node("RightArm").rotation = Vector3(deg_to_rad(30), 0, deg_to_rad(-6))
	person.get_node("LeftArm").rotation = Vector3(deg_to_rad(38), 0, deg_to_rad(-18))

	var metal := Models.material(Color(0.7, 0.7, 0.72), 0.4)
	var orange := Models.material(Models.ORANGE, 0.5)
	var dark := Models.material(Models.DARK, 0.7)
	var top := Vector3(0.15, 1.05, -0.1)
	var head := Vector3(tip_offset.x, 0.12, tip_offset.z)
	var along := func(t: float) -> Vector3: return top.lerp(head, t)
	Models.add_rod(self, top, head, 0.018, metal)
	Models.add_box(self, Vector3(0.14, 0.16, 0.22), top + Vector3(0, 0.02, 0.1), orange) # motor
	Models.add_box(self, Vector3(0.1, 0.08, 0.12), top + Vector3(0, -0.08, 0.12), dark) # fuel tank
	Models.add_cylinder(self, 0.03, 0.14, along.call(0.17), dark, Vector3(48, 0, 0)) # rear grip
	var post: Vector3 = along.call(0.4)
	Models.add_rod(self, post, post + Vector3(0, 0.22, 0), 0.015, dark)
	Models.add_rod(self, post + Vector3(-0.18, 0.22, 0), post + Vector3(0.04, 0.22, 0), 0.022, dark) # front handle
	Models.add_box(self, Vector3(0.08, 0.06, 0.1), head + Vector3(0, 0.03, 0), dark) # gearbox
	var guard := CylinderMesh.new()
	guard.top_radius = 0.17
	guard.bottom_radius = 0.17
	guard.height = 0.02
	guard.radial_segments = 16
	guard.material = orange
	Models.add_mesh(self, guard, head + Vector3(0, 0.0, 0.08), Vector3(-15, 0, 0))

	trimmer_head = Node3D.new()
	trimmer_head.position = tip_offset
	add_child(trimmer_head)
	Models.add_cylinder(trimmer_head, 0.06, 0.06, Vector3.ZERO, orange)
	Models.add_box(trimmer_head, Vector3(cut_radius * 2.0, 0.01, 0.015), Vector3.ZERO, Models.material(Color(0.95, 0.9, 0.3), 0.5))
	var disc := CylinderMesh.new()
	disc.top_radius = cut_radius
	disc.bottom_radius = cut_radius
	disc.height = 0.01
	disc.material = Models.material(Color(1, 1, 1, 0.12), 1.0, true)
	swath = Models.add_mesh(self, disc, Vector3(tip_offset.x, 0.03, tip_offset.z))
	clippings = Models.clippings(cut_radius)
	clippings.position = Vector3(tip_offset.x, 0.1, tip_offset.z)
	add_child(clippings)

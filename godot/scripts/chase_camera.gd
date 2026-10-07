class_name ChaseCamera
extends Node3D
## Follows the mower from behind with smoothing. A SpringArm3D pulls the
## camera in when a fence or tree would block the view.

@export var target: Node3D
@export var follow_speed := 6.0
@export var turn_speed := 3.0
@export var distance := 3.8
@export var pitch_degrees := -15.0

var arm: SpringArm3D
var camera: Camera3D


func _ready() -> void:
	top_level = true
	arm = SpringArm3D.new()
	arm.spring_length = distance
	arm.margin = 0.2
	arm.rotation.x = deg_to_rad(pitch_degrees)
	arm.position.y = 1.5
	add_child(arm)
	camera = Camera3D.new()
	camera.fov = 62.0
	camera.current = true
	arm.add_child(camera)
	if target:
		follow(target, distance, true)


## Switches who the camera follows; snap jumps there instead of gliding.
func follow(node: Node3D, new_distance: float, snap := false) -> void:
	if target is CollisionObject3D:
		arm.remove_excluded_object(target.get_rid())
	target = node
	distance = new_distance
	if target is CollisionObject3D:
		arm.add_excluded_object(target.get_rid())
	if snap:
		arm.spring_length = distance
		global_transform = Transform3D(Basis(Vector3.UP, target.global_rotation.y), target.global_position)


func _physics_process(delta: float) -> void:
	if not target:
		return
	arm.spring_length = lerpf(arm.spring_length, distance, clampf(3.0 * delta, 0.0, 1.0))
	global_position = global_position.lerp(target.global_position, clampf(follow_speed * delta, 0.0, 1.0))
	rotation.y = lerp_angle(rotation.y, target.global_rotation.y, clampf(turn_speed * delta, 0.0, 1.0))

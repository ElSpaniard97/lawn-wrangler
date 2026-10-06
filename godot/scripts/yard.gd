extends Node3D
## The yard: 20 x 20 m of lawn inside a fence, two trees in stone rings and
## two flower beds. Ride the mower for the open lawn, then hop off and use
## the weed eater along the fence and around the trees and beds.

const YARD_SIZE := 20.0
## Trees: x, z. Each sits in a stone ring the mower cannot drive over.
const TREES := [Vector2(13.0, 7.0), Vector2(5.5, 4.5)]
const RING_RADIUS := 0.6
## Flower beds: x, z, radius.
const BEDS := [Vector3(5.0, 12.5, 1.0), Vector3(15.0, 15.0, 1.3)]
const WIN_PERCENT := 99.0
const MPS_TO_MPH := 2.237
const REMOUNT_DISTANCE := 1.8
## Past this, missed patches light up on their own, like the original game.
const AUTO_HIGHLIGHT_PERCENT := 95.0

var lawn: LawnGrid
var view: LawnView
var mower: Mower
var walker: Walker
var camera: ChaseCamera
var run: RunState
var hud: Hud
var floor_body: StaticBody3D
var on_mower := true
var auto_highlighted := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_build_environment()

	lawn = LawnGrid.new()
	lawn.name = "LawnGrid"
	add_child(lawn)
	lawn.reset()
	for tree in TREES:
		lawn.block_circle(tree.x, tree.y, RING_RADIUS)
	for bed in BEDS:
		lawn.block_circle(bed.x, bed.y, bed.z)
	lawn.seal_layout()

	view = LawnView.new()
	view.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(view)
	view.build(lawn)

	_build_fence()
	for tree in TREES:
		_build_tree(Vector3(tree.x, 0, tree.y), 1.0, true)
	for bed in BEDS:
		_build_bed(Vector3(bed.x, 0, bed.y), bed.z)
	_build_scenery()

	mower = Mower.new()
	mower.name = "Mower"
	mower.process_mode = Node.PROCESS_MODE_PAUSABLE
	mower.lawn = lawn
	add_child(mower)
	mower.global_position = Vector3(2.0, 0.05, 16.5)

	walker = Walker.new()
	walker.name = "Walker"
	walker.lawn = lawn
	add_child(walker)
	walker.set_active(false)

	camera = ChaseCamera.new()
	camera.process_mode = Node.PROCESS_MODE_PAUSABLE
	camera.target = mower
	add_child(camera)

	run = RunState.new()
	add_child(run)
	hud = Hud.new()
	add_child(hud)
	run.finished_run.connect(_on_finished)
	hud.say("Mow the open lawn, then press Space to hop off and trim the edges.", 5.0)


func _process(_delta: float) -> void:
	var percent := lawn.percent_cut()
	if percent >= WIN_PERCENT and not run.finished:
		run.finish_run()
	elif percent >= AUTO_HIGHLIGHT_PERCENT and not auto_highlighted:
		auto_highlighted = true
		if not view.highlight:
			view.set_highlight(true)
			hud.say("Almost there! The last patches are highlighted in yellow.")
	var speed := mower.measured_speed if on_mower else walker.measured_speed
	hud.update_play(percent, lawn.total - lawn.cut_count, speed * MPS_TO_MPH, not on_mower,
		mower.blades_on, run.elapsed, run.best)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("pause"):
		run.toggle_pause()
		hud.show_paused(get_tree().paused)
	elif event.is_action_pressed("restart"):
		get_tree().paused = false
		get_tree().reload_current_scene()
	elif get_tree().paused or run.finished:
		return
	elif event.is_action_pressed("hop"):
		toggle_mower()
	elif event.is_action_pressed("toggle_blades") and on_mower:
		mower.toggle_blades()
	elif event.is_action_pressed("highlight"):
		view.set_highlight(not view.highlight)


## Hops off beside the mower where there is room, or back on when close.
func toggle_mower() -> bool:
	if on_mower:
		for side in [Vector3(-1.0, 0, 0), Vector3(1.0, 0, 0), Vector3(0, 0, 1.4), Vector3(0, 0, -1.4)]:
			var spot := mower.to_global(side)
			spot.y = 0.0
			if _walker_fits(spot):
				walker.global_position = spot
				walker.global_rotation.y = mower.global_rotation.y
				walker.set_active(true)
				mower.set_driving(false)
				camera.follow(walker, 3.2)
				on_mower = false
				hud.say("Weed eater out! Trim along the fence and around the beds.")
				return true
		hud.say("No room to step off here.")
		return false
	if walker.global_position.distance_to(mower.global_position) > REMOUNT_DISTANCE:
		hud.say("Walk over to the mower to hop back on.")
		return false
	walker.set_active(false)
	mower.set_driving(true)
	camera.follow(mower, 4.5)
	on_mower = true
	hud.say("Back on the mower.")
	return true


func _walker_fits(spot: Vector3) -> bool:
	if spot.x < 0.3 or spot.z < 0.3 or spot.x > YARD_SIZE - 0.3 or spot.z > YARD_SIZE - 0.3:
		return false
	var shape := CapsuleShape3D.new()
	shape.radius = 0.25
	shape.height = 1.7
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), spot + Vector3(0, 0.9, 0))
	query.exclude = [floor_body.get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and hud and get_tree().paused and not run.finished:
		hud.show_paused(true)


func _on_finished(time: float, is_record: bool) -> void:
	mower.set_physics_process(false)
	walker.set_physics_process(false)
	hud.show_finished(time, run.best, is_record, run.storage_ok)


func _setup_input() -> void:
	var keys := {
		"accelerate": [KEY_W, KEY_UP],
		"reverse": [KEY_S, KEY_DOWN],
		"steer_left": [KEY_A, KEY_LEFT],
		"steer_right": [KEY_D, KEY_RIGHT],
		"toggle_blades": [KEY_B],
		"hop": [KEY_SPACE],
		"highlight": [KEY_H],
		"pause": [KEY_P, KEY_ESCAPE],
		"restart": [KEY_R],
	}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)


func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.32, 0.55, 0.85)
	sky_material.sky_horizon_color = Color(0.75, 0.84, 0.92)
	sky_material.ground_horizon_color = Color(0.6, 0.65, 0.55)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.0
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)

	# Flat ground: a collider under the yard and a darker lawn beyond the fence.
	floor_body = StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(floor_shape)
	add_child(floor_body)
	var outer := PlaneMesh.new()
	outer.size = Vector2(120, 120)
	outer.material = _material(Color(0.16, 0.28, 0.09), 1.0)
	var outer_instance := MeshInstance3D.new()
	outer_instance.mesh = outer
	outer_instance.position = Vector3(YARD_SIZE / 2.0, -0.02, YARD_SIZE / 2.0)
	add_child(outer_instance)


func _build_fence() -> void:
	var wood := _material(Color(0.55, 0.38, 0.24), 0.9)
	var height := 1.2
	var walls := [
		[Vector3(YARD_SIZE / 2.0, 0, -0.1), Vector3(YARD_SIZE + 0.4, height, 0.2)],
		[Vector3(YARD_SIZE / 2.0, 0, YARD_SIZE + 0.1), Vector3(YARD_SIZE + 0.4, height, 0.2)],
		[Vector3(-0.1, 0, YARD_SIZE / 2.0), Vector3(0.2, height, YARD_SIZE)],
		[Vector3(YARD_SIZE + 0.1, 0, YARD_SIZE / 2.0), Vector3(0.2, height, YARD_SIZE)],
	]
	for wall in walls:
		var at: Vector3 = wall[0]
		var size: Vector3 = wall[1]
		var body := StaticBody3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		body.position = at + Vector3(0, height / 2.0, 0)
		add_child(body)
		# Pickets every 0.25 m along the wall.
		var length := maxf(size.x, size.z)
		var along_x := size.x > size.z
		var count := int(length / 0.25)
		var picket := BoxMesh.new()
		picket.size = Vector3(0.18, height, 0.04) if along_x else Vector3(0.04, height, 0.18)
		picket.material = wood
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = picket
		mm.instance_count = count
		for i in count:
			var offset := -length / 2.0 + (i + 0.5) * length / count
			var local := Vector3(offset, 0, 0) if along_x else Vector3(0, 0, offset)
			mm.set_instance_transform(i, Transform3D(Basis(), local))
		var pickets := MultiMeshInstance3D.new()
		pickets.multimesh = mm
		body.add_child(pickets)


func _build_tree(at: Vector3, scale_factor: float, collide: bool) -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.18 * scale_factor
	trunk_mesh.bottom_radius = 0.25 * scale_factor
	trunk_mesh.height = 2.4 * scale_factor
	trunk_mesh.material = _material(Color(0.36, 0.25, 0.17), 1.0)
	var trunk := MeshInstance3D.new()
	trunk.mesh = trunk_mesh
	trunk.position = at + Vector3(0, trunk_mesh.height / 2.0, 0)
	add_child(trunk)
	var leaves := _material(Color(0.20, 0.42, 0.16), 1.0)
	for blob in [[Vector3(0, 3.0, 0), 1.5], [Vector3(0.8, 2.6, 0.3), 1.0], [Vector3(-0.7, 2.7, -0.4), 1.1], [Vector3(0.1, 3.7, 0.2), 1.0]]:
		var sphere := SphereMesh.new()
		sphere.radius = blob[1] * scale_factor
		sphere.height = blob[1] * 2.0 * scale_factor
		sphere.material = leaves
		var canopy := MeshInstance3D.new()
		canopy.mesh = sphere
		canopy.position = at + blob[0] * scale_factor
		add_child(canopy)
	if collide:
		var ring := CylinderMesh.new()
		ring.top_radius = RING_RADIUS
		ring.bottom_radius = RING_RADIUS + 0.03
		ring.height = 0.2
		ring.material = _material(Color(0.55, 0.53, 0.50), 0.9)
		var ring_instance := MeshInstance3D.new()
		ring_instance.mesh = ring
		ring_instance.position = at + Vector3(0, 0.1, 0)
		add_child(ring_instance)
		var mulch := CylinderMesh.new()
		mulch.top_radius = RING_RADIUS - 0.06
		mulch.bottom_radius = RING_RADIUS - 0.06
		mulch.height = 0.02
		mulch.material = _material(Color(0.30, 0.20, 0.13), 1.0)
		var mulch_instance := MeshInstance3D.new()
		mulch_instance.mesh = mulch
		mulch_instance.position = at + Vector3(0, 0.205, 0)
		add_child(mulch_instance)
		var body := StaticBody3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = RING_RADIUS
		shape.height = 2.0
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		body.position = at + Vector3(0, 1.0, 0)
		add_child(body)


func _build_bed(at: Vector3, radius: float) -> void:
	var soil := CylinderMesh.new()
	soil.top_radius = radius
	soil.bottom_radius = radius + 0.05
	soil.height = 0.16
	soil.material = _material(Color(0.30, 0.21, 0.14), 1.0)
	var bed := MeshInstance3D.new()
	bed.mesh = soil
	bed.position = at + Vector3(0, 0.08, 0)
	add_child(bed)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(at.x * 31.0 + at.z)
	var colors := [Color(0.85, 0.35, 0.55), Color(0.95, 0.8, 0.3), Color(0.9, 0.9, 0.95)]
	for i in 9:
		var angle := i * TAU / 9.0 + rng.randf() * 0.3
		var r := rng.randf_range(0.2, radius - 0.25)
		var shrub := SphereMesh.new()
		shrub.radius = rng.randf_range(0.18, 0.28)
		shrub.height = shrub.radius * 1.6
		shrub.material = _material(Color(0.18, 0.38, 0.14), 1.0) if i % 3 else _material(colors[i % 3 + (i / 3) % 2], 0.9)
		var instance := MeshInstance3D.new()
		instance.mesh = shrub
		instance.position = at + Vector3(cos(angle) * r, 0.2, sin(angle) * r)
		add_child(instance)
	var body := StaticBody3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 0.6
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	body.position = at + Vector3(0, 0.3, 0)
	add_child(body)


func _build_scenery() -> void:
	# A simple house beyond the far fence and a few trees around the yard.
	var wall := _material(Color(0.78, 0.76, 0.72), 0.9)
	var roof := _material(Color(0.32, 0.30, 0.30), 0.8)
	var house := BoxMesh.new()
	house.size = Vector3(12, 5, 7)
	house.material = wall
	var house_instance := MeshInstance3D.new()
	house_instance.mesh = house
	house_instance.position = Vector3(8, 2.5, -6)
	add_child(house_instance)
	var roof_mesh := PrismMesh.new()
	roof_mesh.size = Vector3(13, 2.5, 8)
	roof_mesh.material = roof
	var roof_instance := MeshInstance3D.new()
	roof_instance.mesh = roof_mesh
	roof_instance.position = Vector3(8, 6.25, -6)
	add_child(roof_instance)
	for spot in [Vector3(-4, 0, 4), Vector3(-5, 0, 15), Vector3(25, 0, 3), Vector3(24, 0, 16), Vector3(18, 0, 26), Vector3(3, 0, 26)]:
		_build_tree(spot, 1.3, false)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

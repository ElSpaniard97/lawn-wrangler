extends Node3D
## Phase 0 test yard: 20 x 20 m of cuttable lawn inside a fence, one tree
## in a mulch ring, one flower bed, a mower and a chase camera.

const YARD_SIZE := 20.0
const TREE_AT := Vector2(13.0, 7.0)
const BED_AT := Vector2(5.0, 12.5)
const BED_RADIUS := 1.0
const WIN_PERCENT := 99.0
const MPS_TO_MPH := 2.237

var lawn: LawnGrid
var view: LawnView
var mower: Mower
var run: RunState
var hud: Hud


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_build_environment()

	lawn = LawnGrid.new()
	lawn.name = "LawnGrid"
	add_child(lawn)
	lawn.reset()
	lawn.block_circle(TREE_AT.x, TREE_AT.y, 0.9)
	lawn.block_circle(BED_AT.x, BED_AT.y, BED_RADIUS + 0.2)
	lawn.seal_layout()

	view = LawnView.new()
	view.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(view)
	view.build(lawn)

	_build_fence()
	_build_tree(Vector3(TREE_AT.x, 0, TREE_AT.y), 1.0, true)
	_build_bed()
	_build_scenery()

	mower = Mower.new()
	mower.name = "Mower"
	mower.process_mode = Node.PROCESS_MODE_PAUSABLE
	mower.lawn = lawn
	add_child(mower)
	mower.global_position = Vector3(2.0, 0.05, 16.5)

	var camera := ChaseCamera.new()
	camera.process_mode = Node.PROCESS_MODE_PAUSABLE
	camera.target = mower
	add_child(camera)

	run = RunState.new()
	add_child(run)
	hud = Hud.new()
	add_child(hud)
	run.finished_run.connect(_on_finished)


func _process(_delta: float) -> void:
	var percent := lawn.percent_cut()
	if percent >= WIN_PERCENT and not run.finished:
		run.finish_run()
	hud.update_play(percent, mower.measured_speed * MPS_TO_MPH, mower.blades_on, run.elapsed, run.best)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("pause"):
		run.toggle_pause()
		hud.show_paused(get_tree().paused)
	elif event.is_action_pressed("restart"):
		get_tree().paused = false
		get_tree().reload_current_scene()
	elif event.is_action_pressed("toggle_blades") and not get_tree().paused:
		mower.toggle_blades()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and hud and get_tree().paused and not run.finished:
		hud.show_paused(true)


func _on_finished(time: float, is_record: bool) -> void:
	mower.set_physics_process(false)
	hud.show_finished(time, run.best, is_record, run.storage_ok)


func _setup_input() -> void:
	var keys := {
		"accelerate": [KEY_W, KEY_UP],
		"reverse": [KEY_S, KEY_DOWN],
		"steer_left": [KEY_A, KEY_LEFT],
		"steer_right": [KEY_D, KEY_RIGHT],
		"toggle_blades": [KEY_B],
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
	var floor_body := StaticBody3D.new()
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
		var body := StaticBody3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.25
		shape.height = 2.0
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		body.position = at + Vector3(0, 1.0, 0)
		add_child(body)


func _build_bed() -> void:
	var at := Vector3(BED_AT.x, 0, BED_AT.y)
	var soil := CylinderMesh.new()
	soil.top_radius = BED_RADIUS
	soil.bottom_radius = BED_RADIUS + 0.05
	soil.height = 0.16
	soil.material = _material(Color(0.30, 0.21, 0.14), 1.0)
	var bed := MeshInstance3D.new()
	bed.mesh = soil
	bed.position = at + Vector3(0, 0.08, 0)
	add_child(bed)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var colors := [Color(0.85, 0.35, 0.55), Color(0.95, 0.8, 0.3), Color(0.9, 0.9, 0.95)]
	for i in 9:
		var angle := i * TAU / 9.0 + rng.randf() * 0.3
		var r := rng.randf_range(0.2, BED_RADIUS - 0.25)
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
	shape.radius = BED_RADIUS
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

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
var sounds: Sounds
var floor_body: StaticBody3D
## Everything that never moves; baked into a few meshes once it is built.
var scenery: Node3D
var sun: DirectionalLight3D
var settings: Settings
var touch: TouchControls
var on_mower := true
var auto_highlighted := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_build_environment()
	settings = Settings.new()
	settings.load_settings()
	apply_quality(settings.quality)
	AudioServer.set_bus_mute(0, settings.muted)

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

	scenery = Node3D.new()
	scenery.name = "Scenery"
	add_child(scenery)
	_build_fence()
	for tree in TREES:
		_build_tree(Vector3(tree.x, 0, tree.y), 1.0, true)
	for bed in BEDS:
		_build_bed(Vector3(bed.x, 0, bed.y), bed.z)
	_build_scenery()
	Models.bake(scenery)

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
	hud.quality_name = Settings.LABELS[settings.quality]
	touch = TouchControls.new()
	add_child(touch)
	if DisplayServer.is_touchscreen_available():
		show_touch_controls()
	hud.set_minimap(view.texture)
	sounds = Sounds.new()
	sounds.name = "Sounds"
	sounds.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(sounds)
	run.finished_run.connect(_on_finished)
	hud.say("Mow the open lawn, then %s to hop off and trim the edges." % ("tap Hop" if touch.visible else "press Space"), 5.0)


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
	var heading := -mower.global_rotation.y
	hud.update_minimap(map_point(mower.global_position), heading,
		Vector2(-1, -1) if on_mower else map_point(walker.global_position))
	var top_speed := mower.max_speed if on_mower else walker.walk_speed
	var cutting := mower.clippings.emitting or walker.clippings.emitting
	sounds.update(on_mower, clampf(speed / top_speed, 0.0, 1.0), mower.blades_on, cutting, not run.finished)


## Where a spot in the yard falls on the minimap, as fractions across it.
func map_point(at: Vector3) -> Vector2:
	return Vector2(clampf(at.x / YARD_SIZE, 0.0, 1.0), clampf(at.z / YARD_SIZE, 0.0, 1.0))


## On-screen buttons replace the keyboard list on phones and tablets.
func show_touch_controls() -> void:
	touch.visible = true
	hud.use_touch()


func _input(event: InputEvent) -> void:
	# A touch screen we did not detect up front still gets the buttons.
	if event is InputEventScreenTouch and not touch.visible:
		show_touch_controls()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("mute"):
		settings.muted = Sounds.toggle_mute()
		settings.save()
		hud.say("Sound off" if settings.muted else "Sound on", 1.5)
	elif event.is_action_pressed("quality"):
		apply_quality(settings.next_quality())
		settings.save()
		hud.say("Graphics quality: %s" % Settings.LABELS[settings.quality], 1.5)
	elif event.is_action_pressed("stats"):
		hud.toggle_stats()
	elif event.is_action_pressed("pause"):
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
	sounds.chime()


## Low: no shadows and a smaller 3D render, scaled up. Medium: shadows.
## High: sharper shadows that reach further, and smoothed edges.
func apply_quality(level: String) -> void:
	var viewport := get_viewport()
	sun.shadow_enabled = level != "low"
	sun.directional_shadow_max_distance = 40.0 if level == "high" else 28.0
	# Each shadow split redraws the scene, so Medium uses two instead of four.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if level == "high" else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	RenderingServer.directional_shadow_atlas_set_size(4096 if level == "high" else 2048, true)
	viewport.msaa_3d = Viewport.MSAA_2X if level == "high" else Viewport.MSAA_DISABLED
	viewport.scaling_3d_scale = 0.75 if level == "low" else 1.0
	if hud:
		hud.quality_name = Settings.LABELS[level]


func _setup_input() -> void:
	var keys := {
		"accelerate": [KEY_W, KEY_UP],
		"reverse": [KEY_S, KEY_DOWN],
		"steer_left": [KEY_A, KEY_LEFT],
		"steer_right": [KEY_D, KEY_RIGHT],
		"toggle_blades": [KEY_B],
		"hop": [KEY_SPACE],
		"highlight": [KEY_H],
		"mute": [KEY_M],
		"quality": [KEY_Q],
		"stats": [KEY_F3],
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

	sun = DirectionalLight3D.new()
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
	var post_wood := _material(Color(0.45, 0.31, 0.2), 0.9)
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
		scenery.add_child(body)
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
		# Posts every few metres and two rails on the outside of the pickets.
		var outward := (at - Vector3(YARD_SIZE / 2.0, 0, YARD_SIZE / 2.0)).normalized() * 0.07
		var axis := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
		var posts := int(length / 2.5)
		for i in posts + 1:
			var post_at := axis * (-length / 2.0 + i * length / posts) + outward
			Models.add_box(body, Vector3(0.1, height + 0.15, 0.1), post_at + Vector3(0, 0.07, 0), post_wood)
			Models.add_box(body, Vector3(0.14, 0.04, 0.14), post_at + Vector3(0, height / 2.0 + 0.16, 0), post_wood)
		for rail_y in [-0.3, 0.38]:
			var rail_size := Vector3(length, 0.08, 0.04) if along_x else Vector3(0.04, 0.08, length)
			Models.add_box(body, rail_size, outward * 0.6 + Vector3(0, rail_y, 0), post_wood)


## A round leafy tree, or a pine when `pine` is set. Trees inside the yard
## get a stone ring with mulch and a collider.
func _build_tree(at: Vector3, scale_factor: float, collide: bool, pine := false) -> void:
	var bark := _material(Color(0.36, 0.25, 0.17), 1.0)
	if pine:
		Models.add_cylinder(scenery, 0.18 * scale_factor, 1.4 * scale_factor, at + Vector3(0, 0.7, 0) * scale_factor, bark)
		var needles := _material(Color(0.12, 0.30, 0.15), 1.0)
		for layer in 4:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = (1.6 - layer * 0.32) * scale_factor
			cone.height = 1.6 * scale_factor
			cone.radial_segments = 12
			cone.rings = 1
			cone.material = needles
			Models.add_mesh(scenery, cone, at + Vector3(0, 1.6 + layer * 0.85, 0) * scale_factor)
	else:
		var trunk_mesh := CylinderMesh.new()
		trunk_mesh.top_radius = 0.18 * scale_factor
		trunk_mesh.bottom_radius = 0.25 * scale_factor
		trunk_mesh.height = 2.4 * scale_factor
		trunk_mesh.material = bark
		Models.add_mesh(scenery, trunk_mesh, at + Vector3(0, trunk_mesh.height / 2.0, 0))
		var shade := 0.04 * sin(at.x * 1.7 + at.z)
		var leaves := _material(Color(0.20 + shade, 0.42 + shade, 0.16), 1.0)
		for blob in [[Vector3(0, 3.0, 0), 1.5], [Vector3(0.8, 2.6, 0.3), 1.0], [Vector3(-0.7, 2.7, -0.4), 1.1], [Vector3(0.1, 3.7, 0.2), 1.0]]:
			Models.add_sphere(scenery, blob[1] * scale_factor, at + blob[0] * scale_factor, leaves)
	if collide:
		var ring := CylinderMesh.new()
		ring.top_radius = RING_RADIUS
		ring.bottom_radius = RING_RADIUS + 0.03
		ring.height = 0.2
		ring.material = _material(Color(0.42, 0.40, 0.38), 0.9)
		var ring_instance := MeshInstance3D.new()
		ring_instance.mesh = ring
		ring_instance.position = at + Vector3(0, 0.1, 0)
		scenery.add_child(ring_instance)
		var mulch := CylinderMesh.new()
		mulch.top_radius = RING_RADIUS - 0.06
		mulch.bottom_radius = RING_RADIUS - 0.06
		mulch.height = 0.02
		mulch.material = _material(Color(0.30, 0.20, 0.13), 1.0)
		var mulch_instance := MeshInstance3D.new()
		mulch_instance.mesh = mulch
		mulch_instance.position = at + Vector3(0, 0.205, 0)
		scenery.add_child(mulch_instance)
		var body := StaticBody3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = RING_RADIUS
		shape.height = 2.0
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		body.position = at + Vector3(0, 1.0, 0)
		scenery.add_child(body)


func _build_bed(at: Vector3, radius: float) -> void:
	var soil := CylinderMesh.new()
	soil.top_radius = radius
	soil.bottom_radius = radius + 0.05
	soil.height = 0.16
	soil.material = _material(Color(0.30, 0.21, 0.14), 1.0)
	var bed := MeshInstance3D.new()
	bed.mesh = soil
	bed.position = at + Vector3(0, 0.08, 0)
	scenery.add_child(bed)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(at.x * 31.0 + at.z)
	# Edging stones around the rim.
	var stone := SphereMesh.new()
	stone.radius = 0.11
	stone.height = 0.12
	stone.radial_segments = 8
	stone.rings = 4
	stone.material = _material(Color(0.5, 0.48, 0.45), 0.9)
	var stones := MultiMesh.new()
	stones.transform_format = MultiMesh.TRANSFORM_3D
	stones.mesh = stone
	stones.instance_count = int(TAU * radius / 0.2)
	for i in stones.instance_count:
		var angle := i * TAU / stones.instance_count
		var size := rng.randf_range(0.85, 1.15)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(size, size, size))
		stones.set_instance_transform(i, Transform3D(basis, Vector3(cos(angle), 0, sin(angle)) * (radius - 0.04) + Vector3(0, 0.12, 0)))
	var stone_instance := MultiMeshInstance3D.new()
	stone_instance.multimesh = stones
	stone_instance.position = at
	scenery.add_child(stone_instance)
	# Shrubs in the middle, flowers on stems around them.
	var leaf := _material(Color(0.18, 0.38, 0.14), 1.0)
	var stem := _material(Color(0.2, 0.45, 0.15), 1.0)
	var colors := [Color(0.85, 0.3, 0.5), Color(0.95, 0.8, 0.25), Color(0.92, 0.92, 0.96), Color(0.6, 0.35, 0.85)]
	for i in 3:
		var angle := i * TAU / 3.0 + rng.randf()
		Models.add_sphere(scenery, rng.randf_range(0.25, 0.32), at + Vector3(cos(angle), 0, sin(angle)) * radius * 0.3 + Vector3(0, 0.28, 0), leaf, 0.8)
	var flowers := int(radius * 14.0)
	for i in flowers:
		var angle := i * TAU / flowers + rng.randf() * 0.2
		var r := rng.randf_range(radius * 0.55, radius - 0.18)
		var base := at + Vector3(cos(angle) * r, 0.16, sin(angle) * r)
		var tall := rng.randf_range(0.18, 0.32)
		Models.add_rod(scenery, base, base + Vector3(0, tall, 0), 0.01, stem, 4)
		Models.add_sphere(scenery, 0.06, base + Vector3(0, tall + 0.02, 0), _material(colors[i % colors.size()], 0.8), 0.6)
	var body := StaticBody3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 0.6
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	body.position = at + Vector3(0, 0.3, 0)
	scenery.add_child(body)


func _build_scenery() -> void:
	# The house behind the far fence, neighbours on either side, and trees.
	_build_house(Vector3(8, 0, -6), Vector3(12, 4.6, 7), 0.0, Color(0.80, 0.77, 0.70), Color(0.30, 0.28, 0.28), true)
	_build_house(Vector3(-11, 0, 9), Vector3(9, 4.0, 7), 90.0, Color(0.62, 0.70, 0.76), Color(0.36, 0.22, 0.18), false)
	_build_house(Vector3(31, 0, 11), Vector3(9, 4.2, 7), -90.0, Color(0.82, 0.74, 0.58), Color(0.25, 0.27, 0.32), false)
	var spots := [Vector3(-4, 0, 1), Vector3(-5, 0, 18), Vector3(24.5, 0, 2), Vector3(24, 0, 19), Vector3(18, 0, 26), Vector3(3, 0, 26), Vector3(10, 0, 30)]
	for i in spots.size():
		_build_tree(spots[i], 1.3 if i % 2 else 1.1, false, i % 2 == 0)


## A house facing local +Z: walls, roof with overhang, chimney, windows,
## a door with a step, and a garage door on the main house.
func _build_house(at: Vector3, size: Vector3, turn: float, wall_color: Color, roof_color: Color, garage: bool) -> void:
	var house := Node3D.new()
	house.position = at
	house.rotation_degrees.y = turn
	scenery.add_child(house)
	var wall := _material(wall_color, 0.9)
	var trim := _material(Color(0.95, 0.95, 0.93), 0.7)
	var glass := Models.glow(Color(0.45, 0.6, 0.72), 0.25)
	var front := size.z / 2.0
	Models.add_box(house, size, Vector3(0, size.y / 2.0, 0), wall)
	Models.add_box(house, Vector3(size.x + 0.1, 0.3, size.z + 0.1), Vector3(0, 0.15, 0), _material(Color(0.45, 0.44, 0.42), 0.9)) # foundation
	var roof := PrismMesh.new()
	roof.size = Vector3(size.x + 1.0, size.y * 0.5, size.z + 1.2)
	roof.material = _material(roof_color, 0.8)
	Models.add_mesh(house, roof, Vector3(0, size.y + size.y * 0.25, 0))
	Models.add_box(house, Vector3(0.8, 2.0, 0.8), Vector3(size.x * 0.3, size.y + 1.4, -size.z * 0.15), _material(Color(0.55, 0.3, 0.25), 0.9)) # chimney
	Models.add_box(house, Vector3(size.x + 0.2, 0.15, size.z + 0.2), Vector3(0, size.y, 0), trim) # eave trim
	# Door near one end, garage at the other, windows between.
	var door_x := -size.x * 0.3 if garage else 0.0
	Models.add_box(house, Vector3(1.1, 2.2, 0.08), Vector3(door_x, 1.1 + 0.3, front + 0.02), _material(Color(0.35, 0.18, 0.12), 0.7))
	Models.add_box(house, Vector3(1.6, 0.2, 0.8), Vector3(door_x, 0.1, front + 0.4), _material(Color(0.55, 0.54, 0.52), 0.9)) # step
	var windows: Array = [-size.x * 0.32, size.x * 0.32] if not garage else [-size.x * 0.08, size.x * 0.12]
	if garage:
		Models.add_box(house, Vector3(3.2, 2.5, 0.08), Vector3(size.x * 0.33, 1.25 + 0.3, front + 0.02), trim)
		for row in 4:
			Models.add_box(house, Vector3(3.0, 0.03, 0.1), Vector3(size.x * 0.33, 0.9 + row * 0.6, front + 0.04), _material(Color(0.8, 0.8, 0.78), 0.7))
	for x in windows:
		Models.add_box(house, Vector3(1.4, 1.3, 0.08), Vector3(x, 2.1, front + 0.02), trim)
		Models.add_box(house, Vector3(1.2, 1.1, 0.1), Vector3(x, 2.1, front + 0.03), glass)
		Models.add_box(house, Vector3(0.05, 1.1, 0.12), Vector3(x, 2.1, front + 0.04), trim)
		Models.add_box(house, Vector3(1.2, 0.05, 0.12), Vector3(x, 2.1, front + 0.04), trim)
	# Back and side windows so the neighbours look lived in from any angle.
	for x in [-size.x * 0.25, size.x * 0.25]:
		Models.add_box(house, Vector3(1.2, 1.1, 0.1), Vector3(x, 2.1, -front - 0.03), glass)
	for side in [-1, 1]:
		Models.add_box(house, Vector3(0.1, 1.1, 1.2), Vector3(side * (size.x / 2.0 + 0.03), 2.1, 0), glass)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	return Models.material(color, roughness)

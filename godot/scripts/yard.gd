extends Node3D
## The yard: a 30 x 36 m lot inside a wood privacy fence. The house stands
## along the left side with a porch facing the lawn, so the grass wraps
## round it as a back yard, a side yard and a front yard. Trees sit in
## stone rings, shrubs and flowers fill edged beds, and a pergola shades a
## patio in the back corner. Ride the mower for the open lawn, then hop off
## and use the weed eater along the fence and around everything else.

## Lot size in metres: x across, z from the back fence to the front.
const LOT := Vector2(30.0, 36.0)
## Trees: x, z. Each sits in a stone ring the mower cannot drive over.
const TREES := [Vector2(20.0, 8.0), Vector2(24.0, 28.0), Vector2(6.0, 31.0)]
const RING_RADIUS := 0.6
## Round flower beds: x, z, radius.
const BEDS := [Vector3(25.0, 17.5, 1.3), Vector3(14.0, 6.0, 1.0)]
## The house (centre, size along x and z) and its porch.
const HOUSE_CENTER := Vector2(5.0, 19.0)
const HOUSE_SIZE := Vector2(10.0, 12.0)
const PORCH := Rect2(10.0, 15.8, 4.0, 6.4)
## Edged shrub beds: along the house either side of the porch, the back
## fence and the right fence.
const SHRUB_BEDS := [Rect2(10.0, 13.0, 1.5, 2.8), Rect2(10.0, 22.2, 1.5, 2.8),
	Rect2(3.0, 0.0, 14.0, 1.4), Rect2(28.6, 10.0, 1.4, 14.0)]
## Paver patio under the pergola, in the back right corner.
const PATIO := Rect2(21.5, 0.0, 8.5, 7.5)
const START := Vector3(16.0, 0.05, 30.5)
## The red gas can on the landing by the porch steps (x, z).
const GAS_CAN := Vector2(13.5, 16.6)
const REFUEL_DISTANCE := 2.5
## Share of a full tank poured in per second at the gas can.
const REFUEL_RATE := 0.35
const LOW_FUEL := 0.2
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
var environment: Environment
## True in the desktop builds, which use Godot's Forward+ renderer and can
## afford ambient occlusion, bounce light, glow and softer shadows. The web
## build uses the Compatibility renderer and skips them, as does a desktop
## that had to fall back to it, and the headless test runner (no GPU device).
var rich_graphics := RenderingServer.get_current_rendering_method() == "forward_plus" \
	and RenderingServer.get_rendering_device() != null
var settings: Settings
var touch: TouchControls
var on_mower := true
var auto_highlighted := false
var objectives: Objectives
## Which fuel warning was last shown: 0 none, 1 low, 2 empty.
var fuel_warning := 0
var refuelling := false


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
	lawn.columns = int(LOT.x / lawn.cell_size)
	lawn.rows = int(LOT.y / lawn.cell_size)
	add_child(lawn)
	lawn.reset()
	for tree in TREES:
		lawn.block_circle(tree.x, tree.y, RING_RADIUS)
	for bed in BEDS:
		lawn.block_circle(bed.x, bed.y, bed.z)
	lawn.block_rect(Rect2(HOUSE_CENTER - HOUSE_SIZE / 2.0, HOUSE_SIZE))
	lawn.block_rect(PORCH)
	lawn.block_rect(PATIO)
	for bed in SHRUB_BEDS:
		lawn.block_rect(bed)
	lawn.seal_layout()
	objectives = Objectives.new()
	objectives.setup(lawn, HOUSE_CENTER.y - HOUSE_SIZE.y / 2.0, HOUSE_CENTER.y + HOUSE_SIZE.y / 2.0)

	view = LawnView.new()
	view.blades = LawnView.RICH_BLADES if rich_graphics else LawnView.BLADES
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
	for bed in SHRUB_BEDS:
		_build_shrub_bed(bed)
	_build_pergola(PATIO)
	_build_gas_can(Vector3(GAS_CAN.x, 0, GAS_CAN.y))
	_build_scenery()
	Models.bake(scenery)

	mower = Mower.new()
	mower.name = "Mower"
	mower.process_mode = Node.PROCESS_MODE_PAUSABLE
	mower.lawn = lawn
	add_child(mower)
	mower.global_position = START

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
	hud.set_minimap(view.texture, Rect2((HOUSE_CENTER - HOUSE_SIZE / 2.0) / LOT, HOUSE_SIZE / LOT))
	if not Input.get_connected_joypads().is_empty():
		hud.use_gamepad(true)
	sounds = Sounds.new()
	sounds.name = "Sounds"
	sounds.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(sounds)
	run.finished_run.connect(_on_finished)
	var hop := "tap Hop" if touch.visible else ("press Y" if hud.gamepad else "press Space")
	hud.say("Mow the open lawn, then %s to hop off and trim the edges." % hop, 5.0)


func _process(delta: float) -> void:
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
	hud.update_objectives(objectives.states())
	_update_fuel(delta)
	var heading := -mower.global_rotation.y
	hud.update_minimap(map_point(mower.global_position), heading,
		Vector2(-1, -1) if on_mower else map_point(walker.global_position))
	var top_speed := mower.max_speed if on_mower else walker.walk_speed
	var cutting := mower.clippings.emitting or walker.clippings.emitting
	sounds.update(on_mower, clampf(speed / top_speed, 0.0, 1.0), mower.blades_on, cutting, not run.finished)


## Burns and refills fuel and warns when the tank runs low or dry. Driving
## the mower, or walking the weed eater, up to the gas can fills it up.
func _update_fuel(delta: float) -> void:
	var can := Vector3(GAS_CAN.x, 0, GAS_CAN.y)
	var helper: Node3D = mower if on_mower else walker
	var near := Vector2(helper.global_position.x - can.x, helper.global_position.z - can.z).length() < REFUEL_DISTANCE
	if near and mower.fuel < 1.0 and not run.finished:
		mower.refuel(REFUEL_RATE * delta)
		if not refuelling:
			hud.say("Filling up the tank...", 2.0)
		refuelling = true
		if mower.fuel >= 1.0:
			hud.say("Tank full!", 1.5)
	else:
		refuelling = false
	if mower.fuel > 0.5:
		fuel_warning = 0
	elif mower.fuel <= 0.0 and fuel_warning < 2:
		fuel_warning = 2
		hud.say("Out of gas! Crawl over to the red gas can by the porch steps.", 5.0)
	elif mower.fuel < LOW_FUEL and fuel_warning < 1:
		fuel_warning = 1
		hud.say("Fuel is low. Top up at the red gas can by the porch steps.", 4.0)
	hud.update_fuel(mower.fuel)


## Where a spot in the yard falls on the minimap, as fractions across it.
func map_point(at: Vector3) -> Vector2:
	return Vector2(clampf(at.x / LOT.x, 0.0, 1.0), clampf(at.z / LOT.y, 0.0, 1.0))


## On-screen buttons replace the keyboard list on phones and tablets.
func show_touch_controls() -> void:
	touch.visible = true
	hud.use_touch()


func _input(event: InputEvent) -> void:
	# A touch screen we did not detect up front still gets the buttons.
	if event is InputEventScreenTouch and not touch.visible:
		show_touch_controls()
	# The prompts follow whichever was used last: gamepad or keyboard.
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		hud.use_gamepad(true)
	elif event is InputEventKey:
		hud.use_gamepad(false)


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
	camera.follow(mower, 3.8)
	on_mower = true
	hud.say("Back on the mower.")
	return true


func _walker_fits(spot: Vector3) -> bool:
	if spot.x < 0.3 or spot.z < 0.3 or spot.x > LOT.x - 0.3 or spot.z > LOT.y - 0.3:
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
	# Pause here as well as in RunState: the yard hears about lost focus
	# before its children do, so the screen must not wait for them.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and hud and not run.finished:
		get_tree().paused = true
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
	if rich_graphics:
		_apply_rich_effects(level)
	if hud:
		hud.quality_name = Settings.LABELS[level]


## Desktop only. Medium adds ambient occlusion (soft contact shadows under
## the mower, trees and fence); High adds bounce light, a gentle glow and
## shadows that soften with distance from what casts them.
func _apply_rich_effects(level: String) -> void:
	# Forward+ lights in linear space and comes out darker than the web build.
	environment.tonemap_exposure = 1.25
	environment.ssao_enabled = level != "low"
	environment.ssao_radius = 1.2
	environment.ssao_intensity = 1.6
	environment.ssil_enabled = level == "high"
	environment.ssil_intensity = 0.8
	environment.glow_enabled = level == "high"
	environment.glow_intensity = 0.25
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 1.2
	sun.light_angular_distance = 0.6 if level == "high" else 0.0


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
	# Gamepad: triggers drive, the left stick steers, face buttons for the rest.
	var pad_axes := {
		"accelerate": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
		"reverse": [JOY_AXIS_TRIGGER_LEFT, 1.0],
		"steer_left": [JOY_AXIS_LEFT_X, -1.0],
		"steer_right": [JOY_AXIS_LEFT_X, 1.0],
	}
	var pad_buttons := {
		"toggle_blades": JOY_BUTTON_X,
		"hop": JOY_BUTTON_Y,
		"highlight": JOY_BUTTON_RIGHT_SHOULDER,
		"pause": JOY_BUTTON_START,
		"restart": JOY_BUTTON_BACK,
	}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.2)
		for key in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
		if pad_axes.has(action):
			var motion := InputEventJoypadMotion.new()
			motion.axis = pad_axes[action][0]
			motion.axis_value = pad_axes[action][1]
			InputMap.action_add_event(action, motion)
		if pad_buttons.has(action):
			var button := InputEventJoypadButton.new()
			button.button_index = pad_buttons[action]
			InputMap.action_add_event(action, button)


func _build_environment() -> void:
	# Bright summer afternoon: deep blue sky with clouds, warm low sun, a little haze so
	# the distance fades instead of ending in a hard line.
	var sky_material := ShaderMaterial.new()
	sky_material.shader = load("res://shaders/sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	environment = env
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.fog_enabled = true
	env.fog_light_color = Color(0.66, 0.78, 0.90)
	env.fog_density = 0.0015
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.06
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.light_energy = 1.35
	sun.light_color = Color(1.0, 0.93, 0.80)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)

	# Flat ground: a collider under the yard and a darker lawn beyond the fence.
	floor_body = StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(floor_shape)
	add_child(floor_body)
	var outer := PlaneMesh.new()
	outer.size = Vector2(200, 200)
	outer.material = Models.textured("grass", Color(0.62, 0.68, 0.55), 1.6, 1.0)
	var outer_instance := MeshInstance3D.new()
	outer_instance.mesh = outer
	outer_instance.position = Vector3(LOT.x / 2.0, -0.02, LOT.y / 2.0)
	add_child(outer_instance)


## A 1.8 m wood privacy fence: tight vertical boards with a cap rail, and
## posts and two rails on the yard side.
func _build_fence() -> void:
	var boards := Models.textured("wood", Color.WHITE, 1.0)
	var frame := Models.textured("wood", Color(0.78, 0.72, 0.68), 1.0)
	var height := 1.8
	var walls := [
		[Vector3(LOT.x / 2.0, 0, -0.1), Vector3(LOT.x + 0.4, height, 0.2)],
		[Vector3(LOT.x / 2.0, 0, LOT.y + 0.1), Vector3(LOT.x + 0.4, height, 0.2)],
		[Vector3(-0.1, 0, LOT.y / 2.0), Vector3(0.2, height, LOT.y)],
		[Vector3(LOT.x + 0.1, 0, LOT.y / 2.0), Vector3(0.2, height, LOT.y)],
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
		var length := maxf(size.x, size.z)
		var along_x := size.x > size.z
		# Boards every 15 cm, each slightly different in height.
		var count := int(length / 0.15)
		var board := BoxMesh.new()
		board.size = Vector3(0.145, height, 0.025) if along_x else Vector3(0.025, height, 0.145)
		board.material = boards
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = board
		mm.instance_count = count
		for i in count:
			var offset := -length / 2.0 + (i + 0.5) * length / count
			var local := Vector3(offset, 0, 0) if along_x else Vector3(0, 0, offset)
			var stretch := 1.0 + 0.012 * ((i * 7) % 3)
			mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(1, stretch, 1)), local + Vector3(0, height * (stretch - 1.0) / 2.0, 0)))
		var fence_boards := MultiMeshInstance3D.new()
		fence_boards.multimesh = mm
		body.add_child(fence_boards)
		# Cap rail on top; posts every 2.4 m and two rails on the yard side.
		var inward := (Vector3(LOT.x / 2.0, 0, LOT.y / 2.0) - at)
		inward = Vector3(signf(inward.x), 0, 0) if not along_x else Vector3(0, 0, signf(inward.z))
		var axis := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
		var cap := Vector3(length, 0.05, 0.12) if along_x else Vector3(0.12, 0.05, length)
		Models.add_box(body, cap, Vector3(0, height / 2.0 + 0.03, 0), frame)
		var posts := int(length / 2.4)
		for i in posts + 1:
			var post_at := axis * (-length / 2.0 + i * length / posts) + inward * 0.07
			Models.add_box(body, Vector3(0.1, height + 0.08, 0.1), post_at + Vector3(0, 0.04, 0), frame)
		for rail_y in [-0.6, 0.6]:
			var rail_size := Vector3(length, 0.09, 0.04) if along_x else Vector3(0.04, 0.09, length)
			Models.add_box(body, rail_size, inward * 0.04 + Vector3(0, rail_y, 0), frame)


## A round leafy tree, or a pine when `pine` is set. Trees inside the yard
## get a stone ring with mulch and a collider.
func _build_tree(at: Vector3, scale_factor: float, collide: bool, pine := false) -> void:
	var bark := Models.textured("wood", Color(0.5, 0.45, 0.42), 0.8, 1.0)
	if pine:
		Models.add_cylinder(scenery, 0.18 * scale_factor, 1.4 * scale_factor, at + Vector3(0, 0.7, 0) * scale_factor, bark)
		var needles := Models.textured("leaves", Color(0.55, 0.8, 0.75), 1.2, 1.0)
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
		var shade := 0.04 * roundf(sin(at.x * 1.7 + at.z)) # three shades, so trees share materials
		var leaves := Models.textured("leaves", Color(1.0 + shade, 1.0 + shade, 1.0), 1.5, 1.0)
		for blob in [[Vector3(0, 3.0, 0), 1.5], [Vector3(0.8, 2.6, 0.3), 1.0], [Vector3(-0.7, 2.7, -0.4), 1.1], [Vector3(0.1, 3.7, 0.2), 1.0]]:
			Models.add_sphere(scenery, blob[1] * scale_factor, at + blob[0] * scale_factor, leaves)
	if collide:
		var ring := CylinderMesh.new()
		ring.top_radius = RING_RADIUS
		ring.bottom_radius = RING_RADIUS + 0.03
		ring.height = 0.2
		ring.material = Models.textured("stone", Color.WHITE, 0.8)
		var ring_instance := MeshInstance3D.new()
		ring_instance.mesh = ring
		ring_instance.position = at + Vector3(0, 0.1, 0)
		scenery.add_child(ring_instance)
		var mulch := CylinderMesh.new()
		mulch.top_radius = RING_RADIUS - 0.06
		mulch.bottom_radius = RING_RADIUS - 0.06
		mulch.height = 0.02
		mulch.material = Models.textured("mulch", Color.WHITE, 0.8, 1.0)
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
	soil.material = Models.textured("mulch", Color.WHITE, 0.8, 1.0)
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
	stone.material = Models.textured("stone", Color.WHITE, 0.5)
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
	var leaf := Models.textured("leaves", Color.WHITE, 0.6, 1.0)
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
	# The family house inside the lot, its porch facing the lawn.
	_build_house(Vector3(HOUSE_CENTER.x, 0, HOUSE_CENTER.y), Vector3(HOUSE_SIZE.y, 5.2, HOUSE_SIZE.x), 90.0,
		Color(0.90, 0.89, 0.86), Color(0.24, 0.24, 0.26), false, true)
	_add_block(Rect2(HOUSE_CENTER - HOUSE_SIZE / 2.0, HOUSE_SIZE), 5.0)
	_add_block(Rect2(PORCH.position, Vector2(2.8, PORCH.size.y)), 0.6) # deck and steps
	# Neighbours over the back and side fences and across the street. They
	# share three colour schemes so the baked scenery keeps few materials.
	_build_house(Vector3(8, 0, -9), Vector3(12, 4.6, 7), 0.0, Color(0.80, 0.77, 0.70), Color(0.30, 0.28, 0.28), true)
	_build_house(Vector3(24, 0, -10), Vector3(9, 4.2, 7), 0.0, Color(0.62, 0.70, 0.76), Color(0.36, 0.22, 0.18), false)
	_build_house(Vector3(-12, 0, 6), Vector3(9, 4.0, 7), 90.0, Color(0.82, 0.74, 0.58), Color(0.25, 0.27, 0.32), false)
	_build_house(Vector3(41, 0, 20), Vector3(10, 4.4, 7), -90.0, Color(0.80, 0.77, 0.70), Color(0.30, 0.28, 0.28), true)
	_build_house(Vector3(14, 0, 48), Vector3(11, 4.4, 7), 180.0, Color(0.62, 0.70, 0.76), Color(0.36, 0.22, 0.18), true)
	var spots := [Vector3(-4, 0, 22), Vector3(-5, 0, 32), Vector3(35, 0, 4), Vector3(34, 0, 31),
		Vector3(16, 0, -4), Vector3(-3, 0, -3), Vector3(28, 0, 41), Vector3(3, 0, 41), Vector3(34, 0, 12)]
	for i in spots.size():
		_build_tree(spots[i], 1.3 if i % 2 else 1.1, false, i % 3 == 0)
	# A ring of distant trees hides the edge of the world.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 32:
		var angle := i * TAU / 32.0 + rng.randf_range(-0.06, 0.06)
		var distance := rng.randf_range(44.0, 58.0)
		var spot := Vector3(LOT.x / 2.0 + cos(angle) * distance, 0, LOT.y / 2.0 + sin(angle) * distance)
		_build_tree(spot, rng.randf_range(1.7, 2.5), false, rng.randf() < 0.35)


## An invisible box collider over a rectangle of the yard (x, z in metres).
func _add_block(rect: Rect2, height: float) -> void:
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(rect.size.x, height, rect.size.y)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	body.position = Vector3(rect.get_center().x, height / 2.0, rect.get_center().y)
	scenery.add_child(body)


## A rectangular bed of mulch with stone edging, a row of rounded shrubs
## in a few greens, and flowers in front of them.
func _build_shrub_bed(rect: Rect2) -> void:
	var center := Vector3(rect.get_center().x, 0, rect.get_center().y)
	Models.add_box(scenery, Vector3(rect.size.x, 0.12, rect.size.y), center + Vector3(0, 0.06, 0),
		Models.textured("mulch", Color.WHITE, 0.8, 1.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(rect.position.x * 17.0 + rect.position.y * 5.0)
	# Edging stones round the rim.
	var stone := SphereMesh.new()
	stone.radius = 0.12
	stone.height = 0.14
	stone.radial_segments = 8
	stone.rings = 4
	stone.material = Models.textured("stone", Color.WHITE, 0.5)
	var rim := []
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for side in 4:
		var a: Vector2 = corners[side]
		var b: Vector2 = corners[(side + 1) % 4]
		var count := maxi(1, int(a.distance_to(b) / 0.22))
		for i in count:
			rim.append(a.lerp(b, float(i) / count))
	var stones := MultiMesh.new()
	stones.transform_format = MultiMesh.TRANSFORM_3D
	stones.mesh = stone
	stones.instance_count = rim.size()
	for i in rim.size():
		var size := rng.randf_range(0.85, 1.15)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(size, size, size))
		stones.set_instance_transform(i, Transform3D(basis, Vector3(rim[i].x, 0.1, rim[i].y)))
	var stone_instance := MultiMeshInstance3D.new()
	stone_instance.multimesh = stones
	scenery.add_child(stone_instance)
	# Shrubs along the long axis, flowers along the lawn side of them.
	var along_x := rect.size.x >= rect.size.y
	var length := rect.size.x if along_x else rect.size.y
	var depth := rect.size.y if along_x else rect.size.x
	var axis := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	var across := Vector3(0, 0, 1) if along_x else Vector3(1, 0, 0)
	var greens := [Models.textured("leaves", Color.WHITE, 0.6, 1.0),
		Models.textured("leaves", Color(0.8, 0.95, 0.75), 0.6, 1.0),
		Models.textured("leaves", Color(1.1, 1.05, 0.85), 0.6, 1.0)]
	var count := maxi(1, int(length / 0.95))
	for i in count:
		var spot := center + axis * (-length / 2.0 + (i + 0.5) * length / count)
		var radius := minf(rng.randf_range(0.38, 0.5), depth * 0.42)
		var shrub := spot + across * rng.randf_range(-0.1, 0.1) + Vector3(0, 0.12 + radius * 0.75, 0)
		Models.add_sphere(scenery, radius, shrub, greens[i % greens.size()], 0.85)
		Models.add_sphere(scenery, radius * 0.6, shrub + axis * radius * 0.6 + Vector3(0, radius * 0.35, 0), greens[(i + 1) % greens.size()], 0.85)
	var colors := [Color(0.85, 0.3, 0.5), Color(0.95, 0.8, 0.25), Color(0.92, 0.92, 0.96), Color(0.6, 0.35, 0.85)]
	var stem := _material(Color(0.2, 0.45, 0.15), 1.0)
	var flowers := int(length / 0.45)
	for i in flowers:
		for edge in [-1.0, 1.0]:
			var base: Vector3 = center + axis * (-length / 2.0 + (i + 0.5) * length / flowers) + across * edge * (depth / 2.0 - 0.2)
			base.y = 0.12
			var tall := rng.randf_range(0.14, 0.26)
			Models.add_rod(scenery, base, base + Vector3(0, tall, 0), 0.01, stem, 4)
			Models.add_sphere(scenery, 0.06, base + Vector3(0, tall + 0.02, 0), _material(colors[(i + int(edge)) % colors.size()], 0.8), 0.6)
	_add_block(rect, 0.6)


## A paver patio with a wood pergola over it: four posts, two beams and a
## row of rafters, and a table with chairs underneath.
func _build_pergola(rect: Rect2) -> void:
	var center := Vector3(rect.get_center().x, 0, rect.get_center().y)
	Models.add_box(scenery, Vector3(rect.size.x, 0.06, rect.size.y), center + Vector3(0, 0.03, 0),
		Models.textured("pavers", Color.WHITE, 1.5))
	var wood := Models.textured("wood", Color(0.7, 0.55, 0.42), 1.0)
	var inset := Vector2(rect.size.x / 2.0 - 0.8, rect.size.y / 2.0 - 0.8)
	var height := 2.6
	for x in [-1, 1]:
		for z in [-1, 1]:
			var post := center + Vector3(x * inset.x, 0, z * inset.y)
			Models.add_box(scenery, Vector3(0.18, height, 0.18), post + Vector3(0, height / 2.0, 0), wood)
			_add_block(Rect2(post.x - 0.15, post.z - 0.15, 0.3, 0.3), height)
	for z in [-1, 1]:
		Models.add_box(scenery, Vector3(inset.x * 2.0 + 1.0, 0.24, 0.1), center + Vector3(0, height - 0.12, z * inset.y), wood)
	var rafters := int(inset.x * 2.0 / 0.45) + 1
	for i in rafters:
		var x := -inset.x + i * inset.x * 2.0 / (rafters - 1)
		Models.add_box(scenery, Vector3(0.06, 0.16, inset.y * 2.0 + 0.9), center + Vector3(x, height + 0.08, 0), wood)
	# Table and four chairs.
	var dark := _material(Color(0.16, 0.16, 0.17), 0.6)
	Models.add_cylinder(scenery, 0.7, 0.05, center + Vector3(0, 0.74, 0), wood, Vector3.ZERO, 20)
	Models.add_cylinder(scenery, 0.06, 0.72, center + Vector3(0, 0.37, 0), dark)
	for i in 4:
		var angle := i * TAU / 4.0 + 0.4
		var chair := center + Vector3(cos(angle), 0, sin(angle)) * 1.05
		var holder := Node3D.new()
		holder.position = chair
		holder.rotation.y = -angle - PI / 2.0
		scenery.add_child(holder)
		Models.add_box(holder, Vector3(0.45, 0.05, 0.45), Vector3(0, 0.45, 0), wood)
		Models.add_box(holder, Vector3(0.45, 0.45, 0.05), Vector3(0, 0.7, 0.21), wood)
		for leg_x in [-0.19, 0.19]:
			for leg_z in [-0.19, 0.19]:
				Models.add_box(holder, Vector3(0.04, 0.45, 0.04), Vector3(leg_x, 0.22, leg_z), dark)
	_add_block(Rect2(center.x - 1.4, center.z - 1.4, 2.8, 2.8), 1.0)


## A house facing local +Z: sided walls on a stone foundation, a shingled
## roof with overhang, stone chimney, trimmed windows (two rows on a tall
## house) and a door. A garage adds a garage door and driveway; a porch adds
## a covered porch on posts with steps, otherwise the door gets a step and
## a small paver patio.
func _build_house(at: Vector3, size: Vector3, turn: float, wall_color: Color, roof_color: Color, garage: bool, porch := false) -> void:
	var house := Node3D.new()
	house.position = at
	house.rotation_degrees.y = turn
	scenery.add_child(house)
	# Photo siding and shingles, tinted towards each house's own colours.
	# The photos average about 0.81 (siding) and 0.27 (shingles) in brightness.
	var wall := Models.textured("siding_white", _tint(wall_color, 0.81), 2.0)
	var stone := Models.textured("stone", Color.WHITE, 1.2)
	var shingles := Models.textured("shingles", _tint(roof_color, 0.27), 2.0, 0.85)
	var trim := _material(Color(0.95, 0.95, 0.93), 0.7)
	var concrete := Models.textured("concrete", Color.WHITE, 1.5)
	var front := size.z / 2.0
	Models.add_box(house, size, Vector3(0, size.y / 2.0, 0), wall)
	Models.add_box(house, Vector3(size.x + 0.1, 0.3, size.z + 0.1), Vector3(0, 0.15, 0), stone) # foundation
	var roof := PrismMesh.new()
	roof.size = Vector3(size.x + 1.0, size.y * 0.45, size.z + 1.2)
	roof.material = shingles
	Models.add_mesh(house, roof, Vector3(0, size.y + size.y * 0.225, 0))
	Models.add_box(house, Vector3(0.8, 2.0, 0.8), Vector3(size.x * 0.3, size.y + 1.4, -size.z * 0.15), stone) # chimney
	Models.add_box(house, Vector3(size.x + 0.2, 0.15, size.z + 0.2), Vector3(0, size.y, 0), trim) # eave trim
	for corner in [-1, 1]:
		Models.add_box(house, Vector3(0.14, size.y, 0.14), Vector3(corner * size.x / 2.0, size.y / 2.0, front), trim) # corner boards
	# Door near one end with a garage, otherwise in the middle.
	var door_x := -size.x * 0.3 if garage else 0.0
	Models.add_box(house, Vector3(1.3, 2.4, 0.08), Vector3(door_x, 1.2 + 0.3, front + 0.02), trim)
	Models.add_box(house, Vector3(1.1, 2.2, 0.1), Vector3(door_x, 1.1 + 0.3, front + 0.03), _material(Color(0.22, 0.20, 0.19), 0.6))
	if porch:
		_build_porch(house, Vector3(door_x, 0, front), minf(size.x * 0.25, 6.0), roof_color)
	else:
		Models.add_box(house, Vector3(1.6, 0.2, 0.8), Vector3(door_x, 0.1, front + 0.4), concrete) # step
		Models.add_box(house, Vector3(2.4, 0.06, 1.4), Vector3(door_x, 0.03, front + 1.5), Models.textured("pavers", Color.WHITE, 1.5))
	if garage:
		Models.add_box(house, Vector3(3.8, 0.06, 2.3), Vector3(size.x * 0.33, 0.03, front + 1.15), concrete)
		Models.add_box(house, Vector3(3.2, 2.5, 0.08), Vector3(size.x * 0.33, 1.25 + 0.3, front + 0.02), trim)
		for row in 4:
			Models.add_box(house, Vector3(3.0, 0.03, 0.1), Vector3(size.x * 0.33, 0.9 + row * 0.6, front + 0.04), _material(Color(0.8, 0.8, 0.78), 0.7))
	var windows: Array = [-size.x * 0.08, size.x * 0.12] if garage else [-size.x * 0.34, size.x * 0.34]
	for x in windows:
		_add_window(house, Vector3(x, 2.1, front), trim)
	if size.y > 4.5:
		for x in [-size.x * 0.3, 0.0, size.x * 0.3]:
			_add_window(house, Vector3(x, 3.9, front), trim)
	# Back and side windows so the houses look lived in from any angle.
	for x in [-size.x * 0.25, size.x * 0.25]:
		_add_window(house, Vector3(x, 2.1, -front), trim, true)
	for side in [-1, 1]:
		var side_window := Node3D.new()
		side_window.position = Vector3(side * size.x / 2.0, 0, 0)
		side_window.rotation_degrees.y = 90.0 * side
		house.add_child(side_window)
		for z in [-size.z * 0.22, size.z * 0.22]:
			_add_window(side_window, Vector3(z, 2.1, 0), trim)


## A trimmed window with a cross bar, on a wall whose outside faces +Z (or
## -Z when `back` is set) at `at`.
func _add_window(parent: Node3D, at: Vector3, trim: Material, back := false) -> void:
	var out := -1.0 if back else 1.0
	var glass := Models.glow(Color(0.45, 0.6, 0.72), 0.25)
	Models.add_box(parent, Vector3(1.4, 1.4, 0.08), at + Vector3(0, 0, 0.02 * out), trim)
	Models.add_box(parent, Vector3(1.2, 1.2, 0.1), at + Vector3(0, 0, 0.03 * out), glass)
	Models.add_box(parent, Vector3(0.05, 1.2, 0.12), at + Vector3(0, 0, 0.04 * out), trim)
	Models.add_box(parent, Vector3(1.2, 0.05, 0.12), at + Vector3(0, 0, 0.04 * out), trim)
	Models.add_box(parent, Vector3(1.6, 0.08, 0.16), at + Vector3(0, -0.72, 0.06 * out), trim) # sill


## A covered front porch: a raised deck, wood posts on stone bases, a
## shingled roof and two steps down to a paver landing.
func _build_porch(house: Node3D, door: Vector3, half_width: float, roof_color: Color) -> void:
	var deck := Models.textured("wood", Color(0.85, 0.8, 0.75), 1.0)
	var posts := Models.textured("wood", Color(0.7, 0.55, 0.42), 1.0)
	var stone := Models.textured("stone", Color.WHITE, 1.0)
	var depth := 2.4
	var floor_y := 0.35
	Models.add_box(house, Vector3(half_width * 2.0, floor_y, depth), door + Vector3(0, floor_y / 2.0, depth / 2.0), deck)
	for x in [-half_width + 0.2, -1.0, 1.0, half_width - 0.2]:
		var base := door + Vector3(x, floor_y, depth - 0.2)
		Models.add_box(house, Vector3(0.4, 0.6, 0.4), base + Vector3(0, 0.3, 0), stone)
		Models.add_box(house, Vector3(0.2, 2.1, 0.2), base + Vector3(0, 1.65, 0), posts)
	var roof_y := floor_y + 2.75
	Models.add_box(house, Vector3(half_width * 2.0 + 0.4, 0.2, depth + 0.3), door + Vector3(0, roof_y, depth / 2.0), Models.textured("wood", Color(0.9, 0.88, 0.85), 1.0))
	var roof := PrismMesh.new()
	roof.size = Vector3(half_width * 2.0 + 0.6, 0.9, depth + 0.5)
	roof.material = Models.textured("shingles", _tint(roof_color, 0.27), 2.0, 0.85)
	Models.add_mesh(house, roof, door + Vector3(0, roof_y + 0.55, depth / 2.0))
	var concrete := Models.textured("concrete", Color.WHITE, 1.5)
	Models.add_box(house, Vector3(1.8, 0.23, 0.35), door + Vector3(0, 0.115, depth + 0.17), concrete)
	Models.add_box(house, Vector3(1.8, 0.12, 0.35), door + Vector3(0, 0.06, depth + 0.5), concrete)
	Models.add_box(house, Vector3(2.4, 0.06, 1.0), door + Vector3(0, 0.03, depth + 1.1), Models.textured("pavers", Color.WHITE, 1.5))
	# A hanging basket and a potted plant either side of the door.
	var leaves := Models.textured("leaves", Color.WHITE, 0.6, 1.0)
	Models.add_sphere(house, 0.3, door + Vector3(half_width - 0.9, roof_y - 0.6, depth - 0.3), leaves)
	for side in [-1, 1]:
		var pot := door + Vector3(side * 1.0, floor_y, 0.5)
		Models.add_cylinder(house, 0.2, 0.4, pot + Vector3(0, 0.2, 0), _material(Color(0.25, 0.22, 0.2), 0.8))
		Models.add_sphere(house, 0.3, pot + Vector3(0, 0.6, 0), leaves, 0.9)


## A red jerry can with a handle and spout, for topping up the mower.
func _build_gas_can(at: Vector3) -> void:
	var red := _material(Color(0.75, 0.08, 0.06), 0.5)
	var dark := _material(Color(0.25, 0.22, 0.2), 0.8)
	Models.add_box(scenery, Vector3(0.34, 0.42, 0.2), at + Vector3(0, 0.21 + 0.06, 0), red, Vector3(0, 30, 0))
	Models.add_box(scenery, Vector3(0.22, 0.05, 0.05), at + Vector3(0, 0.52, 0), dark, Vector3(0, 30, 0))
	Models.add_rod(scenery, at + Vector3(0.1, 0.48, -0.06), at + Vector3(0.22, 0.6, -0.13), 0.025, dark)
	_add_block(Rect2(at.x - 0.25, at.z - 0.25, 0.5, 0.5), 0.6)


## The tint that turns a photo of average brightness `mean` into `color`.
func _tint(color: Color, mean: float) -> Color:
	return Color(minf(color.r / mean, 1.0), minf(color.g / mean, 1.0), minf(color.b / mean, 1.0))


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	return Models.material(color, roughness)

extends SceneTree
## Headless checks, run in CI before export:
##   godot --headless --path godot --script res://tests/run_tests.gd
## Exits with code 1 if any check fails. The yard tests are ports of the
## original pygame regression tests.

const TEST_SAVE := "user://test_best_times.json"
const TEST_SETTINGS := "user://test_settings.json"

var failures := 0


func _initialize() -> void:
	RunState.default_path = TEST_SAVE
	Settings.default_path = TEST_SETTINGS
	_remove_test_save()
	test_cutting_counts_each_cell_once()
	test_blocked_cells_never_count()
	test_saved_record_rejects_bad_data()
	test_swept_cut_leaves_no_gaps()
	test_back_and_forth_passes_alternate_stripes()
	await test_mower_drives_cuts_and_stays_in_yard()
	await test_pause_freezes_time_and_position()
	await test_hop_off_parks_mower_and_hop_back_on()
	await test_walker_blocked_by_tree_ring_and_parked_mower()
	await test_weed_eater_reaches_fence_strip_mower_cannot()
	await test_finish_once_and_record_survives_reload()
	await test_highlight_and_finish_screens()
	await test_cut_grass_becomes_stubble_and_throws_clippings()
	await test_sounds_follow_what_you_are_doing()
	await test_walk_animation_and_minimap()
	await test_everything_is_built_in_code()
	await test_static_models_are_baked()
	await test_photo_textures_are_local_and_listed()
	await test_quality_presets_and_saved_settings()
	await test_desktop_builds_get_richer_effects()
	await test_touch_controls()
	await test_lost_focus_pauses_with_pause_screen()
	await test_restart_starts_a_fresh_yard()
	await test_blocked_storage_still_finishes()
	await test_resize_keeps_touch_buttons_on_screen()
	_remove_test_save()
	Models._materials.clear()
	print("%s: %d failure(s)" % ["FAILED" if failures else "OK", failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func new_yard() -> Node3D:
	var yard: Node3D = load("res://scenes/yard.tscn").instantiate()
	root.add_child(yard)
	await physics_frame
	return yard


func end_yard(yard: Node3D) -> void:
	for action in ["accelerate", "reverse", "steer_left", "steer_right"]:
		Input.action_release(action)
	paused = false
	yard.queue_free()
	# The audio server lets go of stopped sounds a frame or two later.
	for i in 3:
		await process_frame


func _remove_test_save() -> void:
	for path in [TEST_SAVE, TEST_SETTINGS]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_cutting_counts_each_cell_once() -> void:
	var grid := LawnGrid.new()
	grid.seal_layout()
	var first := grid.cut_at(Vector3(5, 0, 5), 0.6, LawnGrid.STRIPE_A)
	var again := grid.cut_at(Vector3(5, 0, 5), 0.6, LawnGrid.STRIPE_B)
	check(first > 0, "cutting tall grass cuts cells")
	check(again == 0, "cutting the same spot twice adds nothing")
	check(grid.cut_count == first, "cut_count matches cells cut")
	check(grid.cell(20, 20) == LawnGrid.STRIPE_A, "first pass sets the stripe")
	grid.free()


func test_blocked_cells_never_count() -> void:
	var grid := LawnGrid.new()
	grid.block_circle(5, 5, 1.0)
	grid.seal_layout()
	check(grid.total < grid.columns * grid.rows, "blocked cells leave the total")
	check(grid.cut_at(Vector3(5, 0, 5), 0.5, LawnGrid.STRIPE_A) == 0, "blocked cells are never cut")
	for z in grid.rows:
		for x in grid.columns:
			grid.cut_at(Vector3((x + 0.5) * grid.cell_size, 0, (z + 0.5) * grid.cell_size), 0.01, LawnGrid.STRIPE_A)
	check(is_equal_approx(grid.percent_cut(), 100.0), "cutting every open cell reaches 100%")
	grid.free()


func test_saved_record_rejects_bad_data() -> void:
	check(RunState.save_best(83.5, TEST_SAVE), "record saves")
	check(is_equal_approx(RunState.load_best(TEST_SAVE), 83.5), "record loads back")
	for bad in ['{"yard_01": "83"}', '{"yard_01": -4}', '{"yard_01": 1e999}', '[83]', 'not json', '{"yard_01": {"x": 1}}']:
		var file := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
		file.store_string(bad)
		file.close()
		check(RunState.load_best(TEST_SAVE) == 0.0, "rejects saved data: " + bad)
	_remove_test_save()
	check(RunState.load_best(TEST_SAVE) == 0.0, "missing file means no record")


func test_mower_drives_cuts_and_stays_in_yard() -> void:
	var yard := await new_yard()
	var mower: Mower = yard.mower
	var start := mower.global_position
	Input.action_press("accelerate")
	await frames(600) # 10 s at full throttle straight at the far fence
	Input.action_release("accelerate")
	check(yard.lawn.percent_cut() > 1.0, "driving with blades on cuts grass")
	check(mower.global_position.z > 0.5, "fence stops the mower (z=%.2f)" % mower.global_position.z)
	check(start.z - mower.global_position.z > 14.0, "mower drove most of the yard")
	check(mower.measured_speed < 0.2, "blocked mower reads ~0 speed (%.2f)" % mower.measured_speed)
	var cut_before: int = yard.lawn.cut_count
	mower.blades_on = false
	Input.action_press("reverse")
	await frames(120)
	check(yard.lawn.cut_count == cut_before, "blades off cuts nothing")
	await end_yard(yard)


func test_pause_freezes_time_and_position() -> void:
	var yard := await new_yard()
	Input.action_press("accelerate")
	await frames(30)
	yard.run.toggle_pause()
	await frames(5)
	var where: Vector3 = yard.mower.global_position
	var time: float = yard.run.elapsed
	await frames(90)
	check(yard.mower.global_position.is_equal_approx(where), "paused mower does not move")
	check(yard.run.elapsed == time, "paused timer does not run")
	yard.run.toggle_pause()
	await frames(30)
	check(yard.run.elapsed > time, "timer resumes after pause")
	check(not yard.mower.global_position.is_equal_approx(where), "mower moves after pause")
	await end_yard(yard)


func test_hop_off_parks_mower_and_hop_back_on() -> void:
	var yard := await new_yard()
	check(yard.toggle_mower(), "can hop off in the open")
	check(not yard.on_mower and yard.walker.active, "walker takes over")
	check(yard.walker.global_position.distance_to(yard.mower.global_position) < 1.6, "walker steps off beside the mower")
	var parked: Vector3 = yard.mower.global_position
	Input.action_press("accelerate")
	await frames(90)
	Input.action_release("accelerate")
	check(Vector2(yard.mower.global_position.x - parked.x, yard.mower.global_position.z - parked.z).length() < 0.01, "parked mower stays put")
	check(yard.walker.global_position.distance_to(parked) > 2.0, "walker walks away")
	check(not yard.toggle_mower(), "too far away to hop back on")
	yard.walker.global_position = parked + Vector3(1.2, 0, 0)
	await frames(2)
	check(yard.toggle_mower(), "hop back on when close")
	check(yard.on_mower and yard.mower.driving and not yard.walker.active, "mower takes over again")
	await end_yard(yard)


func test_walker_blocked_by_tree_ring_and_parked_mower() -> void:
	var yard := await new_yard()
	yard.toggle_mower()
	var tree: Vector2 = yard.TREES[0]
	# Walk straight at the tree from 3 m away, facing -Z.
	yard.walker.global_position = Vector3(tree.x, 0, tree.y + 3.0)
	yard.walker.global_rotation.y = 0.0
	Input.action_press("accelerate")
	await frames(180)
	Input.action_release("accelerate")
	var gap := Vector2(yard.walker.global_position.x, yard.walker.global_position.z).distance_to(tree)
	check(gap >= yard.RING_RADIUS + 0.2, "stone ring stops the walker (%.2f m)" % gap)
	# Walk into the parked mower from behind.
	var mower: Mower = yard.mower
	yard.walker.global_position = mower.global_position + Vector3(0, 0, 2.5)
	yard.walker.global_rotation.y = 0.0
	Input.action_press("accelerate")
	await frames(120)
	Input.action_release("accelerate")
	check(yard.walker.global_position.z - mower.global_position.z > 0.9, "parked mower blocks the walker")
	await end_yard(yard)


func test_weed_eater_reaches_fence_strip_mower_cannot() -> void:
	var yard := await new_yard()
	var mower: Mower = yard.mower
	var lawn: LawnGrid = yard.lawn
	# Scrape along the left fence for 3 s.
	mower.global_position = Vector3(0.4, 0.05, 14.0)
	Input.action_press("accelerate")
	await frames(180)
	Input.action_release("accelerate")
	var row := int(mower.global_position.z / lawn.cell_size) + 4
	check(lawn.cell(2, row) != LawnGrid.TALL, "mower cuts near the fence")
	check(lawn.cell(0, row) == LawnGrid.TALL, "mower blade cannot reach the fence strip")
	await frames(30)
	check(yard.toggle_mower(), "hop off by the fence")
	yard.walker.global_position = Vector3(1.0, 0, (row + 0.5) * lawn.cell_size)
	yard.walker.global_rotation.y = PI / 2.0 # facing -X, toward the fence
	await frames(3)
	check(lawn.cell(0, row) != LawnGrid.TALL, "weed eater trims the fence strip")
	await end_yard(yard)


func test_finish_once_and_record_survives_reload() -> void:
	var yard := await new_yard()
	var lawn: LawnGrid = yard.lawn
	await frames(30)
	for z in lawn.rows:
		for x in lawn.columns:
			lawn.cut_at(Vector3((x + 0.5) * lawn.cell_size, 0, (z + 0.5) * lawn.cell_size), 0.01, LawnGrid.STRIPE_A)
	await process_frame
	await process_frame
	check(yard.run.finished, "reaching 99% finishes the run")
	var best: float = yard.run.best
	check(best > 0.0 and is_equal_approx(RunState.load_best(TEST_SAVE), best), "new record is saved")
	await frames(30)
	check(yard.run.best == best and is_equal_approx(RunState.load_best(TEST_SAVE), best), "record updates once")
	await end_yard(yard)
	var again := await new_yard()
	check(is_equal_approx(again.run.best, best), "record survives a reload")
	await end_yard(again)


func test_highlight_and_finish_screens() -> void:
	var yard := await new_yard()
	var view: LawnView = yard.view
	var before := view.image.get_pixel(40, 40)
	view.set_highlight(true)
	check(view.image.get_pixel(40, 40).r > before.r + 0.3, "highlight paints tall grass yellow")
	view.set_highlight(false)
	check(view.image.get_pixel(40, 40).is_equal_approx(before), "highlight turns off")
	yard.run.toggle_pause()
	yard.hud.show_paused(true)
	check(yard.hud.overlay.visible and yard.hud.overlay_title.text == "Paused", "pause screen shows")
	yard.run.toggle_pause()
	yard.hud.show_finished(75.0, 70.0, false, true)
	check(yard.hud.overlay_body.text.contains("Personal best 1:10"), "finish screen shows the best time")
	await end_yard(yard)


func test_swept_cut_leaves_no_gaps() -> void:
	var grid := LawnGrid.new()
	grid.seal_layout()
	# One big jump, as if a slow frame moved the blade 6 m at once.
	grid.cut_segment(Vector3(2.0, 0, 10.1), Vector3(8.0, 0, 10.1), 0.2, LawnGrid.STRIPE_A)
	var gaps := 0
	for x in range(8, 32):
		if grid.cell(x, 40) == LawnGrid.TALL:
			gaps += 1
	check(gaps == 0, "swept cut leaves no gaps along its path (%d gaps)" % gaps)
	grid.free()


func test_cut_grass_becomes_stubble_and_throws_clippings() -> void:
	var yard := await new_yard()
	var view: LawnView = yard.view
	var lawn: LawnGrid = yard.lawn
	# MultiMesh data is not kept by the headless renderer, so check the
	# stubble transform the view builds and the ground pixel it repaints.
	var full: Transform3D = view.clump_transforms[40 * lawn.columns + 40]
	var stubble: Transform3D = view._stubble(full)
	check(is_equal_approx(stubble.basis.y.length(), full.basis.y.length() * LawnView.STUBBLE_HEIGHT), "cut clump shrinks to stubble")
	check(is_equal_approx(stubble.basis.x.length(), full.basis.x.length()), "stubble keeps its width")
	check(stubble.origin.is_equal_approx(full.origin), "stubble stays where the clump was")
	var before := view.image.get_pixel(40, 40)
	lawn.cut_at(Vector3(10.1, 0, 10.1), 0.1, LawnGrid.STRIPE_A)
	check(view.image.get_pixel(40, 40).g > before.g + 0.05, "cut patch is repainted as a light stripe")
	var saw_clippings := false
	Input.action_press("accelerate")
	for i in 60:
		await physics_frame
		saw_clippings = saw_clippings or yard.mower.clippings.emitting
	Input.action_release("accelerate")
	check(saw_clippings, "mowing tall grass throws clippings")
	await frames(60)
	check(not yard.mower.clippings.emitting, "no clippings once the mower stops")
	await end_yard(yard)


func test_sounds_follow_what_you_are_doing() -> void:
	var yard := await new_yard()
	var sounds: Sounds = yard.sounds
	for player in [sounds.engine, sounds.blades, sounds.trimmer, sounds.rustle]:
		var wave: AudioStreamWAV = player.stream
		check(wave.loop_mode == AudioStreamWAV.LOOP_FORWARD and wave.data.size() == Sounds.RATE * 2, "%s is a one-second generated loop" % player.name)
	check(sounds.chime_player.stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "finish chime plays once")
	Input.action_press("accelerate")
	await frames(60)
	check(sounds.targets[sounds.engine] > 0.6, "engine gets louder with speed")
	check(sounds.engine.pitch_scale > 1.2, "engine pitch rises with speed")
	check(sounds.targets[sounds.blades] > 0.0 and sounds.targets[sounds.rustle] > 0.0, "blades whir and grass rustles while mowing")
	check(sounds.engine.volume_linear > 0.3, "engine fades in")
	Input.action_release("accelerate")
	yard.mower.blades_on = false
	await frames(5)
	check(sounds.targets[sounds.blades] == 0.0, "blades fall silent when switched off")
	yard.toggle_mower()
	await frames(5)
	check(sounds.targets[sounds.trimmer] > 0.0 and sounds.targets[sounds.engine] < 0.2, "weed eater buzzes and the parked mower idles")
	check(Sounds.toggle_mute() and AudioServer.is_bus_mute(0), "M mutes the game")
	check(not Sounds.toggle_mute() and not AudioServer.is_bus_mute(0), "M again unmutes it")
	yard.run.finish_run()
	await frames(5)
	check(sounds.targets[sounds.trimmer] == 0.0, "trimmer stops once the lawn is done")
	await end_yard(yard)


func test_walk_animation_and_minimap() -> void:
	var yard := await new_yard()
	var hud: Hud = yard.hud
	check(hud.minimap.visible and hud.minimap.texture == yard.view.texture, "minimap shows the lawn")
	await frames(2)
	var expected: Vector2 = yard.map_point(yard.mower.global_position)
	check(hud.minimap_mower.is_equal_approx(expected) and expected.y > 0.7, "minimap marks the mower near the bottom")
	check(hud.minimap_walker.x < 0.0, "no walker marker while riding")
	yard.toggle_mower()
	var leg: Node3D = yard.walker.person.get_node("LeftLeg")
	Input.action_press("accelerate")
	var swing := 0.0
	for i in 40:
		await physics_frame
		swing = maxf(swing, absf(leg.rotation.x))
	Input.action_release("accelerate")
	check(swing > 0.2, "legs swing while walking (%.2f)" % swing)
	await frames(3)
	check(is_zero_approx(leg.rotation.x), "legs come to rest when standing")
	check(hud.minimap_walker.x >= 0.0, "minimap marks the walker on foot")
	await end_yard(yard)


func test_everything_is_built_in_code() -> void:
	var yard := await new_yard()
	var loaded := []
	var surfaces := 0
	for node in yard.find_children("*", "MeshInstance3D", true, false):
		surfaces += node.mesh.get_surface_count()
		var path: String = node.mesh.resource_path
		if path != "" and not path.contains("::"):
			loaded.append(path)
	check(surfaces > 50, "yard is dressed with models (%d surfaces)" % surfaces)
	check(loaded.is_empty(), "no model files are loaded: %s" % [loaded])
	await end_yard(yard)


## Scenery photos come only from res://textures, are plain JPEG images, and
## each one is credited in ASSET_LICENSES.md.
func test_photo_textures_are_local_and_listed() -> void:
	var yard := await new_yard()
	var used := {}
	for node in yard.find_children("*", "MeshInstance3D", true, false):
		for surface in node.mesh.get_surface_count():
			var mat = node.mesh.surface_get_material(surface)
			if mat is StandardMaterial3D and mat.albedo_texture:
				used[mat.albedo_texture.resource_path] = true
	var ground: MeshInstance3D = yard.view.get_node("Ground")
	var ground_material: ShaderMaterial = ground.mesh.material
	check(ground_material.shader.resource_path == "res://shaders/ground.gdshader", "the lawn uses the ground shader")
	used[ground_material.get_shader_parameter("detail").resource_path] = true
	check(used.size() >= 8, "scenery uses the photo textures (%d)" % used.size())
	var licenses := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../ASSET_LICENSES.md"))
	for path: String in used:
		check(path.begins_with("res://textures/") and path.ends_with(".jpg"), "texture %s is a local JPEG" % path)
		check(licenses.contains(path.get_file()), "%s is listed in ASSET_LICENSES.md" % path.get_file())
	for file in DirAccess.get_files_at("res://textures"):
		check(file.ends_with(".jpg") or file.ends_with(".jpg.import"), "only images in textures/: %s" % file)
		if file.ends_with(".jpg"):
			check(used.has("res://textures/" + file), "%s is used" % file)
	await end_yard(yard)


func test_static_models_are_baked() -> void:
	var yard := await new_yard()
	var scenery_meshes: Array = yard.scenery.find_children("*", "MeshInstance3D", true, false)
	check(scenery_meshes.size() == 1, "scenery is baked into one mesh (%d)" % scenery_meshes.size())
	check(scenery_meshes[0].mesh.get_surface_count() < 40, "baked scenery has one surface per material")
	var all: Array = yard.find_children("*", "MeshInstance3D", true, false)
	check(all.size() < 30, "few mesh instances left to draw (%d)" % all.size())
	check(yard.mower.wheels[0].get_child_count() == 1, "each wheel is baked but still spins on its own")
	check(yard.walker.person.get_node("LeftLeg").get_child_count() == 1, "limbs are baked but still swing")
	await end_yard(yard)


## The web build must stay on the Compatibility renderer; desktop builds
## use Forward+ and turn on extra effects by quality level.
func test_desktop_builds_get_richer_effects() -> void:
	check(ProjectSettings.get_setting("rendering/renderer/rendering_method.web") == "gl_compatibility", "web uses the Compatibility renderer")
	check(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "forward_plus", "desktop uses Forward+")
	var yard := await new_yard()
	check(not yard.rich_graphics, "tests run without the desktop renderer")
	check(yard.view.blades == LawnView.BLADES, "the web build keeps the lighter grass")
	yard._apply_rich_effects("low")
	check(not yard.environment.ssao_enabled and not yard.environment.glow_enabled, "low skips the desktop effects")
	yard._apply_rich_effects("medium")
	check(yard.environment.ssao_enabled and not yard.environment.ssil_enabled, "medium adds ambient occlusion")
	yard._apply_rich_effects("high")
	check(yard.environment.ssil_enabled and yard.environment.glow_enabled and yard.sun.light_angular_distance > 0.0, "high adds bounce light, glow and soft shadows")
	await end_yard(yard)


func test_quality_presets_and_saved_settings() -> void:
	var yard := await new_yard()
	var viewport: Viewport = yard.get_viewport()
	yard.apply_quality("low")
	check(not yard.sun.shadow_enabled and is_equal_approx(viewport.scaling_3d_scale, 0.75), "low turns off shadows and renders smaller")
	yard.apply_quality("medium")
	check(yard.sun.shadow_enabled and viewport.msaa_3d == Viewport.MSAA_DISABLED, "medium has shadows without smoothing")
	yard.apply_quality("high")
	check(viewport.msaa_3d == Viewport.MSAA_2X and is_equal_approx(viewport.scaling_3d_scale, 1.0), "high smooths edges at full size")
	var press := InputEventAction.new()
	press.action = "quality"
	press.pressed = true
	var before: String = yard.settings.quality
	yard._unhandled_input(press)
	check(yard.settings.quality != before, "Q changes the quality")
	var reloaded := Settings.new()
	reloaded.load_settings()
	check(reloaded.quality == yard.settings.quality, "quality is remembered")
	var cycle := Settings.new()
	cycle.quality = "high"
	check(cycle.next_quality() == "low" and cycle.next_quality() == "medium", "Q cycles through every level")
	for bad in ['{"quality": "ultra", "muted": "yes"}', "not json", "[1, 2]", '{"quality": 3}']:
		var file := FileAccess.open(TEST_SETTINGS, FileAccess.WRITE)
		file.store_string(bad)
		file.close()
		var settings := Settings.new()
		settings.load_settings()
		check(settings.quality == "high" and settings.muted == false, "bad settings fall back to defaults: %s" % bad)
	yard.apply_quality("high")
	await end_yard(yard)


func test_touch_controls() -> void:
	var yard := await new_yard()
	var touch: TouchControls = yard.touch
	check(not touch.visible and yard.hud.controls.visible, "no touch buttons without a touch screen")
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	yard._input(tap)
	check(touch.visible and not yard.hud.controls.visible, "first touch shows the buttons instead of the key list")
	var screen: Rect2 = yard.get_viewport().get_visible_rect()
	for spec in TouchControls.BUTTONS:
		var button: TouchScreenButton = touch.buttons[spec[0]]
		check(InputMap.has_action(button.action), "%s button presses a real action" % spec[0])
		var rect := Rect2(button.position, Vector2(spec[2], spec[2]) * 2.0)
		check(screen.encloses(rect), "%s button is on screen" % spec[0])
	yard.hud.show_paused(true)
	check(yard.hud.overlay_body.text.begins_with("Tap"), "pause screen talks about tapping")
	await end_yard(yard)


func test_lost_focus_pauses_with_pause_screen() -> void:
	var yard := await new_yard()
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(paused, "switching away pauses the game")
	check(yard.hud.overlay.visible and yard.hud.overlay_title.text == "Paused", "pause screen shows after switching away")
	yard.run.toggle_pause()
	await end_yard(yard)


func test_restart_starts_a_fresh_yard() -> void:
	var yard := await new_yard()
	current_scene = yard
	Input.action_press("accelerate")
	await frames(60)
	Input.action_release("accelerate")
	check(yard.lawn.cut_count > 0, "some grass cut before restarting")
	var press := InputEventAction.new()
	press.action = "restart"
	press.pressed = true
	yard._unhandled_input(press)
	await frames(3)
	var fresh: Node3D = current_scene
	check(fresh != yard and is_instance_valid(fresh), "restart loads a new yard")
	check(fresh.lawn.cut_count == 0 and fresh.run.elapsed < 1.0, "the new yard starts uncut with the clock reset")
	await end_yard(fresh)


func test_blocked_storage_still_finishes() -> void:
	var yard := await new_yard()
	yard.run.save_path = "user://no/such/folder/best.json"
	yard.run.finish_run()
	await frames(2)
	check(yard.run.finished and not yard.run.storage_ok, "a blocked save is noticed, not fatal")
	check(yard.hud.overlay_body.text.contains("blocked saving"), "finish screen explains the record was not saved")
	var settings := Settings.new("user://no/such/folder/settings.json")
	check(not settings.save(), "settings that cannot be saved fail quietly")
	await end_yard(yard)


func test_resize_keeps_touch_buttons_on_screen() -> void:
	var yard := await new_yard()
	var touch: TouchControls = yard.touch
	var original := root.size
	for size in [Vector2i(800, 600), Vector2i(1920, 800), Vector2i(1280, 720)]:
		root.size = size
		await process_frame
		touch.layout()
		var screen: Rect2 = yard.get_viewport().get_visible_rect()
		var inside := true
		for spec in TouchControls.BUTTONS:
			var rect := Rect2(touch.buttons[spec[0]].position, Vector2(spec[2], spec[2]) * 2.0)
			inside = inside and screen.encloses(rect)
		check(inside, "touch buttons stay on screen at %s (visible %s)" % [size, screen.size])
	root.size = original
	await end_yard(yard)


func test_back_and_forth_passes_alternate_stripes() -> void:
	check(LawnGrid.stripe_for(Vector3(0, 0, -1)) != LawnGrid.stripe_for(Vector3(0, 0, 1)), "up and back along a line leave different stripes")
	check(LawnGrid.stripe_for(Vector3(1, 0, 0.2)) != LawnGrid.stripe_for(Vector3(-1, 0, -0.2)), "across and back leave different stripes")
	var view := LawnView.new()
	check(view._cut_data(LawnGrid.STRIPE_A).g > view._cut_data(LawnGrid.STRIPE_B).g, "stubble on a light stripe is drawn lighter")
	view.free()

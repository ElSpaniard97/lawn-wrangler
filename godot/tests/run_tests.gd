extends SceneTree
## Headless checks, run in CI before export:
##   godot --headless --path godot --script res://tests/run_tests.gd
## Exits with code 1 if any check fails. The yard tests are ports of the
## original pygame regression tests.

const TEST_SAVE := "user://test_best_times.json"

var failures := 0


func _initialize() -> void:
	RunState.default_path = TEST_SAVE
	_remove_test_save()
	test_cutting_counts_each_cell_once()
	test_blocked_cells_never_count()
	test_saved_record_rejects_bad_data()
	test_swept_cut_leaves_no_gaps()
	await test_mower_drives_cuts_and_stays_in_yard()
	await test_pause_freezes_time_and_position()
	await test_hop_off_parks_mower_and_hop_back_on()
	await test_walker_blocked_by_tree_ring_and_parked_mower()
	await test_weed_eater_reaches_fence_strip_mower_cannot()
	await test_finish_once_and_record_survives_reload()
	await test_highlight_and_finish_screens()
	await test_cut_grass_becomes_stubble_and_throws_clippings()
	_remove_test_save()
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
	await process_frame


func _remove_test_save() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


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

extends SceneTree
## Headless checks, run in CI before export:
##   godot --headless --path godot --script res://tests/run_tests.gd
## Exits with code 1 if any check fails.

var failures := 0


func _initialize() -> void:
	test_cutting_counts_each_cell_once()
	test_blocked_cells_never_count()
	test_saved_record_rejects_bad_data()
	await test_mower_drives_cuts_and_stays_in_yard()
	print("%s: %d failure(s)" % ["FAILED" if failures else "OK", failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


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
	var total_before := grid.total
	check(total_before < grid.columns * grid.rows, "blocked cells leave the total")
	check(grid.cut_at(Vector3(5, 0, 5), 0.5, LawnGrid.STRIPE_A) == 0, "blocked cells are never cut")
	for z in grid.rows:
		for x in grid.columns:
			grid.cut_at(Vector3((x + 0.5) * grid.cell_size, 0, (z + 0.5) * grid.cell_size), 0.01, LawnGrid.STRIPE_A)
	check(is_equal_approx(grid.percent_cut(), 100.0), "cutting every open cell reaches 100%")
	grid.free()


func test_saved_record_rejects_bad_data() -> void:
	var path := "user://test_best_times.json"
	check(RunState.save_best(83.5, path), "record saves")
	check(is_equal_approx(RunState.load_best(path), 83.5), "record loads back")
	for bad in ['{"yard_01": "83"}', '{"yard_01": -4}', '{"yard_01": 1e999}', '[83]', 'not json', '{"yard_01": {"x": 1}}']:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(bad)
		file.close()
		check(RunState.load_best(path) == 0.0, "rejects saved data: " + bad)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check(RunState.load_best(path) == 0.0, "missing file means no record")


func test_mower_drives_cuts_and_stays_in_yard() -> void:
	var yard: Node3D = load("res://scenes/yard.tscn").instantiate()
	root.add_child(yard)
	await physics_frame
	var mower: Mower = yard.mower
	var start := mower.global_position
	Input.action_press("accelerate")
	for i in 600: # 10 s at full throttle straight at the far fence
		await physics_frame
	Input.action_release("accelerate")
	check(yard.lawn.percent_cut() > 1.0, "driving with blades on cuts grass")
	check(mower.global_position.z > 0.5, "fence stops the mower (z=%.2f)" % mower.global_position.z)
	check(start.z - mower.global_position.z > 15.0, "mower drove most of the yard")
	check(mower.measured_speed < 0.2, "blocked mower reads ~0 speed (%.2f)" % mower.measured_speed)
	var cut_before: int = yard.lawn.cut_count
	mower.blades_on = false
	Input.action_press("reverse")
	for i in 120:
		await physics_frame
	Input.action_release("reverse")
	check(yard.lawn.cut_count == cut_before, "blades off cuts nothing")
	yard.queue_free()
	await process_frame

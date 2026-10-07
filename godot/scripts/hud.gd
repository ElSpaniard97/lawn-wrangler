class_name Hud
extends CanvasLayer
## Translucent panels like a modern sports game: the objectives checklist,
## progress, a round minimap, a speedometer with a fuel gauge, the control
## prompts (keyboard or gamepad), and the pause and finish overlays.

const PANEL_COLOR := Color(0.05, 0.08, 0.06, 0.62)
const ACCENT := Color(0.55, 0.85, 0.35)
const LOW := Color(0.95, 0.6, 0.4)
## Top speed on the speedometer dial, in mph.
const DIAL_MPH := 10.0
## How much of the yard the round minimap shows across, in cells.
const MAP_VIEW_CELLS := 88.0
const MAP_SIZE := 210.0
const KEYBOARD_PROMPTS := [["W / S", "Drive / walk"], ["A / D", "Steer"], ["Space", "Hop off or on"],
	["B", "Blades on/off"], ["H", "Find missed grass"], ["M", "Sound on/off"], ["Q", "Graphics quality"],
	["P", "Pause"], ["R", "Restart"]]
const GAMEPAD_PROMPTS := [["RT", "Accelerate"], ["LT", "Reverse"], ["L", "Steer"], ["X", "Toggle blades"],
	["Y", "Hop off or on"], ["RB", "Find missed grass"], ["Start", "Pause"], ["Back", "Restart"]]

var objective_boxes: Array[Control] = []
var objective_labels: Array[Label] = []
var objectives_done := [false, false, false, false]
var progress_label: Label
var percent_label: Label
var progress_bar: ProgressBar
var time_label: Label
var patches_label: Label
var message: PanelContainer
var message_label: Label
var message_time := 0.0
var overlay: PanelContainer
var overlay_title: Label
var overlay_body: Label
var map_frame: Control
var minimap: TextureRect
## Draws the ring and markers above the map (its own shader would tint them).
var map_markers: Control
var stats: Label
var quality_name := ""
var controls: PanelContainer
var prompts: VBoxContainer
var gamepad := false
var touch := false
var gauge_panel: PanelContainer
var gauge: Control
var mph := 0.0
var fuel := 1.0
var blades_text := "Blades ON"
var blades_color := ACCENT
var minimap_mower := Vector2(-1, -1)
var minimap_heading := 0.0
var minimap_walker := Vector2(-1, -1)
var _root: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Objectives checklist.
	var tasks := _panel()
	_place(tasks, Control.PRESET_TOP_LEFT, Vector2(20, 20))
	var tasks_box := VBoxContainer.new()
	tasks_box.add_theme_constant_override("separation", 5)
	tasks.add_child(tasks_box)
	tasks_box.add_child(_label("Mow the Lawn", 21, Color.WHITE))
	for name in Objectives.NAMES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 9)
		var box := Control.new()
		box.custom_minimum_size = Vector2(17, 17)
		box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.draw.connect(_draw_check.bind(box, objective_boxes.size()))
		row.add_child(box)
		objective_boxes.append(box)
		var label := _label(name, 15, Color(0.92, 0.92, 0.92))
		row.add_child(label)
		objective_labels.append(label)
		tasks_box.add_child(row)
	time_label = _label("Time 0:00   Best --:--", 14, Color(0.78, 0.78, 0.78))
	tasks_box.add_child(time_label)

	# Progress bar.
	var progress := _panel()
	_place(progress, Control.PRESET_TOP_RIGHT, Vector2(-20, 20))
	var progress_box := VBoxContainer.new()
	progress_box.custom_minimum_size = Vector2(280, 0)
	progress.add_child(progress_box)
	var title_row := HBoxContainer.new()
	progress_box.add_child(title_row)
	progress_label = _label("Progress", 18, Color.WHITE)
	progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(progress_label)
	percent_label = _label("0%", 18, Color.WHITE)
	title_row.add_child(percent_label)
	progress_bar = ProgressBar.new()
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size = Vector2(280, 10)
	var fill := StyleBoxFlat.new()
	fill.bg_color = ACCENT
	fill.set_corner_radius_all(5)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.18)
	back.set_corner_radius_all(5)
	progress_bar.add_theme_stylebox_override("fill", fill)
	progress_bar.add_theme_stylebox_override("background", back)
	progress_box.add_child(progress_bar)
	patches_label = _label("", 13, Color(0.8, 0.8, 0.8))
	progress_box.add_child(patches_label)

	# Round minimap: the lawn texture seen through a circle, centred on the mower.
	map_frame = Control.new()
	map_frame.custom_minimum_size = Vector2(MAP_SIZE, MAP_SIZE)
	map_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(map_frame)
	_place(map_frame, Control.PRESET_BOTTOM_LEFT, Vector2(20, -20))
	minimap = TextureRect.new()
	minimap.set_anchors_preset(Control.PRESET_FULL_RECT)
	minimap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	minimap.stretch_mode = TextureRect.STRETCH_SCALE
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var map_material := ShaderMaterial.new()
	map_material.shader = load("res://shaders/minimap.gdshader")
	minimap.material = map_material
	map_frame.add_child(minimap)
	map_markers = Control.new()
	map_markers.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_markers.draw.connect(_draw_minimap_markers)
	map_frame.add_child(map_markers)
	map_frame.visible = false

	# Control prompts, keyboard or gamepad.
	controls = _panel()
	prompts = VBoxContainer.new()
	prompts.add_theme_constant_override("separation", 6)
	controls.add_child(prompts)
	_fill_prompts()
	_place(controls, Control.PRESET_CENTER_RIGHT, Vector2(-20, 10))

	stats = _label("", 13, Color(1, 1, 0.7))
	stats.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	stats.grow_horizontal = Control.GROW_DIRECTION_BOTH
	stats.position.y = 8
	stats.visible = false
	_root.add_child(stats)

	# Speedometer and fuel gauge, drawn by hand.
	gauge_panel = _panel(26)
	gauge = Control.new()
	gauge.custom_minimum_size = Vector2(220, 150)
	gauge.draw.connect(_draw_gauge)
	gauge_panel.add_child(gauge)
	_place(gauge_panel, Control.PRESET_BOTTOM_RIGHT, Vector2(-20, -20))

	message = _panel()
	message_label = _label("", 16, Color.WHITE)
	message.add_child(message_label)
	_place(message, Control.PRESET_CENTER_BOTTOM, Vector2(0, -24))
	message.visible = false

	overlay = _panel()
	var overlay_box := VBoxContainer.new()
	overlay_box.custom_minimum_size = Vector2(360, 0)
	overlay.add_child(overlay_box)
	overlay_title = _label("", 30, Color.WHITE)
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_box.add_child(overlay_title)
	overlay_body = _label("", 16, Color(0.9, 0.9, 0.9))
	overlay_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_box.add_child(overlay_body)
	_place(overlay, Control.PRESET_CENTER, Vector2.ZERO)
	overlay.visible = false


func _process(delta: float) -> void:
	if stats.visible:
		stats.text = "%d fps   %d draw calls   %s quality" % [Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), quality_name]
	if message_time > 0.0:
		message_time -= delta
		message.visible = message_time > 0.0


## Hides the prompts and moves the map and speedometer up under the
## progress bar, clear of the on-screen buttons.
func use_touch() -> void:
	touch = true
	controls.visible = false
	map_frame.custom_minimum_size = Vector2(150, 150)
	_place(map_frame, Control.PRESET_TOP_RIGHT, Vector2(-20, 128))
	_place(gauge_panel, Control.PRESET_TOP_RIGHT, Vector2(-190, 128))


## Swaps the prompts between keyboard keys and gamepad buttons.
func use_gamepad(value: bool) -> void:
	if value == gamepad:
		return
	gamepad = value
	_fill_prompts()


func _fill_prompts() -> void:
	for child in prompts.get_children():
		prompts.remove_child(child)
		child.queue_free()
	for spec in (GAMEPAD_PROMPTS if gamepad else KEYBOARD_PROMPTS):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var cap := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0.06)
		style.border_color = Color(1, 1, 1, 0.75)
		style.set_border_width_all(2)
		# Gamepad face buttons and the stick are round, everything else a key cap.
		style.set_corner_radius_all(12 if gamepad and spec[0].length() == 1 else 5)
		style.content_margin_left = 6
		style.content_margin_right = 6
		cap.add_theme_stylebox_override("panel", style)
		cap.custom_minimum_size = Vector2(26, 24)
		var key := _label(spec[0], 12, Color.WHITE)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.add_child(key)
		var holder := CenterContainer.new()
		holder.custom_minimum_size = Vector2(52, 0)
		holder.add_child(cap)
		row.add_child(holder)
		row.add_child(_label(spec[1], 14, Color(0.92, 0.92, 0.92)))
		prompts.add_child(row)


## F3: frame rate, draw calls and the quality level, for checking speed.
func toggle_stats() -> void:
	stats.visible = not stats.visible


## Shows a short hint above the bottom edge for a few seconds.
func say(text: String, seconds := 2.5) -> void:
	message_label.text = text
	message_time = seconds
	message.visible = true


func update_play(percent: float, remaining: int, mph_value: float, on_foot: bool, blades_on: bool, elapsed: float, best: float) -> void:
	var shown := floorf(percent)
	percent_label.text = "%d%%" % shown
	progress_bar.value = shown
	patches_label.text = "%d patches left" % remaining
	mph = mph_value
	if on_foot:
		blades_text = "Weed eater"
		blades_color = ACCENT
	else:
		blades_text = "Blades ON" if blades_on else "Blades OFF"
		blades_color = ACCENT if blades_on else LOW
	gauge.queue_redraw()
	time_label.text = "Time %s   Best %s" % [format_time(elapsed), format_time(best) if best > 0.0 else "--:--"]


## Ticks goals off the checklist, in the order of Objectives.NAMES.
func update_objectives(states: Array) -> void:
	for i in states.size():
		if states[i] != objectives_done[i]:
			objectives_done[i] = states[i]
			objective_labels[i].add_theme_color_override("font_color", Color(0.7, 0.7, 0.7) if states[i] else Color(0.92, 0.92, 0.92))
			objective_boxes[i].queue_redraw()


## The fuel left in the mower, from 0 (empty) to 1 (full).
func update_fuel(value: float) -> void:
	fuel = clampf(value, 0.0, 1.0)
	gauge.queue_redraw()


func _draw_check(box: Control, index: int) -> void:
	var rect := Rect2(Vector2.ZERO, box.size)
	if objectives_done[index]:
		box.draw_rect(rect, ACCENT)
		box.draw_polyline(PackedVector2Array([Vector2(3.5, 8.5), Vector2(7, 12.5), Vector2(13.5, 4.5)]), Color(0.05, 0.1, 0.05), 2.4, true)
	else:
		box.draw_rect(rect.grow(-1), Color(1, 1, 1, 0.85), false, 1.6)


## An arc speedometer on the left and a fuel gauge on the right.
func _draw_gauge() -> void:
	var font := ThemeDB.fallback_font
	var center := Vector2(78, 80)
	var radius := 64.0
	var start := deg_to_rad(135.0)
	var sweep := deg_to_rad(270.0)
	var fraction := clampf(mph / DIAL_MPH, 0.0, 1.0)
	gauge.draw_arc(center, radius, start, start + sweep, 48, Color(1, 1, 1, 0.16), 10.0, true)
	if fraction > 0.005:
		gauge.draw_arc(center, radius, start, start + sweep * fraction, 48, ACCENT, 10.0, true)
	for i in 11:
		var angle := start + sweep * i / 10.0
		var direction := Vector2.from_angle(angle)
		var inner := radius - (16.0 if i % 5 == 0 else 12.0)
		gauge.draw_line(center + direction * inner, center + direction * (radius - 7.0), Color(1, 1, 1, 0.7), 2.0, true)
	var number := "%d" % roundi(mph)
	gauge.draw_string(font, center + Vector2(-60, 14), number, HORIZONTAL_ALIGNMENT_CENTER, 120, 44, Color.WHITE)
	gauge.draw_string(font, center + Vector2(-60, 36), "MPH", HORIZONTAL_ALIGNMENT_CENTER, 120, 14, Color(0.85, 0.85, 0.85))
	gauge.draw_string(font, center + Vector2(-60, 70), blades_text, HORIZONTAL_ALIGNMENT_CENTER, 120, 13, blades_color)
	# Fuel: a pump, then a column of segments that empties from the top.
	var x := 180.0
	var pump := Color(0.92, 0.92, 0.92)
	gauge.draw_rect(Rect2(x - 2, 8, 13, 17), pump)
	gauge.draw_rect(Rect2(x + 1, 11, 7, 5), Color(0.1, 0.12, 0.1))
	gauge.draw_polyline(PackedVector2Array([Vector2(x + 11, 12), Vector2(x + 16, 15), Vector2(x + 16, 23), Vector2(x + 19, 23), Vector2(x + 19, 11)]), pump, 1.8, true)
	gauge.draw_string(font, Vector2(x + 24, 46), "F", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.85, 0.85))
	gauge.draw_string(font, Vector2(x + 24, 142), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.85, 0.85))
	var segments := 8
	var lit := ceili(fuel * segments - 0.001)
	var color := ACCENT if fuel > 0.25 else (LOW if fuel > 0.1 else Color(0.95, 0.3, 0.25))
	for i in segments:
		var top := 36.0 + i * 13.0
		var on := segments - i <= lit
		gauge.draw_rect(Rect2(x, top, 14, 10), color if on else Color(1, 1, 1, 0.14))


## Shows the lawn texture as a round map. `roof` is the house as fractions
## across the map. Positions are fractions (0..1) across it.
func set_minimap(texture: Texture2D, roof := Rect2()) -> void:
	minimap.texture = texture
	var map_material: ShaderMaterial = minimap.material
	map_material.set_shader_parameter("span", Vector2(MAP_VIEW_CELLS / texture.get_width(), MAP_VIEW_CELLS / texture.get_height()))
	map_material.set_shader_parameter("roof", Vector4(roof.position.x, roof.position.y, roof.end.x, roof.end.y))
	map_frame.visible = true


## `heading` is the mower's facing in radians, 0 meaning up the map.
func update_minimap(mower_at: Vector2, heading: float, walker_at: Vector2) -> void:
	minimap_mower = mower_at
	minimap_heading = heading
	minimap_walker = walker_at
	if minimap.material:
		minimap.material.set_shader_parameter("center", mower_at)
	map_markers.queue_redraw()


## The mower always sits in the middle of the map; the landscaper is drawn
## where they stand, when that is inside the circle.
func _draw_minimap_markers() -> void:
	var size := map_markers.size
	var middle := size / 2.0
	var radius := size.x / 2.0
	map_markers.draw_arc(middle, radius - 1.5, 0, TAU, 64, Color(0.05, 0.08, 0.06, 0.9), 4.0, true)
	map_markers.draw_arc(middle, radius - 4.0, 0, TAU, 64, Color(1, 1, 1, 0.55), 1.5, true)
	if minimap.texture == null:
		return
	if minimap_walker.x >= 0.0:
		var span: Vector2 = minimap.material.get_shader_parameter("span")
		var at := middle + (minimap_walker - minimap_mower) / span * size
		if at.distance_to(middle) < radius - 8.0:
			map_markers.draw_circle(at, 5.5, Color.BLACK)
			map_markers.draw_circle(at, 4.0, Color.WHITE)
	if minimap_mower.x >= 0.0:
		var points := PackedVector2Array([Vector2(0, -10), Vector2(7, 7), Vector2(0, 3), Vector2(-7, 7)])
		for i in points.size():
			points[i] = middle + points[i].rotated(minimap_heading)
		map_markers.draw_colored_polygon(points, Color.WHITE)
		map_markers.draw_polyline(points + PackedVector2Array([points[0]]), Color.BLACK, 1.2, true)


func show_paused(paused: bool) -> void:
	overlay.visible = paused
	overlay_title.text = "Paused"
	overlay_body.text = ("Tap Pause to keep mowing." if touch else "Press P or Esc to keep mowing.") \
		+ "\n\nLawn Wrangler %s, made with Godot Engine" % ProjectSettings.get_setting("application/config/version", "")


func show_finished(time: float, best: float, is_record: bool, saved: bool) -> void:
	overlay.visible = true
	overlay_title.text = "Lawn done!"
	var lines := ["Time %s" % format_time(time)]
	lines.append("New personal best!" if is_record else "Personal best %s" % format_time(best))
	if is_record and not saved:
		lines.append("This browser blocked saving, so the record lasts this session.")
	lines.append("Tap Restart to mow again." if touch else "Press R to mow again.")
	overlay_body.text = "\n".join(lines)


static func format_time(seconds: float) -> String:
	var whole := int(seconds)
	return "%d:%02d" % [whole / 60, whole % 60]


func _panel(corner := 10) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.set_corner_radius_all(corner)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)
	return panel


## Pins a control to a corner or edge of the screen, `offset` in from it.
func _place(control: Control, preset: int, offset: Vector2) -> void:
	control.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE)
	control.grow_horizontal = Control.GROW_DIRECTION_END
	control.grow_vertical = Control.GROW_DIRECTION_END
	match preset:
		Control.PRESET_TOP_RIGHT:
			control.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_BOTTOM_LEFT:
			control.grow_vertical = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_BOTTOM_RIGHT:
			control.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			control.grow_vertical = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_CENTER_RIGHT:
			control.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			control.grow_vertical = Control.GROW_DIRECTION_BOTH
		Control.PRESET_CENTER_BOTTOM:
			control.grow_horizontal = Control.GROW_DIRECTION_BOTH
			control.grow_vertical = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_CENTER:
			control.grow_horizontal = Control.GROW_DIRECTION_BOTH
			control.grow_vertical = Control.GROW_DIRECTION_BOTH
	control.position += offset


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

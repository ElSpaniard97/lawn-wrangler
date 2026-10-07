class_name Hud
extends CanvasLayer
## Translucent panels: objective, progress, speed, controls, and the pause
## and finish overlays.

const PANEL_COLOR := Color(0.05, 0.08, 0.06, 0.62)
const ACCENT := Color(0.55, 0.85, 0.35)

var objective: Label
var progress_label: Label
var progress_bar: ProgressBar
var speed_label: Label
var blades_label: Label
var time_label: Label
var patches_label: Label
var message: PanelContainer
var message_label: Label
var message_time := 0.0
var overlay: PanelContainer
var overlay_title: Label
var overlay_body: Label
var minimap: TextureRect
var stats: Label
var quality_name := ""
var controls: PanelContainer
var touch := false
var minimap_mower := Vector2(-1, -1)
var minimap_heading := 0.0
var minimap_walker := Vector2(-1, -1)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var tasks := _panel(root, Control.PRESET_TOP_LEFT, Vector2(20, 20))
	var tasks_box := VBoxContainer.new()
	tasks.add_child(tasks_box)
	tasks_box.add_child(_label("Mow the Lawn", 20, Color.WHITE))
	objective = _label("[  ] Cut 99% of the grass", 15, Color(0.9, 0.9, 0.9))
	tasks_box.add_child(objective)
	time_label = _label("Time 0:00   Best --:--", 15, Color(0.8, 0.8, 0.8))
	tasks_box.add_child(time_label)

	var progress := _panel(root, Control.PRESET_TOP_RIGHT, Vector2(-20, 20))
	var progress_box := VBoxContainer.new()
	progress_box.custom_minimum_size = Vector2(240, 0)
	progress.add_child(progress_box)
	progress_label = _label("Progress 0%", 18, Color.WHITE)
	progress_box.add_child(progress_label)
	progress_bar = ProgressBar.new()
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size = Vector2(240, 10)
	var fill := StyleBoxFlat.new()
	fill.bg_color = ACCENT
	fill.set_corner_radius_all(5)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.18)
	back.set_corner_radius_all(5)
	progress_bar.add_theme_stylebox_override("fill", fill)
	progress_bar.add_theme_stylebox_override("background", back)
	progress_box.add_child(progress_bar)
	patches_label = _label("", 14, Color(0.85, 0.85, 0.85))
	progress_box.add_child(patches_label)
	# Top-down map of the lawn (the same texture the ground uses).
	minimap = TextureRect.new()
	minimap.custom_minimum_size = Vector2(150, 150)
	minimap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	minimap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	minimap.stretch_mode = TextureRect.STRETCH_SCALE
	minimap.self_modulate = Color(1.7, 1.7, 1.7) # the ground texture is darker than it looks lit
	minimap.draw.connect(_draw_minimap_markers)
	minimap.visible = false
	progress_box.add_child(minimap)

	controls = _panel(root, Control.PRESET_BOTTOM_LEFT, Vector2(20, -20))
	controls.add_child(_label("W/S  Drive / walk\nA/D  Steer\nSpace  Hop off or on\nB  Blades on/off\nH  Find missed grass\nM  Sound on/off\nQ  Graphics quality\nP / Esc  Pause\nR  Restart", 14, Color(0.9, 0.9, 0.9)))

	stats = _label("", 13, Color(1, 1, 0.7))
	stats.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	stats.grow_horizontal = Control.GROW_DIRECTION_BOTH
	stats.position.y = 8
	stats.visible = false
	root.add_child(stats)

	var gauge := _panel(root, Control.PRESET_BOTTOM_RIGHT, Vector2(-20, -20))
	var gauge_box := VBoxContainer.new()
	gauge_box.alignment = BoxContainer.ALIGNMENT_CENTER
	gauge.add_child(gauge_box)
	speed_label = _label("0", 44, Color.WHITE)
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gauge_box.add_child(speed_label)
	var mph := _label("MPH", 13, Color(0.8, 0.8, 0.8))
	mph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gauge_box.add_child(mph)
	blades_label = _label("Blades ON", 13, ACCENT)
	blades_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gauge_box.add_child(blades_label)

	message = _panel(root, Control.PRESET_CENTER_BOTTOM, Vector2(0, -24))
	message_label = _label("", 16, Color.WHITE)
	message.add_child(message_label)
	message.visible = false

	overlay = _panel(root, Control.PRESET_CENTER, Vector2.ZERO)
	var overlay_box := VBoxContainer.new()
	overlay_box.custom_minimum_size = Vector2(360, 0)
	overlay.add_child(overlay_box)
	overlay_title = _label("", 30, Color.WHITE)
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_box.add_child(overlay_title)
	overlay_body = _label("", 16, Color(0.9, 0.9, 0.9))
	overlay_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_box.add_child(overlay_body)
	overlay.visible = false


func _process(delta: float) -> void:
	if stats.visible:
		stats.text = "%d fps   %d draw calls   %s quality" % [Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), quality_name]
	if message_time > 0.0:
		message_time -= delta
		message.visible = message_time > 0.0


## Hides the keyboard list and words the screens for tapping instead.
func use_touch() -> void:
	touch = true
	controls.visible = false


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
	progress_label.text = "Progress %d%%" % shown
	progress_bar.value = shown
	patches_label.text = "%d patches left" % remaining
	objective.text = ("[x]" if percent >= 99.0 else "[  ]") + " Cut 99% of the grass"
	speed_label.text = "%d" % roundi(mph_value)
	if on_foot:
		blades_label.text = "Weed eater"
		blades_label.add_theme_color_override("font_color", ACCENT)
	else:
		blades_label.text = "Blades ON" if blades_on else "Blades OFF"
		blades_label.add_theme_color_override("font_color", ACCENT if blades_on else Color(0.95, 0.6, 0.4))
	time_label.text = "Time %s   Best %s" % [format_time(elapsed), format_time(best) if best > 0.0 else "--:--"]


## Shows the lawn texture as a map. Positions are fractions (0..1) across it.
func set_minimap(texture: Texture2D) -> void:
	minimap.texture = texture
	# Keep the yard's shape: 150 px tall, as wide as its proportions allow.
	minimap.custom_minimum_size = Vector2(150.0 * texture.get_width() / texture.get_height(), 150.0)
	minimap.visible = true


## `heading` is the mower's facing in radians, 0 meaning up the map.
func update_minimap(mower_at: Vector2, heading: float, walker_at: Vector2) -> void:
	minimap_mower = mower_at
	minimap_heading = heading
	minimap_walker = walker_at
	minimap.queue_redraw()


func _draw_minimap_markers() -> void:
	var size := minimap.size
	minimap.draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.5), false, 1.5)
	if minimap_mower.x >= 0.0:
		var at := minimap_mower * size
		var points := PackedVector2Array([Vector2(0, -7), Vector2(5, 5), Vector2(-5, 5)])
		for i in points.size():
			points[i] = at + points[i].rotated(minimap_heading)
		minimap.draw_colored_polygon(points, Models.ORANGE)
		minimap.draw_polyline(points + PackedVector2Array([points[0]]), Color.BLACK, 1.0)
	if minimap_walker.x >= 0.0:
		var at := minimap_walker * size
		minimap.draw_circle(at, 4.5, Color.BLACK)
		minimap.draw_circle(at, 3.0, Color.WHITE)


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


func _panel(root: Control, preset: int, offset: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE)
	match preset:
		Control.PRESET_TOP_RIGHT:
			panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_BOTTOM_LEFT:
			panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_BOTTOM_RIGHT:
			panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_CENTER_BOTTOM:
			panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
			panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_CENTER:
			panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
			panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.position += offset
	return panel


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

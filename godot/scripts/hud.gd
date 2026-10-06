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
var overlay: PanelContainer
var overlay_title: Label
var overlay_body: Label


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

	var controls := _panel(root, Control.PRESET_BOTTOM_LEFT, Vector2(20, -20))
	controls.add_child(_label("W/S  Drive and reverse\nA/D  Steer\nB  Blades on/off\nP / Esc  Pause\nR  Restart", 14, Color(0.9, 0.9, 0.9)))

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


func update_play(percent: float, mph_value: float, blades_on: bool, elapsed: float, best: float) -> void:
	var shown := floorf(percent)
	progress_label.text = "Progress %d%%" % shown
	progress_bar.value = shown
	objective.text = ("[x]" if percent >= 99.0 else "[  ]") + " Cut 99% of the grass"
	speed_label.text = "%d" % roundi(mph_value)
	blades_label.text = "Blades ON" if blades_on else "Blades OFF"
	blades_label.add_theme_color_override("font_color", ACCENT if blades_on else Color(0.95, 0.6, 0.4))
	time_label.text = "Time %s   Best %s" % [format_time(elapsed), format_time(best) if best > 0.0 else "--:--"]


func show_paused(paused: bool) -> void:
	overlay.visible = paused
	overlay_title.text = "Paused"
	overlay_body.text = "Press P or Esc to keep mowing."


func show_finished(time: float, best: float, is_record: bool, saved: bool) -> void:
	overlay.visible = true
	overlay_title.text = "Lawn done!"
	var lines := ["Time %s" % format_time(time)]
	lines.append("New personal best!" if is_record else "Personal best %s" % format_time(best))
	if is_record and not saved:
		lines.append("This browser blocked saving, so the record lasts this session.")
	lines.append("Press R to mow again.")
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

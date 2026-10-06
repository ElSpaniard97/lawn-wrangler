class_name TouchControls
extends CanvasLayer
## On-screen buttons for phones and tablets. Each one presses the same
## input action as its keyboard key, so the game itself does not care which
## was used, and several can be held at once (steer while driving). Hidden
## until the yard sees a touch screen.

const FILL := Color(0.05, 0.08, 0.06, 0.45)
const FILL_PRESSED := Color(0.55, 0.85, 0.35, 0.6)
## Action, label, radius, corner (0 top left, 1 bottom left, 2 bottom right),
## and where the centre sits from that corner.
const BUTTONS := [
	["steer_left", "<", 70, 1, Vector2(110, -110)],
	["steer_right", ">", 70, 1, Vector2(270, -110)],
	["accelerate", "GO", 75, 2, Vector2(-235, -120)],
	["reverse", "BACK", 52, 2, Vector2(-385, -85)],
	["hop", "HOP", 45, 2, Vector2(-75, -225)],
	["toggle_blades", "BLADES", 40, 2, Vector2(-75, -325)],
	["pause", "PAUSE", 38, 0, Vector2(60, 185)],
	["restart", "RESTART", 38, 0, Vector2(60, 275)],
	["highlight", "FIND", 38, 0, Vector2(60, 365)],
	["mute", "SOUND", 38, 0, Vector2(60, 455)],
]
## Steering and driving keep working when a thumb slides onto them.
const SLIDE_ON := ["steer_left", "steer_right", "accelerate", "reverse"]

var buttons := {}


func _ready() -> void:
	layer = 2
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	for spec in BUTTONS:
		_add_button(spec[0], spec[1], spec[2])
	get_viewport().size_changed.connect(layout)
	layout()


## Keeps buttons pinned to their corners whatever the screen shape.
func layout() -> void:
	var size := get_viewport().get_visible_rect().size
	var corners := [Vector2.ZERO, Vector2(0, size.y), size]
	for spec in BUTTONS:
		var radius: float = spec[2]
		buttons[spec[0]].position = corners[spec[3]] + spec[4] - Vector2(radius, radius)


func _add_button(action: String, text: String, radius: int) -> void:
	var button := TouchScreenButton.new()
	button.name = action
	button.action = action
	button.texture_normal = circle(radius, FILL)
	button.texture_pressed = circle(radius, FILL_PRESSED)
	var shape := CircleShape2D.new()
	shape.radius = radius
	button.shape = shape
	button.shape_centered = true
	button.passby_press = SLIDE_ON.has(action)
	var label := Label.new()
	label.text = text
	label.size = Vector2(radius * 2, radius * 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 34 if text.length() == 1 else (18 if radius > 45 else 13))
	label.add_theme_color_override("font_color", Color.WHITE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	add_child(button)
	buttons[action] = button


## A soft-edged disc with a light rim, drawn pixel by pixel.
static func circle(radius: int, fill: Color) -> ImageTexture:
	var size := radius * 2
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var distance := Vector2(x + 0.5 - radius, y + 0.5 - radius).length()
			var edge := clampf(radius - distance, 0.0, 1.0)
			var color := Color(1, 1, 1, 0.7) if distance > radius - 3.0 else fill
			image.set_pixel(x, y, Color(color, color.a * edge))
	return ImageTexture.create_from_image(image)

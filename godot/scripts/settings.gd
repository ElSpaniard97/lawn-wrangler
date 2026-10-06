class_name Settings
extends RefCounted
## Player settings kept in the browser: graphics quality and sound on/off.
## Saved as a small JSON object; anything unexpected in it is ignored and
## the default used instead, so a tampered file cannot break the game.

const QUALITIES := ["low", "medium", "high"]
const LABELS := {"low": "Low", "medium": "Medium", "high": "High"}

## Tests point this somewhere else so they never touch a player's settings.
static var default_path := "user://settings.json"

var path: String
var quality := "high"
var muted := false


func _init(file := "") -> void:
	path = file if file != "" else default_path
	# Phones and tablets start on Low; desktops start on High.
	if DisplayServer.is_touchscreen_available():
		quality = "low"


func load_settings() -> void:
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		return
	var data: Dictionary = json.data
	var saved_quality = data.get("quality")
	if saved_quality is String and QUALITIES.has(saved_quality):
		quality = saved_quality
	var saved_muted = data.get("muted")
	if saved_muted is bool:
		muted = saved_muted


func save() -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"quality": quality, "muted": muted}))
	return true


## Moves to the next quality level, wrapping from High back to Low.
func next_quality() -> String:
	quality = QUALITIES[(QUALITIES.find(quality) + 1) % QUALITIES.size()]
	return quality

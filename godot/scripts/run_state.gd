class_name RunState
extends Node
## Timer, pause, finish and personal best. Keeps running while the game is
## paused so the pause key still works.

signal finished_run(time: float, is_record: bool)

const SAVE_PATH := "user://best_times.json"
const RECORD_KEY := "yard_01"

var elapsed := 0.0
var finished := false
var best := 0.0
var storage_ok := true
## Tests point this somewhere else so they never touch a real record.
static var default_path := SAVE_PATH
var save_path := default_path


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	best = load_best(save_path)


func _process(delta: float) -> void:
	if not get_tree().paused and not finished:
		elapsed += delta


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not finished:
		get_tree().paused = true


func toggle_pause() -> void:
	if not finished:
		get_tree().paused = not get_tree().paused


func finish_run() -> void:
	if finished:
		return
	finished = true
	var is_record := best <= 0.0 or elapsed < best
	if is_record:
		best = elapsed
		storage_ok = save_best(best, save_path)
	finished_run.emit(elapsed, is_record)


## Reads the saved best time. The file is plain JSON holding numbers only;
## anything else (edited, corrupt or from a future version) is ignored.
static func load_best(path := SAVE_PATH) -> float:
	if not FileAccess.file_exists(path):
		return 0.0
	var text := FileAccess.get_file_as_string(path)
	if text.length() > 4096:
		return 0.0
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return 0.0
	var data: Dictionary = json.data
	var value = data.get(RECORD_KEY)
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		return 0.0
	var seconds := float(value)
	return seconds if is_finite(seconds) and seconds > 0.0 else 0.0


static func save_best(seconds: float, path := SAVE_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({RECORD_KEY: seconds}))
	return true

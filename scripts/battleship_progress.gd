extends Node

const SAVE_PATH := "user://battleship_progress.json"

var data: Dictionary = {
	"levels": {},
	"unlocked": ["l1"],
	"last_fleet_signature": ""
}


func _init() -> void:
	_load()


func get_stars(level_id: String) -> int:
	var levels: Dictionary = data.get("levels", {})
	var level_data: Dictionary = levels.get(level_id, {})
	return int(level_data.get("stars", 0))


func get_last_fleet_signature() -> String:
	return String(data.get("last_fleet_signature", ""))


func set_last_fleet_signature(signature: String) -> void:
	data["last_fleet_signature"] = signature
	_save()


func set_result(level_id: String, stars: int, accuracy: float) -> void:
	var levels: Dictionary = data.get("levels", {})
	var previous: Dictionary = levels.get(level_id, {})
	var best_stars: int = maxi(stars, int(previous.get("stars", 0)))
	var best_accuracy: float = maxf(accuracy, float(previous.get("best_accuracy", 0.0)))
	levels[level_id] = {
		"stars": best_stars,
		"best_accuracy": best_accuracy
	}
	data["levels"] = levels
	_save()


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	data = parsed


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "\t"))

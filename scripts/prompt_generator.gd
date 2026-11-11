extends RefCounted

const GridMath = preload("res://scripts/grid_math.gd")

const NUMBER_WORDS := {
	1: "one",
	2: "two",
	3: "three"
}

var cells := 6
var landmarks: Array = []
var blocked: Dictionary = {}
var candidates: Array = []
var used_prompts: Dictionary = {}
var last_target := Vector2i(-999, -999)


func setup(p_cells: int, p_landmarks: Array, p_blocked: Dictionary) -> void:
	cells = p_cells
	landmarks = p_landmarks.duplicate(true)
	blocked = p_blocked.duplicate()
	used_prompts.clear()
	last_target = Vector2i(-999, -999)
	refresh_candidates()


func reset_round() -> void:
	used_prompts.clear()
	last_target = Vector2i(-999, -999)


func refresh_candidates() -> void:
	candidates.clear()
	var landmark_cells := _landmark_cells()

	for landmark in landmarks:
		var base: Vector2i = landmark["cell"]
		var name: String = String(landmark["name"])
		for direction in _directions():
			var delta: Vector2i = direction["delta"]
			var phrase: String = direction["phrase"]
			for distance_value in [1, 2, 3]:
				var distance := int(distance_value)
				var target: Vector2i = base + delta * distance
				if not _is_fireable(target, landmark_cells):
					continue
				var text := "Fire %s %s the %s." % [_amount_text(distance), phrase, name]
				candidates.append({
					"text": text,
					"target": target,
					"landmark": String(landmark["id"]),
					"kind": String(direction["key"])
				})

	_add_between_candidates(landmark_cells)


func get_candidate_cells() -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	for candidate in candidates:
		var target: Vector2i = candidate["target"]
		if seen.has(target):
			continue
		seen[target] = true
		result.append(target)
	return result


func pick_instruction(ship_cells: Array, fired: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var available: Array = []
	for candidate in candidates:
		if fired.has(candidate["target"]):
			continue
		available.append(candidate)

	if available.is_empty():
		return {}

	var ship_targets: Dictionary = {}
	for cell in ship_cells:
		ship_targets[cell] = true

	var ship_pool: Array = []
	for candidate in available:
		if ship_targets.has(candidate["target"]):
			ship_pool.append(candidate)

	var pool: Array = available
	if not ship_pool.is_empty():
		pool = ship_pool

	var fresh: Array = []
	for candidate in pool:
		if not used_prompts.has(candidate["text"]):
			fresh.append(candidate)
	if fresh.is_empty():
		used_prompts.clear()
		fresh = pool

	for attempt in 20:
		var chosen: Dictionary = fresh[rng.randi_range(0, fresh.size() - 1)]
		var target: Vector2i = chosen["target"]
		if target != last_target or fresh.size() == 1:
			last_target = target
			used_prompts[chosen["text"]] = true
			return chosen

	var fallback: Dictionary = fresh[0]
	last_target = fallback["target"]
	used_prompts[fallback["text"]] = true
	return fallback


func _directions() -> Array:
	return [
		{"key": "above", "delta": Vector2i(0, 1), "phrase": "above"},
		{"key": "below", "delta": Vector2i(0, -1), "phrase": "below"},
		{"key": "left", "delta": Vector2i(-1, 0), "phrase": "to the left of"},
		{"key": "right", "delta": Vector2i(1, 0), "phrase": "to the right of"}
	]


func _amount_text(distance: int) -> String:
	var word: String = String(NUMBER_WORDS.get(distance, str(distance)))
	if distance == 1:
		return "%s square" % word
	return "%s squares" % word


func _landmark_cells() -> Dictionary:
	var result: Dictionary = {}
	for landmark in landmarks:
		result[landmark["cell"]] = true
	return result


func _is_fireable(cell: Vector2i, landmark_cells: Dictionary) -> bool:
	if not GridMath.in_bounds(cell, cells):
		return false
	if blocked.has(cell):
		return false
	if landmark_cells.has(cell):
		return false
	return true


func _add_between_candidates(landmark_cells: Dictionary) -> void:
	for i in range(landmarks.size()):
		for j in range(i + 1, landmarks.size()):
			var first: Dictionary = landmarks[i]
			var second: Dictionary = landmarks[j]
			var first_cell: Vector2i = first["cell"]
			var second_cell: Vector2i = second["cell"]
			var middle := Vector2i(-999, -999)
			if first_cell.x == second_cell.x and abs(first_cell.y - second_cell.y) == 2:
				middle = Vector2i(first_cell.x, int((first_cell.y + second_cell.y) / 2))
			elif first_cell.y == second_cell.y and abs(first_cell.x - second_cell.x) == 2:
				middle = Vector2i(int((first_cell.x + second_cell.x) / 2), first_cell.y)
			if middle == Vector2i(-999, -999):
				continue
			if not _is_fireable(middle, landmark_cells):
				continue
			candidates.append({
				"text": "Fire at the square between the %s and the %s." % [
					String(first["name"]),
					String(second["name"])
				],
				"target": middle,
				"landmark": String(first["id"]),
				"kind": "between"
			})

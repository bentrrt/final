extends SceneTree

const GridMath = preload("res://scripts/grid_math.gd")
const PromptGenerator = preload("res://scripts/prompt_generator.gd")
const FleetPlacer = preload("res://scripts/fleet_placer.gd")

const ORIGIN := Vector2(500, 80)
const BOARD_PIXELS := 960.0
const CELLS := 8

var failures := 0


func _init() -> void:
	_test_grid_math()
	_test_prompt_generation()
	_test_fleet_placement()
	print("TESTS DONE. failures=%d" % failures)
	quit(1 if failures > 0 else 0)


func _test_grid_math() -> void:
	_check(GridMath.world_to_cell(Vector2(1050, 160), ORIGIN, BOARD_PIXELS, CELLS) == Vector2i(4, 7), "grey wreck maps to E8")
	_check(GridMath.world_to_cell(Vector2(1090, 520), ORIGIN, BOARD_PIXELS, CELLS) == Vector2i(4, 4), "white wreck maps to E5")
	_check(GridMath.world_to_cell(Vector2(1410, 360), ORIGIN, BOARD_PIXELS, CELLS) == Vector2i(7, 5), "rocks map to H6")
	_check(GridMath.in_bounds(Vector2i(0, 0), CELLS), "A1 is in bounds")
	_check(not GridMath.in_bounds(Vector2i(8, 0), CELLS), "I1 is out of bounds")
	_check(GridMath.point_in_rect(Vector2(580, 320), [300, 40, 500, 510]), "island rect blocks A5 center")


func _test_prompt_generation() -> void:
	var fixture := _build_fixture()
	var generator = fixture["generator"]
	var blocked: Dictionary = fixture["blocked"]
	var landmark_cells: Dictionary = {}
	var landmarks: Array = fixture["landmarks"]
	for landmark in landmarks:
		landmark_cells[landmark["cell"]] = true

	var candidates: Array = generator.candidates
	_check(not candidates.is_empty(), "prompt generator produced candidates")
	_check(candidates.size() >= 10, "prompt generator produced a useful number of candidates")

	var found_between := false
	for candidate in candidates:
		var target: Vector2i = candidate["target"]
		_check(GridMath.in_bounds(target, CELLS), "candidate target is in bounds: %s" % str(target))
		_check(not blocked.has(target), "candidate target is not blocked: %s" % str(target))
		_check(not landmark_cells.has(target), "candidate target is not a landmark: %s" % str(target))
		_check(not String(candidate["text"]).is_empty(), "candidate has prompt text")
		if String(candidate["kind"]) == "between":
			found_between = true
			_check(target == Vector2i(4, 5), "between prompt targets E6")
	_check(found_between, "between prompt exists for small rocks and white wreck")

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var all_cells: Array = generator.get_candidate_cells()
	for index in range(200):
		var instruction: Dictionary = generator.pick_instruction(all_cells, {}, rng)
		_check(not instruction.is_empty(), "pick_instruction returned an instruction")
		if instruction.is_empty():
			continue
		var target: Vector2i = instruction["target"]
		_check(GridMath.in_bounds(target, CELLS), "picked target in bounds")
		_check(not blocked.has(target), "picked target not blocked")
		_check(not landmark_cells.has(target), "picked target not a landmark")
		_check(not String(instruction["text"]).is_empty(), "picked instruction has text")

	var one_ship_cell: Vector2i = all_cells[0]
	for index in range(50):
		var ship_instruction: Dictionary = generator.pick_instruction([one_ship_cell], {}, rng)
		_check(not ship_instruction.is_empty(), "ship-only instruction exists")
		if not ship_instruction.is_empty():
			_check(ship_instruction["target"] == one_ship_cell, "prompt targets a ship cell when one is available")


func _test_fleet_placement() -> void:
	var fixture := _build_fixture()
	var generator = fixture["generator"]
	var allowed: Array = generator.get_candidate_cells()
	var ship_lengths: Array = [2, 3, 3]
	var rng := RandomNumberGenerator.new()
	rng.seed = 77

	for attempt in range(100):
		var placed: Array = FleetPlacer.place_fleet(allowed, ship_lengths, rng)
		_check(placed.size() == ship_lengths.size(), "fleet placement returned all ships")
		if placed.size() != ship_lengths.size():
			continue
		var used: Dictionary = {}
		var allowed_lookup: Dictionary = {}
		for cell in allowed:
			allowed_lookup[cell] = true
		for index in range(placed.size()):
			var cells: Array = placed[index]
			_check(cells.size() == int(ship_lengths[index]), "ship %d has the right length" % index)
			for cell in cells:
				_check(allowed_lookup.has(cell), "ship cell is on an allowed square")
				_check(not used.has(cell), "ship cells do not overlap")
				used[cell] = true


func _build_fixture() -> Dictionary:
	var file := FileAccess.open("res://data/listening.json", FileAccess.READ)
	if file == null:
		_check(false, "listening.json opens")
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_check(false, "listening.json parses as a dictionary")
		return {}
	var root: Dictionary = parsed
	var levels: Array = root.get("levels", [])
	var level: Dictionary = levels[0]

	var prepared: Array = []
	var landmark_values: Array = level.get("landmarks", [])
	for item in landmark_values:
		var data: Dictionary = item
		var world_array: Array = data["world"]
		var world := Vector2(float(world_array[0]), float(world_array[1]))
		prepared.append({
			"id": String(data["id"]),
			"name": String(data["name"]),
			"world": world,
			"cell": GridMath.world_to_cell(world, ORIGIN, BOARD_PIXELS, CELLS),
			"color": Color.from_string(String(data.get("color", "#ffd166")), Color.WHITE)
		})

	var blocked: Dictionary = {}
	var rect_values: Array = level.get("blocked_rects", [])
	for rect_value in rect_values:
		var rect: Array = rect_value
		for row in range(CELLS):
			for column in range(CELLS):
				var cell := Vector2i(column, row)
				var center := GridMath.cell_center(cell, ORIGIN, BOARD_PIXELS, CELLS)
				if GridMath.point_in_rect(center, rect):
					blocked[cell] = true

	var generator = PromptGenerator.new()
	generator.setup(CELLS, prepared, blocked)
	return {
		"landmarks": prepared,
		"blocked": blocked,
		"generator": generator
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: %s" % message)

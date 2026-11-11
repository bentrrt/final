extends Node2D

const GridMath = preload("res://scripts/grid_math.gd")
const PromptGenerator = preload("res://scripts/prompt_generator.gd")
const FleetPlacer = preload("res://scripts/fleet_placer.gd")
const BattleshipBoard = preload("res://scripts/battleship_board.gd")
const BattleshipHud = preload("res://scripts/battleship_hud.gd")
const TtsService = preload("res://scripts/tts_service.gd")
const BattleshipProgressScript = preload("res://scripts/battleship_progress.gd")

@export var level_id := "l1"
@export var board_origin := Vector2(500, 80)
@export var board_pixel_size := 960.0

var level: Dictionary = {}
var board
var hud
var tts
var generator
var progress
var ships: Array = []
var ship_by_cell: Dictionary = {}
var fired: Dictionary = {}
var hits_count := 0
var shots := 0
var hulls_lost := 0
var hulls_total := 3
var state := "intro"
var current_prompt: Dictionary = {}
var speak_serial := 0
var last_fleet_signature := ""
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	level = _load_level(level_id)
	if level.is_empty():
		push_error("Could not load level '%s'." % level_id)
		return

	board = BattleshipBoard.new()
	board.board_origin = board_origin
	board.board_pixel_size = board_pixel_size
	board.cell_clicked.connect(_on_cell_clicked)
	add_child(board)

	tts = TtsService.new()
	add_child(tts)

	progress = get_node_or_null("/root/BattleshipProgress")
	if progress == null:
		progress = BattleshipProgressScript.new()
		progress.name = "BattleshipProgress"
		add_child(progress)
	last_fleet_signature = String(progress.get_last_fleet_signature())

	hud = BattleshipHud.new()
	add_child(hud)
	hud.replay_pressed.connect(_on_replay)
	hud.restart_pressed.connect(_on_restart)
	hud.subtitle_toggled.connect(_on_subtitle_toggled)
	hud.vocab_started.connect(_on_vocab_started)
	hud.vocab_hear_pressed.connect(_on_vocab_hear)

	_prepare_level()


func _prepare_level() -> void:
	var cell_count := int(level.get("board", 6))
	hulls_total = 3

	var prepared: Array = []
	var landmark_values: Array = level.get("landmarks", [])
	for item in landmark_values:
		var landmark_data: Dictionary = item
		var world_array: Array = landmark_data.get("world", [0, 0])
		var world := Vector2(float(world_array[0]), float(world_array[1]))
		var cell := GridMath.world_to_cell(world, board_origin, board_pixel_size, cell_count)
		if not GridMath.in_bounds(cell, cell_count):
			push_warning("Landmark '%s' is outside the board." % String(landmark_data.get("id", "")))
			continue
		prepared.append({
			"id": String(landmark_data.get("id", "")),
			"name": String(landmark_data.get("name", "")),
			"world": world,
			"cell": cell,
			"color": Color.from_string(String(landmark_data.get("color", "#ffd166")), Color("#ffd166"))
		})

	var blocked: Dictionary = {}
	var rect_values: Array = level.get("blocked_rects", [])
	for rect_value in rect_values:
		var rect: Array = rect_value
		for row in range(cell_count):
			for column in range(cell_count):
				var cell := Vector2i(column, row)
				var center := GridMath.cell_center(cell, board_origin, board_pixel_size, cell_count)
				if GridMath.point_in_rect(center, rect):
					blocked[cell] = true

	board.configure(cell_count, prepared, blocked)
	generator = PromptGenerator.new()
	generator.setup(cell_count, prepared, blocked)

	hud.set_voice(String(tts.voice_name), bool(tts.available))
	hud.set_hulls(hulls_total, hulls_total)
	hud.set_ships_remaining((level.get("ships", []) as Array).size())
	hud.set_accuracy(0.0)
	hud.show_vocab(level.get("vocab", []))
	state = "intro"


func _start_round() -> void:
	if generator == null:
		return

	speak_serial += 1
	rng.randomize()
	generator.reset_round()
	tts.stop()
	state = "playing"
	hulls_lost = 0
	shots = 0
	hits_count = 0
	fired.clear()
	ship_by_cell.clear()
	ships.clear()
	current_prompt = {}
	board.reset_marks()
	board.set_input_enabled(false)

	var allowed: Array = generator.get_candidate_cells()
	var ship_lengths: Array = level.get("ships", [2, 3, 3])
	var placed: Array = FleetPlacer.place_fleet(allowed, ship_lengths, rng)
	if placed.is_empty():
		hud.set_status("No room for the fleet. Move the board or landmarks and try again.")
		return

	var signature := _fleet_signature(placed)
	var retries := 0
	while signature == last_fleet_signature and retries < 12:
		var alternative: Array = FleetPlacer.place_fleet(allowed, ship_lengths, rng)
		if alternative.is_empty():
			break
		placed = alternative
		signature = _fleet_signature(placed)
		retries += 1
	last_fleet_signature = signature
	if progress != null:
		progress.set_last_fleet_signature(signature)

	var colors: Array = ["#e85d5d", "#5aa9e6", "#6fcf7a", "#f0c75e", "#b48cff"]
	for index in range(placed.size()):
		var cells: Array = placed[index]
		var color := Color.from_string(String(colors[index % colors.size()]), Color.WHITE)
		var ship := {
			"cells": cells,
			"hits": 0,
			"sunk": false,
			"color": color
		}
		ships.append(ship)
		for cell in cells:
			ship_by_cell[cell] = ship

	hud.hide_result()
	hud.hide_vocab()
	hud.set_hulls(hulls_total, hulls_total)
	hud.set_ships_remaining(ships.size())
	hud.set_accuracy(0.0)
	_next_prompt()


func _next_prompt() -> void:
	if state == "ended":
		return

	var remaining_ship_cells: Array = []
	for cell in ship_by_cell.keys():
		if not fired.has(cell):
			remaining_ship_cells.append(cell)

	current_prompt = generator.pick_instruction(remaining_ship_cells, fired, rng)
	if current_prompt.is_empty():
		hud.set_status("No prompts left. Press New round.")
		return

	hud.set_prompt(String(current_prompt["text"]))
	_speak_current()


func _speak_current() -> void:
	if current_prompt.is_empty():
		return

	speak_serial += 1
	var serial := speak_serial
	state = "speaking"
	board.set_input_enabled(false)
	hud.set_status("Listen to the captain...")
	tts.speak(String(current_prompt.get("text", "")), float(level.get("tts_rate", 0.9)))

	if not tts.available:
		hud.set_status("Audio unavailable. Read the prompt, then choose a square.")
		hud.force_subtitle_visible()
		_ready_for_shot()
		return

	var started_speaking := false
	var waited := 0.0
	while waited < 2.0:
		if serial != speak_serial:
			return
		if tts.is_speaking():
			started_speaking = true
			break
		await get_tree().create_timer(0.1).timeout
		waited += 0.1

	if not started_speaking:
		hud.set_status("Audio did not start. Read the prompt, then choose a square.")
		hud.force_subtitle_visible()
		_ready_for_shot()
		return

	while tts.is_speaking():
		if serial != speak_serial:
			return
		await get_tree().create_timer(0.1).timeout

	if serial != speak_serial:
		return
	_ready_for_shot()


func _ready_for_shot() -> void:
	if state == "ended":
		return
	state = "awaiting"
	board.set_input_enabled(true)
	hud.set_status("Your turn. Click the square.")


func _on_cell_clicked(cell: Vector2i) -> void:
	if state != "awaiting":
		return
	if fired.has(cell):
		hud.set_status("Already fired there. Choose another square.")
		return

	fired[cell] = true
	shots += 1
	var ship: Dictionary = ship_by_cell.get(cell, {})
	if not ship.is_empty():
		hits_count += 1
		board.mark_hit(cell)
		ship["hits"] = int(ship["hits"]) + 1
		var ship_cells: Array = ship["cells"]
		if int(ship["hits"]) >= ship_cells.size():
			ship["sunk"] = true
			var ship_color: Color = ship["color"]
			board.mark_sunk(ship_cells, ship_color)
			hud.set_status("Direct hit! That ship is sinking.")
			hud.set_ships_remaining(_remaining_ships())
		else:
			hud.set_status("Direct hit! Keep firing.")
		hud.set_accuracy(_accuracy())
		if _remaining_ships() == 0:
			_end_round(true)
			return
		state = "resolving"
		board.set_input_enabled(false)
		await get_tree().create_timer(0.7).timeout
		_next_prompt()
	else:
		board.mark_miss(cell)
		hud.set_status("Miss! The enemy fires back...")
		hud.set_accuracy(_accuracy())
		state = "resolving"
		board.set_input_enabled(false)
		await get_tree().create_timer(0.5).timeout
		_enemy_turn()


func _enemy_turn() -> void:
	if state == "ended":
		return

	if rng.randf() < 0.35:
		hulls_lost += 1
		hud.set_hulls(hulls_total - hulls_lost, hulls_total)
		hud.set_status("The enemy hit your hull!")
		if hulls_lost >= hulls_total:
			_end_round(false)
			return
	else:
		hud.set_status("The enemy missed. Next order incoming...")

	await get_tree().create_timer(0.9).timeout
	_next_prompt()


func _end_round(won: bool) -> void:
	state = "ended"
	speak_serial += 1
	tts.stop()
	board.set_input_enabled(false)

	var accuracy := _accuracy()
	var stars := 0
	if won:
		if hulls_lost == 0 and accuracy >= 0.60:
			stars = 3
		elif hulls_lost <= 1:
			stars = 2
		else:
			stars = 1
		if progress != null:
			progress.set_result(level_id, stars, accuracy)

	hud.set_ships_remaining(_remaining_ships())
	hud.set_accuracy(accuracy)
	await get_tree().create_timer(0.65).timeout
	hud.show_result(won, stars, accuracy, hulls_lost)


func _on_replay() -> void:
	if current_prompt.is_empty() or state == "ended":
		return
	_speak_current()


func _on_restart() -> void:
	hud.hide_result()
	_start_round()


func _on_subtitle_toggled(enabled: bool) -> void:
	hud.set_subtitle_visible(enabled)


func _on_vocab_started() -> void:
	_start_round()


func _on_vocab_hear() -> void:
	var words: Array = level.get("vocab", [])
	var text := "Listen and repeat. "
	for item in words:
		var word_data: Dictionary = item
		text += String(word_data.get("say", word_data.get("word", ""))) + ". "
	tts.speak(text, 0.85)


func _fleet_signature(placed: Array) -> String:
	var cells: Array = []
	for ship in placed:
		for cell in ship:
			cells.append("%d:%d" % [cell.x, cell.y])
	cells.sort()
	var signature := ""
	for cell_text in cells:
		if not signature.is_empty():
			signature += "|"
		signature += String(cell_text)
	return signature


func _remaining_ships() -> int:
	var count := 0
	for ship in ships:
		if not bool(ship["sunk"]):
			count += 1
	return count


func _accuracy() -> float:
	if shots == 0:
		return 0.0
	return float(hits_count) / float(shots)


func _load_level(id: String) -> Dictionary:
	var file := FileAccess.open("res://data/listening.json", FileAccess.READ)
	if file == null:
		push_error("Cannot open res://data/listening.json")
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("listening.json is not a dictionary.")
		return {}

	var root: Dictionary = parsed
	var level_values: Array = root.get("levels", [])
	for item in level_values:
		var level_data: Dictionary = item
		if String(level_data.get("id", "")) == id:
			return level_data

	push_error("Level '%s' not found in listening.json." % id)
	return {}

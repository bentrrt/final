extends Node2D

const DATA_PATH := "res://data/sentences.json"
const TRAIN_START_X := 60.0

var data: Dictionary = {}
var level_index := 0
var round_index := 0
var trains: Array = []
var train_colors := [Color(0.23, 0.74, 0.78), Color(0.86, 0.32, 0.32)]
var unified_color := Color(0.85, 0.72, 0.35)
var mistakes := 0
var hints_used := 0

@onready var feedback: Label = $HUD/Feedback
@onready var round_label: Label = $HUD/RoundLabel
@onready var depart_button: Button = $HUD/DepartButton
@onready var train_nodes: Array = [$Track1/Train1, $Track2/Train2, $Track3/Train3]

@onready var hint_button: Button = $HUD/HintButton
@onready var hint_overlay: Control = $HUD/HintOverlay
@onready var hint_dim: ColorRect = $HUD/HintOverlay/Dim
@onready var hint_close_button: Button = $HUD/HintOverlay/Wrap/Panel/MarginContainer/VBoxContainer/Buttons/CloseButton

func _ready() -> void:
	data = _load_json(DATA_PATH)
	depart_button.pressed.connect(_on_depart_pressed)
	hint_button.pressed.connect(_show_tag_hints)
	hint_dim.gui_input.connect(_on_hint_dim_input)
	hint_close_button.pressed.connect(_hide_tag_hints)
	_start_round()

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open %s" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null:
		push_error("Invalid JSON in %s" % path)
		return {}
	return parsed

func _level() -> Dictionary:
	return data["levels"][level_index]

func _round() -> Dictionary:
	return _level()["rounds"][round_index]

func _start_round() -> void:
	_clear_trains()
	var round_data := _round()
	round_label.text = "Round %d" % (round_index + 1)
	feedback.text = ""
	var train_items: Array = round_data["trains"]
	for i in range(train_items.size()):
		var item: Dictionary = train_items[i]
		var color: Color = train_colors[i % train_colors.size()]
		var train = train_nodes[i]
		train.visible = true
		train.position.x = TRAIN_START_X
		train.setup(item, color, i)
		trains.append(train)
	depart_button.disabled = false

func _clear_trains() -> void:
	for t in train_nodes:
		if is_instance_valid(t):
			t.visible = false
	trains.clear()

func _on_depart_pressed() -> void:
	depart_button.disabled = true
	var all_correct := true
	var first_bad_train := -1
	for train in trains:
		train.reset_marks()
	for ti in range(trains.size()):
		var train = trains[ti]
		var answer: Array = train.item["answer"]
		var words: Array = train.words()
		var bad := -1
		for i in range(words.size()):
			if words[i] != answer[i]:
				bad = i
				break
		if bad >= 0:
			all_correct = false
			if first_bad_train < 0:
				first_bad_train = ti
			train.mark_wrong(bad)
		else:
			train.mark_correct(unified_color)
	if all_correct:
		feedback.text = "All trains depart."
		_depart_all()
	else:
		mistakes += 1
		var item: Dictionary = trains[first_bad_train].item
		feedback.text = item.get("hint", "Check the marked car.")
		depart_button.disabled = false

func _depart_all() -> void:
	for train in trains:
		var tween := create_tween()
		tween.tween_property(train, "position:x", train.position.x + 2200, 0.9)
		tween.tween_callback(_finish_depart.bind(train))
	await get_tree().create_timer(1.0).timeout
	_next_round()

func _finish_depart(train) -> void:
	train.visible = false
	train.position.x = TRAIN_START_X

func _next_round() -> void:
	round_index += 1
	if round_index >= _level()["rounds"].size():
		round_index = 0
		level_index += 1
		if level_index >= data["levels"].size():
			feedback.text = "Level complete."
			return
	_start_round()

func _show_tag_hints() -> void:
	hint_overlay.visible = true

func _hide_tag_hints() -> void:
	hint_overlay.visible = false

func _on_hint_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_hide_tag_hints()

func _input(event: InputEvent) -> void:
	if hint_overlay != null and hint_overlay.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_hide_tag_hints()

extends CanvasLayer

signal finished

@onready var intro_box: VBoxContainer = %IntroBox
@onready var title_label: Label = %Title
@onready var word_label: Label = %Word
@onready var group_label: Label = %Group
@onready var meaning_label: Label = %Meaning
@onready var examples_label: Label = %Examples
@onready var continue_button: Button = %ContinueButton

@onready var practice_box: VBoxContainer = %PracticeBox
@onready var progress_label: Label = %ProgressLabel
@onready var sentence_label: Label = %Sentence
@onready var choices_box: HBoxContainer = %Choices
@onready var feedback_label: Label = %FeedbackLabel
@onready var next_button: Button = %NextButton

@onready var done_box: VBoxContainer = %DoneBox
@onready var done_title: Label = %DoneTitle
@onready var score_label: Label = %Score
@onready var close_button: Button = %CloseButton

var particle: Dictionary = {}
var practice_index := 0
var correct_count := 0
var answered := false
var closed := false
var choice_rng := RandomNumberGenerator.new()
var last_choice_order := ""

func _ready() -> void:
	choice_rng.randomize()
	continue_button.pressed.connect(_start_practice)
	next_button.pressed.connect(_next_practice)
	close_button.pressed.connect(_close)

func start(data: Dictionary) -> void:
	particle = data
	practice_index = 0
	correct_count = 0
	answered = false
	closed = false
	_show_intro()

func _show_intro() -> void:
	intro_box.visible = true
	practice_box.visible = false
	done_box.visible = false
	next_button.visible = false
	feedback_label.text = ""

	title_label.text = "You caught a particle!"
	word_label.text = String(particle.get("word", "")).to_upper()

	var group_id := String(particle.get("group", ""))
	group_label.text = _group_label(group_id)
	group_label.modulate = GameState.get_group_color(group_id)

	meaning_label.text = String(particle.get("meaning", ""))

	var example_text := ""
	for example in particle.get("examples", []):
		example_text += "• " + String(example) + "\n"
	examples_label.text = example_text.strip_edges()

func _group_label(group_id: String) -> String:
	match group_id:
		"article":
			return "ARTICLE"
		"determiner":
			return "DETERMINER"
		"phrasal_particle":
			return "PHRASAL PARTICLE"
	return group_id.to_upper()

func _practice_list() -> Array:
	return particle.get("practice", [])

func _start_practice() -> void:
	if particle.is_empty():
		return

	if _practice_list().is_empty():
		_show_done()
		return

	practice_index = 0
	correct_count = 0
	intro_box.visible = false
	practice_box.visible = true
	done_box.visible = false
	_show_practice()

func _show_practice() -> void:
	answered = false
	next_button.visible = false
	feedback_label.text = ""
	feedback_label.modulate = Color.WHITE

	var practice := _practice_list()
	var current: Dictionary = practice[practice_index]

	progress_label.text = "Sentence %d of %d" % [practice_index + 1, practice.size()]
	sentence_label.text = String(current.get("sentence", "")).replace("{blank}", "_____")

	var choices: Array = current.get("choices", []).duplicate()
	_shuffle_choices(choices)

	_clear_choices()
	for choice in choices:
		var button := Button.new()
		button.text = String(choice)
		button.custom_minimum_size = Vector2(130, 52)
		button.add_theme_font_size_override("font_size", 22)
		button.pressed.connect(_on_choice.bind(String(choice)))
		choices_box.add_child(button)

func _shuffle_choices(choices: Array) -> void:
	if choices.size() < 2:
		return

	for _attempt in range(6):
		for i in range(choices.size() - 1, 0, -1):
			var j := choice_rng.randi_range(0, i)
			var temp = choices[i]
			choices[i] = choices[j]
			choices[j] = temp

		var signature := ""
		for choice in choices:
			signature += String(choice) + "|"

		if signature != last_choice_order:
			last_choice_order = signature
			return

	last_choice_order = ""

func _on_choice(choice: String) -> void:
	if answered:
		return

	var practice := _practice_list()
	var current: Dictionary = practice[practice_index]
	var answer := String(current.get("answer", ""))
	var particle_id := String(particle.get("id", ""))

	if choice == answer:
		answered = true
		correct_count += 1
		GameState.mark_practice(particle_id, true)
		feedback_label.text = "Correct! " + String(current.get("explain", ""))
		feedback_label.modulate = Color(0.65, 1.0, 0.65)
		_set_choices_disabled(true)
		next_button.visible = true
		next_button.text = "Finish" if practice_index == practice.size() - 1 else "Next"
	else:
		GameState.mark_practice(particle_id, false)
		feedback_label.text = "Not quite. " + String(current.get("hint", "Try again."))
		feedback_label.modulate = Color(1.0, 0.7, 0.45)

func _next_practice() -> void:
	var practice := _practice_list()
	if practice_index + 1 >= practice.size():
		_show_done()
	else:
		practice_index += 1
		_show_practice()

func _show_done() -> void:
	intro_box.visible = false
	practice_box.visible = false
	done_box.visible = true

	var total := _practice_list().size()
	var word := String(particle.get("word", "")).to_upper()
	done_title.text = "You learned %s!" % word
	score_label.text = "Practice complete: %d / %d" % [correct_count, total]

func _set_choices_disabled(disabled: bool) -> void:
	for child in choices_box.get_children():
		var button := child as Button
		if button:
			button.disabled = disabled

func _clear_choices() -> void:
	for child in choices_box.get_children():
		choices_box.remove_child(child)
		child.queue_free()

func _close() -> void:
	if closed:
		return
	closed = true
	finished.emit()
	queue_free()

extends Node

signal hint_collected(hint_id: String)
signal paragraph_found(passage_id: String, letter: String)
signal particle_learned(particle_id: String)

const PARTICLE_DATA_PATH := "res://data/particles.json"
const PROGRESS_PATH := "user://progress.json"

var data: Dictionary = {}
var particle_data: Dictionary = {}
var collected_hints: Dictionary = {}
var found_paragraphs: Dictionary = {}
var learned_particles: Dictionary = {}
var particle_mastery: Dictionary = {}

func _ready() -> void:
	data = _load_json("res://data/content.json")
	particle_data = _load_json(PARTICLE_DATA_PATH)
	_load_progress()

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

# --- hints ---
func collect_hint(hint_id: String) -> void:
	if collected_hints.has(hint_id):
		return
	collected_hints[hint_id] = true
	hint_collected.emit(hint_id)

func get_question(q_id: String) -> Dictionary:
	for q in data.get("questions", []):
		if q["id"] == q_id:
			return q
	return {}

func get_hints_for_question(q_id: String) -> Array:
	var result: Array = []
	var q := get_question(q_id)
	for hint_id in q.get("hint_ids", []):
		if collected_hints.has(hint_id):
			var hint: Dictionary = data["hints"][hint_id].duplicate()
			hint["id"] = hint_id
			result.append(hint)
	return result

# --- passage paragraphs ---
func find_paragraph(passage_id: String, letter: String) -> void:
	found_paragraphs["%s:%s" % [passage_id, letter]] = true
	paragraph_found.emit(passage_id, letter)

func get_paragraph_text(passage_id: String, letter: String) -> String:
	return data["passages"][passage_id]["paragraphs"][letter]

# --- particles ---
func get_particles() -> Dictionary:
	return particle_data.get("particles", {})

func get_particle(particle_id: String) -> Dictionary:
	var particles := get_particles()
	if not particles.has(particle_id):
		return {}
	return particles[particle_id].duplicate(true)

func get_group_color(group_id: String) -> Color:
	var groups: Dictionary = particle_data.get("groups", {})
	if not groups.has(group_id):
		return Color.WHITE
	var group: Dictionary = groups[group_id]
	return Color.from_string(String(group.get("color", "#ffffff")), Color.WHITE)

func pick_particles(count: int) -> Array:
	var particles := get_particles()
	if particles.is_empty() or count <= 0:
		return []

	var unlearned: Array = []
	var learned_ids: Array = []
	for particle_id in particles.keys():
		var id := String(particle_id)
		if learned_particles.has(id):
			learned_ids.append(id)
		else:
			unlearned.append(id)

	unlearned.shuffle()
	learned_ids.sort_custom(_sort_by_correct)

	var ordered := unlearned + learned_ids
	var pick_count := count
	if pick_count > ordered.size():
		pick_count = ordered.size()

	var result: Array = []
	for i in range(pick_count):
		var chosen_id := String(ordered[i])
		var particle: Dictionary = particles[chosen_id].duplicate(true)
		particle["id"] = chosen_id
		result.append(particle)
	return result

func _sort_by_correct(a, b) -> bool:
	return _correct_count(String(a)) < _correct_count(String(b))

func _correct_count(particle_id: String) -> int:
	var mastery: Dictionary = particle_mastery.get(particle_id, {})
	return int(mastery.get("correct", 0))

func pick_next_particle() -> Dictionary:
	var picks := pick_particles(1)
	if picks.is_empty():
		return {}
	return picks[0]

func mark_learned(particle_id: String) -> void:
	if particle_id.is_empty():
		return
	if learned_particles.has(particle_id):
		return
	learned_particles[particle_id] = true
	particle_learned.emit(particle_id)
	_save_progress()

func mark_practice(particle_id: String, correct: bool) -> void:
	if particle_id.is_empty():
		return

	var mastery: Dictionary = particle_mastery.get(particle_id, {})
	if mastery.is_empty():
		mastery = {"attempts": 0, "correct": 0}
	else:
		mastery = mastery.duplicate(true)

	mastery["attempts"] = int(mastery.get("attempts", 0)) + 1
	if correct:
		mastery["correct"] = int(mastery.get("correct", 0)) + 1
	particle_mastery[particle_id] = mastery
	_save_progress()

func _load_progress() -> void:
	if not FileAccess.file_exists(PROGRESS_PATH):
		return

	var file := FileAccess.open(PROGRESS_PATH, FileAccess.READ)
	if file == null:
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var learned = parsed.get("learned_particles", [])
	if typeof(learned) == TYPE_ARRAY:
		for particle_id in learned:
			learned_particles[String(particle_id)] = true

	var mastery = parsed.get("particle_mastery", {})
	if typeof(mastery) == TYPE_DICTIONARY:
		particle_mastery = mastery

func _save_progress() -> void:
	var file := FileAccess.open(PROGRESS_PATH, FileAccess.WRITE)
	if file == null:
		return

	var payload := {
		"learned_particles": learned_particles.keys(),
		"particle_mastery": particle_mastery
	}
	file.store_string(JSON.stringify(payload, "\t"))

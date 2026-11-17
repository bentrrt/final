extends Control

signal fish_caught(particle: Dictionary)

const FISH_SCENE := preload("res://fish.tscn")

@export var fish_count := 3

@onready var catch_bar: ProgressBar = %CatchBar
@onready var fish: CharacterBody2D = $Fish
@onready var target: Area2D = $Target

var onCatch := false
var catchSpeed := 0.3
var catchingValue := 0.0
var particle: Dictionary = {}
var active_fish: CharacterBody2D = null
var enabled := true
var finished := false
var fish_total := 0
var caught_count := 0

func _ready() -> void:
	var picks := GameState.pick_particles(fish_count)
	if picks.is_empty():
		return

	fish_total = picks.size()
	particle = picks[0]
	_setup_fish(fish, picks[0])

	var container: Control = fish.get("aquaContainer")
	await get_tree().process_frame
	await get_tree().process_frame

	while container.size.x < 48.0 or container.size.y < 48.0:
		await get_tree().process_frame

	fish.global_position = _random_aqua_position(container)

	for i in range(1, picks.size()):
		var extra := FISH_SCENE.instantiate() as CharacterBody2D
		extra.set("aquaContainer", container)
		add_child(extra)
		extra.global_position = _random_aqua_position(container)
		extra.set("targetPosition", extra.global_position)
		_setup_fish(extra, picks[i])
		extra.name = "Fish%d" % (i + 1)

func _setup_fish(f: CharacterBody2D, data: Dictionary) -> void:
	f.set("particle", data)
	if f.has_method("set_particle"):
		f.call("set_particle", data)

func _random_aqua_position(container: Control) -> Vector2:
	var rect := container.get_global_rect()
	return Vector2(
		randf_range(rect.position.x + 24.0, rect.end.x - 24.0),
		randf_range(rect.position.y + 24.0, rect.end.y - 24.0)
	)

func _physics_process(_delta: float) -> void:
	if not enabled or finished:
		return

	if onCatch:
		_update_active_fish()
		if active_fish:
			catchingValue += catchSpeed
		else:
			onCatch = false
			catchingValue -= catchSpeed
	else:
		catchingValue -= catchSpeed

	if catchingValue < 0.0:
		catchingValue = 0.0
	elif catchingValue >= 100.0:
		_game_end()

	catch_bar.value = catchingValue

func _update_active_fish() -> void:
	active_fish = null
	for body in target.get_overlapping_bodies():
		if body.is_in_group("fish") and not bool(body.get("caught")):
			active_fish = body as CharacterBody2D
			return

func _game_end() -> void:
	if not enabled or finished:
		return
	if not active_fish or not is_instance_valid(active_fish):
		return

	set_enabled(false)
	catchingValue = 0.0
	catch_bar.value = 0.0

	if active_fish and is_instance_valid(active_fish):
		var active_particle = active_fish.get("particle")
		if typeof(active_particle) == TYPE_DICTIONARY and not active_particle.is_empty():
			particle = active_particle
		active_fish.call("set_caught", true)

	GameState.mark_learned(String(particle.get("id", "")))
	caught_count += 1
	onCatch = false
	active_fish = null
	fish_caught.emit(particle)

func resume_after_lesson() -> void:
	if finished:
		return

	catchingValue = 0.0
	catch_bar.value = 0.0
	onCatch = false
	active_fish = null

	if caught_count >= fish_total:
		_close()
	else:
		set_enabled(true)
		_update_active_fish()
		onCatch = active_fish != null

func set_enabled(value: bool) -> void:
	enabled = value
	set_physics_process(value)

	if is_instance_valid(target):
		target.set_physics_process(value)

	for child in get_children():
		if child.is_in_group("fish") and not bool(child.get("caught")):
			child.set_physics_process(value)

func _close() -> void:
	if finished:
		return

	finished = true
	set_enabled(false)

	var tween = get_tree().create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "global_position", global_position + Vector2(0, 700), 0.5)
	await tween.finished
	queue_free()

func _on_tarruget_target_entered() -> void:
	if not enabled:
		return

	_update_active_fish()
	onCatch = active_fish != null

func _on_target_target_exited() -> void:
	if not enabled:
		return

	onCatch = false
	active_fish = null

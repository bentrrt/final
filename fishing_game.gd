extends Control

signal fish_caught(particle: Dictionary)

@onready var catch_bar: ProgressBar = %CatchBar
@onready var fish: CharacterBody2D = $Fish

var onCatch := false
var catchSpeed := 0.3
var catchingValue := 0.0
var particle: Dictionary = {}
var finished := false

func _ready() -> void:
	particle = GameState.pick_next_particle()
	if not particle.is_empty() and fish.has_method("set_group_color"):
		var group_id := String(particle.get("group", ""))
		fish.set_group_color(GameState.get_group_color(group_id))

func _physics_process(_delta: float) -> void:
	if finished:
		return

	if onCatch:
		catchingValue += catchSpeed
	else:
		catchingValue -= catchSpeed

	if catchingValue < 0.0:
		catchingValue = 0.0
	elif catchingValue >= 100.0:
		_game_end()

	catch_bar.value = catchingValue

func _game_end() -> void:
	if finished:
		return

	finished = true
	set_physics_process(false)
	catch_bar.value = 100.0

	if fish:
		fish.set_physics_process(false)

	var tween = get_tree().create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "global_position", global_position + Vector2(0, 700), 0.5)
	await tween.finished

	fish_caught.emit(particle)
	queue_free()

func _on_target_target_entered() -> void:
	onCatch = true

func _on_target_target_exited() -> void:
	onCatch = false

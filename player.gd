extends CharacterBody2D

@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var tile_marker = $AnimatedSprite2D/tileMarker
@onready var waiting: Sprite2D = $Waiting
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var waiting_timer: Timer = $WaitingTimer

const SPEED = 100.0
const LESSON_SCENE := preload("res://lesson_card.tscn")


var rng = RandomNumberGenerator.new()
var startFishing = false
var waitForFish = false
var fishBitten = false
var maxWaitingTime = 4

func _ready() -> void:
	waiting.visible = false

func _physics_process(_delta):
	if startFishing: _fishing_state()
	else: _move_state()

	move_and_slide()

func _fishing_state():
	velocity = Vector2.ZERO
	
	if Input.is_action_just_pressed("ui_accept") && fishBitten:
		_stop_fishing()
	
	if waitForFish: _wait_for_fish()
	if fishBitten: _fish_bitten_animation()

func _move_state():
	if Input.is_action_just_pressed("ui_accept"):
		_start_fishing()
		return
	
	var direction = Vector2.ZERO
	direction.x = Input.get_axis("ui_left", "ui_right")
	direction.y = Input.get_axis("ui_up", "ui_down")

	if direction:
		velocity = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.y = move_toward(velocity.y, 0, SPEED)	
	
	if velocity.x < 0: animated_sprite_2d.scale.x = -1
	elif velocity.x >0: animated_sprite_2d.scale.x = 1
	
	if velocity: animated_sprite_2d.play("Walk")
	else: animated_sprite_2d.play("Idle")

func _start_fishing():
	if not _get_tile_data() == "water": return
	
	startFishing = true
	animated_sprite_2d.play("Fishing_start")

func _stop_fishing():
	fishBitten = false
	waitForFish = false
	animation_player.stop()
	animated_sprite_2d.visible = true
	waiting.visible = false
	animated_sprite_2d.play("Fishing_end")

func _wait_for_fish():
	animated_sprite_2d.visible = false
	animation_player.play("waiting")
	
	if waiting_timer.time_left == 0: 
		waiting_timer.wait_time = rng.randf_range(0,maxWaitingTime)
		waiting_timer.start()

func _fish_bitten_animation():
	var forceX = rng.randf_range(-1,1) * 2
	var forceY = rng.randf_range(-1,1) * 2
		
	waiting.offset = Vector2(forceX, forceY)		
	
func _get_tile_data():
	var tileMap = get_parent().find_child("Water")
	var searchPosition = tileMap.local_to_map(tileMap.to_local(tile_marker.global_position))
	var data = tileMap.get_cell_tile_data(searchPosition)

	if data: return data.get_custom_data("type")

func _on_animated_sprite_2d_animation_finished():
	if animated_sprite_2d.animation == "Fishing_start":
		waitForFish = true
	elif animated_sprite_2d.animation == "Fishing_end":
		startFishing = false
		_start_mini_game()

func _start_mini_game() -> void:
	get_tree().paused = true
	PhysicsServer2D.set_active(true)

	var minigame := preload("res://fishing_minigame.tscn").instantiate()
	var game_ui := minigame.get_node("FishingGame")
	game_ui.connect("fish_caught", _on_fish_caught)
	get_tree().current_scene.add_child(minigame)


func _on_fish_caught(particle: Dictionary) -> void:
	if particle.is_empty():
		get_tree().paused = false
		return

	var lesson := LESSON_SCENE.instantiate()
	get_tree().current_scene.add_child(lesson)
	lesson.connect("finished", _on_lesson_finished)
	lesson.call("start", particle)

func _on_lesson_finished() -> void:
	get_tree().paused = false

func _on_waiting_timer_timeout() -> void:
	waiting_timer.stop()
	animation_player.stop()
	fishBitten = true
	waitForFish = false
	
	


#
#func _ready():
	#animated_sprite.play("Idle")
#
#func _physics_process(delta: float) -> void:
	## 1. Get input vector for all 4 directions (returns a Vector2 between -1 and 1)
	#var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	#
	## 2. Apply speed to the velocity vector (automatically normalizes diagonals)
	#velocity = input_vector * SPEED
#
	## 3. Handle animations and sprite flipping
	#if input_vector != Vector2.ZERO:
		#animated_sprite.play("Walk") # Make sure you have an animation named "Walk"
		#
		## Flip the sprite left or right depending on horizontal movement
		#if input_vector.x != 0:
			#animated_sprite.flip_h = input_vector.x < 0
	#else:
		#animated_sprite.play("Idle")
#
	## 4. Move the character smoothly
	#move_and_slide()

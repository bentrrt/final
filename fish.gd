extends CharacterBody2D

@export var aquaContainer : Control

@onready var fish_sprite: AnimatedSprite2D = $AnimatedSprite2D

const SPEED := 100.0

const FISH_TEXTURES := {
	"a": "res://assets/SpearFishing Assets Pack/Sprites/Fish1 - 16x16/Orange.png",
	"an": "res://assets/SpearFishing Assets Pack/Sprites/Fish1 - 16x16/Pink.png",
	"the": "res://assets/SpearFishing Assets Pack/Sprites/Fish1 - 16x16/Purple.png",
	"some": "res://assets/SpearFishing Assets Pack/Sprites/Fish1 - 16x16/Red.png",
	"any": "res://assets/SpearFishing Assets Pack/Sprites/Fish2 - 32x16/Blue.png",
	"this": "res://assets/SpearFishing Assets Pack/Sprites/Fish2 - 32x16/Green.png",
	"up": "res://assets/SpearFishing Assets Pack/Sprites/Fish2 - 32x16/Orange.png",
	"down": "res://assets/SpearFishing Assets Pack/Sprites/Fish2 - 32x16/Purple.png",
	"in": "res://assets/SpearFishing Assets Pack/Sprites/Fish3 - 32x16/Blue.png",
	"out": "res://assets/SpearFishing Assets Pack/Sprites/Fish3 - 32x16/Grey.png",
	"on": "res://assets/SpearFishing Assets Pack/Sprites/Fish3 - 32x16/Orange.png",
	"off": "res://assets/SpearFishing Assets Pack/Sprites/Fish3 - 32x16/Red.png"
}

var targetPosition: Vector2
var borderDistance := 10
var particle: Dictionary = {}
var caught := false

func _ready() -> void:
	add_to_group("fish")
	_set_target_position()

func set_caught(value: bool) -> void:
	caught = value
	fish_sprite.modulate = Color(0.45, 0.45, 0.45, 0.55) if value else Color.WHITE
	collision_layer = 0 if value else 1
	collision_mask = 0 if value else 1
	if value:
		set_physics_process(true)
	
func _set_target_position() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	_set_new_target_position()
	
func _set_new_target_position() -> void:
	var boxSize := aquaContainer.get_global_rect()
	var xPosition := randi_range(
		int(boxSize.position.x + borderDistance), int(boxSize.position.x + boxSize.size.x - borderDistance))
	var yPosition := randi_range(
		int(boxSize.position.y + borderDistance), int(boxSize.position.y + boxSize.size.y - borderDistance))
	
	targetPosition = Vector2(xPosition, yPosition)

func _physics_process(_delta: float) -> void:
	var direction := (targetPosition - global_position).normalized()

	if direction:
		velocity = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.y = move_toward(velocity.y, 0, SPEED)
		
	if global_position.distance_to(targetPosition) < 5: _on_target()
		
	_set_animation()

	move_and_slide()

func _on_target() -> void:
	set_physics_process(false)
	await get_tree().create_timer(1.5).timeout
	
	_set_new_target_position()
	
	set_physics_process(true)
	
func _set_animation() -> void:
	if velocity: fish_sprite.play("move")
	else: fish_sprite.stop()

func set_particle(data: Dictionary) -> void:
	particle = data

	var id := String(data.get("id", ""))

	var path := String(FISH_TEXTURES.get(id, ""))
	if path.is_empty():
		return

	var texture := load(path) as Texture2D
	if texture == null:
		return

	var frame_width := texture.get_width() / 8
	var frame_height := texture.get_height() / 4

	var frames := SpriteFrames.new()
	frames.add_animation("move")
	frames.set_animation_speed("move", 5.0)
	frames.set_animation_loop("move", true)

	for row in range(2):
		for col in range(8):
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(col * frame_width, row * frame_height, frame_width, frame_height)
			frames.add_frame("move", atlas)

	fish_sprite.sprite_frames = frames
	fish_sprite.modulate = Color.WHITE
	fish_sprite.play("move")

func set_group_color(color: Color) -> void:
	fish_sprite.modulate = color

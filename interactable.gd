class_name Interactable
extends Node3D

@export var prompt_text := "Left click to interact"

@onready var zone: Area3D = $InteractionZone

func _ready() -> void:
	zone.body_entered.connect(_on_body_entered)
	zone.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.register_interactable(self)

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.unregister_interactable(self)

# Override this in NPCs, hint collectibles, exhibits, etc.
func interact(_player: Node3D) -> void:
	pass

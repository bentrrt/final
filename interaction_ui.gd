extends CanvasLayer

@onready var label: Label = $PromptLabel

func _ready() -> void:
	label.visible = false
	var player := get_tree().get_first_node_in_group("player")
	player.interactable_changed.connect(_on_interactable_changed)

func _on_interactable_changed(i: Interactable) -> void:
	label.visible = i != null
	if i:
		label.text = i.prompt_text

extends Interactable

@export var hint_id := "brochure_bees"

func interact(_player: Node3D) -> void:
	GameState.collect_hint(hint_id)
	print("Collected: ", hint_id)
	print("Hints for q1: ", GameState.get_hints_for_question("q1"))
	queue_free()

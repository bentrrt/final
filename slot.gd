class_name TrainSlot
extends Control

var carriage: TrainCarriage = null

func _ready() -> void:
	carriage = get_node_or_null("Carriage") as TrainCarriage

func _get_drag_data(_at_position: Vector2) -> Variant:
	if carriage == null:
		return null
	var preview := Label.new()
	preview.text = carriage.word
	preview.add_theme_font_size_override("font_size", 20)
	set_drag_preview(preview)
	return {"slot": self}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("slot")

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var other: TrainSlot = data["slot"]
	if other == self:
		return
	var my_car := carriage
	var other_car := other.carriage
	if my_car != null:
		remove_child(my_car)
		other.add_child(my_car)
		other.carriage = my_car
		carriage = null
	if other_car != null:
		other.remove_child(other_car)
		add_child(other_car)
		carriage = other_car
		other.carriage = null
	if my_car != null and other_car != null:
		other.carriage = my_car
		carriage = other_car

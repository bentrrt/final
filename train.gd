extends HBoxContainer

@export var carriage_textures: Array[Texture2D] = []

@onready var slot_nodes: Array = [$Slot1, $Slot2, $Slot3, $Slot4, $Slot5]
@onready var smoke: Sprite2D = $Loco/Smoke
@onready var wheel_smoke: CPUParticles2D = $WheelSmoke

var smoke_timer := 0.0

var item: Dictionary = {}
var train_color: Color
var train_index: int = 0
var fade_tags := false
var slots: Array[TrainSlot] = []

func setup(p_item: Dictionary, color: Color, index: int, fade_tags: bool = false) -> void:
	item = p_item
	train_color = color
	train_index = index
	self.fade_tags = fade_tags
	slots.clear()
	var answer: Array = item["answer"]
	var classes: Array = item["classes"]
	var pairs: Array = []
	for i in range(answer.size()):
		pairs.append({"word": answer[i], "cls": classes[i]})
	_shuffle_pairs(pairs)
	for i in range(slot_nodes.size()):
		var slot: TrainSlot = slot_nodes[i]
		if i < pairs.size():
			slot.visible = true
			var car: TrainCarriage = slot.carriage
			car.visible = true
			car.modulate = Color(1, 1, 1)
			car.setup(pairs[i]["word"], pairs[i]["cls"], color, _carriage_texture(i), fade_tags)
			slots.append(slot)
		else:
			slot.visible = false

func _carriage_texture(index: int) -> Texture2D:
	if carriage_textures.is_empty():
		return null
	return carriage_textures[(train_index * 3 + index) % carriage_textures.size()]

func _shuffle_pairs(arr: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(arr))
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

func words() -> Array:
	var result: Array = []
	for slot in slots:
		result.append(slot.carriage.word if slot.carriage != null else "")
	return result

func mark_correct(color: Color) -> void:
	for slot in slots:
		if slot.carriage != null:
			slot.carriage.modulate = Color(1, 1, 1)

func mark_wrong(index: int) -> void:
	if index < 0 or index >= slots.size():
		return
	if slots[index].carriage != null:
		slots[index].carriage.modulate = Color(1, 0.4, 0.4)

func reset_marks() -> void:
	for slot in slots:
		if slot.carriage != null:
			slot.carriage.modulate = Color(1, 1, 1)

func _process(delta: float) -> void:
	if smoke == null:
		return
	smoke_timer += delta
	if smoke_timer >= 0.08:
		smoke_timer = 0.0
		smoke.frame = (smoke.frame + 1) % 30

func start_smoke() -> void:
	if wheel_smoke != null:
		wheel_smoke.emitting = true

func stop_smoke() -> void:
	if wheel_smoke != null:
		wheel_smoke.emitting = false

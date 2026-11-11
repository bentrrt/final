extends CharacterBody3D

@onready var navigationAgent :=$NavigationAgent3D
var Speed = 10
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if(navigationAgent.is_navigation_finished()):
		return
	moveToPoint(delta,Speed)
	pass
func moveToPoint(delta, speed):
	var targetPos = navigationAgent.get_next_path_position()
	var direction = global_position.direction_to(targetPos)
	
	velocity = direction * speed
	move_and_slide()
	
func _input(event):
	if Input.is_action_just_pressed("RightMouse"):
		var camera = get_tree().get_nodes_in_group("Camera")[0]
		var mousePos = get_viewport().get_mouse_position()
		var rayLength = 100
		var from = camera.project_ray_origin(mousePos)
		var to = from + camera.project_ray_normal(mousePos) * rayLength
		var space = get_world_3d().direct_space_state
		var rayQuery = PhysicsRayQueryParameters3D.new()
		rayQuery.from = from
		rayQuery.to = to
		var result = space.intersect_ray(rayQuery)
		print(result)
		
		navigationAgent.target_position = result.position
		
#	ai stuff
		
signal interactable_changed(interactable: Interactable)

var nearby_interactables: Array[Interactable] = []
var current_interactable: Interactable = null

func register_interactable(i: Interactable) -> void:
	if i not in nearby_interactables:
		nearby_interactables.append(i)

func unregister_interactable(i: Interactable) -> void:
	nearby_interactables.erase(i)

func _physics_process(_delta: float) -> void:
	_update_current_interactable()
	# ... your existing movement code stays here

func _update_current_interactable() -> void:
	# drop anything that was freed (e.g. a collected hint)
	nearby_interactables = nearby_interactables.filter(func(i): return is_instance_valid(i))

	var best: Interactable = null
	var best_dist := INF
	for i in nearby_interactables:
		var d := global_position.distance_squared_to(i.global_position)
		if d < best_dist:
			best_dist = d
			best = i

	if best != current_interactable:
		current_interactable = best
		interactable_changed.emit(current_interactable)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and current_interactable:
		current_interactable.interact(self)
		get_viewport().set_input_as_handled()

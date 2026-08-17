extends CharacterBody3D

@onready var animPlayer : AnimationPlayer = $AnimationPlayer
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@export var move_speed := 5.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animPlayer.play("Armature|mixamo_com|Layer0")
	var target = Vector3.ZERO
	target.x = randf_range(-30,30)
	target.z = randf_range(-10,10)
	nav_agent.target_position = target


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var current_location = global_transform.origin
	var next_location = nav_agent.get_next_path_position()
	var new_velocity = (next_location - current_location).normalized() * move_speed
	new_velocity.y = 0.0
	
	next_location.y = 0.0
	
	look_at(next_location)
	
	velocity = velocity.move_toward(new_velocity, 0.25)
	move_and_slide()

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			move_to_mouse()

func move_to_mouse():
	var camera = get_viewport().get_camera_3d()
	if camera == null:
		return

	var mouse_pos = get_viewport().get_mouse_position()

	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 1000.0

	var space_state = get_world_3d().direct_space_state

	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = false

	var result = space_state.intersect_ray(query)
	if not result: return
	var target = Vector3(result.position.x, 0.0, result.position.z)

	if result:
		nav_agent.target_position = target

extends Node3D

@export var rotation_speed := PI / 2
@onready var inner_gimbal := $InnerGimbal as Node3D


func _process(delta: float) -> void:
	var y_rotation := 0
	if Input.is_action_pressed("move_right"):
		y_rotation += 1
	if Input.is_action_pressed("move_left"):
		y_rotation -= 1
	self.rotate_object_local(Vector3.UP, y_rotation * rotation_speed * delta)
	
	var x_rotation := 0
	if Input.is_action_pressed("move_down"):
		x_rotation += 1
	if Input.is_action_pressed("move_up"):
		x_rotation -= 1
	inner_gimbal.rotate_object_local(Vector3.RIGHT, x_rotation * rotation_speed * delta)

	inner_gimbal.rotation.x = clamp(inner_gimbal.rotation.x, -1.2, 0.3)

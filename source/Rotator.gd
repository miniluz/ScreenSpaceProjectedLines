extends Node3D

const SPEED = 10 * PI / 180

func _process(delta):
	transform = transform.rotated(Vector3(0,0,1).normalized(), delta*SPEED);

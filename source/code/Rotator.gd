extends Node3D

const SPEED = 10 * PI / 180
@export
var enable: bool

func _process(delta):
	if enable:
		transform = transform.rotated(Vector3(0,0,1).normalized(), delta*SPEED);

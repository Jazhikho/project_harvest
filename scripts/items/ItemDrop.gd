extends RigidBody3D

var settle_timer := 0.0
const SETTLE_SPEED := 0.03
const SETTLE_TIME := 0.6

func _physics_process(delta):
	if linear_velocity.length() < SETTLE_SPEED and angular_velocity.length() < SETTLE_SPEED:
		settle_timer += delta
		if settle_timer >= SETTLE_TIME:
			freeze = true  # keeps collisions, stops sim
			set_physics_process(false)
	else:
		settle_timer = 0.0

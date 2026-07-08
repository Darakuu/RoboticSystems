extends RigidBody3D

@onready var L = 0.195
@onready var p1 = Vector3(L,0,L)
@onready var p2 = Vector3(-L,0,L)
@onready var p3 = Vector3(-L,0,-L)
@onready var p4 = Vector3(L,0,-L)
var f1 = Vector3(0,0,0)
var f2 = Vector3(0,0,0)
var f3 = Vector3(0,0,0)
var f4 = Vector3(0,0,0)

var initial_position
var initial_rotation
var initial_velocity
var initial_angular_velocity
var perform_reset : bool = false

func _ready():
	initial_position = position
	initial_rotation = rotation
	initial_velocity = linear_velocity
	initial_angular_velocity = angular_velocity

# Requests a reset on the next physics tick.
func do_reset():
	perform_reset = true

# Restores the drone to its initial local transform and velocity.
func reset():
	position = initial_position
	rotation = initial_rotation
	linear_velocity = initial_velocity 
	angular_velocity = initial_angular_velocity

# Applies the current motor forces during the physics step.
func _physics_process(_delta):
	if perform_reset:
		reset()
		perform_reset = false
		DDS.clear("f1")
		DDS.clear("f2")
		DDS.clear("f3")
		DDS.clear("f4")
	else:
		apply_local_force(f1, p1)
		apply_local_force(f2, p2)
		apply_local_force(f3, p3)
		apply_local_force(f4, p4)

# Converts a motor force from drone-local coordinates to world physics coordinates.
func apply_local_force(force: Vector3, pos: Vector3):
	var body_basis = global_transform.basis
	var pos_global = body_basis * pos
	var force_global = body_basis * force
	apply_force(force_global, pos_global)

# Stores the latest scalar force for each motor.
func set_forces(_f1,_f2,_f3,_f4):
	f1 = Vector3(0,_f1,0)
	f2 = Vector3(0,_f2,0)
	f3 = Vector3(0,_f3,0)
	f4 = Vector3(0,_f4,0)

# Returns global position and Euler rotation for DDS publishing.
func get_pose():
	return [global_position, global_rotation]

# Returns linear and angular velocity for DDS publishing.
func get_velocity():
	return [linear_velocity, angular_velocity]

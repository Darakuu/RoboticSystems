class_name MultirotorBody
extends RigidBody3D

const ARM_LENGTH: float = 0.195
const MOTOR_POSITIONS: Array[Vector3] = [
	Vector3(ARM_LENGTH, 0.0, ARM_LENGTH),
	Vector3(-ARM_LENGTH, 0.0, ARM_LENGTH),
	Vector3(-ARM_LENGTH, 0.0, -ARM_LENGTH),
	Vector3(ARM_LENGTH, 0.0, -ARM_LENGTH),
]

var motor_forces: Array[float] = [0.0, 0.0, 0.0, 0.0]
var initial_transform: Transform3D
var initial_linear_velocity: Vector3
var initial_angular_velocity: Vector3
var reset_requested: bool = false


func _ready() -> void:
	initial_transform = transform
	initial_linear_velocity = linear_velocity
	initial_angular_velocity = angular_velocity


func _physics_process(_delta: float) -> void:
	if reset_requested:
		_reset_state()
		return

	for motor_id: int in range(MOTOR_POSITIONS.size()):
		_apply_motor_force(motor_forces[motor_id], MOTOR_POSITIONS[motor_id])


func do_reset() -> void:
	reset_requested = true


func set_forces(f1: float, f2: float, f3: float, f4: float) -> void:
	motor_forces[0] = f1
	motor_forces[1] = f2
	motor_forces[2] = f3
	motor_forces[3] = f4


func get_pose() -> Array[Vector3]:
	return [global_position, global_rotation]


func get_velocity() -> Array[Vector3]:
	return [linear_velocity, angular_velocity]


func _apply_motor_force(force: float, motor_position: Vector3) -> void:
	var basis: Basis = global_transform.basis
	apply_force(basis * Vector3.UP * force, basis * motor_position)


func _reset_state() -> void:
	transform = initial_transform
	linear_velocity = initial_linear_velocity
	angular_velocity = initial_angular_velocity
	set_forces(0.0, 0.0, 0.0, 0.0)
	reset_requested = false

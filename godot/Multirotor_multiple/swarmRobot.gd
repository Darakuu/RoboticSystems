class_name SwarmRobot
extends Node3D

const FORCE_TOPICS: Array[String] = ["f1", "f2", "f3", "f4"]

@export var drone_id: int = 0

var is_active: bool = true

@onready var drone: MultirotorBody = $drone


func _ready() -> void:
	for force_topic: String in FORCE_TOPICS:
		DDS.subscribe(topic(force_topic))
	_publish_active_state()


func _process(_delta: float) -> void:
	_publish_active_state()
	if not is_active:
		return

	_publish_state()
	_apply_motor_forces()


func topic(name: String) -> String:
	return "D%d_%s" % [drone_id, name]


func get_display_position() -> Vector3:
	var position_state: Vector3 = drone.global_position
	return Vector3(position_state.z, position_state.x, position_state.y)


func get_world_position() -> Vector3:
	return drone.global_position


func do_reset() -> void:
	drone.do_reset()
	_clear_motor_forces()


func deactivate() -> void:
	is_active = false
	_publish_active_state()
	_clear_motor_forces()


func _publish_state() -> void:
	var pose: Array[Vector3] = drone.get_pose()
	var velocity: Array[Vector3] = drone.get_velocity()
	var position_state: Vector3 = pose[0]
	var attitude: Vector3 = pose[1]
	var linear_velocity: Vector3 = velocity[0]
	var angular_velocity: Vector3 = velocity[1]

	# DDS X/Y/Z correspond to Godot Z/X/Y.
	var state := {
		"X": position_state.z,
		"Y": position_state.x,
		"Z": position_state.y,
		"TX": attitude.z,
		"TY": attitude.x,
		"TZ": attitude.y,
		"VX": linear_velocity.z,
		"VY": linear_velocity.x,
		"VZ": linear_velocity.y,
		"WX": angular_velocity.z,
		"WY": angular_velocity.x,
		"WZ": angular_velocity.y,
	}

	for name: String in state:
		DDS.publish(topic(name), DDS.DDS_TYPE_FLOAT, state[name])


func _apply_motor_forces() -> void:
	var forces: Array[float] = []
	for force_topic: String in FORCE_TOPICS:
		forces.append(float(DDS.read(topic(force_topic))))
	drone.set_forces(forces[0], forces[1], forces[2], forces[3])


func _publish_active_state() -> void:
	DDS.publish(topic("active"), DDS.DDS_TYPE_INT, int(is_active))


func _clear_motor_forces() -> void:
	for force_topic: String in FORCE_TOPICS:
		DDS.clear(topic(force_topic))
	drone.set_forces(0.0, 0.0, 0.0, 0.0)

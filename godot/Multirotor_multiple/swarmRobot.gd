class_name SwarmRobot
extends Node3D

@export var drone_id: int = 0

const FORCE_TOPICS: Array[String] = ["f1", "f2", "f3", "f4"]

@onready var drone = _find_drone()

# Prepares this drone's namespaced DDS subscriptions.
func _ready() -> void:
	if drone == null:
		push_error("SwarmRobot requires a RigidBody3D child with the multirotor drone script.")
		set_process(false)
		return
	if not drone.has_method("get_pose") or not drone.has_method("get_velocity") or not drone.has_method("set_forces"):
		push_error("SwarmRobot found a drone node, but it does not expose the required multirotor API.")
		set_process(false)
		return

	for force_topic: String in FORCE_TOPICS:
		DDS.subscribe(topic(force_topic))

	DDS.publish(topic("active"), DDS.DDS_TYPE_INT, 1)

# Updates DDS state output and applies the latest motor commands.
func _process(_delta: float) -> void:
	DDS.publish(topic("active"), DDS.DDS_TYPE_INT, 1)
	_publish_state()
	_apply_motor_forces()

# Builds this drone's namespaced DDS topic name.
func topic(topic_name: String) -> String:
	return "D%d_%s" % [drone_id, topic_name]

# Resets the physical drone and clears its motor commands.
func do_reset() -> void:
	if drone == null:
		return

	drone.do_reset()
	_clear_motor_forces()

# Marks this drone inactive on DDS and clears its motor commands.
func deactivate() -> void:
	DDS.publish(topic("active"), DDS.DDS_TYPE_INT, 0)
	_clear_motor_forces()

# Finds the physical drone node wrapped by this SwarmRobot.
func _find_drone():
	var direct_drone: RigidBody3D = get_node_or_null("drone") as RigidBody3D
	if direct_drone != null:
		return direct_drone

	var named_drone: RigidBody3D = get_node_or_null("Drone") as RigidBody3D
	if named_drone != null:
		return named_drone

	var nested_drone: RigidBody3D = get_node_or_null("Robot/drone") as RigidBody3D
	if nested_drone != null:
		return nested_drone

	for child: Node in get_children():
		if child is RigidBody3D:
			return child as RigidBody3D

	return null

# Publishes this drone's pose and velocity on namespaced DDS topics.
func _publish_state() -> void:
	var pose: Array = drone.get_pose()
	var velocity: Array = drone.get_velocity()
	var pos_state: Vector3 = pose[0]
	var attitude: Vector3 = pose[1]
	var linear_velocity: Vector3 = velocity[0]
	var angular_velocity: Vector3 = velocity[1]

	DDS.publish(topic("X"), DDS.DDS_TYPE_FLOAT, pos_state.z)
	DDS.publish(topic("Y"), DDS.DDS_TYPE_FLOAT, pos_state.x)
	DDS.publish(topic("Z"), DDS.DDS_TYPE_FLOAT, pos_state.y)

	DDS.publish(topic("TX"), DDS.DDS_TYPE_FLOAT, attitude.z)
	DDS.publish(topic("TY"), DDS.DDS_TYPE_FLOAT, attitude.x)
	DDS.publish(topic("TZ"), DDS.DDS_TYPE_FLOAT, attitude.y)

	DDS.publish(topic("VX"), DDS.DDS_TYPE_FLOAT, linear_velocity.z)
	DDS.publish(topic("VY"), DDS.DDS_TYPE_FLOAT, linear_velocity.x)
	DDS.publish(topic("VZ"), DDS.DDS_TYPE_FLOAT, linear_velocity.y)

	DDS.publish(topic("WX"), DDS.DDS_TYPE_FLOAT, angular_velocity.z)
	DDS.publish(topic("WY"), DDS.DDS_TYPE_FLOAT, angular_velocity.x)
	DDS.publish(topic("WZ"), DDS.DDS_TYPE_FLOAT, angular_velocity.y)

# Reads namespaced motor-force topics and sends them to the physical drone.
func _apply_motor_forces() -> void:
	var f1: float = float(DDS.read(topic("f1")))
	var f2: float = float(DDS.read(topic("f2")))
	var f3: float = float(DDS.read(topic("f3")))
	var f4: float = float(DDS.read(topic("f4")))

	drone.set_forces(f1, f2, f3, f4)

# Clears this drone's namespaced motor-force commands.
func _clear_motor_forces() -> void:
	for force_topic: String in FORCE_TOPICS:
		DDS.clear(topic(force_topic))

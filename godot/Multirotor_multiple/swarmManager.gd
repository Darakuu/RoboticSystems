class_name SwarmManager
extends Node3D

@export var current_drones: int = 4
@export var max_drones: int = 6
@export var spawn_spacing: float = 1.0
@export var spawn_height: float = 0.214639
@export var robot_scene: PackedScene = preload("res://swarmRobot.tscn")

const MANAGER_PROCESS_PRIORITY: int = 100

var active_drones: Array[SwarmRobot] = []
var drone_count: int = 0

# Spawns the initial contiguous set of swarm drones.
func _ready() -> void:
	# Publish tick after child drones have published their per-drone state.
	process_priority = MANAGER_PROCESS_PRIORITY

	max_drones = max(max_drones, 0)
	current_drones = clamp(current_drones, 0, max_drones)

	for drone_index: int in range(current_drones):
		add_drone(_spawn_position_for(drone_index, current_drones))

	_publish_drone_count()

# Publishes the manager-owned global DDS state for this frame.
func _process(delta: float) -> void:
	_publish_drone_count()
	_publish_tick(delta)

# Instantiates one SwarmRobot with the next contiguous drone id.
func add_drone(spawn_position: Vector3 = Vector3.ZERO) -> SwarmRobot:
	if active_drones.size() >= max_drones:
		push_warning("SwarmManager cannot add more than %d drones." % max_drones)
		return null

	if robot_scene == null:
		push_error("SwarmManager cannot add drones because robot_scene is not assigned.")
		return null

	var next_drone_id: int = active_drones.size()
	var swarm_robot: SwarmRobot = robot_scene.instantiate() as SwarmRobot
	if swarm_robot == null:
		push_error("robot_scene must point to a scene with a SwarmRobot root.")
		return null

	swarm_robot.name = "D%d" % next_drone_id
	swarm_robot.drone_id = next_drone_id
	swarm_robot.position = spawn_position
	add_child(swarm_robot)

	active_drones.append(swarm_robot)
	drone_count = active_drones.size()
	current_drones = drone_count
	_publish_drone_count()

	return swarm_robot

# Resets every active drone without changing swarm membership.
func reset_all() -> void:
	for swarm_robot: SwarmRobot in active_drones:
		swarm_robot.do_reset()

# Computes deterministic startup positions centered around the world origin.
func _spawn_position_for(drone_id_to_spawn: int, total_count: int) -> Vector3:
	var centered_index: float = float(drone_id_to_spawn) - (float(total_count - 1) * 0.5)
	return Vector3(centered_index * spawn_spacing, spawn_height, 0.0)

# Publishes the manager-owned drone count through DDS.
func _publish_drone_count() -> void:
	DDS.publish("drone_count", DDS.DDS_TYPE_INT, drone_count)

# Publishes the single global controller wake-up signal.
func _publish_tick(delta: float) -> void:
	DDS.publish("tick", DDS.DDS_TYPE_FLOAT, delta)

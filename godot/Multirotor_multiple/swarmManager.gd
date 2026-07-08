class_name SwarmManager
extends Node3D

enum Formation {
	NONE = 0,
	LINE = 1,
	TRIANGLE = 2,
	SQUARE = 3,
	CIRCLE = 4,
}

@export var current_drones: int = 4
@export var max_drones: int = 6
@export var min_drones: int = 1
@export var spawn_spacing: float = 1.4
@export var spawn_height: float = 0.214639
@export var robot_scene: PackedScene = preload("res://swarmRobot.tscn")
@export var formation_id: int = Formation.LINE
@export var telemetry_panel_path: NodePath = ^"../TelemetryPanel"

const MANAGER_PROCESS_PRIORITY: int = 100
const CURRENT_DRONES_TOPIC: String = "current_drones"
const LEGACY_DRONE_COUNT_TOPIC: String = "drone_count"

var active_drones: Array[Node3D] = []
var drone_count: int = 0
var telemetry_labels: Dictionary = {}

@onready var telemetry_panel: VBoxContainer = get_node_or_null(telemetry_panel_path) as VBoxContainer

# Spawns the initial contiguous set of swarm drones.
func _ready() -> void:
	# Publish tick after child drones have published their per-drone state.
	process_priority = MANAGER_PROCESS_PRIORITY

	max_drones = max(max_drones, 1)
	min_drones = clamp(min_drones, 1, max_drones)
	current_drones = clamp(current_drones, min_drones, max_drones)
	formation_id = _clamp_formation_id(formation_id)

	for drone_index: int in range(current_drones):
		add_drone(_spawn_position_for(drone_index))

	_publish_drone_count()
	_publish_formation_id()
	_sync_telemetry_widgets()
	_update_telemetry_widgets()

# Publishes the manager-owned global DDS state for this frame.
func _process(delta: float) -> void:
	_publish_drone_count()
	_publish_formation_id()
	_publish_tick(delta)
	_sync_telemetry_widgets()
	_update_telemetry_widgets()

# Instantiates one SwarmRobot with the next contiguous drone id.
func add_drone(spawn_position: Vector3 = Vector3.ZERO) -> Node3D:
	if active_drones.size() >= max_drones:
		push_warning("SwarmManager cannot add more than %d drones." % max_drones)
		return null

	if robot_scene == null:
		push_error("SwarmManager cannot add drones because robot_scene is not assigned.")
		return null

	var next_drone_id: int = active_drones.size()
	var swarm_robot: Node3D = robot_scene.instantiate() as Node3D
	if swarm_robot == null:
		push_error("robot_scene must point to a Node3D root.")
		return null

	if not swarm_robot.has_method("deactivate") or not swarm_robot.has_method("do_reset") or not swarm_robot.has_method("get_display_position"):
		push_error("robot_scene root must expose the SwarmRobot API.")
		return null

	swarm_robot.name = "D%d" % next_drone_id
	swarm_robot.set("drone_id", next_drone_id)
	swarm_robot.position = spawn_position
	add_child(swarm_robot)

	active_drones.append(swarm_robot)
	drone_count = active_drones.size()
	current_drones = drone_count
	_publish_drone_count()

	return swarm_robot

# Adds one drone in the next stable id slot.
func add_next_drone() -> Node3D:
	return add_drone(_spawn_position_for(active_drones.size()))

# Removes the most recently added drone and marks it inactive on DDS.
func remove_latest_drone() -> void:
	if active_drones.size() <= min_drones:
		push_warning("SwarmManager cannot keep fewer than %d drone(s)." % min_drones)
		_refresh_drone_count()
		return

	var swarm_robot: Node3D = active_drones.pop_back() as Node3D
	if is_instance_valid(swarm_robot):
		swarm_robot.call("deactivate")
		if swarm_robot.get_parent() == self:
			remove_child(swarm_robot)
		swarm_robot.queue_free()

	_refresh_drone_count()

# Updates the selected formation without computing target offsets in Godot.
func set_formation_id(next_formation_id: int) -> void:
	formation_id = _clamp_formation_id(next_formation_id)
	_publish_formation_id()

# Resets every active drone without changing swarm membership.
func reset_all() -> void:
	for swarm_robot: Node3D in active_drones:
		swarm_robot.call("do_reset")
	_publish_drone_count()

# Computes a deterministic world slot for a drone id.
func _spawn_position_for(drone_id_to_spawn: int) -> Vector3:
	var slot_count: int = max(max_drones, 1)
	var centered_index: float = float(drone_id_to_spawn) - (float(slot_count - 1) * 0.5)
	return Vector3(centered_index * spawn_spacing, spawn_height, 0.0)

# Refreshes count fields and republishes the DDS count.
func _refresh_drone_count() -> void:
	drone_count = active_drones.size()
	current_drones = drone_count
	_publish_drone_count()
	_sync_telemetry_widgets()

# Adds and removes telemetry rows so the UI matches active_drones.
func _sync_telemetry_widgets() -> void:
	if telemetry_panel == null:
		return

	var active_ids: Dictionary = {}
	for swarm_robot: Node3D in active_drones:
		var drone_id_value: int = _drone_id_for(swarm_robot)
		active_ids[drone_id_value] = true
		if not telemetry_labels.has(drone_id_value):
			var label := Label.new()
			label.name = "D%dTelemetry" % drone_id_value
			label.add_theme_font_size_override("font_size", 14)
			telemetry_panel.add_child(label)
			telemetry_labels[drone_id_value] = label

	for drone_id in telemetry_labels.keys():
		if not active_ids.has(drone_id):
			var label_to_remove: Label = telemetry_labels[drone_id] as Label
			if label_to_remove != null:
				label_to_remove.queue_free()
			telemetry_labels.erase(drone_id)

# Writes the current bare minimum per-drone telemetry rows.
func _update_telemetry_widgets() -> void:
	if telemetry_panel == null:
		return

	for swarm_robot: Node3D in active_drones:
		var drone_id_value: int = _drone_id_for(swarm_robot)
		var label: Label = telemetry_labels.get(drone_id_value) as Label
		if label == null:
			continue

		var display_position: Vector3 = _display_position_for(swarm_robot)
		label.text = "D%d | X %.2f  Y %.2f  Z %.2f" % [
			drone_id_value,
			display_position.x,
			display_position.y,
			display_position.z,
		]

# Reads the dynamic drone id from a SwarmRobot-compatible node.
func _drone_id_for(swarm_robot: Node) -> int:
	return int(swarm_robot.get("drone_id"))

# Reads the display position from a SwarmRobot-compatible node.
func _display_position_for(swarm_robot: Node) -> Vector3:
	var display_position = swarm_robot.call("get_display_position")
	if display_position is Vector3:
		return display_position
	return Vector3.ZERO

# Clamps the formation enum to the supported DDS contract range.
func _clamp_formation_id(value: int) -> int:
	return clamp(value, Formation.NONE, Formation.CIRCLE)

# Publishes the current active drone count through DDS.
func _publish_drone_count() -> void:
	drone_count = active_drones.size()
	current_drones = drone_count
	DDS.publish(CURRENT_DRONES_TOPIC, DDS.DDS_TYPE_INT, current_drones)
	DDS.publish(LEGACY_DRONE_COUNT_TOPIC, DDS.DDS_TYPE_INT, current_drones)

# Publishes the selected formation enum through DDS.
func _publish_formation_id() -> void:
	DDS.publish("formation_id", DDS.DDS_TYPE_INT, formation_id)

# Publishes the single global controller wake-up signal.
func _publish_tick(delta: float) -> void:
	DDS.publish("tick", DDS.DDS_TYPE_FLOAT, delta)

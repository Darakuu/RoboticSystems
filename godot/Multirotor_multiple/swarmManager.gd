class_name SwarmManager
extends Node3D

enum Formation { NONE, LINE, TRIANGLE, SQUARE, CIRCLE }

const MANAGER_PROCESS_PRIORITY: int = 100

@export_range(1, 6) var current_drones: int = 4
@export_range(1, 6) var max_drones: int = 6
@export_range(1, 6) var min_drones: int = 1
@export var spawn_spacing: float = 1.4
@export var spawn_height: float = 0.214639
@export var robot_scene: PackedScene = preload("res://swarmRobot.tscn")
@export var formation_id: Formation = Formation.LINE

var active_drones: Array[SwarmRobot] = []
var telemetry_labels: Array[Label] = []

@onready var telemetry_panel: VBoxContainer = $"../TelemetryPanel"


func _ready() -> void:
	# Child drones publish their state before the manager publishes the global tick.
	process_priority = MANAGER_PROCESS_PRIORITY
	max_drones = max(max_drones, 1)
	min_drones = clamp(min_drones, 1, max_drones)
	current_drones = clamp(current_drones, min_drones, max_drones)

	for drone_id: int in range(current_drones):
		_add_drone(_spawn_position(drone_id))


func _process(delta: float) -> void:
	_publish_global_state(delta)
	_update_telemetry()


func add_next_drone() -> void:
	if active_drones.size() >= max_drones:
		return
	_add_drone(_spawn_position(active_drones.size()))


func remove_latest_drone() -> void:
	if active_drones.size() <= min_drones:
		return

	var robot: SwarmRobot = active_drones.pop_back()
	robot.deactivate()
	robot.queue_free()
	current_drones = active_drones.size()

	if not telemetry_labels.is_empty():
		var label: Label = telemetry_labels.pop_back()
		label.queue_free()


func reset_all() -> void:
	for robot: SwarmRobot in active_drones:
		robot.do_reset()


func set_formation_id(value: int) -> void:
	formation_id = clampi(value, Formation.NONE, Formation.CIRCLE)


func _add_drone(spawn_position: Vector3) -> void:
	var robot: SwarmRobot = robot_scene.instantiate() as SwarmRobot
	if robot == null:
		push_error("robot_scene must use SwarmRobot as its root script.")
		return

	robot.drone_id = active_drones.size()
	robot.name = "D%d" % robot.drone_id
	robot.position = spawn_position
	add_child(robot)
	active_drones.append(robot)
	current_drones = active_drones.size()
	_add_telemetry_label(robot.drone_id)


func _spawn_position(drone_id: int) -> Vector3:
	var centered_id: float = drone_id - (max_drones - 1) * 0.5
	return Vector3(centered_id * spawn_spacing, spawn_height, 0.0)


func _publish_global_state(delta: float) -> void:
	DDS.publish("current_drones", DDS.DDS_TYPE_INT, current_drones)
	DDS.publish("drone_count", DDS.DDS_TYPE_INT, current_drones)
	DDS.publish("formation_id", DDS.DDS_TYPE_INT, formation_id)
	DDS.publish("tick", DDS.DDS_TYPE_FLOAT, delta)


func _add_telemetry_label(drone_id: int) -> void:
	var label := Label.new()
	label.name = "D%dTelemetry" % drone_id
	label.add_theme_font_size_override("font_size", 14)
	telemetry_panel.add_child(label)
	telemetry_labels.append(label)


func _update_telemetry() -> void:
	for drone_id: int in range(active_drones.size()):
		var position_state: Vector3 = active_drones[drone_id].get_display_position()
		telemetry_labels[drone_id].text = "D%d | X %.2f  Y %.2f  Z %.2f" % [
			drone_id,
			position_state.x,
			position_state.y,
			position_state.z,
		]

class_name BoidsDebugOverlay
extends Node3D

const FLOAT_TOPICS: Array[String] = [
	"boids_x", "boids_y", "boids_length", "boids_safe_distance",
	"base_target_x", "base_target_y", "base_target_z",
	"target_x", "target_y", "target_z", "target_distance",
]
const INT_TOPICS: Array[String] = ["boids_active", "boids_neighbors", "boids_mode"]
const BOIDS_SEPARATION: int = 1
const BOIDS_PREDICTIVE: int = 2
const BOX_EDGES: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 0),
	Vector2i(4, 5), Vector2i(5, 6), Vector2i(6, 7), Vector2i(7, 4),
	Vector2i(0, 4), Vector2i(1, 5), Vector2i(2, 6), Vector2i(3, 7),
]

@export_range(1, 12) var max_drones: int = 6
@export var label_height: float = 0.45
@export var arrow_head_length: float = 0.18
@export var arrow_head_width: float = 0.08
@export var bounds_half_size: Vector3 = Vector3(0.35, 0.2, 0.35)

var debug_visible: bool = false
var collision_bounds_visible: bool = true
var debug_text_visible: bool = true
var rows: Array[DebugRow] = []

var target_material: StandardMaterial3D
var separation_material: StandardMaterial3D
var predictive_material: StandardMaterial3D
var bounds_material: StandardMaterial3D

@onready var swarm_manager: SwarmManager = $"../SwarmManager"


class DebugRow:
	var target_mesh: MeshInstance3D
	var avoidance_mesh: MeshInstance3D
	var bounds_mesh: MeshInstance3D
	var label: Label3D


func _ready() -> void:
	target_material = _line_material(Color(0.1, 0.7, 1.0))
	separation_material = _line_material(Color(1.0, 0.35, 0.1))
	predictive_material = _line_material(Color(1.0, 0.85, 0.1))
	bounds_material = _line_material(Color(0.2, 1.0, 0.35))

	_subscribe_topics()
	for drone_id: int in range(max_drones):
		rows.append(_create_row(drone_id))
	set_debug_visible(false)


func _process(_delta: float) -> void:
	if not debug_visible:
		return

	for drone_id: int in range(max_drones):
		var robot: SwarmRobot = null
		if drone_id < swarm_manager.active_drones.size():
			robot = swarm_manager.active_drones[drone_id]
		_update_row(drone_id, rows[drone_id], robot)


func set_debug_visible(enabled: bool) -> void:
	debug_visible = enabled
	visible = enabled
	if not enabled:
		for row: DebugRow in rows:
			row.label.visible = false


func toggle_debug_visible() -> bool:
	set_debug_visible(not debug_visible)
	return debug_visible


func set_collision_bounds_visible(enabled: bool) -> void:
	collision_bounds_visible = enabled
	for row: DebugRow in rows:
		row.bounds_mesh.visible = debug_visible and enabled


func toggle_collision_bounds_visible() -> bool:
	set_collision_bounds_visible(not collision_bounds_visible)
	return collision_bounds_visible


func set_debug_text_visible(enabled: bool) -> void:
	debug_text_visible = enabled
	if not enabled:
		for row: DebugRow in rows:
			row.label.visible = false


func toggle_debug_text_visible() -> bool:
	set_debug_text_visible(not debug_text_visible)
	return debug_text_visible


func _subscribe_topics() -> void:
	for drone_id: int in range(max_drones):
		for drone_name: String in FLOAT_TOPICS:
			DDS.subscribe(_topic(drone_id, drone_name))
		for drone_name: String in INT_TOPICS:
			DDS.subscribe(_topic(drone_id, drone_name))


func _create_row(drone_id: int) -> DebugRow:
	var row := DebugRow.new()
	row.target_mesh = _new_line_mesh("D%dTarget" % drone_id, target_material)
	row.avoidance_mesh = _new_line_mesh("D%dAvoidance" % drone_id, predictive_material)
	row.bounds_mesh = _new_line_mesh("D%dBounds" % drone_id, bounds_material)

	row.label = Label3D.new()
	row.label.name = "D%dDebugLabel" % drone_id
	row.label.font_size = 32
	row.label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	row.label.no_depth_test = true
	add_child(row.label)
	return row


func _new_line_mesh(node_name: String, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.mesh = ImmediateMesh.new()
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	return mesh_instance


func _update_row(drone_id: int, row: DebugRow, robot: SwarmRobot) -> void:
	var target_mesh: ImmediateMesh = row.target_mesh.mesh as ImmediateMesh
	var avoidance_mesh: ImmediateMesh = row.avoidance_mesh.mesh as ImmediateMesh
	var bounds_mesh: ImmediateMesh = row.bounds_mesh.mesh as ImmediateMesh
	target_mesh.clear_surfaces()
	avoidance_mesh.clear_surfaces()
	bounds_mesh.clear_surfaces()

	if robot == null or _read_int(drone_id, "boids_active") == 0:
		row.label.visible = false
		row.bounds_mesh.visible = false
		return

	var current_position: Vector3 = robot.get_world_position()
	var base_target: Vector3 = _read_point(drone_id, "base_target")
	var target: Vector3 = _read_point(drone_id, "target")
	var mode: int = _read_int(drone_id, "boids_mode")

	row.avoidance_mesh.material_override = _material_for_mode(mode)
	_draw_arrow(target_mesh, current_position, target)
	_draw_arrow(avoidance_mesh, base_target, target)

	row.bounds_mesh.visible = collision_bounds_visible
	if collision_bounds_visible:
		_draw_box(bounds_mesh, current_position - bounds_half_size, current_position + bounds_half_size)

	row.label.visible = debug_text_visible
	row.label.global_position = current_position + Vector3.UP * label_height
	row.label.text = "D%d\n[boids mode: %s]\n[boids offset: %.2f]\n[neighbors: %d]\n[target dist %.2f]" % [
		drone_id,
		_mode_name(mode),
		_read_float(drone_id, "boids_length"),
		_read_int(drone_id, "boids_neighbors"),
		_read_float(drone_id, "target_distance"),
	]


func _draw_arrow(mesh: ImmediateMesh, start: Vector3, end: Vector3) -> void:
	var delta: Vector3 = end - start
	if delta.length() < 0.01:
		return

	var direction: Vector3 = delta.normalized()
	var side: Vector3 = direction.cross(Vector3.UP).normalized()
	if side.is_zero_approx():
		side = Vector3.RIGHT

	var head_length: float = min(arrow_head_length, delta.length() * 0.4)
	var head_width: float = min(arrow_head_width, head_length * 0.6)
	var head_base: Vector3 = end - direction * head_length

	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for point: Vector3 in [start, end, end, head_base + side * head_width, end, head_base - side * head_width]:
		mesh.surface_add_vertex(point)
	mesh.surface_end()


func _draw_box(mesh: ImmediateMesh, minimum: Vector3, maximum: Vector3) -> void:
	var corners: Array[Vector3] = [
		Vector3(minimum.x, minimum.y, minimum.z),
		Vector3(maximum.x, minimum.y, minimum.z),
		Vector3(maximum.x, minimum.y, maximum.z),
		Vector3(minimum.x, minimum.y, maximum.z),
		Vector3(minimum.x, maximum.y, minimum.z),
		Vector3(maximum.x, maximum.y, minimum.z),
		Vector3(maximum.x, maximum.y, maximum.z),
		Vector3(minimum.x, maximum.y, maximum.z),
	]

	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for edge: Vector2i in BOX_EDGES:
		mesh.surface_add_vertex(corners[edge.x])
		mesh.surface_add_vertex(corners[edge.y])
	mesh.surface_end()


func _read_point(drone_id: int, prefix: String) -> Vector3:
	var x: float = _read_float(drone_id, "%s_x" % prefix)
	var y: float = _read_float(drone_id, "%s_y" % prefix)
	var z: float = _read_float(drone_id, "%s_z" % prefix)
	return Vector3(y, z, x)


func _read_float(drone_id: int, drone_name: String) -> float:
	return float(DDS.read(_topic(drone_id, drone_name)))


func _read_int(drone_id: int, drone_name: String) -> int:
	return int(round(_read_float(drone_id, drone_name)))


func _topic(drone_id: int, drone_name: String) -> String:
	return "D%d_%s" % [drone_id, drone_name]


func _material_for_mode(mode: int) -> StandardMaterial3D:
	return separation_material if mode == BOIDS_SEPARATION else predictive_material


func _mode_name(mode: int) -> String:
	if mode == BOIDS_SEPARATION:
		return "separation"
	if mode == BOIDS_PREDICTIVE:
		return "predictive"
	return "none"


func _line_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.disable_receive_shadows = true
	return material

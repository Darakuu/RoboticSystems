extends Node3D

@export var max_drones: int = 6
@export var swarm_manager_path: NodePath = ^"../SwarmManager"
@export var label_height: float = 0.45
@export var arrow_head_length: float = 0.18
@export var arrow_head_width: float = 0.08

const FLOAT_DEBUG_TOPICS: Array[String] = [
	"boids_x", "boids_y", "boids_length", "boids_safe_distance",
	"base_target_x", "base_target_y", "base_target_z",
	"target_x", "target_y", "target_z", "target_distance",
]
const INT_DEBUG_TOPICS: Array[String] = ["boids_active", "boids_neighbors", "boids_mode"]
const BOIDS_MODE_NONE: int = 0
const BOIDS_MODE_SEPARATION: int = 1
const BOIDS_MODE_PREDICTIVE: int = 2

var debug_visible: bool = false
var collision_bounds_visible: bool = true
var debug_rows: Dictionary = {}
var target_material: StandardMaterial3D
var separation_material: StandardMaterial3D
var predictive_material: StandardMaterial3D
var collision_material: StandardMaterial3D
var swarm_manager: Node = null
var collision_bounds: Dictionary = {}

# Builds debug draw nodes and DDS subscriptions.
func _ready() -> void:
	swarm_manager = get_node_or_null(swarm_manager_path)
	target_material = _make_line_material(Color(0.1, 0.7, 1.0, 1.0))
	separation_material = _make_line_material(Color(1.0, 0.35, 0.1, 1.0))
	predictive_material = _make_line_material(Color(1.0, 0.85, 0.1, 1.0))
	collision_material = _make_line_material(Color(0.2, 1.0, 0.35, 1.0))
	_subscribe_debug_topics()
	_create_debug_rows()
	set_debug_visible(false)

# Refreshes arrows and labels from DDS debug topics.
func _process(_delta: float) -> void:
	if not debug_visible:
		return

	for drone_id: int in range(max_drones):
		_update_drone_debug(drone_id)
	_sync_collision_bounds()

# Shows or hides all debug helpers.
func set_debug_visible(enabled: bool) -> void:
	debug_visible = enabled
	visible = enabled
	for row in debug_rows.values():
		var label: Label3D = row["label"] as Label3D
		var target_mesh: MeshInstance3D = row["target_mesh"] as MeshInstance3D
		var boids_mesh: MeshInstance3D = row["boids_mesh"] as MeshInstance3D
		label.visible = enabled
		target_mesh.visible = enabled
		boids_mesh.visible = enabled
	_set_collision_bounds_visible(enabled and collision_bounds_visible)

# Flips the current debug visibility state.
func toggle_debug_visible() -> bool:
	set_debug_visible(not debug_visible)
	return debug_visible

# Shows or hides the per-drone collision bounds while debug is enabled.
func set_collision_bounds_visible(enabled: bool) -> void:
	collision_bounds_visible = enabled
	_set_collision_bounds_visible(debug_visible and collision_bounds_visible)

# Flips the current collision-bound visibility state.
func toggle_collision_bounds_visible() -> bool:
	set_collision_bounds_visible(not collision_bounds_visible)
	return collision_bounds_visible

# Registers every notebook-published Boids debug topic.
func _subscribe_debug_topics() -> void:
	for drone_id: int in range(max_drones):
		for topic_name: String in FLOAT_DEBUG_TOPICS:
			DDS.subscribe(_topic(drone_id, topic_name))
		for topic_name: String in INT_DEBUG_TOPICS:
			DDS.subscribe(_topic(drone_id, topic_name))

# Creates one mesh pair and one value label per possible drone.
func _create_debug_rows() -> void:
	for drone_id: int in range(max_drones):
		var target_mesh := MeshInstance3D.new()
		target_mesh.name = "D%dTargetArrow" % drone_id
		target_mesh.mesh = ImmediateMesh.new()
		target_mesh.material_override = target_material
		add_child(target_mesh)

		var boids_mesh := MeshInstance3D.new()
		boids_mesh.name = "D%dBoidsArrow" % drone_id
		boids_mesh.mesh = ImmediateMesh.new()
		boids_mesh.material_override = predictive_material
		add_child(boids_mesh)

		var label := Label3D.new()
		label.name = "D%dBoidsLabel" % drone_id
		label.font_size = 32
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		add_child(label)

		debug_rows[drone_id] = {
			"target_mesh": target_mesh,
			"boids_mesh": boids_mesh,
			"label": label,
		}

# Updates one drone's visual Boids diagnostics.
func _update_drone_debug(drone_id: int) -> void:
	var row: Dictionary = debug_rows[drone_id]
	var target_mesh_instance: MeshInstance3D = row["target_mesh"] as MeshInstance3D
	var boids_mesh_instance: MeshInstance3D = row["boids_mesh"] as MeshInstance3D
	var target_mesh: ImmediateMesh = target_mesh_instance.mesh as ImmediateMesh
	var boids_mesh: ImmediateMesh = boids_mesh_instance.mesh as ImmediateMesh
	var label: Label3D = row["label"] as Label3D

	target_mesh.clear_surfaces()
	boids_mesh.clear_surfaces()

	if _read_int(_topic(drone_id, "boids_active")) == 0:
		label.visible = false
		return

	var current_position: Vector3 = _world_position_for_drone(drone_id)
	var base_target: Vector3 = _read_debug_point(drone_id, "base_target")
	var adjusted_target: Vector3 = _read_debug_point(drone_id, "target")
	var boids_length: float = _read_float(_topic(drone_id, "boids_length"))
	var safe_distance: float = _read_float(_topic(drone_id, "boids_safe_distance"))
	var target_distance: float = _read_float(_topic(drone_id, "target_distance"))
	var neighbor_count: int = _read_int(_topic(drone_id, "boids_neighbors"))
	var boids_mode: int = _read_int(_topic(drone_id, "boids_mode"))

	boids_mesh_instance.material_override = _boids_material_for_mode(boids_mode)
	_draw_arrow(target_mesh, current_position, adjusted_target)
	_draw_arrow(boids_mesh, base_target, adjusted_target)

	label.visible = true
	label.global_position = current_position + Vector3(0.0, label_height, 0.0)
	label.text = "D%d\nmode %s (%d)\nboids %.2f\nsafe %.2f\nneighbors %d\ntarget %.2f" % [
		drone_id,
		_boids_mode_name(boids_mode),
		boids_mode,
		boids_length,
		safe_distance,
		neighbor_count,
		target_distance,
	]

# Draws a simple line arrow into an ImmediateMesh.
func _draw_arrow(mesh: ImmediateMesh, start: Vector3, end: Vector3) -> void:
	var delta: Vector3 = end - start
	var length: float = delta.length()
	if length <= 0.01:
		return

	var direction: Vector3 = delta / length
	var side: Vector3 = direction.cross(Vector3.UP)
	if side.length() <= 0.01:
		side = Vector3.RIGHT
	else:
		side = side.normalized()

	var head_length: float = min(arrow_head_length, length * 0.4)
	var head_width: float = min(arrow_head_width, head_length * 0.6)
	var head_base: Vector3 = end - (direction * head_length)

	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(start)
	mesh.surface_add_vertex(end)
	mesh.surface_add_vertex(end)
	mesh.surface_add_vertex(head_base + (side * head_width))
	mesh.surface_add_vertex(end)
	mesh.surface_add_vertex(head_base - (side * head_width))
	mesh.surface_end()

# Converts a DDS x/y/z point into Godot world axes.
func _dds_point_to_world(x: float, y: float, z: float) -> Vector3:
	return Vector3(y, z, x)

# Reads a notebook-published target point from DDS.
func _read_debug_point(drone_id: int, prefix: String) -> Vector3:
	return _dds_point_to_world(
		_read_float(_topic(drone_id, "%s_x" % prefix)),
		_read_float(_topic(drone_id, "%s_y" % prefix)),
		_read_float(_topic(drone_id, "%s_z" % prefix))
	)

# Reads the current drone position using the same DDS axis convention.
func _world_position_for_drone(drone_id: int) -> Vector3:
	for swarm_robot in _active_drones():
		if int(swarm_robot.get("drone_id")) != drone_id:
			continue

		var display_position = swarm_robot.call("get_display_position")
		if display_position is Vector3:
			return _dds_point_to_world(display_position.x, display_position.y, display_position.z)

	return Vector3.ZERO

# Returns the manager-owned active drone list without depending on custom types.
func _active_drones() -> Array:
	if swarm_manager == null:
		return []

	var drones = swarm_manager.get("active_drones")
	if drones is Array:
		return drones
	return []

# Updates one wireframe collision bound for each active drone.
func _sync_collision_bounds() -> void:
	var active_ids: Dictionary = {}
	for swarm_robot in _active_drones():
		var drone_id: int = int(swarm_robot.get("drone_id"))
		active_ids[drone_id] = true
		var mesh_instance: MeshInstance3D = _collision_bounds_mesh_for(drone_id)
		var mesh: ImmediateMesh = mesh_instance.mesh as ImmediateMesh
		mesh.clear_surfaces()
		mesh_instance.visible = debug_visible and collision_bounds_visible

		var bounds: Dictionary = _collision_bounds_for(swarm_robot)
		if bounds.is_empty():
			mesh_instance.visible = false
			continue

		_draw_wire_box(mesh, bounds["min"], bounds["max"])

	for drone_id in collision_bounds.keys():
		if active_ids.has(drone_id):
			continue

		var stale_mesh: MeshInstance3D = collision_bounds[drone_id] as MeshInstance3D
		if stale_mesh == null:
			continue

		stale_mesh.visible = false
		var stale_immediate_mesh: ImmediateMesh = stale_mesh.mesh as ImmediateMesh
		if stale_immediate_mesh != null:
			stale_immediate_mesh.clear_surfaces()

# Returns the reusable wireframe mesh for one drone id.
func _collision_bounds_mesh_for(drone_id: int) -> MeshInstance3D:
	if collision_bounds.has(drone_id):
		return collision_bounds[drone_id] as MeshInstance3D

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "D%dCollisionBounds" % drone_id
	mesh_instance.mesh = ImmediateMesh.new()
	mesh_instance.material_override = collision_material
	add_child(mesh_instance)
	collision_bounds[drone_id] = mesh_instance
	return mesh_instance

# Shows or hides all collision bound helpers.
func _set_collision_bounds_visible(enabled: bool) -> void:
	for mesh_instance in collision_bounds.values():
		var collision_mesh: MeshInstance3D = mesh_instance as MeshInstance3D
		if collision_mesh != null:
			collision_mesh.visible = enabled

# Computes a world-space AABB around a drone's collision shapes.
func _collision_bounds_for(swarm_robot: Node) -> Dictionary:
	var points: Array = []
	for collision_shape in _collision_shapes_for(swarm_robot):
		points.append_array(_world_points_for_collision_shape(collision_shape))

	if points.is_empty():
		return {}

	var minimum: Vector3 = points[0]
	var maximum: Vector3 = points[0]
	for point: Vector3 in points:
		minimum = minimum.min(point)
		maximum = maximum.max(point)

	return {"min": minimum, "max": maximum}

# Finds CollisionShape3D descendants under a swarm robot.
func _collision_shapes_for(root: Node) -> Array:
	var shapes: Array = []
	if root is CollisionShape3D:
		shapes.append(root as CollisionShape3D)

	for child: Node in root.get_children():
		shapes.append_array(_collision_shapes_for(child))

	return shapes

# Converts a collision shape into representative world-space points.
func _world_points_for_collision_shape(collision_shape: CollisionShape3D) -> Array:
	var points: Array = []
	var shape: Shape3D = collision_shape.shape
	if shape == null:
		return points

	if shape is ConvexPolygonShape3D:
		var convex_shape: ConvexPolygonShape3D = shape as ConvexPolygonShape3D
		for point in convex_shape.points:
			points.append(collision_shape.global_transform * point)
		return points

	if shape is BoxShape3D:
		var box_shape: BoxShape3D = shape as BoxShape3D
		var half_size: Vector3 = box_shape.size * 0.5
		for point: Vector3 in _box_corners(-half_size, half_size):
			points.append(collision_shape.global_transform * point)
		return points

	var fallback_half_size := Vector3(0.35, 0.35, 0.35)
	for point: Vector3 in _box_corners(-fallback_half_size, fallback_half_size):
		points.append(collision_shape.global_transform * point)
	return points

# Returns the eight corners of an axis-aligned box.
func _box_corners(minimum: Vector3, maximum: Vector3) -> Array:
	return [
		Vector3(minimum.x, minimum.y, minimum.z),
		Vector3(maximum.x, minimum.y, minimum.z),
		Vector3(maximum.x, minimum.y, maximum.z),
		Vector3(minimum.x, minimum.y, maximum.z),
		Vector3(minimum.x, maximum.y, minimum.z),
		Vector3(maximum.x, maximum.y, minimum.z),
		Vector3(maximum.x, maximum.y, maximum.z),
		Vector3(minimum.x, maximum.y, maximum.z),
	]

# Draws a wireframe box into an ImmediateMesh.
func _draw_wire_box(mesh: ImmediateMesh, minimum: Vector3, maximum: Vector3) -> void:
	var corners: Array = _box_corners(minimum, maximum)
	var edges: Array = [
		[0, 1], [1, 2], [2, 3], [3, 0],
		[4, 5], [5, 6], [6, 7], [7, 4],
		[0, 4], [1, 5], [2, 6], [3, 7],
	]

	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for edge in edges:
		mesh.surface_add_vertex(corners[edge[0]])
		mesh.surface_add_vertex(corners[edge[1]])
	mesh.surface_end()

# Builds a namespaced DDS topic.
func _topic(drone_id: int, topic_name: String) -> String:
	return "D%d_%s" % [drone_id, topic_name]

# Reads a subscribed float DDS value.
func _read_float(topic_name: String) -> float:
	return float(DDS.read(topic_name))

# Reads a subscribed int DDS value.
func _read_int(topic_name: String) -> int:
	return int(round(_read_float(topic_name)))

# Chooses the correction-arrow material for the active Boids mode.
func _boids_material_for_mode(boids_mode: int) -> StandardMaterial3D:
	if boids_mode == BOIDS_MODE_SEPARATION:
		return separation_material
	if boids_mode == BOIDS_MODE_PREDICTIVE:
		return predictive_material
	return predictive_material

# Converts the numeric Boids mode to a compact debug label.
func _boids_mode_name(boids_mode: int) -> String:
	if boids_mode == BOIDS_MODE_SEPARATION:
		return "separation"
	if boids_mode == BOIDS_MODE_PREDICTIVE:
		return "predictive"
	return "none"

# Creates an unshaded line material for debug helpers.
func _make_line_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

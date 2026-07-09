extends Area3D

@export var radius: float = 0.18
@export var alpha: float = 0.35

const TOPIC_X: String = "target_point_x"
const TOPIC_Y: String = "target_point_y"
const TOPIC_Z: String = "target_point_z"

var dragging: bool = false

# Builds the visible marker and collision volume.
func _ready() -> void:
	input_ray_pickable = true
	_create_marker()
	_publish_position()

# Publishes the marker as a DDS x/y/z target point.
func _process(_delta: float) -> void:
	_publish_position()

# Starts dragging when the marker is clicked.
func _input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed

# Moves the marker while left-click dragging.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		dragging = false
	if dragging and event is InputEventMouseMotion:
		_drag_to_mouse()

# Creates a transparent sphere that remains visible in the scene.
func _create_marker() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.1, 0.8, 1.0, alpha)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var mesh_instance := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = radius
	sphere_mesh.height = radius * 2.0
	mesh_instance.mesh = sphere_mesh
	mesh_instance.material_override = material
	add_child(mesh_instance)

	var collision_shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = radius
	collision_shape.shape = sphere_shape
	add_child(collision_shape)

# Projects the mouse ray onto the current horizontal target plane.
func _drag_to_mouse() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var mouse_position := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	if abs(ray_direction.y) <= 0.001:
		return

	var distance := (global_position.y - ray_origin.y) / ray_direction.y
	if distance < 0.0:
		return

	global_position = ray_origin + (ray_direction * distance)
	_publish_position()

# Converts Godot x/y/z into the existing DDS X/Y/Z axis convention.
func _publish_position() -> void:
	DDS.publish(TOPIC_X, DDS.DDS_TYPE_FLOAT, global_position.z)
	DDS.publish(TOPIC_Y, DDS.DDS_TYPE_FLOAT, global_position.x)
	DDS.publish(TOPIC_Z, DDS.DDS_TYPE_FLOAT, global_position.y)

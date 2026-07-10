extends Area3D

const TOPICS: Array[String] = ["target_point_x", "target_point_y", "target_point_z"]

@export var radius: float = 0.18
@export_range(0.0, 1.0) var alpha: float = 0.35

var dragging: bool = false


func _ready() -> void:
	input_ray_pickable = true
	_create_marker()
	_publish_position()


func _process(_delta: float) -> void:
	_publish_position()


func _input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		dragging = false
	elif dragging and event is InputEventMouseMotion:
		_drag_to_mouse()


func _create_marker() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.1, 0.8, 1.0, alpha)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = sphere
	mesh_instance.material_override = material
	add_child(mesh_instance)

	var collision_shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = radius
	collision_shape.shape = sphere_shape
	add_child(collision_shape)


func _drag_to_mouse() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return

	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_position)
	var ray_direction: Vector3 = camera.project_ray_normal(mouse_position)
	if abs(ray_direction.y) < 0.001:
		return

	var distance: float = (global_position.y - ray_origin.y) / ray_direction.y
	if distance >= 0.0:
		global_position = ray_origin + ray_direction * distance


func _publish_position() -> void:
	# DDS X/Y/Z correspond to Godot Z/X/Y.
	var values: Array[float] = [global_position.z, global_position.x, global_position.y]
	for index: int in range(TOPICS.size()):
		DDS.publish(TOPICS[index], DDS.DDS_TYPE_FLOAT, values[index])

extends Button

@export var camera_path: NodePath = ^"../Camera3D"
@export var top_down_position: Vector3 = Vector3(0.0, 6.0, 0.0)
@export var top_down_target: Vector3 = Vector3.ZERO

var is_top_down: bool = false
var default_transform: Transform3D

@onready var camera: Camera3D = get_node_or_null(camera_path) as Camera3D

# Connects this button to the camera view toggle.
func _ready() -> void:
	pressed.connect(on_pressed)
	if camera == null:
		push_warning("CameraToggleButton could not find the Camera3D.")
		return

	default_transform = camera.global_transform
	_update_text()

# Switches between the default camera and top-down camera.
func on_pressed() -> void:
	if camera == null:
		return

	is_top_down = not is_top_down
	if is_top_down:
		_apply_top_down_view()
	else:
		_apply_default_view()
	_update_text()

# Applies the saved startup camera transform.
func _apply_default_view() -> void:
	camera.global_transform = default_transform

# Applies a top-down camera aimed at the world origin.
func _apply_top_down_view() -> void:
	camera.global_position = top_down_position
	camera.look_at(top_down_target, Vector3.FORWARD)

# Shows the action that pressing the button will perform next.
func _update_text() -> void:
	text = "Default View" if is_top_down else "Top View"

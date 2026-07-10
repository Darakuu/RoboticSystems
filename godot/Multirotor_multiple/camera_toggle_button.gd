extends Button

@export var top_position: Vector3 = Vector3(0.0, 6.0, 0.0)

var top_view: bool = false
var default_transform: Transform3D

@onready var camera: Camera3D = $"../Camera3D"


func _ready() -> void:
	default_transform = camera.global_transform
	pressed.connect(_toggle_view)
	_update_text()


func _toggle_view() -> void:
	top_view = not top_view
	if top_view:
		camera.global_position = top_position
		camera.look_at(Vector3.ZERO, Vector3.FORWARD)
	else:
		camera.global_transform = default_transform
	_update_text()


func _update_text() -> void:
	text = "Default View" if top_view else "Top View"

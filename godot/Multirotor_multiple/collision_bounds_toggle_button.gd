extends Button

@export var debug_overlay_path: NodePath = ^"../BoidsDebugOverlay"

@onready var debug_overlay: Node = get_node_or_null(debug_overlay_path)

# Connects this button to the Boids collision-bound toggle.
func _ready() -> void:
	pressed.connect(on_pressed)
	_refresh_label(true)
	if debug_overlay == null:
		push_warning("CollisionBoundsToggleButton could not find the Boids debug overlay.")

# Toggles the green per-drone collision bounds.
func on_pressed() -> void:
	if debug_overlay == null:
		return

	var is_visible: bool = bool(debug_overlay.call("toggle_collision_bounds_visible"))
	_refresh_label(is_visible)

# Shows whether pressing the button will enable or disable collision bounds.
func _refresh_label(is_visible: bool) -> void:
	text = "Hide Bounds" if is_visible else "Show Bounds"

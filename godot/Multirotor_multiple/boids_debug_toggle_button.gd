extends Button

@export var debug_overlay_path: NodePath = ^"../BoidsDebugOverlay"

@onready var debug_overlay: Node = get_node_or_null(debug_overlay_path)

# Connects this button to the Boids debug overlay toggle.
func _ready() -> void:
	pressed.connect(on_pressed)
	if debug_overlay == null:
		push_warning("BoidsDebugToggleButton could not find the BoidsDebugOverlay.")
		return
	_update_text(false)

# Toggles Boids arrows, labels, and collision bounds.
func on_pressed() -> void:
	if debug_overlay == null:
		return

	var is_visible: bool = bool(debug_overlay.call("toggle_debug_visible"))
	_update_text(is_visible)

# Shows whether pressing the button will enable or disable debug helpers.
func _update_text(is_visible: bool) -> void:
	text = "Hide Debug" if is_visible else "Show Debug"

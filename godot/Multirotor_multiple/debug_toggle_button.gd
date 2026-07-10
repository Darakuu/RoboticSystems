extends Button

enum Mode { OVERLAY, BOUNDS, TEXT }

@export var mode: Mode = Mode.OVERLAY

@onready var overlay: BoidsDebugOverlay = $"../BoidsDebugOverlay"


func _ready() -> void:
	pressed.connect(_toggle)
	_update_text(_is_enabled())


func _toggle() -> void:
	var enabled: bool
	match mode:
		Mode.BOUNDS:
			enabled = overlay.toggle_collision_bounds_visible()
		Mode.TEXT:
			enabled = overlay.toggle_debug_text_visible()
		_:
			enabled = overlay.toggle_debug_visible()
	_update_text(enabled)


func _is_enabled() -> bool:
	match mode:
		Mode.BOUNDS:
			return overlay.collision_bounds_visible
		Mode.TEXT:
			return overlay.debug_text_visible
		_:
			return overlay.debug_visible


func _update_text(enabled: bool) -> void:
	var label: String
	match mode:
		Mode.BOUNDS:
			label = "Bounds"
		Mode.TEXT:
			label = "Text"
		_:
			label = "Debug"
	text = "%s %s" % ["Hide" if enabled else "Show", label]

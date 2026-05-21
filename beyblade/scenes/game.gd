extends Node3D

func _input(event):
	if event is InputEventKey:
		if event.keycode == KEY_R:
			get_tree().reload_current_scene()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

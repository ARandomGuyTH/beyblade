extends Node3D

var effects = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for child in get_children():
		effects.append(child)

func activate_effects(pos : Vector3):
	for effect in effects:
		effect.activate(pos)

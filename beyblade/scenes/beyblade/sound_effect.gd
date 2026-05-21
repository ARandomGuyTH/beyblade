extends AudioStreamPlayer3D

func activate(pos : Vector3):
	global_position = pos
	play()

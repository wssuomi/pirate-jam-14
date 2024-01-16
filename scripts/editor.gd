extends Node2D

@onready var map_tiles = $MapTiles

func _on_quit_pressed():
	get_tree().quit()

func _input(event):
	if event is InputEventMouseButton:
		if Input.is_action_just_pressed("place_tile"):
			var pos = map_tiles.local_to_map(get_global_mouse_position())
			map_tiles.set_cell(0, pos, 0, Vector2(0,0))


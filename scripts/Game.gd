extends Node2D

@onready var pause_menu = $Camera/PauseMenu

var paused = false

func toggle_pause():
	if paused:
		pause_menu.hide()
		Engine.time_scale = 1
	else:
		pause_menu.show()
		Engine.time_scale = 0
	paused = !paused


func _physics_process(_delta):
	if Input.is_action_just_pressed("pause"):
		toggle_pause()

extends Node2D

@onready var pause_menu = $Camera/PauseMenu
@onready var camera = $Camera

const GRID_WIDTH = 128
const GRID_HEIGHT = 128

var paused = false
var grid = {}

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

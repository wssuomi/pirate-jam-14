extends Node2D

@onready var select_indicator = $SelectIndicator
@onready var map = $"../Map"
@onready var units: Dictionary = $"..".units

const SPEED = 10

var move_queue: Array[Vector2i] = []
var state: States = States.Guard
var start_pos: Vector2i

enum States {Guard, Walk, Attack}

func _process(delta):
	match state:
		States.Guard:
			if move_queue != []:
				state = States.Walk
				start_pos = map.local_to_map(global_position)
		States.Walk:
			var destination = map.map_to_local(move_queue[0])
			global_position = global_position.move_toward(destination, SPEED * delta)
			if global_position == destination:
				state = States.Guard
				units.erase(start_pos)
				units[move_queue[0]] = self
				start_pos = move_queue[0]
				move_queue.remove_at(0)

func select():
	select_indicator.show()

func deselect():
	select_indicator.hide()

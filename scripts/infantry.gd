extends Node2D

@onready var select_indicator = $SelectIndicator
@onready var map = $"../Map"
@onready var units: Dictionary = $"..".units
@onready var main = $".."

const SPEED = 10

var move_queue: Array[Vector2i] = []
var state: States = States.Guard

enum States {Guard, Walk, Attack}

func _process(delta):
	match state:
		States.Guard:
			if move_queue != []:
				if move_queue[0] not in units and main.is_walkable(main.tiles[move_queue[0]]):
					state = States.Walk
					units.erase(map.local_to_map(global_position))
					units[move_queue[0]] = self
				else:
					if len(move_queue) != 1:
						var path: Array[Vector2i] = main.find_path(map.local_to_map(global_position), move_queue[1])
						move_queue = path
					else:
						move_queue = []
		States.Walk:
			var destination = map.map_to_local(move_queue[0])
			global_position = global_position.move_toward(destination, SPEED * delta)
			if global_position == destination:
				state = States.Guard
				move_queue.remove_at(0)

func select():
	select_indicator.show()

func deselect():
	select_indicator.hide()

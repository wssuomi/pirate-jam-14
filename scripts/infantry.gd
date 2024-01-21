extends Node2D

@onready var select_indicator = $SelectIndicator
@onready var map = $"../Map"
@onready var units: Dictionary = $"..".units
@onready var main = $".."
@onready var unit_sprite = $UnitSprite

const SPEED = 10

enum Directions {Up, Down, Left, Right}

var move_queue: Array[Vector2i] = []
var state: States = States.Guard
var look_dir: Directions = Directions.Down

enum States {Guard, Walk, Attack}

func _process(delta):
	match state:
		States.Guard:
			if move_queue != []:
				if move_queue[0] not in units and main.is_walkable(main.tiles[move_queue[0]]):
					state = States.Walk
					units.erase(map.local_to_map(global_position))
					units[move_queue[0]] = self
					#NewValue = (((OldValue - OldMin) * NewRange) / OldRange) + NewMin
					#int((x - 0.0) / (128.0 - 0.0) * (4.0 - 0.0) + 0.0)
					print("pos: ", map.local_to_map(global_position))
					print("queue: ", move_queue[0])
					var angle = Vector2(map.local_to_map(global_position)).angle_to_point(move_queue[0])
					angle = int(angle * 180 / PI) + 135
					angle = int((((angle - 0) * (8 - 0)) / (360. - 0)) + 0) - 1
					print(angle)
					match angle:
						0:
							unit_sprite.play("walk_up")
							look_dir = Directions.Up
						4:
							unit_sprite.play("walk_down")
							look_dir = Directions.Down
						1,2,3:
							unit_sprite.play("walk_right")
							look_dir = Directions.Right
						5,6,7:
							unit_sprite.play("walk_left")
							look_dir = Directions.Left
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
				match look_dir:
					Directions.Up:
						unit_sprite.play("idle_up")
					Directions.Down:
						unit_sprite.play("idle_down")
					Directions.Left:
						unit_sprite.play("idle_left")
					Directions.Right:
						unit_sprite.play("idle_right")

func select():
	select_indicator.show()

func deselect():
	select_indicator.hide()

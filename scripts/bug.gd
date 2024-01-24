extends CharacterBody2D

@onready var map = $"../Map"
@onready var enemies: Dictionary = $"..".enemies
@onready var units: Dictionary = $"..".units
@onready var main = $".."
@onready var bug_sprite = $BugSprite

const SPEED = 15

enum Directions {Up, UpRight, UpLeft, Down, DownLeft, DownRight, Left, Right}

var move_queue: Array[Vector2i] = []
var state: States = States.Guard
var look_dir: Directions = Directions.Down

enum States {Guard, Walk, Attack}

func _process(delta):
	match state:
		States.Guard:
			if move_queue != []:
				if move_queue[0] not in enemies and move_queue[0] not in units and main.is_walkable(main.tiles[move_queue[0]]):
					state = States.Walk
					enemies.erase(map.local_to_map(global_position))
					enemies[move_queue[0]] = self
					var angle = Vector2(map.local_to_map(global_position)).angle_to_point(move_queue[0])
					angle = int(angle * 180 / PI) + 135
					angle = int((((angle - 0) * (8 - 0)) / (360. - 0)) + 0)
					main.clear_fog_around_pos(move_queue[0])
					match angle:
						1:
							bug_sprite.play("walk_up")
							look_dir = Directions.Up
						2:
							bug_sprite.play("walk_up_right")
							look_dir = Directions.UpRight
						3:
							bug_sprite.play("walk_right")
							look_dir = Directions.Right
						4:
							bug_sprite.play("walk_down_right")
							look_dir = Directions.DownRight
						5:
							bug_sprite.play("walk_down")
							look_dir = Directions.Down
						6:
							bug_sprite.play("walk_down_left")
							look_dir = Directions.DownLeft
						7:
							bug_sprite.play("walk_left")
							look_dir = Directions.Left
						0:
							bug_sprite.play("walk_up_left")
							look_dir = Directions.UpLeft
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
						bug_sprite.play("idle_up")
					Directions.Down:
						bug_sprite.play("idle_down")
					Directions.Left:
						bug_sprite.play("idle_left")
					Directions.Right:
						bug_sprite.play("idle_right")
					Directions.UpLeft:
						bug_sprite.play("idle_up_left")
					Directions.DownLeft:
						bug_sprite.play("idle_down_left")
					Directions.UpRight:
						bug_sprite.play("idle_up_right")
					Directions.DownRight:
						bug_sprite.play("idle_down_right")

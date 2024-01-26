extends CharacterBody2D

@onready var map = $"../Map"
@onready var enemies: Dictionary = $"..".enemies
@onready var units: Dictionary = $"..".units
@onready var buildings: Dictionary = $"..".buildings
@onready var main = $".."
@onready var bug_sprite = $BugSprite
@onready var idle_timer: Timer = $IdleTimer

const SPEED = 15

enum Directions {Up, UpRight, UpLeft, Down, DownLeft, DownRight, Left, Right}

var move_queue: Array[Vector2i] = []
var state: States = States.Idle
var look_dir: Directions = Directions.Down
var random_walk_range = 1
var rng = RandomNumberGenerator.new()
var health: int = 2
var attack_damage: int = 1
var attack_target: Vector2i = Vector2i(-1,-1)
var search_range: int = 3

enum States {Idle, Walk, Attack}

func _process(delta):
	match state:
		States.Idle:
			if move_queue != []:
				if move_queue[0] not in enemies and move_queue[0] not in units and main.is_walkable(main.tiles[move_queue[0]]):
					state = States.Walk
					enemies.erase(map.local_to_map(global_position))
					enemies[move_queue[0]] = self
					var angle = Vector2(map.local_to_map(global_position)).angle_to_point(move_queue[0])
					angle = int(angle * 180 / PI) + 135
					angle = int((((angle - 0) * (8 - 0)) / (360. - 0)) + 0)
					#main.clear_fog_around_pos(move_queue[0])
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
						var path: Array[Vector2i] = main.find_path(map.local_to_map(global_position), move_queue[-1])
						move_queue = path
					else:
						move_queue = []
		States.Walk:
			var destination = map.map_to_local(move_queue[0])
			global_position = global_position.move_toward(destination, SPEED * delta)
			if global_position == destination:
				state = States.Idle
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

func random_walk():
	var pos = main.map.local_to_map(self.global_position)
	var offset = Vector2i(rng.randi_range(-random_walk_range, random_walk_range), rng.randi_range(-random_walk_range,random_walk_range))
	var tile_pos = pos + offset
	if tile_pos.x >= 0 and tile_pos.x < main.GRID_WIDTH and tile_pos.y >= 0 and tile_pos.y < main.GRID_HEIGHT:
		if tile_pos not in enemies and tile_pos not in units and main.is_walkable(main.tiles[tile_pos]):
			return main.find_path(pos,tile_pos)
	return []

func _on_random_walk_timer_timeout():
	if state == States.Idle and attack_target == Vector2i(-1,-1):
		move_queue.append_array(random_walk())

func take_damage(damage_amount):
	health -= damage_amount
	if health <= 0:
		var k = enemies.find_key(self)
		if k != null:
			enemies.erase(k)
		self.queue_free()

func attack():
	if state == States.Walk:
		return
	if attack_target == Vector2i(-1,-1):
		return
	var pos = main.map.local_to_map(self.global_position)
	if main.get_distance(main.tiles[pos], main.tiles[attack_target]) > 14:
		return
	if attack_target in units.keys():
		if is_instance_valid(units[attack_target]):
			units[attack_target].take_damage(attack_damage)
			var angle = Vector2(map.local_to_map(global_position)).angle_to_point(attack_target)
			angle = int(angle * 180 / PI) + 135
			angle = int((((angle - 0) * (8 - 0)) / (360. - 0)) + 0)
			play_attack(angle)
		else:
			attack_target = Vector2i(-1,-1)
			play_idle()
	else:
		for k in buildings:
			if attack_target in k:
				if is_instance_valid(buildings[k]):
					buildings[k].take_damage(attack_damage)
					var angle = Vector2(map.local_to_map(global_position)).angle_to_point(attack_target)
					angle = int(angle * 180 / PI) + 135
					angle = int((((angle - 0) * (8 - 0)) / (360. - 0)) + 0)
					play_attack(angle)
				else:
					attack_target = Vector2i(-1,-1)
					play_idle()
				break

func _on_attack_timer_timeout():
	attack()

func _on_search_timer_timeout():
	for y in range(-search_range,search_range):
		for x in range(-search_range,search_range):
			var pos = main.map.local_to_map(global_position) + Vector2i(x,y)
			if pos in units.keys():
				attack_target = pos
				if main.get_distance(main.tiles[main.map.local_to_map(global_position)], main.tiles[attack_target]) > 14:
					if move_queue != []:
						var path = main.find_attack_path(move_queue[0],attack_target,14)
						var tmp: Array[Vector2i] = [move_queue[0]]
						tmp.append_array(path)
						move_queue = tmp
					else:
						var path = main.find_attack_path(main.map.local_to_map(global_position),attack_target,14)
						move_queue = path
				return
			else:
				for k in buildings:
					if pos in k:
						if not is_instance_valid(buildings[k]):
							continue
						attack_target = pos
						if main.get_distance(main.tiles[main.map.local_to_map(global_position)], main.tiles[attack_target]) > 14:
							if move_queue != []:
								var path = main.find_attack_path(move_queue[0],attack_target,14)
								var tmp: Array[Vector2i] = [move_queue[0]]
								tmp.append_array(path)
								move_queue = tmp
							else:
								var path = main.find_attack_path(main.map.local_to_map(global_position),attack_target,14)
								move_queue = path
						return

func play_attack(angle):
	match angle:
		1:
			bug_sprite.play("attack_up")
			look_dir = Directions.Up
		2:
			bug_sprite.play("attack_right")
			look_dir = Directions.UpRight
		3:
			bug_sprite.play("attack_right")
			look_dir = Directions.Right
		4:
			bug_sprite.play("attack_right")
			look_dir = Directions.DownRight
		5:
			bug_sprite.play("attack_down")
			look_dir = Directions.Down
		6:
			bug_sprite.play("attack_left")
			look_dir = Directions.DownLeft
		7:
			bug_sprite.play("attack_left")
			look_dir = Directions.Left
		0:
			bug_sprite.play("attack_left")
			look_dir = Directions.UpLeft
	idle_timer.start()

func play_idle():
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

func _on_idle_timer_timeout():
	play_idle()

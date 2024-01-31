extends Node2D

@onready var select_indicator = $SelectIndicator
@onready var map = $"../Map"
@onready var units: Dictionary = $"..".units
@onready var enemies: Dictionary = $"..".enemies
@onready var main = $".."
@onready var unit_sprite = $UnitSprite
@onready var idle_timer = $IdleTimer
@onready var hit = $Hit
@onready var shoot = $Shoot
@onready var attack_timer = $AttackTimer

const SPEED = 10

enum Directions {Up, Down, Left, Right}

var move_queue: Array = []
var state: States = States.Guard
var look_dir: Directions = Directions.Down
var attack_target: Vector2i = Vector2i(-1,-1)
var health: int = 10
var attack_damage = 3
var search_range = 2
var can_attack = false

enum States {Guard, Walk, Attack}

func _process(delta):
	match state:
		States.Guard:
			if move_queue != []:
				if move_queue[0] not in enemies and move_queue[0] not in units and main.is_walkable(main.tiles[move_queue[0]]):
					state = States.Walk
					units.erase(map.local_to_map(global_position))
					units[move_queue[0]] = self
					var angle = Vector2(map.local_to_map(global_position)).angle_to_point(move_queue[0])
					angle = int(angle * 180 / PI) + 135
					angle = int((((angle - 0) * (8 - 0)) / (360. - 0)) + 0)
					main.clear_fog_around_pos(move_queue[0])
					match angle:
						1:
							unit_sprite.play("walk_up")
							look_dir = Directions.Up
						5:
							unit_sprite.play("walk_down")
							look_dir = Directions.Down
						2,3,4:
							unit_sprite.play("walk_right")
							look_dir = Directions.Right
						6,7,0:
							unit_sprite.play("walk_left")
							look_dir = Directions.Left
				else:
					if len(move_queue) != 1:
						var path: Array[Vector2i] = main.find_path(map.local_to_map(global_position), move_queue[-1])
						move_queue = path
					else:
						move_queue = []
			else:
				attack()
		States.Walk:
			var destination = map.map_to_local(move_queue[0])
			global_position = global_position.move_toward(destination, SPEED * delta)
			if global_position == destination:
				state = States.Guard
				move_queue.remove_at(0)
				search_for_enemies()
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

func attack():
	if not can_attack:
		return
	if state == States.Walk:
		return
	if attack_target == Vector2i(-1,-1):
		return
	var pos = main.map.local_to_map(self.global_position)
	if main.get_distance(main.tiles[pos], main.tiles[attack_target]) >= 28:
		return
	if attack_target not in enemies.keys():
		return
	enemies[attack_target].take_damage(attack_damage)
	can_attack = false
	attack_timer.start()
	var angle = Vector2(map.local_to_map(global_position)).angle_to_point(attack_target)
	angle = int(angle * 180 / PI) + 135
	angle = int((((angle - 0) * (8 - 0)) / (360. - 0)) + 0)
	play_attack(angle)

func take_damage(damage_amount):
	health -= damage_amount
	hit.play()
	if health > 0:
		return
	if main.selected_unit == self:
		main.deselect_unit()
		main.change_mode_to(main.Modes.Normal)
	var k = units.find_key(self)
	if k != null:
		units.erase(k)
	else:
		print("trying to attack null")
	self.queue_free()

func _on_attack_timer_timeout():
	can_attack = true

func search_for_enemies():
	var closest = Vector2i(-1,-1)
	var dist_to_closest = INF
	var grid_pos = main.map.local_to_map(global_position)
	for y in range(-search_range,search_range):
		for x in range(-search_range,search_range):
			var pos = grid_pos + Vector2i(x,y)
			if pos not in enemies.keys():
				continue
			if not is_instance_valid(enemies[pos]):
				print("found invalid enemy")
				continue
			if closest == Vector2i(-1,-1):
				attack_target = pos
				dist_to_closest = get_distance(grid_pos,pos)
				continue
			var dst = get_distance(grid_pos, pos)
			if dst < dist_to_closest:
				attack_target = pos

func get_distance(start: Vector2i, end: Vector2i):
	var dst_x = abs(start.x - end.x)
	var dst_y = abs(start.y - end.y)
	if dst_x > dst_y:
		return 14*dst_y + 10 * (dst_x-dst_y)
	return 14*dst_x + 10 * (dst_y-dst_x)

func _on_search_timer_timeout():
	if state == States.Guard:
		search_for_enemies()

func play_attack(angle):
	shoot.play()
	match angle:
		1:
			unit_sprite.play("attack_up")
			look_dir = Directions.Up
		5:
			unit_sprite.play("attack_down")
			look_dir = Directions.Down
		2,3,4:
			unit_sprite.play("attack_right")
			look_dir = Directions.Right
		6,7,0:
			unit_sprite.play("attack_left")
			look_dir = Directions.Left
	idle_timer.start()

func play_idle():
	match look_dir:
		Directions.Up:
			unit_sprite.play("idle_up")
		Directions.Down:
			unit_sprite.play("idle_down")
		Directions.Left:
			unit_sprite.play("idle_left")
		Directions.Right:
			unit_sprite.play("idle_right")

func _on_idle_timer_timeout():
	play_idle()

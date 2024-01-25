extends Node

@onready var main = $".."
@onready var enemies: Dictionary = $"..".enemies
@onready var units: Dictionary = $"..".units
@onready var spawn_timer = $SpawnTimer

var rng = RandomNumberGenerator.new()
var spawn_range = 2
var state = States.Normal
var health: int = 15

enum SpawnCooldowns {Normal, LowPollution, MediumPollution, HighPollution, Alert}
enum States {Normal, Alert}

var spawn_cooldowns = {
	SpawnCooldowns.Normal:60,
	SpawnCooldowns.LowPollution:45,
	SpawnCooldowns.MediumPollution:35,
	SpawnCooldowns.HighPollution:25,
	SpawnCooldowns.Alert:15,
}

func _on_timer_timeout():
	try_spawn_random()

func try_spawn_random():
	var pos = main.map.local_to_map(self.global_position)
	var offset = Vector2i(rng.randi_range(-spawn_range, spawn_range), rng.randi_range(-spawn_range,spawn_range))
	var tile_pos = pos + offset
	if tile_pos.x >= 0 and tile_pos.x < main.GRID_WIDTH and tile_pos.y >= 0 and tile_pos.y < main.GRID_HEIGHT:
		if tile_pos not in enemies and tile_pos not in units and main.is_walkable(main.tiles[tile_pos]):
			main.spawn_enemy(main.Enemies.Bug,pos + offset)

func change_spawn_cooldown(cooldown):
	#print("Spawn Cooldown: ", spawn_cooldowns[cooldown])
	spawn_timer.wait_time = spawn_cooldowns[cooldown]

func _on_check_timer_timeout():
	var tile = main.tiles[main.map.local_to_map(self.global_position)]
	if state == States.Alert:
		return
	#print(tile.pollution)
	if tile.pollution > 1 and tile.pollution <= 10:
		change_spawn_cooldown(SpawnCooldowns.LowPollution)
	if tile.pollution > 10 and tile.pollution <= 20:
		change_spawn_cooldown(SpawnCooldowns.MediumPollution)
	if tile.pollution > 20:
		change_spawn_cooldown(SpawnCooldowns.HighPollution)

func _ready():
	change_spawn_cooldown(SpawnCooldowns.Normal)
	try_spawn_random()

func take_damage(damage_amount):
	health -= damage_amount
	if health <= 0:
		enemies.erase(main.map.local_to_map(self.global_position))
		self.queue_free()

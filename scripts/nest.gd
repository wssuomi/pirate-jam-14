extends Node

@onready var main = $".."
@onready var enemies: Dictionary = $"..".enemies
@onready var units: Dictionary = $"..".units

var rng = RandomNumberGenerator.new()
var spawn_range = 2

func _on_timer_timeout():
	try_spawn_random()

func try_spawn_random():
	var pos = main.map.local_to_map(self.global_position)
	var offset = Vector2i(rng.randi_range(-spawn_range, spawn_range), rng.randi_range(-spawn_range,spawn_range))
	var tile_pos = pos + offset
	if tile_pos.x >= 0 and tile_pos.x < main.GRID_WIDTH and tile_pos.y >= 0 and tile_pos.y < main.GRID_HEIGHT:
		if tile_pos not in enemies and tile_pos not in units and main.is_walkable(main.tiles[tile_pos]):
			main.spawn_enemy(main.Enemies.Bug,pos + offset)

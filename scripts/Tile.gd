extends TileMap

const Buildings = preload("res://scripts/Game.gd").Buildings

class Tile:
	var grid_position: Vector2i
	var ground_sprite: Vector2i
	var decoration_sprite: Vector2i
	var resource_sprite: Vector2i
	var building_sprite: Vector2i
	var g_cost: int
	var h_cost: int
	var f_cost: int
	var parent: Tile
	var building: Buildings
	var pollution: float
	func _init(_grid_position: Vector2i, 
			_ground_sprite: Vector2i,
			_building: Buildings = Buildings.None,
			_resource_sprite: Vector2i = Vector2i(-1,-1),
			_decoration_sprite: Vector2i = Vector2i(-1,-1),
			_building_sprite: Vector2i = Vector2i(-1,-1)):
		self.f_cost = g_cost + h_cost
		ground_sprite = _ground_sprite
		resource_sprite = _resource_sprite
		decoration_sprite = _decoration_sprite
		building_sprite = _building_sprite
		grid_position = _grid_position

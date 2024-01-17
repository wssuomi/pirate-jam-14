extends Node2D

@onready var map: TileMap = $Map
@onready var preview_tile: TextureRect = $PreviewTile
@onready var selected_tile_tex: TextureRect = $CanvasLayer/Control/SelectedTile

const Tile = preload("res://scripts/Tile.gd").Tile
const GRID_WIDTH: int = 128
const GRID_HEIGHT: int = 128

var rng = RandomNumberGenerator.new()
var tiles: Dictionary = {}
var tiles_texture = preload("res://assets/map_tiles.png")
var atlas: AtlasTexture = AtlasTexture.new()
var current_tile: int = 0
var mouse_on_ui: bool = false
var ground_layer: int = 0
var decoration_layer: int = 1
var resource_layer: int = 2
var buillding_layer: int = 3
var current_layer: int = ground_layer
var ground_tiles: Array[Vector2i] = [
	Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(3,0),
	Vector2i(0,1),Vector2i(1,1),Vector2i(2,1),Vector2i(3,1),
	Vector2i(0,2),Vector2i(1,2),Vector2i(2,2),Vector2i(3,2),
	Vector2i(0,3),Vector2i(1,3),Vector2i(2,3),Vector2i(3,3)
	]
var resource_tiles: Array[Vector2i] = [Vector2i(4,2),Vector2i(5,2),Vector2i(6,2)]
var decoration_tiles: Array[Vector2i] = [
	Vector2i(4,0),Vector2i(4,1),Vector2i(5,1),
	Vector2i(6,1),Vector2i(4,3),Vector2i(5,3)
	]
var building_tiles: Array[Vector2i] = [Vector2i(-1,-1)]
var selected_tiles: Array[Vector2i] = ground_tiles

func _on_quit_pressed():
	get_tree().quit()

func _input(event):
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		if Input.is_action_pressed("place_tile") and not mouse_on_ui:
			var pos: Vector2i = map.local_to_map(get_global_mouse_position())
			if pos.x >= 0 and pos.x < GRID_WIDTH and pos.y >= 0 and pos.y < GRID_HEIGHT:
				var tile: Tile = tiles[pos]
				match current_layer:
					0:
						tile.ground_sprite = ground_tiles[current_tile]
					1:
						tile.decoration_sprite = decoration_tiles[current_tile]
					2:
						tile.resource_sprite = resource_tiles[current_tile]
					3:
						tile.resource_sprite = resource_tiles[current_tile]
				update_tile(tile)
		if Input.is_action_pressed("erase_tile") and not mouse_on_ui:
			var pos: Vector2i = map.local_to_map(get_global_mouse_position())
			if pos.x >= 0 and pos.x < GRID_WIDTH and pos.y >= 0 and pos.y < GRID_HEIGHT:
				var tile: Tile = tiles[pos]
				match current_layer:
					1:
						tile.decoration_sprite = Vector2i(-1,-1)
					2:
						tile.resource_sprite = Vector2i(-1,-1)
					3:
						tile.resource_sprite = Vector2i(-1,-1)
				update_tile(tile)
func _process(_delta):
	preview_tile.position = map.map_to_local(map.local_to_map(get_global_mouse_position())) - Vector2(8,8)

func update_tile(tile: Tile) -> void:
	map.set_cell(ground_layer, tile.grid_position, 0, tile.ground_sprite)
	map.set_cell(decoration_layer, tile.grid_position, 0, tile.decoration_sprite)
	map.set_cell(resource_layer, tile.grid_position, 0, tile.resource_sprite)
	map.set_cell(buillding_layer, tile.grid_position, 0, tile.building_sprite)

func _ready():
	atlas.atlas = tiles_texture
	update_shown_tile()
	selected_tile_tex.texture = atlas
	preview_tile.texture = atlas
	for y in range(GRID_WIDTH):
		for x in range(GRID_HEIGHT):
			var pos: Vector2i = Vector2i(x,y)
			var tile: Tile = Tile.new(pos, Vector2i(rng.randi_range(0,3),0))
			tiles[pos] = tile
			map.set_cell(current_layer, tile.grid_position, 0, tile.ground_sprite)

func update_shown_tile() -> void:
	atlas.region = Rect2(
		selected_tiles[current_tile].x * 16,
		selected_tiles[current_tile].y * 16,
		16,16)

func _on_ground_pressed():
	current_layer = 0
	current_tile = 0
	selected_tiles = ground_tiles
	update_shown_tile()

func _on_resource_pressed():
	current_layer = 2
	current_tile = 0
	selected_tiles = resource_tiles
	update_shown_tile()

func _on_decoration_pressed():
	current_layer = 1
	current_tile = 0
	selected_tiles = decoration_tiles
	update_shown_tile()

func _on_building_pressed():
	current_layer = 3
	current_tile = 0
	selected_tiles = building_tiles
	update_shown_tile()

func _on_control_mouse_entered():
	mouse_on_ui = true

func _on_control_mouse_exited():
	mouse_on_ui = false

func _on_next_pressed():
	if len(selected_tiles) - 1 <= current_tile:
		current_tile = 0
	else:
		current_tile += 1
	update_shown_tile()

func _on_previous_pressed():
	if current_tile == 0:
		current_tile = len(selected_tiles) - 1
	else:
		current_tile -= 1
	update_shown_tile()


func _on_save_pressed():
	var ground_line: Array[String] = []
	var decoration_line: Array[String]  = []
	var resource_line: Array[String]  = []
	var building_line: Array[String] = []
	var save_map = FileAccess.open("res://levels/map.csv", FileAccess.WRITE)
	for tile: Tile in tiles.values():
		if tile.ground_sprite != Vector2i(-1,-1):
			ground_line.append("{0},{1},{2},{3}".format([tile.grid_position.x,tile.grid_position.y,tile.ground_sprite.x,tile.ground_sprite.y]))
		if tile.decoration_sprite != Vector2i(-1,-1):
			decoration_line.append("{0},{1},{2},{3}".format([tile.grid_position.x,tile.grid_position.y,tile.decoration_sprite.x,tile.decoration_sprite.y]))
		if tile.resource_sprite != Vector2i(-1,-1):
			resource_line.append("{0},{1},{2},{3}".format([tile.grid_position.x,tile.grid_position.y,tile.resource_sprite.x,tile.resource_sprite.y]))
		if tile.building_sprite != Vector2i(-1,-1):
			building_line.append("{0},{1},{2},{3}".format([tile.grid_position.x,tile.grid_position.y,tile.building_sprite.x,tile.building_sprite.y]))
	save_map.store_line(";".join(ground_line))
	save_map.store_line(";".join(decoration_line))
	save_map.store_line(";".join(resource_line))
	save_map.store_line(";".join(building_line))
	
func _on_load_pressed():
	var saved_map = FileAccess.open("res://levels/map.csv", FileAccess.READ)
	var ground_line: PackedStringArray = saved_map.get_line().split(";")
	var decoration_line: PackedStringArray  = saved_map.get_line().split(";")
	var resource_line: PackedStringArray  = saved_map.get_line().split(";")
	var building_line: PackedStringArray = saved_map.get_line().split(";")
	var loaded_tiles: Dictionary = {}
	for tile_string: String in ground_line:
		var tile_values: PackedStringArray = tile_string.split(",")
		var pos: Vector2i = Vector2i(int(tile_values[0]),int(tile_values[1]))
		var sprite: Vector2i = Vector2i(int(tile_values[2]),int(tile_values[3]))
		loaded_tiles[pos] = Tile.new(pos,sprite)
	for tile_string: String in decoration_line:
		if tile_string == "":
			continue
		var tile_values: PackedStringArray = tile_string.split(",")
		var pos: Vector2i = Vector2i(int(tile_values[0]),int(tile_values[1]))
		var sprite: Vector2i = Vector2i(int(tile_values[2]),int(tile_values[3]))
		loaded_tiles[pos].decoration_sprite = sprite
	for tile_string: String in resource_line:
		if tile_string == "":
			continue
		var tile_values: PackedStringArray = tile_string.split(",")
		var pos: Vector2i = Vector2i(int(tile_values[0]),int(tile_values[1]))
		var sprite: Vector2i = Vector2i(int(tile_values[2]),int(tile_values[3]))
		loaded_tiles[pos].resource_sprite = sprite
	for tile_string: String in building_line:
		if tile_string == "":
			continue
		var tile_values: PackedStringArray = tile_string.split(",")
		var pos: Vector2i = Vector2i(int(tile_values[0]),int(tile_values[1]))
		var sprite: Vector2i = Vector2i(int(tile_values[2]),int(tile_values[3]))
		loaded_tiles[pos].building_sprite = sprite
	tiles = loaded_tiles
	draw_map_tiles()
		
func draw_map_tiles() -> void:
	for tile in tiles.values():
		update_tile(tile)

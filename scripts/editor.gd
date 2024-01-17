extends Node2D

@onready var map = $Map
@onready var selected_tile_tex: TextureRect = $CanvasLayer/Control/MarginContainer/VBoxContainer/SelectedTile
@onready var preview_tile: TextureRect = $PreviewTile

const Tile = preload("res://scripts/Tile.gd").Tile
const GRID_WIDTH = 128
const GRID_HEIGHT = 128

var rng = RandomNumberGenerator.new()
var tiles: Dictionary = {}
var tiles_texture = preload("res://assets/map_tiles.png")
var atlas: AtlasTexture = AtlasTexture.new()
var current_tile = 0
var mouse_on_ui = false
var ground_layer = 0
var decoration_layer = 1
var resource_layer = 2
var buillding_layer = 3
var current_layer = ground_layer
var ground_tiles = [
	Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(3,0),
	Vector2i(0,1),Vector2i(1,1),Vector2i(2,1),Vector2i(3,1),
	Vector2i(0,2),Vector2i(1,2),Vector2i(2,2),Vector2i(3,2),
	Vector2i(0,3),Vector2i(1,3),Vector2i(2,3),Vector2i(3,3)
	]
var resource_tiles = [Vector2i(4,2),Vector2i(5,2),Vector2i(6,2)]
var decoration_tiles = [
	Vector2i(4,0),Vector2i(4,1),Vector2i(5,1),
	Vector2i(6,1),Vector2i(4,3),Vector2i(5,3)
	]
var building_tiles = [Vector2i(-1,-1)]
var selected_tiles = ground_tiles

func _on_quit_pressed():
	get_tree().quit()

func _input(event):
	if event is InputEventMouseButton:
		if Input.is_action_just_pressed("place_tile") and not mouse_on_ui:
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
			
func _process(_delta):
	preview_tile.position = map.map_to_local(map.local_to_map(get_global_mouse_position())) - Vector2(8,8)

func update_tile(tile: Tile):
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
			var pos = Vector2i(x,y)
			var tile = Tile.new(pos, Vector2i(rng.randi_range(0,3),0))
			tiles[pos] = tile
			map.set_cell(current_layer, tile.grid_position, 0, tile.ground_sprite)

func update_shown_tile():
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

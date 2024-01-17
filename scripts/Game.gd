extends Node2D

@onready var pause_menu = $CanvasLayer/PauseMenu
@onready var camera: Camera2D = $Camera
@onready var map: TileMap = $Map
@onready var copper_label: Label = $CanvasLayer/TopBar/Copper/MarginContainer/HBoxContainer/CopperLabel
@onready var iron_label: Label = $CanvasLayer/TopBar/Iron/MarginContainer/HBoxContainer/IronLabel
@onready var coal_label: Label = $CanvasLayer/TopBar/Coal/MarginContainer/HBoxContainer/CoalLabel

const GRID_WIDTH = 128
const GRID_HEIGHT = 128
const Tile = preload("res://scripts/Tile.gd").Tile

var paused = false
var tiles = {}
var rng = RandomNumberGenerator.new()
var ground_layer: int = 0
var decoration_layer: int = 1
var resource_layer: int = 2
var buillding_layer: int = 3
var copper = 4
var coal = 0
var iron = 2

func toggle_pause():
	if paused:
		pause_menu.hide()
		Engine.time_scale = 1
	else:
		pause_menu.show()
		Engine.time_scale = 0
	paused = !paused
		
func load_map():
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
	return loaded_tiles

func _ready():
	tiles = load_map()
	draw_map_tiles()
	update_labels()
	
func draw_map_tiles() -> void:
	for tile in tiles.values():
		update_tile(tile)

func update_tile(tile: Tile) -> void:
	map.set_cell(ground_layer, tile.grid_position, 0, tile.ground_sprite)
	map.set_cell(decoration_layer, tile.grid_position, 0, tile.decoration_sprite)
	map.set_cell(resource_layer, tile.grid_position, 0, tile.resource_sprite)
	map.set_cell(buillding_layer, tile.grid_position, 0, tile.building_sprite)

func update_labels():
	copper_label.text = str(copper)
	coal_label.text = str(coal)
	iron_label.text = str(iron)
	

func _on_menu_pressed():
	toggle_pause()
	
func _input(event):
	if event is InputEventKey:
		if Input.is_action_just_pressed("pause"):
			toggle_pause()

extends Node2D

@onready var pause_menu = $CanvasLayer/PauseMenu
@onready var camera: Camera2D = $Camera
@onready var map: TileMap = $Map
@onready var copper_label: Label = $CanvasLayer/TopBar/Copper/MarginContainer/HBoxContainer/CopperLabel
@onready var iron_label: Label = $CanvasLayer/TopBar/Iron/MarginContainer/HBoxContainer/IronLabel
@onready var coal_label: Label = $CanvasLayer/TopBar/Coal/MarginContainer/HBoxContainer/CoalLabel
@onready var preview_tile = $PreviewTile
@onready var slab_build_timer = $CanvasLayer/SideBarBuild/BuildOptions/VBoxContainer/Slab/SlabBuildTimer
@onready var slab_building_label = $CanvasLayer/SideBarBuild/BuildOptions/VBoxContainer/Slab/SlabBuildingLabel
@onready var slab_build_button = $CanvasLayer/SideBarBuild/BuildOptions/VBoxContainer/Slab/SlabBuildButton
@onready var slab_place_button = $CanvasLayer/SideBarBuild/BuildOptions/VBoxContainer/Slab/SlabPlaceButton
@onready var slab_cancel_place_button = $CanvasLayer/SideBarBuild/BuildOptions/VBoxContainer/Slab/SlabCancelPlaceButton
@onready var stone_label = $CanvasLayer/TopBar/Stone/MarginContainer/HBoxContainer/StoneLabel

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
var stone = 10
var iron = 2
var mode = 0
var building = Buildings.None
var building_tiles: Dictionary = {"slab":Vector2i(0,4)}
var slab_cost: Array[int] = [0,1,10]

enum Modes {Normal, Place}
enum Buildings {None, Slab}

signal slab_placed

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
	connect("slab_placed",_on_slab_placed)
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
	stone_label.text = str(stone)
	
func _on_menu_pressed():
	toggle_pause()
	
func _input(event):
	if event is InputEventKey:
		if Input.is_action_just_pressed("pause"):
			toggle_pause()
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		if Input.is_action_pressed("place_tile"):
			var pos: Vector2i = map.local_to_map(get_global_mouse_position())
			if pos.x >= 0 and pos.x < GRID_WIDTH and pos.y >= 0 and pos.y < GRID_HEIGHT:
				var tile: Tile = tiles[pos]
				match building:
					Buildings.Slab:
						tile.ground_sprite = building_tiles["slab"]
						emit_signal("slab_placed")
					Buildings.None:
						pass
				update_tile(tile)

func enter_place_mode():
	mode = Modes.Place
	preview_tile.show()
	
func exit_place_mode():
	mode = Modes.Normal
	preview_tile.hide()

func _process(_delta):
	match mode:
		Modes.Normal:
			pass
		Modes.Place:
			preview_tile.position = map.map_to_local(map.local_to_map(get_global_mouse_position())) - Vector2(8,8)

func _on_cancel_pressed():
	exit_place_mode()

func _on_slab_build_button_pressed():
	if check_resources(slab_cost):
		slab_build_timer.start()
		slab_build_button.hide()
		slab_building_label.show()
		copper -= slab_cost[0]
		iron -= slab_cost[1]
		stone -= slab_cost[2]
		update_labels()
	else:
		print("not enough resources")
	
func _on_slab_place_button_pressed():
	enter_place_mode()
	slab_place_button.hide()
	slab_cancel_place_button.show()
	building = Buildings.Slab

func _on_slab_build_timer_timeout():
	slab_place_button.show()
	slab_building_label.hide()

func _on_slab_cancel_place_button_pressed():
	exit_place_mode()
	slab_place_button.show()
	slab_cancel_place_button.hide()
	building = Buildings.None

func _on_slab_placed():
	exit_place_mode()
	slab_cancel_place_button.hide()
	slab_build_button.show()
	building = Buildings.None

func check_resources(cost: Array[int]):
	if copper >= cost[0] and iron >= cost[1] and stone >= cost[2]:
		return true
	return false

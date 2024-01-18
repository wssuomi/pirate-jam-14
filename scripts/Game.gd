extends Node2D

@onready var pause_menu = $CanvasLayer/PauseMenu
@onready var camera: Camera2D = $Camera
@onready var map: TileMap = $Map
@onready var copper_label: Label = $CanvasLayer/TopBar/Copper/MarginContainer/HBoxContainer/CopperLabel
@onready var iron_label: Label = $CanvasLayer/TopBar/Iron/MarginContainer/HBoxContainer/IronLabel
@onready var coal_label: Label = $CanvasLayer/TopBar/Coal/MarginContainer/HBoxContainer/CoalLabel
@onready var preview_tile = $PreviewTile
@onready var stone_label = $CanvasLayer/TopBar/Stone/MarginContainer/HBoxContainer/StoneLabel
@onready var slab = $CanvasLayer/SideBarBuild/BuildOptions/VBoxContainer/Slab
@onready var move = $CanvasLayer/SideBarUnitAction/Actions/VBoxContainer/Move
@onready var side_bar_build = $CanvasLayer/SideBarBuild
@onready var side_bar_unit_action = $CanvasLayer/SideBarUnitAction
@onready var large_slab = $CanvasLayer/SideBarBuild/BuildOptions/VBoxContainer/LargeSlab

const GRID_WIDTH = 128
const GRID_HEIGHT = 128
const Tile = preload("res://scripts/Tile.gd").Tile
const INFANTRY = preload("res://scenes/infantry.tscn")


enum Modes {Normal, Place, MoveUnit, UnitSelected}
enum Buildings {None, Slab, LargeSlab}
enum BuildingStates {None, Building, Waiting, Placing}
enum Units {Infantry}

var tiles_texture = preload("res://assets/map_tiles.png")
var paused = false
var tiles = {}
var units = {}
var rng = RandomNumberGenerator.new()
var ground_layer: int = 0
var decoration_layer: int = 1
var resource_layer: int = 2
var building_layer: int = 3
var copper = 99
var coal = 99
var stone = 99
var iron = 99
var mode = 0
var building = Buildings.None
var building_tiles: Dictionary = {"slab":Vector2i(0,4),"large_slab":[Vector2i(0,5),Vector2i(1,5),Vector2i(0,6),Vector2i(1,6)]}
var slab_cost: Array[int] = [0,1,10]
var slab_state: BuildingStates = BuildingStates.None
var large_slab_state: BuildingStates = BuildingStates.None
var large_slab_cost: Array[int] = [0,4,40]
var mouse_on_ui: bool = false
var selected_unit = null
var preview_atlas: AtlasTexture = AtlasTexture.new()

signal building_placed

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
	preview_atlas.atlas = tiles_texture
	preview_tile.texture = preview_atlas
	connect("building_placed",_on_building_placed)
	tiles = load_map()
	draw_map_tiles()
	update_labels()
	spawn_unit(Units.Infantry, Vector2i(32,15))
	spawn_unit(Units.Infantry, Vector2i(32,25))
	
func draw_map_tiles() -> void:
	for tile in tiles.values():
		update_tile(tile)

func update_tile(tile: Tile) -> void:
	map.set_cell(ground_layer, tile.grid_position, 0, tile.ground_sprite)
	map.set_cell(decoration_layer, tile.grid_position, 0, tile.decoration_sprite)
	map.set_cell(resource_layer, tile.grid_position, 0, tile.resource_sprite)
	map.set_cell(building_layer, tile.grid_position, 0, tile.building_sprite)

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
	match mode:
		Modes.Normal:
			if event is InputEventMouseButton and not mouse_on_ui:
				if Input.is_action_just_pressed("select_unit"):
					var pos: Vector2i = map.local_to_map(get_global_mouse_position())
					if pos in units.keys():
						select_unit(pos)
						change_mode_to(Modes.UnitSelected)
		Modes.Place:
			if event is InputEventMouseButton:
				if Input.is_action_pressed("place_tile") and not mouse_on_ui:
					var pos: Vector2i = map.local_to_map(get_global_mouse_position())
					if pos.x >= 0 and pos.x < GRID_WIDTH and pos.y >= 0 and pos.y < GRID_HEIGHT:
						match building:
							Buildings.Slab:
								var tile: Tile = tiles[pos]
								if check_tile_able_to_build_slab(tiles[pos]):
									tile.building_sprite = building_tiles["slab"]
									emit_signal("building_placed")
									update_tile(tile)
							Buildings.LargeSlab:
								var required_tiles_positions: Array[Vector2i] = [pos, pos + Vector2i(0,1),pos + Vector2i(1,0),pos + Vector2i(1,1)]
								for p in required_tiles_positions:
									if not (p.x >= 0 and p.x < GRID_WIDTH and p.y >= 0 and p.y < GRID_HEIGHT):
										return
									if not check_tile_able_to_build_slab(tiles[p]):
										return
								for n in range(len(required_tiles_positions)):
									tiles[required_tiles_positions[n]].building_sprite = building_tiles["large_slab"][n]
									update_tile(tiles[required_tiles_positions[n]])
								emit_signal("building_placed")
							Buildings.None:
								pass
		Modes.MoveUnit:
			if event is InputEventMouseButton:
				if Input.is_action_just_pressed("select_unit_location") and not mouse_on_ui:
					var pos: Vector2i = map.local_to_map(get_global_mouse_position())
					print(pos)
		Modes.UnitSelected:
			if event is InputEventMouseButton and not mouse_on_ui:
				if Input.is_action_just_pressed("select_unit"):
					var pos: Vector2i = map.local_to_map(get_global_mouse_position())
					if pos in units.keys():
						deselect_unit()
						select_unit(pos)
						change_mode_to(Modes.UnitSelected)
					else:
						deselect_unit()
						change_mode_to(Modes.Normal)

func _process(_delta):
	match mode:
		Modes.Normal:
			pass
		Modes.Place:
			preview_tile.position = map.map_to_local(map.local_to_map(get_global_mouse_position())) - Vector2(8,8)

func check_resources(cost: Array[int]):
	if copper >= cost[0] and iron >= cost[1] and stone >= cost[2]:
		return true
	return false

func _on_slab_button_pressed():
	match slab_state:
		BuildingStates.None:
			if check_resources(slab_cost):
				slab_state = change_state_to(BuildingStates.Building, slab)
				copper -= slab_cost[0]
				iron -= slab_cost[1]
				stone -= slab_cost[2]
				update_labels()
			else:
				print("not enough resources")
		BuildingStates.Waiting:
			if building != Buildings.None:
				return
			slab_state = change_state_to(BuildingStates.Placing, slab)
			building = Buildings.Slab
			update_preview_tile()
		BuildingStates.Placing:
			if building != Buildings.Slab:
				return
			slab_state =  change_state_to(BuildingStates.Waiting, slab)
			change_mode_to(Modes.Normal)
			building = Buildings.None

func change_state_to(state: BuildingStates, target: HBoxContainer) -> BuildingStates:
	var button = target.get_child(1)
	var timer = target.get_child(2)
	var label = target.get_child(3)
	match state:
		BuildingStates.None:
			button.text = "Build"
			button.show()
			label.hide()
			return BuildingStates.None
		BuildingStates.Building:
			button.hide()
			label.text = "Building..."
			label.show()
			timer.start()
			return BuildingStates.Building
		BuildingStates.Waiting:
			button.text = "Place"
			button.show()
			label.hide()
			return BuildingStates.Waiting
		BuildingStates.Placing:
			button.text = "Cancel"
			button.show()
			label.hide()
			change_mode_to(Modes.Place)
			return BuildingStates.Placing
		_:
			return BuildingStates.None

func _on_slab_timer_timeout():
	slab_state = change_state_to(BuildingStates.Waiting, slab)

func change_mode_to(next_mode: Modes):
	match next_mode:
		Modes.Normal:
			mode = Modes.Normal
			hide_building_preview()
			building = Buildings.None
		Modes.Place:
			mode = Modes.Place
			show_building_preview()
		Modes.MoveUnit:
			mode = Modes.MoveUnit
			hide_building_preview()
		Modes.UnitSelected:
			mode = Modes.UnitSelected
			hide_building_preview()

func _on_building_placed():
	match building:
		Buildings.Slab:
			change_mode_to(Modes.Normal)
			slab_state = change_state_to(BuildingStates.None, slab)
		Buildings.LargeSlab:
			change_mode_to(Modes.Normal)
			large_slab_state = change_state_to(BuildingStates.None, large_slab)
	building = Buildings.None

func _on_mouse_entered_ui():
	mouse_on_ui = true

func _on_mouse_exited_ui():
	mouse_on_ui = false

func spawn_unit(unit: Units, pos: Vector2i):
	match unit:
		Units.Infantry:
			var instance = INFANTRY.instantiate()
			instance.position = map.map_to_local(pos)
			add_child(instance)
			units[pos] = instance

func select_unit(pos: Vector2i):
	selected_unit = units[pos]
	selected_unit.select()
	side_bar_unit_action.show()

func deselect_unit():
	if selected_unit != null:
		selected_unit.deselect()
		selected_unit = null
		side_bar_unit_action.hide()

func _on_move_pressed():
	match mode:
		Modes.UnitSelected:
			change_mode_to(Modes.MoveUnit)
			move.text = "Cancel"
		Modes.MoveUnit:
			change_mode_to(Modes.UnitSelected)
			move.text = "Move"

func check_tile_able_to_build_slab(tile: Tile):
	if tile.building_sprite == Vector2i(-1,-1):
		return true
	return false

func _on_large_slab_button_pressed():
	match large_slab_state:
		BuildingStates.None:
			if check_resources(slab_cost):
				large_slab_state = change_state_to(BuildingStates.Building, large_slab)
				copper -= large_slab_cost[0]
				iron -= large_slab_cost[1]
				stone -= large_slab_cost[2]
				update_labels()
			else:
				print("not enough resources")
		BuildingStates.Waiting:
			if building != Buildings.None:
				return
			large_slab_state = change_state_to(BuildingStates.Placing, large_slab)
			building = Buildings.LargeSlab
			update_preview_tile()
		BuildingStates.Placing:
			if building != Buildings.LargeSlab:
				return
			large_slab_state =  change_state_to(BuildingStates.Waiting, large_slab)
			change_mode_to(Modes.Normal)
			building = Buildings.None

func _on_large_slab_timer_timeout():
	large_slab_state = change_state_to(BuildingStates.Waiting, large_slab)

func show_building_preview():
	preview_tile.show()

func hide_building_preview():
	preview_tile.hide()

func update_preview_tile():
	match building:
		Buildings.Slab:
			#preview_atlas.region = Rect2(
				#building_tiles["slab"].x * 16,
				#building_tiles["slab"].y * 16,
				#16,16)
			preview_tile.get_child(0).custom_minimum_size = Vector2i(0,0)
		Buildings.LargeSlab:
			#preview_atlas.region = Rect2(
				#building_tiles["large_slab"][0].x * 16,
				#building_tiles["large_slab"][0].y * 16,
				#32,32)
			preview_tile.get_child(0).custom_minimum_size = Vector2i(34,34)

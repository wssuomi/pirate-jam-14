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
@onready var factory = $CanvasLayer/SideBarBuild/BuildOptions/VBoxContainer/Factory
@onready var drill = $CanvasLayer/SideBarBuild/BuildOptions/VBoxContainer/Drill

const GRID_WIDTH = 64
const GRID_HEIGHT = 64
const Tile = preload("res://scripts/Tile.gd").Tile
const INFANTRY = preload("res://scenes/infantry.tscn")
const FACTORY = preload("res://scenes/factory.tscn")
const POLLUTION_SPREAD_RATE: float = 2.
const fog_dict = preload("res://scripts/fog.gd").fog_dict
const DRILL = preload("res://scenes/drill.tscn")
const SHIP = preload("res://scenes/ship.tscn")

enum Modes {Normal, Place, MoveUnit, UnitSelected, BuildingSelected}
enum Buildings {None, Slab, LargeSlab, Factory, Drill, Ship}
enum BuildingStates {None, Building, Waiting, Placing}
enum Units {Infantry}
enum Neighbors {T,TR,R,BR,B,BL,L,TL}
enum Resources {Copper, Stone, Iron, Coal}

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
var building_tiles: Dictionary = {"slab":Vector2i(0,4),"large_slab":[Vector2i(0,5),Vector2i(0,6),Vector2i(1,5),Vector2i(1,6)],"factory":[Vector2i(0,7),Vector2i(0,8),Vector2i(1,7),Vector2i(1,8)],"drill":[Vector2i(2,8)]}
var slab_cost: Array[int] = [0,1,10]
var slab_state: BuildingStates = BuildingStates.None
var large_slab_state: BuildingStates = BuildingStates.None
var factory_state: BuildingStates = BuildingStates.None
var drill_state: BuildingStates = BuildingStates.None
var large_slab_cost: Array[int] = [0,4,40]
var factory_cost: Array[int] = [0,20,10]
var drill_cost: Array[int] = [5,10,0]
var mouse_on_ui: bool = false
var selected_unit = null
var selected_building = null
var preview_atlas: AtlasTexture = AtlasTexture.new()
var slab_sprites = [Vector2i(0,4),Vector2i(0,5),Vector2i(0,6),Vector2i(1,5),Vector2i(1,6)]
var buildings: Dictionary = {}
var tiles_need_update: Array[Tile] = []
var tiles_with_pollution: Dictionary = {}
var pollution_tile_counter: int = 0
var resource_sprites: Array[Vector2i] = [Vector2i(4,2),Vector2i(5,2),Vector2i(6,2)]
var ship

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
	
	fill_fog()
	var pos = Vector2i(int(GRID_WIDTH / 2.),int(GRID_HEIGHT / 2.))
	preview_atlas.atlas = tiles_texture
	preview_tile.texture = preview_atlas
	connect("building_placed",_on_building_placed)
	tiles = load_map()
	var test_ship = SHIP.instantiate()
	add_child(test_ship)
	ship = $Ship
	ship.create_ship(pos,Buildings.Ship,ship)
	#for n in range(len(start_factory_pos)):
		#tiles[start_factory_pos[n]].building_sprite = building_tiles["factory"][n]
		#tiles[start_factory_pos[n]].building = Buildings.Factory
		#clear_fog_around_pos(start_factory_pos[n])
	#create_building(Buildings.Factory, start_factory_pos)
	draw_map_tiles()
	update_labels()
	spawn_unit(Units.Infantry, Vector2i(32,15))
	spawn_unit(Units.Infantry, Vector2i(32,25))
	spawn_unit(Units.Infantry, Vector2i(60,60))
	
func draw_map_tiles() -> void:
	for tile in tiles.values():
		update_tile(tile)

func update_tile(tile: Tile) -> void:
	map.set_cell(ground_layer, tile.grid_position, 0, tile.ground_sprite)
	map.set_cell(decoration_layer, tile.grid_position, 0, tile.decoration_sprite)
	map.set_cell(resource_layer, tile.grid_position, 0, tile.resource_sprite)
	map.set_cell(building_layer, tile.grid_position, 0, tile.building_sprite)

func update_labels():
	copper_label.text = str(floor(copper))
	coal_label.text = str(floor(coal))
	iron_label.text = str(floor(iron))
	stone_label.text = str(floor(stone))
	
func _on_menu_pressed():
	toggle_pause()
	
func _input(event):
	#if Input.is_action_just_pressed("select_unit"):
		#var pos: Vector2i = map.local_to_map(get_global_mouse_position())
		#print(check_tile_able_to_build_drill(tiles[pos]))
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
				if Input.is_action_just_pressed("interact_with_building") and not mouse_on_ui:
					var pos: Vector2i = map.local_to_map(get_global_mouse_position())
					for k in buildings.keys():
						if pos in k:
							selected_building = buildings[k]
							change_mode_to(Modes.BuildingSelected)
		Modes.Place:
			if event is InputEventMouseButton:
				if Input.is_action_pressed("place_tile") and not mouse_on_ui:
					var pos: Vector2i = map.local_to_map(get_global_mouse_position())
					if ship.try_create_building(ship.selected_building,pos):
						emit_signal("building_placed")
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
									tile.building= Buildings.Slab
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
									tiles[required_tiles_positions[n]].building = Buildings.LargeSlab
									update_tile(tiles[required_tiles_positions[n]])
								emit_signal("building_placed")
							Buildings.Factory:
								var required_tiles_positions: Array[Vector2i] = [pos, pos + Vector2i(0,1),pos + Vector2i(1,0),pos + Vector2i(1,1)]
								for p in required_tiles_positions:
									if not (p.x >= 0 and p.x < GRID_WIDTH and p.y >= 0 and p.y < GRID_HEIGHT):
										return
									if not check_tile_able_to_build(tiles[p]):
										return
								for n in range(len(required_tiles_positions)):
									tiles[required_tiles_positions[n]].building_sprite = building_tiles["factory"][n]
									tiles[required_tiles_positions[n]].building = Buildings.Factory
									clear_fog_around_pos(required_tiles_positions[n])
									update_tile(tiles[required_tiles_positions[n]])
								create_building(Buildings.Factory, required_tiles_positions)
								emit_signal("building_placed")
							Buildings.Drill:
								var required_tiles_positions: Array[Vector2i] = [pos]
								if not (pos.x >= 0 and pos.x < GRID_WIDTH and pos.y >= 0 and pos.y < GRID_HEIGHT):
									return
								if not check_tile_able_to_build_drill(tiles[pos]):
									return
								tiles[required_tiles_positions[0]].building_sprite = building_tiles["drill"][0]
								tiles[required_tiles_positions[0]].building = Buildings.Drill
								clear_fog_around_pos(required_tiles_positions[0])
								update_tile(tiles[required_tiles_positions[0]])
								create_building(Buildings.Drill, required_tiles_positions)
								emit_signal("building_placed")
							Buildings.None:
								pass
		Modes.MoveUnit:
			if event is InputEventMouseButton:
				if Input.is_action_just_pressed("select_unit_location") and not mouse_on_ui:
					var pos: Vector2i = map.local_to_map(get_global_mouse_position())
					if pos.x >= 0 and pos.x < GRID_WIDTH and pos.y >= 0 and pos.y < GRID_HEIGHT:
						if selected_unit.move_queue != []:
							selected_unit.move_queue.append_array(find_path(selected_unit.move_queue[-1],pos))
						else:
							selected_unit.move_queue.append_array(find_path(map.local_to_map(selected_unit.global_position),pos))
						change_mode_to(Modes.UnitSelected)
						move.text = "Move"
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
		Modes.BuildingSelected:
			if event is InputEventMouseButton and not mouse_on_ui:
				if Input.is_action_just_pressed("select_unit"):
					change_mode_to(Modes.Normal)
					selected_building = null

func _process(delta):
	spread_single_tile_pollution(delta)
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
			if selected_building != null:
				selected_building.hide_menu()
		Modes.Place:
			mode = Modes.Place
			show_building_preview()
		Modes.MoveUnit:
			mode = Modes.MoveUnit
			hide_building_preview()
		Modes.UnitSelected:
			mode = Modes.UnitSelected
			hide_building_preview()
		Modes.BuildingSelected:
			mode = Modes.BuildingSelected
			hide_building_preview()
			selected_building.show_menu()

func _on_building_placed():
	ship.change_to_normal()
	match building:
		Buildings.Slab:
			change_mode_to(Modes.Normal)
			slab_state = change_state_to(BuildingStates.None, slab)
		Buildings.LargeSlab:
			change_mode_to(Modes.Normal)
			large_slab_state = change_state_to(BuildingStates.None, large_slab)
		Buildings.Factory:
			change_mode_to(Modes.Normal)
			factory_state = change_state_to(BuildingStates.None, factory)
		Buildings.Drill:
			change_mode_to(Modes.Normal)
			drill_state = change_state_to(BuildingStates.None, drill)
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
	clear_fog_around_pos(pos)
			
func create_building(new_building: Buildings, pos: Array[Vector2i]):
	match new_building:
		Buildings.Factory:
			var instance = FACTORY.instantiate()
			add_child(instance)
			buildings[pos] = instance
		Buildings.Drill:
			var instance = DRILL.instantiate()
			match tiles[pos[0]].resource_sprite:
				Vector2i(4,2):
					instance.resource_type = Resources.Stone
				Vector2i(5,2):
					instance.resource_type = Resources.Copper
				Vector2i(6,2):
					instance.resource_type = Resources.Coal
				Vector2i(7,2):
					instance.resource_type = Resources.Iron
			add_child(instance)
			buildings[pos] = instance

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
	
func check_tile_able_to_build(tile: Tile):
	if tile.building_sprite in slab_sprites:
		return true
	return false

func check_tile_able_to_build_drill(tile: Tile):
	if tile.building_sprite != Vector2i(-1,-1):
		return false
	if not tile.resource_sprite in resource_sprites:
		return false
	return true

func _on_large_slab_button_pressed():
	match large_slab_state:
		BuildingStates.None:
			if check_resources(large_slab_cost):
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
			preview_atlas.region = Rect2(
				building_tiles["slab"].x * 16,
				building_tiles["slab"].y * 16,
				16,16)
			preview_tile.get_child(0).size = Vector2i(18,18)
		Buildings.LargeSlab:
			preview_atlas.region = Rect2(
				building_tiles["large_slab"][0].x * 16,
				building_tiles["large_slab"][0].y * 16,
				32,32)
			preview_tile.get_child(0).size = Vector2i(34,34)
		Buildings.Factory:
			preview_atlas.region = Rect2(
				building_tiles["factory"][0].x * 16,
				building_tiles["factory"][0].y * 16,
				32,32)
			preview_tile.get_child(0).size = Vector2i(34,34)

func _on_factory_button_pressed():
	match factory_state:
		BuildingStates.None:
			if check_resources(factory_cost):
				factory_state = change_state_to(BuildingStates.Building, factory)
				copper -= factory_cost[0]
				iron -= factory_cost[1]
				stone -= factory_cost[2]
				update_labels()
			else:
				print("not enough resources")
		BuildingStates.Waiting:
			if building != Buildings.None:
				return
			factory_state = change_state_to(BuildingStates.Placing, factory)
			building = Buildings.Factory
			update_preview_tile()
		BuildingStates.Placing:
			if building != Buildings.Factory:
				return
			factory_state =  change_state_to(BuildingStates.Waiting, factory)
			change_mode_to(Modes.Normal)
			building = Buildings.None

func _on_factory_timer_timeout():
	factory_state = change_state_to(BuildingStates.Waiting, factory)

func find_path(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	var start_tile: Tile = tiles[start]
	var end_tile: Tile = tiles[end]
	if not is_walkable(end_tile):
		return []
	var open_set: Array[Tile] = []
	var closed_set: Array[Tile] = []
	open_set.append(start_tile)
	while len(open_set) > 0:
		var current_tile = open_set[0]
		for i in range(1,len(open_set)):
			if open_set[i].f_cost < current_tile.f_cost or open_set[i].f_cost == current_tile.f_cost and open_set[i].h_cost < current_tile.h_cost:
				current_tile = open_set[i]
		var index = open_set.find(current_tile)
		open_set.remove_at(index)
		closed_set.append(current_tile)
		if current_tile == end_tile:
			return retrace_path(start_tile, end_tile)
		for n: Tile in get_neighbors(current_tile):
			if not is_walkable(n) or n in closed_set:
				continue
			var new_movement_cost_to_neighbor = current_tile.g_cost + get_distance(current_tile, n)
			if new_movement_cost_to_neighbor < n.g_cost or not n in open_set:
				n.g_cost = new_movement_cost_to_neighbor
				n.h_cost = get_distance(n, end_tile)
				n.parent = current_tile
				if not n in open_set:
					open_set.append(n)
	return []

func get_distance(tile_a: Tile, tile_b: Tile):
	var dst_x = abs(tile_a.grid_position.x - tile_b.grid_position.x)
	var dst_y = abs(tile_a.grid_position.y - tile_b.grid_position.y)
	if dst_x > dst_y:
		return 14*dst_y + 10 * (dst_x-dst_y)
	return 14*dst_x + 10 * (dst_y-dst_x)
	
func retrace_path(start: Tile, end: Tile) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current_tile = end
	while current_tile !=  start:
		path.append(current_tile.grid_position)
		current_tile = current_tile.parent
	path.reverse()
	return path
	
func get_neighbors(tile: Tile) -> Array[Tile]:
	var neighbors: Array[Tile] = []
	for y in range(-1,2):
		for x in range(-1,2):
			if x == 0 and y == 0:
				continue
			var check_x = tile.grid_position.x + x
			var check_y = tile.grid_position.y + y
			if check_x >= 0 and check_x < GRID_WIDTH and check_y >= 0 and check_y < GRID_HEIGHT:
				neighbors.append(tiles[Vector2i(check_x,check_y)])
	return neighbors

func is_walkable(tile: Tile):
	if tile.building != Buildings.Slab and tile.building != Buildings.None and tile.building != Buildings.LargeSlab:
		return false
	for k in units.keys():
		if k == tile.grid_position:
			return false
	return true

func add_pollution():
	for k in buildings:
		match typeof(buildings[k]):
			24:
				for p in k:
					var tile: Tile = tiles[p]
					tile.pollution += buildings[k].POLLUTION_GENERATION
					if tile not in tiles_with_pollution:
						tiles_with_pollution[p] = tile

func spread_single_tile_pollution(delta):
	if tiles_with_pollution.size() != 0:
		if pollution_tile_counter >= tiles_with_pollution.size():
			pollution_tile_counter = 0
		var tile: Tile = tiles_with_pollution.values()[pollution_tile_counter]
		pollution_tile_counter += 1
		if tile.pollution < 4:
			return
		var possible_neighbors = [
			tile.grid_position + Vector2i(-1,0),
			tile.grid_position + Vector2i(1,0),
			tile.grid_position + Vector2i(0,1),
			tile.grid_position + Vector2i(0,-1)
			]
		var spread_to_pos = possible_neighbors[rng.randi_range(0,3)]
		if spread_to_pos.x >= 0 and spread_to_pos.x < GRID_WIDTH and spread_to_pos.y >= 0 and spread_to_pos.y < GRID_HEIGHT:
			var spread_to_tile: Tile = tiles[spread_to_pos]
			if spread_to_tile.pollution < tile.pollution:
				var spread_amount = int(tile.pollution / POLLUTION_SPREAD_RATE) * delta
				spread_to_tile.pollution += spread_amount
				tile.pollution -= spread_amount
				if spread_to_tile not in tiles_with_pollution:
					tiles_with_pollution[spread_to_pos] = spread_to_tile
				#print("spreading ", spread_amount, " from ", tile.grid_position, " to ", spread_to_tile.grid_position)	
		if tile.pollution >= 5 and tile.pollution < 20 and tile.ground_sprite.y != 1:
			tile.ground_sprite.y = 1
			if tile not in tiles_need_update:
				tiles_need_update.append(tile)
		elif tile.pollution >= 20 and tile.pollution > 200 and tile.ground_sprite.y != 2:
			tile.ground_sprite.y = 2
			if tile not in tiles_need_update:
				tiles_need_update.append(tile)
		elif tile.pollution >= 200 and tile.pollution > 600 and tile.ground_sprite.y != 3:
			tile.ground_sprite.y = 3
			if tile not in tiles_need_update:
				tiles_need_update.append(tile)

func _on_pollution_timer_timeout():
	add_pollution()

func _on_pollution_update_timer_timeout():
	for t in tiles_need_update:
		update_tile(t)
	tiles_need_update = []

func fill_fog():
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			map.set_cell(4, Vector2i(x,y),0,Vector2i(1,10))

func clear_fog_around_pos(pos_2: Vector2i):
	map.erase_cell(4,pos_2)
	var neighbors: Array[Tile] = get_neighbors(tiles[pos_2])
	for n in neighbors:
		map.erase_cell(4,n.grid_position)
	for n in neighbors:
		var pos = n.grid_position
		var fog_neighbors = get_fog_neighbors(pos)
		for fn in fog_neighbors:
			var not_fog = get_not_fog_neighbors(pos + fn)
			not_fog.sort()
			if not_fog in fog_dict.keys():
				map.set_cell(4,pos+fn ,0,fog_dict[not_fog])

func get_not_fog_neighbors(pos: Vector2i) -> Array:
	var neighbors: Array = []
	var possible_neighbors: Array = [
		Vector2i(-1,-1),
		Vector2i(0,-1),
		Vector2i(1,-1),
		Vector2i(-1,0),
		Vector2i(1,0),
		Vector2i(-1,1),
		Vector2i(0,1),
		Vector2i(1,1)
	]
	for pn in possible_neighbors:
		var check_x = pos.x + pn.x
		var check_y = pos.y + pn.y
		if check_x >= 0 and check_x < GRID_WIDTH and check_y >= 0 and check_y < GRID_HEIGHT:
			if map.get_cell_atlas_coords(4,pos + pn) != Vector2i(-1,-1):
				continue
			neighbors.append(pn)
	return neighbors

func get_fog_neighbors(pos: Vector2i) -> Array:
	var neighbors: Array = []
	var possible_neighbors: Array = [
		Vector2i(-1,-1),
		Vector2i(0,-1),
		Vector2i(1,-1),
		Vector2i(-1,0),
		Vector2i(1,0),
		Vector2i(-1,1),
		Vector2i(0,1),
		Vector2i(1,1)
	]
	for pn in possible_neighbors:
		var check_x = pos.x + pn.x
		var check_y = pos.y + pn.y
		if check_x >= 0 and check_x < GRID_WIDTH and check_y >= 0 and check_y < GRID_HEIGHT:
			if map.get_cell_atlas_coords(4,pos + pn) == Vector2i(-1,-1):
				continue
			neighbors.append(pn)
	return neighbors

func _on_drill_button_pressed():
	match drill_state:
		BuildingStates.None:
			if check_resources(drill_cost):
				drill_state = change_state_to(BuildingStates.Building, drill)
				copper -= drill_cost[0]
				iron -= drill_cost[1]
				stone -= drill_cost[2]
				update_labels()
			else:
				print("not enough resources")
		BuildingStates.Waiting:
			if building != Buildings.None:
				return
			drill_state = change_state_to(BuildingStates.Placing, drill)
			building = Buildings.Drill
			update_preview_tile()
		BuildingStates.Placing:
			if building != Buildings.Drill:
				return
			drill_state =  change_state_to(BuildingStates.Waiting, drill)
			change_mode_to(Modes.Normal)
			building = Buildings.None

func _on_drill_timer_timeout():
	drill_state = change_state_to(BuildingStates.Waiting, drill)

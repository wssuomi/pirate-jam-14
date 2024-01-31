extends Node2D

@onready var pause_menu = $CanvasLayer/PauseMenu
@onready var camera: Camera2D = $Camera
@onready var map: TileMap = $Map
@onready var copper_label: Label = $CanvasLayer/TopBar/Copper/MarginContainer/HBoxContainer/CopperLabel
@onready var iron_label: Label = $CanvasLayer/TopBar/Iron/MarginContainer/HBoxContainer/IronLabel
@onready var coal_label: Label = $CanvasLayer/TopBar/Coal/MarginContainer/HBoxContainer/CoalLabel
@onready var preview_tile = $PreviewTile
@onready var stone_label = $CanvasLayer/TopBar/Stone/MarginContainer/HBoxContainer/StoneLabel
@onready var move = $CanvasLayer/SideBarUnitAction/Actions/VBoxContainer/Move
@onready var side_bar_unit_action = $CanvasLayer/SideBarUnitAction
@onready var attack = $CanvasLayer/SideBarUnitAction/Actions/VBoxContainer/Attack
@onready var move_target_indicator = $MoveTargetIndicator
@onready var attack_target_indicator = $AttackTargetIndicator

const GRID_WIDTH = 64
const GRID_HEIGHT = 64
const Tile = preload("res://scripts/Tile.gd").Tile
const INFANTRY = preload("res://scenes/infantry.tscn")
const POLLUTION_SPREAD_RATE: float = 2.
const fog_dict = preload("res://scripts/fog.gd").fog_dict
const SHIP = preload("res://scenes/ship.tscn")
const BUG = preload("res://scenes/bug.tscn")
const NEST = preload("res://scenes/nest.tscn")

enum Modes {Normal, Place, PlaceUnit, MoveUnit, UnitSelected, BuildingSelected, AttackWithUnit}
enum Buildings {None, Slab, LargeSlab, Factory, Drill, Ship}
enum Units {None,Infantry}
enum Enemies {Bug, Nest}
enum Resources {Copper, Stone, Iron, Coal}

var tiles_texture = preload("res://assets/map_tiles.png")
var paused = false
var tiles = {}
var units = {}
var enemies = {}
var rng = RandomNumberGenerator.new()
var ground_layer: int = 0
var decoration_layer: int = 1
var resource_layer: int = 2
var building_layer: int = 3
var copper = 0
var coal = 0
var stone = 0
var iron = 0
var mode = 0
var mouse_on_ui: bool = false
var selected_unit = null
var selected_building = null
var preview_atlas: AtlasTexture = AtlasTexture.new()
var buildings: Dictionary = {}
var tiles_need_update: Array[Tile] = []
var tiles_with_pollution: Dictionary = {}
var pollution_tile_counter: int = 0
var alive = true
var ship
var start_units = [
Vector2i(34, 31),
Vector2i(32, 35),
Vector2i(36, 33),
Vector2i(31, 32)
]
var start_bugs = [
Vector2i(43, 38),
Vector2i(39, 29),
Vector2i(27, 27),
Vector2i(23, 36),
Vector2i(33, 43)
]
var nests = [
Vector2i(6, 8),
Vector2i(9, 14),
Vector2i(12, 12),
Vector2i(27, 9),
Vector2i(39, 10),
Vector2i(54, 8),
Vector2i(11, 22),
Vector2i(24, 19),
Vector2i(36, 22),
Vector2i(54, 21),
Vector2i(14, 31),
Vector2i(50, 30),
Vector2i(7, 44),
Vector2i(50, 43),
Vector2i(9, 52),
Vector2i(18, 50),
Vector2i(39, 51),
Vector2i(58, 54),
Vector2i(9, 58),
Vector2i(14, 61),
Vector2i(24, 60),
Vector2i(50, 61),
]

signal building_placed
signal unit_placed

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
	paused = false
	Engine.time_scale = 1
	fill_fog()
	var pos = Vector2i(int(GRID_WIDTH / 2.),int(GRID_HEIGHT / 2.))
	preview_atlas.atlas = tiles_texture
	preview_tile.texture = preview_atlas
	connect("building_placed",_on_building_placed)
	connect("unit_placed",_on_unit_placed)
	tiles = load_map()
	var test_ship = SHIP.instantiate()
	add_child(test_ship)
	ship = $Ship
	ship.create_ship(pos,Buildings.Ship,ship)
	draw_map_tiles()
	update_labels()
	for n in nests:
		spawn_enemy(Enemies.Nest, n)
	for b in start_bugs:
		spawn_enemy(Enemies.Bug, b)
	for u in start_units:
		spawn_unit(Units.Infantry, u)
	ship.try_create_building(Buildings.Drill, Vector2i(35,35), true)
	
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
	if not alive:
		return
	toggle_pause()
	
func _input(event):
	if not alive:
		return
	if event is InputEventKey:
		if Input.is_action_just_pressed("pause"):
			toggle_pause()
	if paused:
		return
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
		Modes.PlaceUnit:
			if event is InputEventMouseButton:
				if Input.is_action_pressed("place_tile") and not mouse_on_ui:
					var pos: Vector2i = map.local_to_map(get_global_mouse_position())
					if selected_building.try_spawn_unit(selected_building.selected_unit,pos):
						emit_signal("unit_placed")
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
						return
					for k in buildings.keys():
						if pos in k:
							selected_building = buildings[k]
							deselect_unit()
							change_mode_to(Modes.BuildingSelected)
							return
					deselect_unit()
					change_mode_to(Modes.Normal)
		Modes.BuildingSelected:
			if event is InputEventMouseButton and not mouse_on_ui:
				if Input.is_action_just_pressed("interact_with_building"):
					var pos: Vector2i = map.local_to_map(get_global_mouse_position())
					if pos in units.keys():
						change_mode_to(Modes.Normal)
						selected_building = null
						select_unit(pos)
						change_mode_to(Modes.UnitSelected)
						return
					for k in buildings.keys():
						if pos in k:
							change_mode_to(Modes.Normal)
							selected_building = buildings[k]
							change_mode_to(Modes.BuildingSelected)
							return
					change_mode_to(Modes.Normal)
					selected_building = null
		Modes.AttackWithUnit:
			if event is InputEventMouseButton:
				if Input.is_action_just_pressed("select_unit_location") and not mouse_on_ui:
					var pos: Vector2i = map.local_to_map(get_global_mouse_position())
					if not (pos.x >= 0 and pos.x < GRID_WIDTH and pos.y >= 0 and pos.y < GRID_HEIGHT):
						return
					if selected_unit.move_queue != []:
						selected_unit.move_queue.append_array(find_attack_path(selected_unit.move_queue[-1],pos,28))
					else:
						selected_unit.move_queue.append_array(find_attack_path(map.local_to_map(selected_unit.global_position),pos,28))
					selected_unit.attack_target = pos
					selected_unit.attack_target_set_by_player = true
					change_mode_to(Modes.UnitSelected)
					attack.text = "Attack"

func _process(delta):
	spread_single_tile_pollution(delta)
	match mode:
		Modes.Normal:
			pass
		Modes.Place:
			preview_tile.position = map.map_to_local(map.local_to_map(get_global_mouse_position())) - Vector2(8,8)
		Modes.MoveUnit:
			move_target_indicator.position = map.map_to_local(map.local_to_map(get_global_mouse_position()))
		Modes.AttackWithUnit:
			attack_target_indicator.position = map.map_to_local(map.local_to_map(get_global_mouse_position()))

func check_resources(cost: Array[int]):
	if copper >= cost[0] and iron >= cost[1] and stone >= cost[2]:
		return true
	return false

func change_mode_to(next_mode: Modes):
	match next_mode:
		Modes.Normal:
			mode = Modes.Normal
			hide_building_preview()
			if selected_building != null:
				selected_building.hide_menu()
		Modes.Place:
			mode = Modes.Place
			show_building_preview()
		Modes.PlaceUnit:
			mode = Modes.PlaceUnit
		Modes.MoveUnit:
			mode = Modes.MoveUnit
			hide_building_preview()
			move_target_indicator.show()
		Modes.UnitSelected:
			mode = Modes.UnitSelected
			hide_building_preview()
			move_target_indicator.hide()
			attack_target_indicator.hide()
		Modes.BuildingSelected:
			mode = Modes.BuildingSelected
			hide_building_preview()
			selected_building.show_menu()
		Modes.AttackWithUnit:
			mode = Modes.AttackWithUnit
			hide_building_preview()
			attack_target_indicator.show()

func _on_building_placed():
	ship.change_to_normal()

func _on_unit_placed():
	selected_building.change_to_normal()

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
	
func spawn_enemy(enemy_type: Enemies, pos: Vector2i):
	match enemy_type:
		Enemies.Bug:
			var instance = BUG.instantiate()
			instance.position = map.map_to_local(pos)
			add_child(instance)
			enemies[pos] = instance
		Enemies.Nest:
			var instance = NEST.instantiate()
			instance.position = map.map_to_local(pos)
			add_child(instance)
			enemies[pos] = instance

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

func show_building_preview():
	preview_tile.show()

func hide_building_preview():
	preview_tile.hide()

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

func find_attack_path(start: Vector2i, end: Vector2i, attack_range) -> Array[Vector2i]:
	var start_tile: Tile = tiles[start]
	var end_tile: Tile = tiles[end]
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
		if get_distance(current_tile,end_tile) <= attack_range:
			end_tile = current_tile
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

func is_valid_attack_target(tile: Tile):
	for k in units.keys():
		if k == tile.grid_position:
			return false
	for k in enemies.keys():
		if k == tile.grid_position:
			return false
	return true

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
	for k in enemies.keys():
		if k == tile.grid_position:
			if map.get_cell_atlas_coords(4,tile.grid_position) == Vector2i(-1,-1):
				return false
	return true

func add_pollution():
	for k in buildings:
		match typeof(buildings[k]):
			24:
				for p in k:
					var tile: Tile = tiles[p]
					if is_instance_valid(buildings[k]):
						tile.pollution += buildings[k].POLLUTION_GENERATION
						if tile not in tiles_with_pollution:
							tiles_with_pollution[p] = tile

func spread_single_tile_pollution(delta):
	if tiles_with_pollution.size() != 0:
		if pollution_tile_counter >= tiles_with_pollution.size():
			pollution_tile_counter = 0
		var tile: Tile = tiles_with_pollution.values()[pollution_tile_counter]
		pollution_tile_counter += 1
		if tile.pollution < 1:
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
				spread_to_tile.pollution += spread_amount * 10
				tile.pollution -= spread_amount
				if spread_to_tile not in tiles_with_pollution:
					tiles_with_pollution[spread_to_pos] = spread_to_tile
				#print("spreading ", spread_amount, " from ", tile.grid_position, " to ", spread_to_tile.grid_position)	
		if tile.pollution > 0 and tile.pollution < 20 and tile.ground_sprite.y != 1:
			tile.ground_sprite.y = 1
			if tile.decoration_sprite != Vector2i(-1,-1):
				tile.decoration_sprite.x = 4
			if tile not in tiles_need_update:
				tiles_need_update.append(tile)
		elif tile.pollution >= 20 and tile.pollution > 200 and tile.ground_sprite.y != 2:
			tile.ground_sprite.y = 2
			if tile.decoration_sprite != Vector2i(-1,-1):
				tile.decoration_sprite.x = 5
			if tile not in tiles_need_update:
				tiles_need_update.append(tile)
		elif tile.pollution >= 200 and tile.pollution > 600 and tile.ground_sprite.y != 3:
			tile.ground_sprite.y = 3
			if tile.decoration_sprite != Vector2i(-1,-1):
				tile.decoration_sprite.x = 6
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

func _on_attack_pressed():
	match mode:
		Modes.UnitSelected:
			change_mode_to(Modes.AttackWithUnit)
			attack.text = "Cancel"
		Modes.AttackWithUnit:
			change_mode_to(Modes.UnitSelected)
			attack.text = "Attack"

func _on_guard_pressed():
	match mode:
		Modes.UnitSelected:
			selected_unit.attack_target = Vector2i(-1,-1)
			selected_unit.attack_target_set_by_player = false
			if selected_unit.move_queue != []:
				selected_unit.move_queue = [selected_unit.move_queue[0]]

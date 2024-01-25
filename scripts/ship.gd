extends CanvasLayer

const FACTORY = preload("res://scenes/factory.tscn")
const DRILL = preload("res://scenes/drill.tscn")
const POLLUTION_GENERATION = 2

@onready var slab = $SideBar/BuildOptions/VBoxContainer/Slab
@onready var large_slab = $SideBar/BuildOptions/VBoxContainer/LargeSlab
@onready var factory = $SideBar/BuildOptions/VBoxContainer/Factory
@onready var drill = $SideBar/BuildOptions/VBoxContainer/Drill
@onready var main = $".."
@onready var side_bar = $SideBar
@onready var building_sprites: Dictionary = {
	main.Buildings.Slab:[Vector2i(0,4)],
	main.Buildings.LargeSlab:[Vector2i(0,5),Vector2i(0,6),Vector2i(1,5),Vector2i(1,6)],
	main.Buildings.Factory:[Vector2i(0,7),Vector2i(0,8),Vector2i(1,7),Vector2i(1,8)],
	main.Buildings.Drill:[Vector2i(2,8)],
	main.Buildings.Ship:[Vector2i(2,5),Vector2i(2,6),Vector2i(3,5),Vector2i(3,6)],
	}
@onready var tile_requirements: Dictionary = {
	main.Buildings.Slab:[Vector2i(0,0)],
	main.Buildings.LargeSlab:[Vector2i(0,0), Vector2i(0,1), Vector2i(1,0), Vector2i(1,1)],
	main.Buildings.Factory:[Vector2i(0,0), Vector2i(0,1), Vector2i(1,0), Vector2i(1,1)],
	main.Buildings.Drill:[Vector2i(0,0)],
	main.Buildings.Ship:[Vector2i(0,0), Vector2i(0,1), Vector2i(1,0), Vector2i(1,1)],
}
#stone, iron, copper, area
@onready var build_costs: Dictionary = {
	main.Buildings.Slab:[10,1,0,"1x1 grass"],
	main.Buildings.LargeSlab:[40,4,0,"2x2 grass"],
	main.Buildings.Factory:[10,20,20,"2x2 slab"],
	main.Buildings.Drill:[0,10,0,"1x1 ore"],
	main.Buildings.Ship:[10,10,10,"End Demo"],
}
@onready var build_times: Dictionary = {
	main.Buildings.Slab:1,
	main.Buildings.LargeSlab:4,
	main.Buildings.Factory:3,
	main.Buildings.Drill:2,
	main.Buildings.Ship:2,
}
@onready var preview_sizes: Dictionary = {
	main.Buildings.Slab:16,
	main.Buildings.LargeSlab:32,
	main.Buildings.Factory:32,
	main.Buildings.Drill:16,
	main.Buildings.Ship:32,
}
@onready var selected_building = main.Buildings.None
@onready var copper_label = $SideBar/Selected/VBoxContainer/HBoxContainer/VBoxContainer/Copper/CopperLabel
@onready var stone_label = $SideBar/Selected/VBoxContainer/HBoxContainer/VBoxContainer/Stone/StoneLabel
@onready var iron_label = $SideBar/Selected/VBoxContainer/HBoxContainer/VBoxContainer/Iron/IronLabel
@onready var area_label = $SideBar/Selected/VBoxContainer/HBoxContainer/VBoxContainer/Area/AreaLabel
@onready var build_timer = $SideBar/Selected/VBoxContainer/BuildTimer
@onready var build_button = $SideBar/Selected/VBoxContainer/Button
@onready var buildings = {
	main.Buildings.Factory:FACTORY,
	main.Buildings.Drill:DRILL,
}
@onready var selected_picture = $SideBar/Selected/VBoxContainer/HBoxContainer/Picture

var building_layer: int = 3
var resource_sprites: Array[Vector2i] = [Vector2i(4,2),Vector2i(5,2),Vector2i(6,2),Vector2i(7,2)]
var slab_sprites = [Vector2i(0,4),Vector2i(0,5),Vector2i(0,6),Vector2i(1,5),Vector2i(1,6)]
var build_state = BuildState.None
var tiles_texture = preload("res://assets/map_tiles.png")
var selected_atlas: AtlasTexture = AtlasTexture.new()
var health = 100

enum BuildState {None, Building, Finished, Placing}

func show_menu():
	side_bar.show()
	
func hide_menu():
	side_bar.hide()

func try_create_building(building_type, pos: Vector2i, ignore_fog=false):
	var required_offsets = tile_requirements[building_type]
	var building_pos = []
	for tile_offset in required_offsets:
		var tile_pos = pos + tile_offset
		if not able_to_build(building_type, tile_pos, ignore_fog):
			return false
		if check_units(tile_pos):
			return false
		building_pos.append(tile_pos)
	for n in range(len(required_offsets)):
		var tile = main.tiles[pos + required_offsets[n]]
		tile.building_sprite = building_sprites[building_type][n]
		tile.building = building_type
		main.clear_fog_around_pos(tile.grid_position)
		main.map.set_cell(building_layer, tile.grid_position, 0, tile.building_sprite)
	if building_type in buildings:
		var building = buildings[building_type].instantiate()
		match building_type:
			main.Buildings.Drill:
				match main.tiles[pos].resource_sprite:
					Vector2i(4,2):
						building.resource_type = main.Resources.Stone
					Vector2i(5,2):
						building.resource_type = main.Resources.Copper
					Vector2i(6,2):
						building.resource_type = main.Resources.Coal
					Vector2i(7,2):
						building.resource_type = main.Resources.Iron
		main.add_child(building)
		main.buildings[building_pos] = building
	return true

func create_ship(pos, building_type, building):
	var required_offsets = tile_requirements[building_type]
	var building_pos = []
	for tile_offset in required_offsets:
		building_pos.append(pos + tile_offset)
	for n in range(len(required_offsets)):
		var tile = main.tiles[pos + required_offsets[n]]
		tile.building_sprite = building_sprites[building_type][n]
		tile.building = building_type
		main.clear_fog_around_pos(tile.grid_position)
		main.map.set_cell(building_layer, tile.grid_position, 0, tile.building_sprite)
	main.buildings[building_pos] = building

func able_to_build(building_type, pos: Vector2i, ignore_fog=false):
	if not (pos.x >= 0 and pos.x < main.GRID_WIDTH and pos.y >= 0 and pos.y < main.GRID_HEIGHT):
		return false
	var fog = main.map.get_cell_atlas_coords(4, pos) 
	if fog != Vector2i(-1,-1) and not ignore_fog:
		return false
	var tile = main.tiles[pos]
	match building_type:
		main.Buildings.Slab:
			if tile.building_sprite != Vector2i(-1,-1):
				return false
			return true
		main.Buildings.LargeSlab:
			if tile.building_sprite != Vector2i(-1,-1):
				return false
			return true
		main.Buildings.Factory:
			if not tile.building_sprite in slab_sprites:
				return false
			return true
		main.Buildings.Drill:
			if tile.building_sprite != Vector2i(-1,-1):
				return false
			if not tile.resource_sprite in resource_sprites:
				return false
			return true
		main.Buildings.Ship:
			return true
		_:
			print("Unknown Building")

func _on_side_bar_mouse_entered():
	main.mouse_on_ui = true

func _on_side_bar_mouse_exited():
	main.mouse_on_ui = false
	
func _on_slab_button_pressed():
	if build_state == BuildState.None:
		var building_type = main.Buildings.Slab
		var size = preview_sizes[building_type]
		selected_atlas.region = Rect2(
			building_sprites[building_type][0].x * 16,
			building_sprites[building_type][0].y * 16,
			size,size
		)
		change_selected_to(main.Buildings.Slab)

func _on_large_button_pressed():
	if build_state == BuildState.None:
		var building_type = main.Buildings.LargeSlab
		var size = preview_sizes[building_type]
		selected_atlas.region = Rect2(
			building_sprites[building_type][0].x * 16,
			building_sprites[building_type][0].y * 16,
			size,size
		)
		change_selected_to(main.Buildings.LargeSlab)

func _on_factory_button_pressed():
	if build_state == BuildState.None:
		var building_type = main.Buildings.Factory
		var size = preview_sizes[building_type]
		selected_atlas.region = Rect2(
			building_sprites[building_type][0].x * 16,
			building_sprites[building_type][0].y * 16,
			size,size
		)
		change_selected_to(main.Buildings.Factory)

func _on_drill_button_pressed():
	if build_state == BuildState.None:
		var building_type = main.Buildings.Drill
		var size = preview_sizes[building_type]
		selected_atlas.region = Rect2(
			building_sprites[building_type][0].x * 16,
			building_sprites[building_type][0].y * 16,
			size,size
		)
		change_selected_to(main.Buildings.Drill)

func change_selected_to(building):
	selected_building = building
	var costs = build_costs[selected_building]
	copper_label.text = str(floor(costs[2]))
	iron_label.text = str(floor(costs[1]))
	stone_label.text = str(floor(costs[0]))
	area_label.text = costs[3]

func _on_build_button_pressed():
	match build_state:
		BuildState.None:
			var cost = build_costs[selected_building]
			var can_build = false
			for t in main.tiles.values():
				if able_to_build(selected_building, t.grid_position):
					can_build = true
			if check_resources(cost) and can_build:
				main.copper -= cost[2]
				main.iron -= cost[1]
				main.stone -= cost[0]
				main.update_labels()
				build_state = BuildState.Building
				build_timer.wait_time = build_times[selected_building]
				build_timer.start()
				build_button.text = "Building..."
		BuildState.Finished:
			build_button.text = "Cancel"
			build_state = BuildState.Placing
			update_preview_tile(selected_building)
			main.change_mode_to(main.Modes.Place)
		BuildState.Placing:
			build_button.text = "Place"
			build_state = BuildState.Finished
			main.change_mode_to(main.Modes.BuildingSelected)

func change_to_normal():
	build_button.text = "Build"
	build_state = BuildState.None
	main.change_mode_to(main.Modes.BuildingSelected)

func check_resources(cost: Array):
	if main.copper >= cost[2] and main.iron >= cost[1] and main.stone >= cost[0]:
		return true
	return false

func _on_build_timer_timeout():
	if selected_building == main.Buildings.Ship:
		get_tree().change_scene_to_file("res://scenes/end_screen.tscn")
	build_button.text = "Place"
	build_state = BuildState.Finished

func update_preview_tile(building_type):
	var size = preview_sizes[building_type]
	main.preview_atlas.region = Rect2(
		building_sprites[building_type][0].x * 16,
		building_sprites[building_type][0].y * 16,
		size,size
	)
	main.preview_tile.get_child(0).size = Vector2i(size+2,size+2)

func _ready():
	selected_atlas.atlas = tiles_texture
	selected_picture.texture = selected_atlas
	change_selected_to(main.Buildings.Slab)

func check_units(pos):
	if pos in main.units.keys():
		return true
	return false

func take_damage(damage_amount):
	health -= damage_amount
	if health <= 0:
		if main.selected_building == self:
			main.selected_building = null
			main.change_mode_to(main.Modes.Normal)
		var k = buildings.find_key(self)
		for t in k:
			main.tiles[t].building_sprite = Vector2i(-1,-1)
			main.map.erase_cell(3,t)
		if k != null:
			buildings.erase(k)
		self.queue_free()

func _on_repair_ship_button_pressed():
	if build_state == BuildState.None:
		var building_type = main.Buildings.Ship
		var size = preview_sizes[building_type]
		selected_atlas.region = Rect2(
			building_sprites[building_type][0].x * 16,
			building_sprites[building_type][0].y * 16,
			size,size
		)
		change_selected_to(main.Buildings.Ship)

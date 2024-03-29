extends CanvasLayer

@onready var main = $".."
@onready var side_bar = $SideBar
@onready var unit_option = $SideBar/BuildOptions/VBoxContainer/Unit
@onready var tank_option = $SideBar/BuildOptions/VBoxContainer/Tank
@onready var selected_unit = main.Units.None
@onready var copper_label = $SideBar/Selected/VBoxContainer/HBoxContainer/VBoxContainer/Copper/CopperLabel
@onready var stone_label = $SideBar/Selected/VBoxContainer/HBoxContainer/VBoxContainer/Stone/StoneLabel
@onready var iron_label = $SideBar/Selected/VBoxContainer/HBoxContainer/VBoxContainer/Iron/IronLabel
@onready var coal_label = $SideBar/Selected/VBoxContainer/HBoxContainer/VBoxContainer/Coal/CoalLabel
@onready var build_timer = $SideBar/Selected/VBoxContainer/BuildTimer
@onready var build_button = $SideBar/Selected/VBoxContainer/Button
@onready var health_label = $SideBar/Selected/VBoxContainer/HBoxContainer2/HealthLabel
@onready var units = {
	main.Units.Infantry:INFANTRY,
	#main.Units.Tank:TANK,
}
@onready var selected_picture = $SideBar/Selected/VBoxContainer/HBoxContainer/Picture
#stone, iron, copper, coal
@onready var build_costs: Dictionary = {
	main.Units.Infantry:[0,5,5,3],
}
@onready var build_times: Dictionary = {
	main.Units.Infantry:5,
}
@onready var buildings: Dictionary = $"..".buildings
@onready var destroyed = $destroyed
@onready var hit = $Hit

# per tile
const POLLUTION_GENERATION: int = 3
const INFANTRY = preload("res://scenes/infantry.tscn")
const MAX_HEALTH = 20

enum BuildState {None, Building, Finished, Placing}

var build_state = BuildState.None
var tiles_texture = preload("res://assets/map_tiles.png")
var selected_atlas: AtlasTexture = AtlasTexture.new()
var health: int = MAX_HEALTH

func show_menu():
	side_bar.show()
	
func hide_menu():
	side_bar.hide()

func _on_side_bar_mouse_entered():
	main.mouse_on_ui = true

func _on_side_bar_mouse_exited():
	main.mouse_on_ui = false

func try_spawn_unit(unit_type, pos: Vector2i):
	if not able_to_spawn(unit_type, pos):
		return false
	if check_units(pos):
		return false
	main.clear_fog_around_pos(pos)
	
	if unit_type in units:
		var unit = units[unit_type].instantiate()
		unit.position = main.map.map_to_local(pos)
		main.add_child(unit)
		main.units[pos] = unit
	return true

func able_to_spawn(_unit_type, pos):
	if not (pos.x >= 0 and pos.x < main.GRID_WIDTH and pos.y >= 0 and pos.y < main.GRID_HEIGHT):
		return false
	var fog = main.map.get_cell_atlas_coords(4, pos) 
	if fog != Vector2i(-1,-1):
		return false
	var tile = main.tiles[pos]
	if tile.building != main.Buildings.Slab and tile.building != main.Buildings.None and tile.building != main.Buildings.LargeSlab:
		return false
	for k in main.units.keys():
		if k == tile.grid_position:
			return false
	for k in main.enemies.keys():
		if k == tile.grid_position:
			return false
	return true

func check_units(pos):
	if pos in main.units.keys():
		return true
	return false

func _on_build_button_pressed():
	match build_state:
		BuildState.None:
			var cost = build_costs[selected_unit]
			var can_spawn = false
			for t in main.tiles.values():
				if able_to_spawn(selected_unit, t.grid_position):
					can_spawn = true
			if check_resources(cost) and can_spawn:
				main.copper -= cost[2]
				main.iron -= cost[1]
				main.stone -= cost[0]
				main.coal -= cost[3]
				main.update_labels()
				build_state = BuildState.Building
				build_timer.wait_time = build_times[selected_unit]
				build_timer.start()
				build_button.text = "Building..."
		BuildState.Finished:
			build_button.text = "Cancel"
			build_state = BuildState.Placing
			main.change_mode_to(main.Modes.PlaceUnit)
		BuildState.Placing:
			build_button.text = "Place"
			build_state = BuildState.Finished
			main.change_mode_to(main.Modes.BuildingSelected)

func check_resources(cost: Array):
	if main.copper >= cost[2] and main.iron >= cost[1] and main.stone >= cost[0] and main.coal >= cost[3]:
		return true
	return false

func change_selected_to(unit):
	selected_unit = unit
	var costs = build_costs[selected_unit]
	copper_label.text = str(floor(costs[2]))
	iron_label.text = str(floor(costs[1]))
	stone_label.text = str(floor(costs[0]))
	coal_label.text = str(floor(costs[3]))

func _ready():
	change_selected_to(main.Units.Infantry)
	health_label.text = str(health) + "/" + str(MAX_HEALTH)
	
func _on_unit_button_pressed():
	if build_state == BuildState.None:
		var unit_type = main.Units.Infantry
		change_selected_to(unit_type)

func _on_tank_button_pressed():
	pass # Replace with function body.

func _on_build_timer_timeout():
	build_button.text = "Place"
	build_state = BuildState.Finished

func change_to_normal():
	build_button.text = "Build"
	build_state = BuildState.None
	main.change_mode_to(main.Modes.BuildingSelected)

func take_damage(damage_amount):
	health -= damage_amount
	if health <= 0:
		if main.selected_building == self:
			main.selected_building = null
			main.change_mode_to(main.Modes.Normal)
		var k = main.buildings.find_key(self)
		for t in k:
			main.tiles[t].building_sprite = Vector2i(-1,-1)
			main.map.erase_cell(3,t)
		if k != null:
			main.buildings.erase(k)
		destroyed.play()
		health_label.text = "0/" + str(MAX_HEALTH)
		self.queue_free()
	else:
		health_label.text = str(health) + "/" + str(MAX_HEALTH)
		hit.play()

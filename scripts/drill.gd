extends CanvasLayer

@onready var main = $".."
@onready var side_bar = $SideBar
@onready var buildings: Dictionary = $"..".buildings

const POLLUTION_GENERATION: int = 1
const RESOURCE_GENERATION = 10/60. * 5

var resource_type
var health: int = 10

func show_menu():
	side_bar.show()
	
func hide_menu():
	side_bar.hide()

func _on_side_bar_mouse_entered():
	main.mouse_on_ui = true

func _on_side_bar_mouse_exited():
	main.mouse_on_ui = false

func _on_mine_timer_timeout():
	match resource_type:
		main.Resources.Copper:
			main.copper += RESOURCE_GENERATION
		main.Resources.Iron:
			main.iron += RESOURCE_GENERATION
		main.Resources.Stone:
			main.stone += RESOURCE_GENERATION
		main.Resources.Coal:
			main.coal += RESOURCE_GENERATION
		_:
			print("Unknown resource")
	main.update_labels()

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

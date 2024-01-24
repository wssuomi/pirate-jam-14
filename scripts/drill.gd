extends CanvasLayer

@onready var main = $".."
@onready var side_bar = $SideBar

const POLLUTION_GENERATION: int = 1
const RESOURCE_GENERATION = 10/60. * 5
var resource_type

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

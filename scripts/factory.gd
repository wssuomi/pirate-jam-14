extends CanvasLayer

@onready var main = $".."
@onready var side_bar_build = $SideBarBuild

# per tile
const POLLUTION_GENERATION: int = 3

func _on_button_pressed():
	main.spawn_unit(main.Units.Infantry,Vector2i(32,32))

func show_menu():
	side_bar_build.show()
	
func hide_menu():
	side_bar_build.hide()

func _on_side_bar_build_mouse_entered():
	main.mouse_on_ui = true

func _on_side_bar_build_mouse_exited():
	main.mouse_on_ui = false


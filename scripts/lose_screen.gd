extends Control

@onready var main = $"../.."

func _on_restart_pressed():
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_main_menu_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_quit_pressed():
	get_tree().quit()

extends Node2D

@onready var select_indicator = $SelectIndicator


func select():
	select_indicator.show()
	
func deselect():
	select_indicator.hide()

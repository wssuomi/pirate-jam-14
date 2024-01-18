extends Node2D

@onready var select_indicator = $SelectIndicator

enum State {Guard, Walk, Attack}

func select():
	select_indicator.show()
	
func deselect():
	select_indicator.hide()

extends Camera2D

@onready var main = $".."

func _process(_delta):
	if main.paused:
		return
	if Input.is_action_just_pressed("zoom_in"):
		if zoom + Vector2(.1,.1) < Vector2(5,5):
			zoom += Vector2(.1,.1)
	if Input.is_action_just_pressed("zoom_out"):
		if zoom - Vector2(.1,.1) > Vector2(1.5,1.5):
			zoom -= Vector2(.1,.1)

func _input(event):
	if main.paused:
		return
	if event is InputEventMouseMotion:
		if Input.is_action_pressed("move_camera"):
			var new_pos = position - event.relative / zoom.x
			new_pos.x = clamp(new_pos.x,0.0,main.GRID_WIDTH * 16.0)
			new_pos.y = clamp(new_pos.y,0.0,main.GRID_HEIGHT * 16.0)
			position = new_pos

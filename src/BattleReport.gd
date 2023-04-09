extends PopupPanel


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	print("This is BattleReport")
	# connect the button's "pressed" signal to the "on_close_button_pressed" method
	#$HUD/BattleReport/OKButton.connect("pressed", self, "_on_OKButton_pressed")



# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_OKButton_pressed():
	print("OKButton  / Back To Game pressed")
	$HUD.hide()


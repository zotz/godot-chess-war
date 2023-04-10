extends PopupPanel
var report_debug = false

# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	if report_debug: print("This is BattleReport")
	pass



# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_OKButton_pressed():
	if report_debug: print("OKButton  / Back To Game pressed")
	$HUD.hide()


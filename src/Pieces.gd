#tool

extends GridContainer

var rng = RandomNumberGenerator.new()

#var variable

#func set_variable(var v):
#    variable = v

func get_rng():
	return rng


var keys = "BKNPQR" # Bishop King kNight Pawn Queen Rook

# The key code used in notation (PRNBQK)

# not sure if I am putting this in the correct spot.
# we shall see
# I know I am doing something wrong below but how to fix?
var kinga = 1
var kingd = 1
var kingv = 1
var kingr = 1
var queena = 1
var queend = 1
var queenv = 1
var queenr = 1
var bishopa = 1
var bishopd = 1
var bishopv = 1
var bishopr = 1
var knighta = 1
var knightd = 1
var knightv = 1
var knightr = 1
var rooka = 1
var rookd = 1
var rookv = 1
var rookr = 1
var pawna = 1
var pawnd = 1
var pawnv = 1
var pawnr = 1
var war_level
var l1_battlechancediv

func call_config ():
	print("IN function call_config in Pieces.gd")
	var config = ConfigFile.new()
	
	var err = config.load("res://config.cfg")

	if err != OK:
		config.set_value('options', 'kinga', 99999)
		config.set_value('options', 'kingd', 95)
		config.set_value('options', 'kingv', 500)
		config.set_value('options', 'kingr', 1)
		config.set_value('options', 'queena', 80)
		config.set_value('options', 'queend', 45)
		config.set_value('options', 'queenv', 9)
		config.set_value('options', 'queenr', .15)
		config.set_value('options', 'bishopa', 50)
		config.set_value('options', 'bishopd', 15)
		config.set_value('options', 'bishopv', 3)
		config.set_value('options', 'bishopr', .1)
		config.set_value('options', 'knighta', 50)
		config.set_value('options', 'knightd', 15)
		config.set_value('options', 'knightv', 3)
		config.set_value('options', 'knightr', .1)
		config.set_value('options', 'rooka', 60)
		config.set_value('options', 'rookd', 25)
		config.set_value('options', 'rookv', 5)
		config.set_value('options', 'rookr', .1)
		config.set_value('options', 'pawna', 45)
		config.set_value('options', 'pawnd', 7)
		config.set_value('options', 'pawnv', 1)
		config.set_value('options', 'pawnr', .15)
		config.set_value('options', 'war_level', "Level1") 
		config.set_value('options', 'l1_battlechancediv', .75)

		
	return config


# Return a chess piece object defaulting to a White Pawn
func get_piece(key = "P", side = "W"):
	var i = keys.find(key)
	if side == "W":
		i += 6
	var p = get_child(i).duplicate()
	p.position = Vector2(0, 0)
	return p


func promote(p: Piece, promote_to = "q"):
	p.key = promote_to.to_upper()
	var parent = p.obj.get_parent()
	p.obj.queue_free() # Delete pawn
	# Now add the new piece in place of the pawn
	p.obj = get_piece(p.key, p.side)
	parent.add_child(p.obj)


# Edit this to start in the game or as a Tool script when the scene is loaded
func _ready():
	rng.randomize()
#	setup()
	visible = false # It is set up as an Autoloaded scene so want to hide it


# This function is used in Tool script mode to set up the 12 Grid child nodes
# It's useful when you change the child node type or the images to save time
func setup():
	# First create a sorted list of the chess piece images
	var dir = Directory.new()
	if dir.open("res://pieces") == OK:
		var files = []
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.get_extension() == "png":
				files.append(file_name)
			file_name = dir.get_next()
		files.sort()
		print(files)
		# Now apply the images to the sprite textures
		var i = 0
		for file in files:
			var sprite = get_child(i)
			sprite.name = file.get_basename()
			var img = load("res://pieces/" + file)
			sprite.texture = img
			sprite.position.x = i *64
			i += 1

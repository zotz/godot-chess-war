extends PopupPanel

# do we need a signal for this?
#signal config_done


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

var kinga
var kingd
var kingv
var kingr
var queena
var queend
var queenv
var queenr
var bishopa
var bishopd
var bishopv
var bishopr
var knighta
var knightd
var knightv
var knightr
var rooka
var rookd
var rookv
var rookr
var pawna
var pawnd
var pawnv
var pawnr
var war_level
var l1_battlechancediv

onready var config = get_node('/root/Pieces').call_config()


# Called when the node enters the scene tree for the first time.
func _ready():
	print("Should be in CreatePop popup panel.")

	print("config is: ", config)
	config.save("res://config.cfg")
	kinga = config.get_value('options', 'kinga')
	kingd = config.get_value('options', 'kingd')
	kingv = config.get_value('options', 'kingv')
	kingr = config.get_value('options', 'kingr')
	queena = config.get_value('options', 'queena')
	queend = config.get_value('options', 'queend')
	queenv = config.get_value('options', 'queenv')
	queenr = config.get_value('options', 'queenr')
	bishopa = config.get_value('options', 'bishopa')
	bishopd = config.get_value('options', 'bishopd')
	bishopv = config.get_value('options', 'bishopv')
	bishopr = config.get_value('options', 'bishopr')
	knighta = config.get_value('options', 'knighta')
	knightd = config.get_value('options', 'knightd')
	knightv = config.get_value('options', 'knightv')
	knightr = config.get_value('options', 'knightr')
	rooka = config.get_value('options', 'rooka')
	rookd = config.get_value('options', 'rookd')
	rookv = config.get_value('options', 'rookv')
	rookr = config.get_value('options', 'rookr')
	pawna = config.get_value('options', 'pawna')
	pawnd = config.get_value('options', 'pawnd')
	pawnv = config.get_value('options', 'pawnv')
	pawnr = config.get_value('options', 'pawnr')
	war_level = config.get_value('options', 'war_level')
	l1_battlechancediv = config.get_value('options', 'l1_battlechancediv')
	print("kinga is now: ",kinga)
	print("Do we have kingd here in ConfigPop?",kingd)
	print("warlevel is now: ", war_level)
	print("l1_battlechancediv is now: ", l1_battlechancediv)


	#var war_level = config.get_value('options', 'war_level')

	# this bit below puts the selection in the graphics to match the config value
	for checkbox in get_tree().get_nodes_in_group('war_levels'):
		if checkbox.name == war_level:
			checkbox.pressed = true
			break

	# this bit below puts the number in the graphics to match the config value for level1
	$Config/VBC_L1/HBC_battlechance/sb_battlechancediv.value = l1_battlechancediv


	# this bit below puts the numbers in the graphics to match the config values for the pieces in level2
	$Config/HBoxContainer/vbc_king/kinga/sb_kinga.value = kinga
	$Config/HBoxContainer/vbc_king/kingd/sb_kingd.value = kingd
	$Config/HBoxContainer/vbc_king/kingr/sb_kingr.value = kingr
	$Config/HBoxContainer/vbc_king/kingv/sb_kingv.value = kingv
	$Config/HBoxContainer/vbc_queen/queena/sb_queena.value = queena
	$Config/HBoxContainer/vbc_queen/queend/sb_queend.value = queend
	$Config/HBoxContainer/vbc_queen/queenr/sb_queenr.value = queenr
	$Config/HBoxContainer/vbc_queen/queenv/sb_queenv.value = queenv
	$Config/HBoxContainer/vbc_bishop/bishopa/sb_bishopa.value = bishopa
	$Config/HBoxContainer/vbc_bishop/bishopd/sb_bishopd.value = bishopd
	$Config/HBoxContainer/vbc_bishop/bishopr/sb_bishopr.value = bishopr
	$Config/HBoxContainer/vbc_bishop/bishopv/sb_bishopv.value = bishopv
	$Config/HBoxContainer/vbc_knight/knighta/sb_knighta.value = knighta
	$Config/HBoxContainer/vbc_knight/knightd/sb_knightd.value = knightd
	$Config/HBoxContainer/vbc_knight/knightr/sb_knightr.value = knightr
	$Config/HBoxContainer/vbc_knight/knightv/sb_knightv.value = knightv
	$Config/HBoxContainer/vbc_rook/rooka/sb_rooka.value = rooka
	$Config/HBoxContainer/vbc_rook/rookd/sb_rookd.value = rookd
	$Config/HBoxContainer/vbc_rook/rookr/sb_rookr.value = rookr
	$Config/HBoxContainer/vbc_rook/rookv/sb_rookv.value = rookv
	$Config/HBoxContainer/vbc_pawn/pawna/sb_pawna.value = pawna
	$Config/HBoxContainer/vbc_pawn/pawnd/sb_pawnd.value = pawnd
	$Config/HBoxContainer/vbc_pawn/pawnr/sb_pawnr.value = pawnr
	$Config/HBoxContainer/vbc_pawn/pawnv/sb_pawnv.value = pawnv



# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

#trying to learn some tings below
func return_boo ():
	var boo = "Boo!"
	return boo


func _on_BackPanel_pressed():
	print("ConfigPop BackPanel pressed - do ya do!")

	#$Menu/VBoxContainer/Local.grab_focus()
	#$Menu.visible = true
	#$ColorRect/BackPanel.visible = false
	#$Options.visible = false


	for checkbox in get_tree().get_nodes_in_group('war_levels'):
		if checkbox.pressed:
			config.set_value('options', 'war_level', checkbox.name)
			break

	#l1_battlechancediv = $Options/VBC_L1/HBC_battlechance/sb_battlechancediv.value
	l1_battlechancediv = $Config/VBC_L1/HBC_battlechance/sb_battlechancediv.value
	config.set_value('options', 'l1_battlechancediv', l1_battlechancediv)
	
	# put the level 2 stuff here
	kinga = $Config/HBoxContainer/vbc_king/kinga/sb_kinga.value
	kingd = $Config/HBoxContainer/vbc_king/kingd/sb_kingd.value
	kingr = $Config/HBoxContainer/vbc_king/kingr/sb_kingr.value
	kingv = $Config/HBoxContainer/vbc_king/kingv/sb_kingv.value
	config.set_value('options', 'kinga', kinga)
	config.set_value('options', 'kingd', kingd)
	config.set_value('options', 'kingr', kingr)
	config.set_value('options', 'kingv', kingv)
	queena = $Config/HBoxContainer/vbc_queen/queena/sb_queena.value
	queend = $Config/HBoxContainer/vbc_queen/queend/sb_queend.value
	queenr = $Config/HBoxContainer/vbc_queen/queenr/sb_queenr.value
	queenv = $Config/HBoxContainer/vbc_queen/queenv/sb_queenv.value
	config.set_value('options', 'queena', queena)
	config.set_value('options', 'queend', queend)
	config.set_value('options', 'queenr', queenr)
	config.set_value('options', 'queenv', queenv)
	bishopa = $Config/HBoxContainer/vbc_bishop/bishopa/sb_bishopa.value
	bishopd = $Config/HBoxContainer/vbc_bishop/bishopd/sb_bishopd.value
	bishopr = $Config/HBoxContainer/vbc_bishop/bishopr/sb_bishopr.value
	bishopv = $Config/HBoxContainer/vbc_bishop/bishopv/sb_bishopv.value
	config.set_value('options', 'bishopa', bishopa)
	config.set_value('options', 'bishopd', bishopd)
	config.set_value('options', 'bishopr', bishopr)
	config.set_value('options', 'bishopv', bishopv)
	knighta = $Config/HBoxContainer/vbc_knight/knighta/sb_knighta.value
	knightd = $Config/HBoxContainer/vbc_knight/knightd/sb_knightd.value
	knightr = $Config/HBoxContainer/vbc_knight/knightr/sb_knightr.value
	knightv = $Config/HBoxContainer/vbc_knight/knightv/sb_knightv.value
	config.set_value('options', 'knighta', knighta)
	config.set_value('options', 'knightd', knightd)
	config.set_value('options', 'knightr', knightr)
	config.set_value('options', 'knightv', knightv)
	rooka = $Config/HBoxContainer/vbc_rook/rooka/sb_rooka.value
	rookd = $Config/HBoxContainer/vbc_rook/rookd/sb_rookd.value
	rookr = $Config/HBoxContainer/vbc_rook/rookr/sb_rookr.value
	rookv = $Config/HBoxContainer/vbc_rook/rookv/sb_rookv.value
	config.set_value('options', 'rooka', rooka)
	config.set_value('options', 'rookd', rookd)
	config.set_value('options', 'rookr', rookr)
	config.set_value('options', 'rookv', rookv)
	pawna = $Config/HBoxContainer/vbc_pawn/pawna/sb_pawna.value
	pawnd = $Config/HBoxContainer/vbc_pawn/pawnd/sb_pawnd.value
	pawnr = $Config/HBoxContainer/vbc_pawn/pawnr/sb_pawnr.value
	pawnv = $Config/HBoxContainer/vbc_pawn/pawnv/sb_pawnv.value
	config.set_value('options', 'pawna', pawna)
	config.set_value('options', 'pawnd', pawnd)
	config.set_value('options', 'pawnr', pawnr)
	config.set_value('options', 'pawnv', pawnv)

	
	config.save("res://config.cfg")
	
	hide()
	

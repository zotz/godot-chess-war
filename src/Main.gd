extends Control

# drew's additions
var game_debug = false

# end drew's additions


onready var engine = $Engine
onready var fd = $c/FileDialog
onready var promote = $c/Promote
onready var configp = $c/ConfigPop
onready var board = $VBox/Board
onready var config = get_node('/root/Pieces').call_config()
onready var rng = get_node('/root/Pieces').get_rng()

var pid = 0
var moves : PoolStringArray = []
var long_moves : PoolStringArray = []
var selected_piece : Piece
var fen = ""
var show_suggested_move = true
var white_next = true
var pgn_moves = []
var move_index = 0
var promote_to = ""
var state = IDLE

# drew's additions
var whitescore = '0'
var blackscore = '0'
var attackwins = '0'
var defendwins = "0"
var whitewins = "0"
var blackwins = "0"
var warresult = "AttackWins"
var warresultl2 = "AttackWins"
var battlechance
var attack1
var attack1type
var defend1
var defend1type
var luck
var battlecount = 0
var war_level

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
var l1_battlechancediv

# I can't seem to get the below color defs to be able to be passed in as bbcode colors
#var bratkcol = Color("#00ffff")
#var brdefcol = Color("#ffa500")

# end drew's additions


# states
enum { IDLE, CONNECTING, STARTING, PLAYER_TURN, ENGINE_TURN, PLAYER_WIN, ENGINE_WIN }
# events
enum { CONNECT, NEW_GAME, DONE, ERROR, MOVE }

func _ready():
	if game_debug: print("configp is now: ", configp)
	rng.randomize()
	if game_debug: print(randi())
	board.connect("clicked", self, "piece_clicked")
	board.connect("right_clicked", self, "piece_right_clicked")
	board.connect("unclicked", self, "piece_unclicked")
	board.connect("moved", self, "mouse_moved")
	board.get_node("Grid").connect("mouse_exited", self, "mouse_entered")
	board.connect("taken", self, "stow_taken_piece")
	promote.connect("promotion_picked", self, "promote_pawn")
	show_transport_buttons(false)
	show_last_move()
	ponder() # Hide it
	if game_debug: print("config is: ",config)
	config.save("res://config.cfg")
	war_level = config.get_value('options', 'war_level')
	if game_debug: print("war_level is currently: ", war_level )
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
	l1_battlechancediv = config.get_value('options', 'l1_battlechancediv')
	if game_debug: print("kinga is now: ",kinga)

func do_recuperate():
	# this is where we go through each piece and regain some health each round
	#print("In do_recuperate...")
	var gi = 0 # Grid index
	for y in 8:
		for x in 8:
			var piece = board.grid[gi]
			gi += 1
			if piece == null:
				# no piece here, no recupe done
				#print("No recupe needed.")
				pass
			else:
				#print("recupe this piece", piece.color," ",piece.type," ",piece.value," ",piece.current_attack," ",piece.max_attack)
				if piece.current_attack < piece.max_attack:
					if game_debug: print("Piece is recovering attack strength!")
					piece.current_attack = piece.current_attack + (piece.current_attack * piece.recuperate)
					if piece.current_attack > piece.max_attack:
						piece.current_attack = piece.max_attack
				if piece.current_defend < piece.max_defend:
					if game_debug: print("Piece is recovering defend strength!")
					piece.current_defend = piece.current_defend + (piece.current_defend * piece.recuperate)
					if piece.current_defend > piece.max_defend:
						piece.current_defend = piece.max_defend
				if game_debug: print("After recuperate:  ", piece.current_attack, " | ", piece.current_defend)

func handle_state(event, msg = ""):
	match state:
		IDLE:
			match event:
				CONNECT:
					var status = engine.start_udp_server()
					if status.started:
						# Need some delay before connecting is possible
						yield(get_tree().create_timer(0.5), "timeout")
						engine.send_packet("uci")
						state = CONNECTING
					else:
						alert(status.error)
				NEW_GAME:
					# Keep piece arrangement and move counts.
					if engine.server_pid > 0:
						engine.send_packet("ucinewgame")
						engine.send_packet("isready")
						state = STARTING
					else:
						handle_state(CONNECT)
		CONNECTING:
			match event:
				DONE:
					if msg == "uciok":
						state = IDLE
						handle_state(NEW_GAME)
				ERROR:
					alert("Unable to connect to Chess Engine!")
					state = IDLE
		STARTING:
			match event:
				DONE:
					if msg == "readyok":
						if white_next:
							alert("White to begin")
							state = PLAYER_TURN
						else:
							alert("Engine to begin")
							prompt_engine()
				ERROR:
					alert("Lost connection to Chess Engine!")
					state = IDLE
		PLAYER_TURN:
			match event:
				DONE:
					print(msg)
				MOVE:
					ponder()
					# msg should contain the player move
					show_last_move(msg)
					prompt_engine(msg)
		ENGINE_TURN:
			match event:
				DONE:
					var move = get_best_move(msg)
					if move != "":
						move_engine_piece(move)
						show_last_move(move)
						state = PLAYER_TURN
					# Don't print the info spam
					if !msg.begins_with("info"):
						print(msg)
		PLAYER_WIN:
			match event:
				DONE:
					print("Player won")
					state = IDLE
					set_next_color()
		ENGINE_WIN:
			match event:
				DONE:
					print("Engine won")
					state = IDLE
					set_next_color()


func prompt_engine(move = ""):
	fen = board.get_fen("b")
	engine.send_packet("position fen %s moves %s" % [fen, move])
	engine.send_packet("go movetime 1000")
	state = ENGINE_TURN


func stow_taken_piece(p: Piece):
	var tex = TextureRect.new()
	tex.texture = p.obj.texture
	if p.side == "B":
		$VBox/BlackPieces.add_child(tex)
	else:
		$VBox/WhitePieces.add_child(tex)
	p.queue_free()


func show_last_move(move = ""):
	$VBox/HBox/Grid/LastMove.text = move


func get_best_move(s: String):
	var move = ""
	# Make sure that whitespace contains spaces
	# since it may only have tabs for example
	var raw_tokens = s.replace("\t", " ").split(" ")
	var tokens = []
	for t in raw_tokens:
		var tt = t.strip_edges()
		if tt != "":
			tokens.append(tt)
	if tokens.size() > 1:
		if tokens[0] == "bestmove": # This is the engine's move
			move = tokens[1]
	if tokens.size() > 3:
		if tokens[2] == "ponder":
			# This is the move suggested to the player by the engine following
			# it's best move (so like the engine playing against itself)
			ponder(tokens[3])
	return move


# The engine sends a suggested next move for the player tagged with "ponder"
# So we display this move to the player in the UI or hide the UI elements
func ponder(move = ""):
	if move == "":
		$VBox/HBox/VBox/Ponder.modulate.a = 0
	elif show_suggested_move:
		$VBox/HBox/VBox/Ponder.modulate.a = 1.0
		$VBox/HBox/VBox/Ponder/Move.text = move


func move_engine_piece(move: String):
	var pos1 = board.move_to_position(move.substr(0, 2))
	var p: Piece = board.get_piece_in_grid(pos1.x, pos1.y)
	p.new_pos = board.move_to_position(move.substr(2, 2))
	if move[move.length() - 1] in "rnbq":
		promote_to = move[move.length() - 1]
	try_to_make_a_move(p)


func alert(txt, duration = 1.0):
	$c/Alert.open(txt, duration)


# This is called after release of the mouse button and when the mouse
# has crossed the Grid border so as to release any selected piece
func mouse_entered():
	return_piece(selected_piece)


func piece_clicked(piece):
	selected_piece = piece
	# Need to ensure that piece displays above all others when moved
	# The z_index gets reset when we settle the piece back into
	# it's resting position
	piece.obj.z_index = 1
	if game_debug: print("Board clicked ", selected_piece)
	print("Board clicked ", selected_piece)


func piece_right_clicked(piece, x, y):
	print("Right clicked at: ", x, " ", y)
	selected_piece = piece
	# Need to ensure that piece displays above all others when moved
	# The z_index gets reset when we settle the piece back into
	# it's resting position
	piece.obj.z_index = 1
	if game_debug: print("Board right clicked ", selected_piece)
	if game_debug: print("Board right clicked ", selected_piece, " ", selected_piece.value, " ", selected_piece.current_attack, " ", selected_piece.current_defend, " ", selected_piece.recuperate)
	var zalerttxt = "Piece " + piece.color + " " + piece.type + " Stats:\nCurrent Attack: " + str(selected_piece.current_attack) +  "\nCurrent Defend:  " +  str(selected_piece.current_defend) + "\nCurrent Recuperate:  " + str(selected_piece.recuperate) + "\nCurrent Value:  " + str(selected_piece.value) + "\n..."
	alert(zalerttxt, 10)
	$c/Alert.rect_position = Vector2(x,y)


func piece_unclicked(piece):
	show_transport_buttons(false)
	try_to_make_a_move(piece, false)

func update_stats_display():
	# white score
	$c/BattleReport/HUD/BTGameStats/VBoxContainer/HBCWhiteScore/WhtScoreNum.text = whitescore
	# black score
	$c/BattleReport/HUD/BTGameStats/VBoxContainer/HBCBlackScore/BlkScoreNum.text = blackscore
	# white wins
	$c/BattleReport/HUD/BTGameStats/VBoxContainer/HBCWhiteWins/WhtWinsNum.text = whitewins
	# black wins
	$c/BattleReport/HUD/BTGameStats/VBoxContainer/HBCBlackWins/BlkWinsNum.text = blackwins
	# attack wins
	$c/BattleReport/HUD/BTGameStats/VBoxContainer/HBCAttackWins/AttackWinsNum.text = attackwins
	# defend wins
	$c/BattleReport/HUD/BTGameStats/VBoxContainer/HBCDefendWins/DefendWinsNum.text = defendwins


func cwl1(apiece, dpiece):
	if game_debug: print("In Chess War L1")
	if game_debug: print("War Level from config is: ", war_level)
	if game_debug: print("cwl1=====The attacker is: ", apiece)
	if game_debug: print("cwl1=====The defender is: ", dpiece)
	if game_debug: print("cwl1=====Attacker: ", apiece)
	if game_debug: print("cwl1=====Defender: ", dpiece)
	battlechance = randf()
	if game_debug: print("cwl1=====Battlechance is: ", battlechance)
	if battlechance <= l1_battlechancediv:
		if game_debug: print("cwl1==========Attack wins with battlechance = ", battlechance)
		# we return the piece to kill
		battlecount = battlecount + 1
		if game_debug: print(battlecount, " battles have now been fought.")
		if game_debug: print("Should end up removing the piece: ", dpiece)
		warresult = "AttackWins"
		return warresult
	else:
		if game_debug: print("cwl1==========Defend wins with battlechance = ", battlechance)
		# we return the piece to kill
		battlecount = battlecount + 1
		if game_debug: print(battlecount, " battles have now been fought.")
		if game_debug: print("Should end up removing the piece: ", apiece)
		warresult = "DefendWins"
		return warresult
		#temp pretend attacker won
		#return dpiece


func cwl2(apiece, dpiece):
	#$c/BattleReport.show()
	$c/BattleReport/HUD.show()
	if game_debug: print("In Chess War L2")
	if game_debug: print("War Level from config is: ", war_level)
	if game_debug: print("cwl2 - apiece on enter is: ", apiece.color, " ", apiece.type)
	if game_debug: print("cwl2 - dpiece on enter is: ", dpiece.color, " ", dpiece.type)
	if game_debug: print("The attacker is a ", apiece.color, " ", apiece.type)
	if game_debug: print("The defender is a ", dpiece.color, " ", dpiece.type)
	$c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text = "[b][u][color=white]In Chess War L2[/color][/u][/b]\n\n"
	# 
	var lp1 = 1
	if game_debug: print("Attacker: ", apiece.color, " ", apiece.type)
	attack1 = apiece.current_attack
	if game_debug: print("Attack1 is: ", attack1)
	attack1type = apiece.type
	if game_debug: print("attack1type is: ", attack1type)
	$c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text = $c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text + "[color=aqua]Attacker " + apiece.color + " " + attack1type + "[/color]\n"
	
	if game_debug: print("Defender: ", dpiece.color, " ", dpiece.type)
	defend1 = dpiece.current_defend
	defend1type = dpiece.type
	if game_debug: print("Attacker, ", apiece.color, " ", apiece.type, " has an attack strength of ", attack1)
	if game_debug: print("Defender, ", dpiece.color, " ", dpiece.type, " has a defend strength of ",defend1)
	$c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text = $c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text + "[color=yellow]Defender: " + dpiece.color + " " + defend1type + "[/color]\n"
	if game_debug: print("cwl2 before while: ", attack1, " | ", defend1)
	var battlerounds = 0
	var totbattlerounds = 0
	var battlereportrounds = 300
	# the while loop below fights a level 2 battle until either
	# the attacker's attack strength goes to 0 or
	# the defenders defend strength goes to 0
	while (attack1 > 0) and (defend1 > 0):
		# trying to run this loop slower
		#if game_debug: print("Trying to yeild for a time...")
		yield(get_tree().create_timer(0.7), "timeout") # see if this fixes anything
		# this is a stupid attempt at a delay loop
		# and it seems to be in the wrong place besides
		# or something is behavin in  way I do not expect.
		# I want to slow down battle updates to the HUD
		#$c/BattleReport/HUD/BattleReport/Label.text = $c/BattleReport/HUD/BattleReport/Label.text + Time.get_time_string_from_system() +"==Before delay loop.==\n"
		#for zn in 10000:
		#	var zo
		#	zo = 0
		#	zo = zo + 1
		#$c/BattleReport/HUD/BattleReport/Label.text = $c/BattleReport/HUD/BattleReport/Label.text + "=====After delay loop.==\n"
		if game_debug: print("A1 - Attack = ", attack1, "            |            Defend = ", defend1,"")
		luck = rng.randi_range(0,8)
		if luck == 0:
			if game_debug: print("The attacking ", apiece.color, " ", apiece.type, " lands a mighty blow!")
			#$c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text = $c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text + "[color=aqua]The attacking " + apiece.color + " " + attack1type + " lands a mighty blow![/color] [right][color=aqua]"+str(attack1)+"[/color]|[color=yellow]"+str(defend1)+"  [/color][/right]\n"
			$c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text = $c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text + "[color=aqua]The attacking " + apiece.color + " " + attack1type + " lands a mighty blow![/color]\n"
			defend1 = int((defend1 * 5) / 6 )
			if game_debug: print("defend1 is now: ", defend1)
		if luck == 1:
			if game_debug: print("D1 - The defending ", dpiece.color, " ", dpiece.type, " gets in a gallant thrust!")
			#$c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text = $c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text + "[color=yellow]The defending " + dpiece.color + " " + defend1type + " gets in a gallant thrust![/color] [right][color=aqua]"+str(attack1)+"[/color]|[color=yellow]"+str(defend1)+"  [/color][/right]\n"
			$c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text = $c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text + "[color=yellow]The defending " + dpiece.color + " " + defend1type + " gets in a gallant thrust![/color]\n"
			if lp1 == 1:
				attack1 = int(attack1 / 2)
				if game_debug: print("It does great damage to the attacker!")
				#$c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text = $c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text + "[color=yellow]It does great damage to the attacker![/color] [right][color=aqua]"+str(attack1)+"[/color]|[color=yellow]"+str(defend1)+"  [/color][/right]\n"
				$c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text = $c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text + "[color=yellow]It does great damage to the attacker![/color]\n"
				lp1 = 2
				if game_debug: print("attack1 is now: ", attack1)
			else:
				attack1 = int((attack1 * 5) /6)
				if game_debug: print("attack1 is now: ", attack1)
		if luck == 2:
			if game_debug: print("The valiant attacker draws blood.")
			#$c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text = $c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text + "[color=aqua]The valiant attacking " + apiece.color + " " + apiece.type + " draws blood.[/color] [right][color=aqua]"+str(attack1)+"[/color]|[color=yellow]"+str(defend1)+"  [/color][/right]\n"
			$c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text = $c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text + "[color=aqua]The valiant attacking " + apiece.color + " " + apiece.type + " draws blood.[/color]\n"
			defend1 = int((defend1 * 4) / 5 )
			if game_debug: print("defend1 is now: ", defend1)
		if luck == 3:
			if game_debug: print("The " + dpiece.color + " " + defend1type, " puts up a strong defence and wounds the " + apiece.color + " " + attack1type + "!!")
			#$c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text = $c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text + "[color=yellow]The " + dpiece.color + " " + defend1type + " puts up a strong defence and wounds the " + apiece.color + " " + attack1type + "!![/color] [right][color=aqua]"+str(attack1)+"[/color]|[color=yellow]"+str(defend1)+"  [/color][/right]\n"
			$c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text = $c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text + "[color=yellow]The " + dpiece.color + " " + defend1type + " puts up a strong defence and wounds the " + apiece.color + " " + attack1type + "!![/color]\n"
			attack1 = int((attack1 * 4) / 5)
			if game_debug: print("attack1 is now: ", attack1)
		if luck == 4:
			if game_debug: print("With a mighty cut, the ", attack1type, " wounds the ", defend1type, ".")
			#$c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text = $c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text + "[color=aqua]With a mighty cut, the " + apiece.color + " " + attack1type + " wounds the " + dpiece.color + " " + defend1type + ".[/color] [right][color=aqua]"+str(attack1)+"[/color]|[color=yellow]"+str(defend1)+"  [/color][/right]\n"
			$c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text = $c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text + "[color=aqua]With a mighty cut, the " + apiece.color + " " + attack1type + " wounds the " + dpiece.color + " " + defend1type + ".[/color]\n"
			# text
			# HUD/BattleReport/OldLabel
			# HUD/BattleReport/BRLabel
			defend1 = int((defend1 * 9) / 10)
			if game_debug: print("defend1 is now: ", defend1)
		if luck == 5:
			if game_debug: print("The defender lands  a crushing blow!")
			#$c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text = $c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text + "[color=yellow]The defending " + dpiece.color + " " + defend1type + " lands  a crushing blow![/color] [right][color=aqua]"+str(attack1)+"[/color]|[color=yellow]"+str(defend1)+"  [/color][/right]\n"
			$c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text = $c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text + "[color=yellow]The defending " + dpiece.color + " " + defend1type + " lands  a crushing blow![/color]\n"
			attack1 = int((attack1 * 9) /10)
			if game_debug: print("attack1 is now: ", attack1)
		if luck == 6:
			if game_debug: print("OH! Surely the ", defend1type, " cannot long endure such a furious attack.")
			#$c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text = $c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text + "[color=aqua]OH! Surely the " + dpiece.color + " " + defend1type + " cannot long endure such a furious attack.[/color] [right][color=aqua]"+str(attack1)+"[/color]|[color=yellow]"+str(defend1)+"  [/color][/right]\n"
			$c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text = $c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text + "[color=aqua]OH! Surely the " + dpiece.color + " " + defend1type + " cannot long endure such a furious attack.[/color]\n"
			defend1 = int((defend1 * 14) / 15)
			if game_debug: print("defend1 is now: ", defend1)
		if luck == 7:
			if game_debug: print("The ", attack1type, "'s attack falters and the ", defend1type, " gets in a blow in return.")
			#$c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text = $c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text + "[color=yellow]The " + apiece.color + " " + attack1type + "'s attack falters and the " + dpiece.color + " " + defend1type + " gets in a blow in return.[/color] [right][color=aqua]"+str(attack1)+"[/color]|[color=yellow]"+str(defend1)+"  [/color][/right]\n"
			$c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text = $c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text + "[color=yellow]The " + apiece.color + " " + attack1type + "'s attack falters and the " + dpiece.color + " " + defend1type + " gets in a blow in return.[/color]\n"
			attack1 = int((attack1 * 14) / 15)
			if game_debug: print("attack1 is now: ", attack1)
		if luck == 8 and battlerounds > 3:
			if game_debug: print("The combatants take a much needed rest.")
			$c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text = $c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text + "[color=white]The combatants take a much needed rest.[/color] [right][color=aqua]"+str(attack1)+"[/color]|[color=yellow]"+str(defend1)+"  [/color][/right]\n"
		battlerounds = battlerounds + 1
		totbattlerounds = totbattlerounds + 1
		if game_debug: print("battlerounds is now: ", battlerounds)
		if battlerounds == battlereportrounds:
			battlerounds = 0
			$c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text = "The battle continues.\n"
	if game_debug: print("A2 - Attack = ", attack1, "            |            Defend = ", defend1,"")
	$c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text = $c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text + "[color=aqua]Attack = " + str(attack1) + "            [/color]|            [color=yellow]Defend = " + str(defend1) + "[/color]\n"
	if game_debug: print("before defend1 == 0 check, defend1 is now: ", defend1, " attack1 is now: ",attack1)
	if (defend1 == 0):
		# ATTACK WINS
		# GOT TO fix the score and wins logic
		attackwins = str(int(attackwins) + 1)
		#$c/BattleReport/HUD/BTGameStats/VBoxContainer/HBCAttackWins/AttackWinsNum.text = attackwins
		if game_debug: print("Below should be true")
		if game_debug: print(defend1==0)
		if game_debug: print("was above true?")
		if game_debug: print("defend1 == 0? A3 - Attack = ", attack1, "            |            Defend = ", defend1,"")
		if game_debug: print("defend1 is: ", defend1)
		if game_debug: print("The attacking ", attack1type, " defeated the defending ", defend1type, "!")
		$c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text = $c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text + "[color=white]The attacking " + apiece.color + " " + attack1type + " defeated the defending " + dpiece.color + " " + defend1type + "![/color]\n"
		if attack1 == 0:
			attack1 = 1
			if game_debug: print("defend1 was 0 and attack1 was 0 so we made attack1 equal 1")
		apiece.current_attack = attack1
		if game_debug: print("apiece.color is now: ", apiece.color)
		if apiece.color == 'white':
			if game_debug: print("Piece is: ", apiece.color, " ", apiece.type, " piece value is: ", dpiece.value)
			whitescore = str(int(whitescore) + dpiece.value)
			if game_debug: print("Whitescore is now: ", whitescore)
			whitewins = str(int(whitewins) + 1)
		else:
			blackscore = str(int(blackscore) + dpiece.value)
			blackwins = str(int(blackwins) + 1)
			if game_debug: print("whitewins is: ", blackwins)
		warresult = "AttackWins"
		return warresult
	else:
		#DEFEND WINS
		defendwins = str(int(defendwins) + 1)
		if game_debug: print("defend1 != 0? A4 - Attack = ", attack1, "            |            Defend = ", defend1,"")
		if game_debug: print("D2 - The defending ", defend1type,  " defeated the attacking ", attack1type, " !")
		$c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text = $c/BattleReport/HUD/BattleReport/BRLabel.bbcode_text + "[color=white]The defending " + dpiece.color + " " + defend1type +  " defeated the attacking " + apiece.color + " " + attack1type + " ![/color]\n"
		if apiece.color == 'white':
			blackscore = str(int(blackscore) + apiece.value)
			if game_debug: print("blackwins is: ", blackwins)
			blackwins = str(int(blackwins) + 1)
			if game_debug: print("blackwins is: ", blackwins)
			
		else:
			whitescore = str(int(whitescore) + apiece.value)
		warresult = "DefendWins"
		#update_stats_display()
		return warresult


func try_to_make_a_move(piece: Piece, non_player_move = true):
	var info = board.get_position_info(piece, non_player_move)
	do_recuperate()
	#print("info concerns board position_info: ", info)
	# When Idle, we are not playing a game so the user may move the black pieces
	if game_debug: print(info.ok)
	# Try to drop the piece
	# Also check for castling and passant
	var ok_to_move = false
	var rook = null
	if info.ok:
		if info.piece != null:
			ok_to_move = true
		else:
			if info.passant and board.passant_pawn.pos.x == piece.new_pos.x:
				if game_debug: print("passant")
				board.take_piece(board.passant_pawn)
				ok_to_move = true
			else:
				ok_to_move = piece.key != "P" or piece.pos.x == piece.new_pos.x
			if info.castling:
				# Get rook
				var rx
				if piece.new_pos.x == 2:
					rx = 3
					rook = board.get_piece_in_grid(0, piece.new_pos.y)
				else:
					rook = board.get_piece_in_grid(7, piece.new_pos.y)
					rx = 5
				if rook != null and rook.key == "R" and rook.tagged and rook.side == piece.side:
					ok_to_move = !board.is_checked(rx, rook.pos.y, rook.side)
					if ok_to_move:
						# Move rook
						rook.new_pos = Vector2(rx, rook.pos.y)
					else:
						alert("Check")
				else:
					ok_to_move = false
	if info.piece != null:
		ok_to_move = ok_to_move and info.piece.key != "K"
	if ok_to_move:
		if piece.key == "K":
			if board.is_king_checked(piece).checked:
				alert("Cannot move into check position!")
			else:
				if rook != null:
					move_piece(rook, false)
				board.take_piece(info.piece)
				move_piece(piece)
		else:
			var dpiece = info.piece
			var active_piece = piece
			var apiece = active_piece
			if info.piece ==null:
				if game_debug: print("==========There is no piece at the end of this move. ", info.piece, dpiece )
				board.take_piece(info.piece) # this may never be called
				move_piece(piece)
			else:
				if game_debug: print("==========There is a piece at the end of this move: ",apiece, " attacks ", dpiece)
				print("==========There is a piece at the end of this move: ",apiece, " attacks ", dpiece)
				if war_level == "Level0":
					# Level0 is plain old chess, the attacker always wins
					if game_debug: print("\n\n-----In War Level: ", war_level)
					warresult = "AttackWins"
				elif war_level == "Level1":
					if game_debug: print("\n\n-----In War Level: ", war_level)
					warresult = cwl1(active_piece, dpiece)
				elif war_level == "Level2":
					if game_debug: print("\n\n-----In War Level: ", war_level)
					attack1 = apiece.current_attack
					# do we need to use attack1type?
					attack1type = apiece.type
					warresultl2 = yield(cwl2(active_piece, dpiece), "completed")
					warresult = warresultl2
				else:
					# should neve get here but just in case and
					# to make adding new levels easier
					# If we got here, something went wrong, pretend.
					warresult = "AttackWins"

				if game_debug: print("warresult is now: ", warresult)
				print("warresult is now: ", warresult)
				# moved the HUD stats update to a single function
				# the numerical stats still need to get updated where they occur. (I think)
				update_stats_display()
				if warresult == "AttackWins":
					if game_debug: print("********** warresult == AttackWins **********")
					if game_debug: print("We should be safe to do nothing piece wise from here")
				else:
					if game_debug: print("---------- warresult == DefendWins ----------")
					if game_debug: print("swap  pieces around and proceed?: ")
					if game_debug: print("Before piece swap piece, info.piece:", piece, info.piece)
					var dwpiece = info.piece
					info.piece = piece
					piece = dwpiece
					#set_next_color()
					if game_debug: print("After piece swap piece, info.piece:", piece, info.piece)



			board.take_piece(info.piece)
			move_piece(piece)


			var status = board.is_king_checked(piece)
			if status.mated:
				alert("Check Mate!")
				if status.side == "B":
					state = PLAYER_WIN
				else:
					state = ENGINE_WIN
				handle_state(DONE)
			else:
				if status.checked:
					alert("Check")
	# Settle the piece precisely into position and reset it's z_order
	return_piece(piece)


func move_piece(piece: Piece, not_castling = true):
	# I need to do something different here when warresult DefendWins? Or do I do an extra set_next_color
	# in the other if (near) where the swap occurs?
	if warresult == "AttackWins":
		set_next_color(piece.side == "B")
	else:
		set_next_color(piece.side == "W")
	var pos = [piece.pos, piece.new_pos]
	board.move_piece(piece, state == ENGINE_TURN)
	if state == PLAYER_TURN:
		moves.append(board.position_to_move(pos[0]) + board.position_to_move(pos[1]))
		if not_castling:
			# When castling there may be 2 moves to convey rook <> king
			handle_state(MOVE, moves.join(" ")) 
			moves = []


func mouse_moved(pos):
	if selected_piece != null:
		selected_piece.obj.position = pos - Vector2(board.square_width, board.square_width) / 2.0


# Return the piece to it's base position after being moved via mouse
# Reset it's z_order and test for the situation of a pawn promotion
func return_piece(piece: Piece):
	if piece != null:
		piece.obj.position = Vector2(0, 0)
		piece.obj.z_index = 0
		selected_piece = null
		if piece.key == "P":
			if piece.side == "B" and piece.pos.y == 7 or piece.side == "W" and piece.pos.y == 0:
				if promote_to == "":
					# Prompt player
					promote.open(piece)
				else:
					Pieces.promote(piece, promote_to)
			promote_to = ""


func promote_pawn(p: Piece, pick: String):
	Pieces.promote(p, pick)


func _on_Start_button_down():
	state = IDLE
	handle_state(NEW_GAME)

func _on_Config_button_down():
	if game_debug: print("Do config stuff")
	$c/ConfigPop.show()


func _on_Engine_done(ok, packet):
	if ok:
		handle_state(DONE, packet)
	else:
		handle_state(ERROR)


func _on_CheckBox_toggled(button_pressed):
	show_suggested_move = button_pressed


func _on_Board_fullmove(n):
	$VBox/HBox/Grid/Moves.text = String(n)


func _on_Board_halfmove(n):
	$VBox/HBox/Grid/HalfMoves.text = String(n)
	if n == 50:
		alert("It's a draw!")
		state = IDLE


func reset_stats():
	# this is a function added by dR for chesswar
	whitescore = "0"
	blackscore = "0"
	whitewins = "0"
	blackwins = "0"
	attackwins = "0"
	defendwins = "0"


func reset_board():
	# I need to figure how to reset all game stats when board is reset
	# also need to reset pieces to beginning values
	if !board.cleared:
		state = IDLE
		board.clear_board()
		board.setup_pieces()
		board.halfmoves = 0
		board.fullmoves = 0
		show_last_move()
		ponder()
		set_next_color()
		state = IDLE
		board.clear_board()
		board.setup_pieces()
		for node in $VBox/WhitePieces.get_children():
			node.queue_free()
		for node in $VBox/BlackPieces.get_children():
			node.queue_free()
	move_index = 0
	update_count(move_index)
	set_next_color()
	reset_stats()


func _on_Reset_button_down():
	reset_board()


func _on_Flip_button_down():
	set_next_color(!white_next)


func set_next_color(is_white = true):
	white_next = is_white
	$VBox/HBox/Menu/Next/Color.color = Color.white if white_next else Color.black


func _on_Load_button_down():
	fd.mode = FileDialog.MODE_OPEN_FILE
	fd.popup_centered()


func _on_Save_button_down():
	fd.mode = FileDialog.MODE_SAVE_FILE
	fd.popup_centered()


func _on_FileDialog_file_selected(path: String):
	if fd.mode == FileDialog.MODE_OPEN_FILE:
		var file = File.new()
		file.open(path, File.READ)
		var content = file.get_as_text()
		file.close()
		if path.get_extension().to_lower() == "pgn":
			set_pgn_moves(pgn_from_file(content))
		else:
			fen_from_file(content)
	else:
		save_file(board.get_fen("w" if white_next else "b"), path)


# Extract the moves from the first game in a Portable Game Notation (PGN) text
func pgn_from_file(content: String) -> String:
	var pgn: PoolStringArray = []
	var lines = content.split("\n")
	var started = false
	for line in lines:
		if !started:
			if line.begins_with("1."):
				started = true
			else:
				continue
		if line.length() == 0:
			break
		else:
			pgn.append(line.strip_edges())
	return pgn.join(" ")


func fen_from_file(content: String):
	var parts = content.split(",")
	# Find the FEN string
	fen = ""
	for s in parts:
		if "/" in s:
			fen = s.replace('"', '')
			break
	# Validate it
	if is_valid_fen(fen):
		board.clear_board()
		set_next_color(board.setup_pieces(fen))
	else:
		alert("Invalid FEN string")


func is_valid_fen(_fen: String):
	var n = 0
	var rows = 1
	for ch in _fen:
		if ch == " ":
			break
		if ch == "/":
			rows += 1
		elif ch.is_valid_integer():
			n += int(ch)
		elif ch in "pPrRnNbBqQkK":
			n += 1
	return n == 64 and rows == 8


func save_file(content, path):
	var file = File.new()
	file.open(path, File.WRITE)
	file.store_string(content)
	file.close()


func set_pgn_moves(_moves):
	_moves = _moves.split(" ")
	_moves.resize(_moves.size() - 1) # Remove the score
	pgn_moves = []
	long_moves = []
	for i in _moves.size():
		if i % 3 > 0:
			pgn_moves.append(_moves[i])
	show_transport_buttons()
	reset_board()


func update_count(n: int):
	$VBox/HBox/Options/TB/Count.text = "%d/%d" % [n, pgn_moves.size()]


func show_transport_buttons(show = true):
	$VBox/HBox/Options/TB.modulate.a = 1.0 if show else 0.0


func _on_Begin_button_down():
	reset_board()


func _on_Forward_button_down():
	step_forward()


func step_forward():
	if move_index >= pgn_moves.size():
		set_next_color()
		return
	if long_moves.size() <= move_index:
		long_moves.append(board.pgn_to_long(pgn_moves[move_index], "W" if move_index % 2 == 0 else "B"))
	move_engine_piece(long_moves[move_index])
	show_last_move(long_moves[move_index])
	move_index += 1
	update_count(move_index)


var stepping = false

func _on_End_button_down():
	stepping = true
	while stepping and pgn_moves.size() > move_index:
		step_forward()


func _on_End_button_up():
	stepping = false

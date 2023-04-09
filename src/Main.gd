extends Control

# drew's additions
var game_debug = true
#rng = $Pieces.get_rng()
#get_rng
# end drew's additions


onready var engine = $Engine
onready var fd = $c/FileDialog
onready var promote = $c/Promote
#onready var configp = $c/ConfigPop
onready var configp = $c/ConfigPop
#print("configp follows")
#print(configp)
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
var incrsc
var warresult = "AttackWins"
var warresultl2 = "AttackWins"
var battlechance
#var l1_battlechancediv = 0.9
var zattackwon = true
var attack1
var attack1type
var defend1
var defend1type
var luck
#var rng = RandomNumberGenerator.new()
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

# end drew's additions


# states
enum { IDLE, CONNECTING, STARTING, PLAYER_TURN, ENGINE_TURN, PLAYER_WIN, ENGINE_WIN }
# events
enum { CONNECT, NEW_GAME, DONE, ERROR, MOVE }

func _ready():
	print("configp is now: ", configp)
	#rng.randomize()
	print(randi())
	board.connect("clicked", self, "piece_clicked")
	board.connect("unclicked", self, "piece_unclicked")
	board.connect("moved", self, "mouse_moved")
	board.get_node("Grid").connect("mouse_exited", self, "mouse_entered")
	board.connect("taken", self, "stow_taken_piece")
	promote.connect("promotion_picked", self, "promote_pawn")
	show_transport_buttons(false)
	show_last_move()
	ponder() # Hide it
	print("config is: ",config)
	config.save("res://config.cfg")
	war_level = config.get_value('options', 'war_level')
	print("war_level is currently: ", war_level )
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
	print("kinga is now: ",kinga)


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
	print("Board clicked ", selected_piece)


func piece_unclicked(piece):
	show_transport_buttons(false)
	try_to_make_a_move(piece, false)


func cwl1(apiece, dpiece):
	if game_debug: print("In Chess War L1")
	if game_debug: print("War Level from config is: ", war_level)
	print("cwl1=====The attacker is: ", apiece)
	#print("The attacker is a ", apiece.color, apiece.type)
	print("cwl1=====The defender is: ", dpiece)
	#print("The defender is a ", dpiece.color, dpiece.type)
	#print("Sending battle report to HUD")
	#l1_battlechancediv = get_node('/root/PlayersData').l1_battlechancediv
	#l1_battlechancediv = config.get_value('options', 'l1_battlechancediv')
	#$HUD/BattleReport/BattleReport.text = "In Chess War L1\n"
	#$HUD/BattleReport.visible = true
	#print("Sent battle report to HUD and set visible")
	if game_debug: print("cwl1=====Attacker: ", apiece)
	#$HUD/BattleReport/BattleReport.text = $HUD/BattleReport/BattleReport.text + "Attacker: " + str(apiece) + "\n"
	if game_debug: print("cwl1=====Defender: ", dpiece)
	#$HUD/BattleReport/BattleReport.text = $HUD/BattleReport/BattleReport.text + "Defender: " + str(dpiece) + "\n"
	battlechance = randf()
	if game_debug: print("cwl1=====Battlechance is: ", battlechance)
	#$HUD/BattleReport/BattleReport.text = $HUD/BattleReport/BattleReport.text + "Battlechance is: "+ str(battlechance) + "\n"
	#$HUD/Announcement.visible = true
	if battlechance <= l1_battlechancediv:
		if game_debug: print("cwl1==========Attack wins with battlechance = ", battlechance)
		#$HUD/BattleReport/BattleReport.text = $HUD/BattleReport/BattleReport.text + "Attack wins with battlechance = " + str(battlechance) + "\n"
		print("01 - zattackwon is: ", zattackwon)
		print("Setting zattackwon to true in Level: ", war_level)
		zattackwon = true
		print("02 - zattackwon is: ", zattackwon)
		# we return the piece to kill
		battlecount = battlecount + 1
		print(battlecount, " battles have now been fought.")
		print("Should end up removing the piece: ", dpiece)
		warresult = "AttackWins"
		return warresult
	else:
		if game_debug: print("cwl1==========Defend wins with battlechance = ", battlechance)
		#$HUD/BattleReport/BattleReport.text = $HUD/BattleReport/BattleReport.text + "Defend wins with battlechance = " + str(battlechance) + "\n"
		print("03 - zattackwon is: ", zattackwon)
		print("Setting zattackwon to false in Level: ", war_level)
		zattackwon = false
		print("04 - zattackwon is: ", zattackwon)
		# we return the piece to kill
		battlecount = battlecount + 1
		print(battlecount, " battles have now been fought.")
		print("Should end up removing the piece: ", apiece)
		warresult = "DefendWins"
		return warresult
		#temp pretend attacker won
		#return dpiece

#func cwl2(apiece, dpiece):
#	if game_debug: print("In Chess War L2")
#	if game_debug: print("War Level from config is: ", war_level)
#	print("The attacker is a ", apiece.color, apiece.type)
#	print("The defender is a ", dpiece.color, dpiece.type)
func cwl2(apiece, dpiece):
	if game_debug: print("In Chess War L2")
	if game_debug: print("War Level from config is: ", war_level)
	if game_debug: print("cwl2 - apiece on enter is: ", apiece.color, " ", apiece.type)
	if game_debug: print("cwl2 - dpiece on enter is: ", dpiece.color, " ", dpiece.type)
	if game_debug: print("The attacker is a ", apiece.color, " ", apiece.type)
	if game_debug: print("The defender is a ", dpiece.color, " ", dpiece.type)
	#$HUD/BattleReport/BattleReport.text = "In Chess War L2\n"
	#$HUD/BattleReport.visible = true
	var lp1 = 1
	if game_debug: print("Attacker: ", apiece.color, " ", apiece.type)
	attack1 = apiece.current_attack
	if game_debug: print("Attack1 is: ", attack1)
	attack1type = apiece.type
	if game_debug: print("attack1type is: ", attack1type)
	#$HUD/BattleReport/BattleReport.text = $HUD/BattleReport/BattleReport.text + "Attacker: " + apiece.color + " " + attack1type + "\n"
	if game_debug: print("Defender: ", dpiece.color, " ", dpiece.type)
	defend1 = dpiece.current_defend
	defend1type = dpiece.type
	if game_debug: print("Attacker, ", apiece.color, " ", apiece.type, " has an attack strength of ", attack1)
	if game_debug: print("Defender, ", dpiece.color, " ", dpiece.type, " has a defend strength of ",defend1)
	#$HUD/BattleReport/BattleReport.text = $HUD/BattleReport/BattleReport.text + "Defender: " + dpiece.color + " " + defend1type + "\n"
	#while (attack1 != 0) && (defend1 != 0):
	#while (attack1 > 0) && (defend1 > 0):
	if game_debug: print("cwl2 before while: ", attack1, " | ", defend1)
	var battlerounds = 0
	var battlereportrounds = 15
	while (attack1 > 0) and (defend1 > 0):
		# trying to run this loop slower
		#if game_debug: print("Trying to yeild for a time...")
		#yield(get_tree().create_timer(0.4), "timeout") # see if this fixes anything
		# this is a stupid attempt at a delay loop
		# and it seems to be in the wrong place besides
		# or something is behavin in  way I do not expect.
		# I want to slow down battle updates to the HUD
		#$HUD/BattleReport/BattleReport.text = $HUD/BattleReport/BattleReport.text + Time.get_time_string_from_system() +"==Before delay loop.==\n"
		#for zn in 10000:
		#	var zo
		#	zo = 0
		#	zo = zo + 1
		#$HUD/BattleReport/BattleReport.text = $HUD/BattleReport/BattleReport.text + "=====After delay loop.==\n"
		if game_debug: print("A1 - Attack = ", attack1, "            |            Defend = ", defend1,"")
		luck = rng.randi_range(0,8)
		if luck == 0:
			if game_debug: print("The attacking ", apiece.color, " ", apiece.type, " lands a mighty blow!")
			#$HUD/BattleReport/BattleReport.text = $HUD/BattleReport/BattleReport.text + "The attacking " + apiece.color + " " + attack1type + " lands a mighty blow!\n"
			defend1 = int((defend1 * 5) / 6 )
			if game_debug: print("defend1 is now: ", defend1)
		if luck == 1:
			if game_debug: print("D1 - The defending ", dpiece.color, " ", dpiece.type, " gets in a gallant thrust!")
			#$HUD/BattleReport/BattleReport.text = $HUD/BattleReport/BattleReport.text + "The defending " + dpiece.color + " " + defend1type + " gets in a gallant thrust!\n"
			if lp1 == 1:
				attack1 = int(attack1 / 2)
				if game_debug: print("It does great damage to the attacker!")
				#$HUD/BattleReport/BattleReport.text = $HUD/BattleReport/BattleReport.text + "It does great damage to the attacker!\n"
				lp1 = 2
				if game_debug: print("attack1 is now: ", attack1)
			else:
				attack1 = int((attack1 * 5) /6)
				if game_debug: print("attack1 is now: ", attack1)
		if luck == 2:
			if game_debug: print("The valiant attacker draws blood.")
			#$HUD/BattleReport/BattleReport.text = $HUD/BattleReport/BattleReport.text + "The valiant attacking " + apiece.color + " " + apiece.type + " draws blood.\n"
			defend1 = int((defend1 * 4) / 5 )
			if game_debug: print("defend1 is now: ", defend1)
		if luck == 3:
			if game_debug: print("The " + dpiece.color + " " + defend1type, " puts up a strong defence and wounds the " + apiece.color + " " + attack1type + "!!")
			#$HUD/BattleReport/BattleReport.text = $HUD/BattleReport/BattleReport.text + "The " + dpiece.color + " " + defend1type + " puts up a strong defence and wounds the " + apiece.color + " " + attack1type + "!!\n"
			attack1 = int((attack1 * 4) / 5)
			if game_debug: print("attack1 is now: ", attack1)
		if luck == 4:
			if game_debug: print("With a mighty cut, the ", attack1type, " wounds the ", defend1type, ".")
			#$HUD/BattleReport/BattleReport.text = $HUD/BattleReport/BattleReport.text + "With a mighty cut, the " + apiece.color + " " + attack1type + " wounds the " + dpiece.color + " " + defend1type + ".\n"
			defend1 = int((defend1 * 9) / 10)
			if game_debug: print("defend1 is now: ", defend1)
		if luck == 5:
			if game_debug: print("The defender lands  a crushing blow!")
			#$HUD/BattleReport/BattleReport.text = $HUD/BattleReport/BattleReport.text + "The defending " + dpiece.color + " " + defend1type + " lands  a crushing blow!\n"
			attack1 = int((attack1 * 9) /10)
			if game_debug: print("attack1 is now: ", attack1)
		if luck == 6:
			if game_debug: print("OH! Surely the ", defend1type, " cannot long endure such a furious attack.")
			#$HUD/BattleReport/BattleReport.text = $HUD/BattleReport/BattleReport.text + "OH! Surely the " + dpiece.color + " " + defend1type + " cannot long endure such a furious attack.\n"
			defend1 = int((defend1 * 14) / 15)
			if game_debug: print("defend1 is now: ", defend1)
		if luck == 7:
			if game_debug: print("The ", attack1type, "'s attack falters and the ", defend1type, " gets in a blow in return.")
			#$HUD/BattleReport/BattleReport.text = $HUD/BattleReport/BattleReport.text + "The " + apiece.color + " " + attack1type + "'s attack falters and the " + dpiece.color + " " + defend1type + " gets in a blow in return.\n"
			attack1 = int((attack1 * 14) / 15)
			if game_debug: print("attack1 is now: ", attack1)
		if luck == 8:
			if game_debug: print("The combatants take a much needed rest.")
			#$HUD/BattleReport/BattleReport.text = $HUD/BattleReport/BattleReport.text + "The combatants take a much needed rest.\n"
			if game_debug: print("attack1 is now: ", attack1)
			if game_debug: print("defend1 is now: ", defend1)
		battlerounds = battlerounds +1
		if game_debug: print("battlerounds is now: ", battlerounds)
		if battlerounds == battlereportrounds:
			battlerounds = 0
			#$HUD/BattleReport/BattleReport.text = "The battle continues.\n"
	if game_debug: print("A2 - Attack = ", attack1, "            |            Defend = ", defend1,"")
	#$HUD/BattleReport/BattleReport.text = $HUD/BattleReport/BattleReport.text + "Attack = " + apiece.color + " " + attack1type + "            |            Defend = " + str(defend1) + "\n"
	if game_debug: print("before defend1 == 0 check, defend1 is now: ", defend1, " attack1 is now: ",attack1)
	if (defend1 == 0):
		# ATTACK WINS
		attackwins = str(int(attackwins) + 1)
		#$'../Game/HUD/GameStats/VBoxContainer/HBCAttackWins/AttackWinsNum'.text = attackwins
		if game_debug: print("Below should be true")
		if game_debug: print(defend1==0)
		if game_debug: print("was above true?")
		if game_debug: print("defend1 == 0? A3 - Attack = ", attack1, "            |            Defend = ", defend1,"")
		if game_debug: print("defend1 is: ", defend1)
		if game_debug: print("The attacking ", attack1type, " defeated the defending ", defend1type, "!")
		#$HUD/BattleReport/BattleReport.text = $HUD/BattleReport/BattleReport.text + "The attacking " + apiece.color + " " + attack1type + " defeated the defending " + dpiece.color + " " + defend1type + "!\n"
		if game_debug: print("Setting zattackwon to true in Level: ", war_level)
		zattackwon = true
		incrsc = apiece.value
		if game_debug: print("incrsc just assigned apiece.value and is now: ",incrsc)
		if attack1 == 0:
			attack1 = 1
			if game_debug: print("defend1 was 0 and attack1 was 0 so we made attack1 equal 1")
		apiece.current_attack = attack1
		if game_debug: print("incrsc is: ", incrsc)
		if apiece.color == 'white':
			whitescore = str(int(whitescore) + dpiece.value)
			$'../Game/HUD/GameStats/VBoxContainer/HBCWhiteScore/WhtScoreNum'.text = whitescore
			if game_debug: print("whitewins is: ", whitewins)
			whitewins = str(int(whitewins) + 1)
			if game_debug: print("whitewins is: ", whitewins)
			$'../Game/HUD/GameStats/VBoxContainer/HBCWhiteWins/WhtWinsNum'.text = whitewins
		else:
			blackscore = str(int(blackscore) + dpiece.value)
			#$'../Game/HUD/GameStats/VBoxContainer/HBCBlackScore/BlkScoreNum'.text = blackscore
			blackwins = str(int(blackwins) + 1)
			if game_debug: print("whitewins is: ", blackwins)
			#$'../Game/HUD/GameStats/VBoxContainer/HBCBlackWins/BlkWinsNum'.text = blackwins
		# we return the piece to kill (loser)
		warresult = "AttackWins"
		return warresult
	else:
		#DEFEND WINS
		defendwins = str(int(defendwins) + 1)
		#$'../Game/HUD/GameStats/VBoxContainer/HBCDefendWins/DefendWinsNum'.text = defendwins
		if game_debug: print("defend1 != 0? A4 - Attack = ", attack1, "            |            Defend = ", defend1,"")
		if game_debug: print("D2 - The defending ", defend1type,  " defeated the attacking ", attack1type, " !")
		#$HUD/BattleReport/BattleReport.text = $HUD/BattleReport/BattleReport.text + "The defending " + dpiece.color + " " + defend1type +  " defeated the attacking " + apiece.color + " " + attack1type + " !\n"
		if game_debug: print("Setting zattackwon to false in Level: ", war_level)
		zattackwon = false
		incrsc = dpiece.value
		if game_debug: print("incrsc just assigned dpiece.value and is now: ",incrsc)
		if game_debug: print("incrsc is: ", incrsc)
		if apiece.color == 'white':
			blackscore = str(int(blackscore) + apiece.value)
			#$'../Game/HUD/GameStats/VBoxContainer/HBCBlackScore/BlkScoreNum'.text = blackscore
			if game_debug: print("blackwins is: ", blackwins)
			blackwins = str(int(blackwins) + 1)
			if game_debug: print("blackwins is: ", blackwins)
			#$'../Game/HUD/GameStats/VBoxContainer/HBCBlackWins/BlkWinsNum'.text = blackwins
			
		else:
			blackscore = str(int(blackscore) + apiece.value)
			#$'../Game/HUD/GameStats/VBoxContainer/HBCBlackScore/BlkScoreNum'.text = blackscore
		# we return the piece to kill
		# - out this back somehow? 
		# dpiece.current.defend = defend1
		warresult = "DefendWins"
		return warresult


func try_to_make_a_move(piece: Piece, non_player_move = true):
	var info = board.get_position_info(piece, non_player_move)
	# When Idle, we are not playing a game so the user may move the black pieces
	print(info.ok)
	# Try to drop the piece
	# Also check for castling and passant
	var ok_to_move = false
	var rook = null
	if info.ok:
		if info.piece != null:
			ok_to_move = true
		else:
			if info.passant and board.passant_pawn.pos.x == piece.new_pos.x:
				print("passant")
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
			#board.take_piece(info.piece)
			#print("Did I just take the piece: ", info.piece)
			var dpiece = info.piece
			var active_piece = piece
			var apiece = active_piece
			if info.piece ==null:
				print("Is this a move with no piece taken? ", info.piece, dpiece )
				board.take_piece(info.piece) # this may never be called
				move_piece(piece)
			else:
				print("There is a piece at the end of this move: ",info.piece, dpiece)
				if war_level == "Level0":
					if game_debug: print("\n\n-----In War Level: ", war_level)
					warresult = "AttackWins"
				elif war_level == "Level1":
					if game_debug: print("\n\n-----In War Level: ", war_level)
					print("Calling cwl1 with active_piece and dpiece: ", active_piece, dpiece)
					warresult = cwl1(active_piece, dpiece)
					print("cwl1 -> warresult is now: ", warresult)
				elif war_level == "Level2":
					if game_debug: print("\n\n-----In War Level: ", war_level)
					print("Attacker: ", apiece)
					attack1 = apiece.current_attack
					print("Attack1 is: ", attack1)
					attack1type = apiece.type
					print("attack1type is: ", attack1type)
					print("calling L2 active_piece, dpiece - ", active_piece, dpiece)
					warresultl2 = cwl2(active_piece, dpiece)
					warresult = warresultl2
					print("cwl2 -> warresult is now: ", warresult)
				else:
					# should neve get here but just in case and
					# to make adding new levels easier
					print("If we got here, something went wrong, pretend.")
					warresult = "AttackWins"

				print("warresult is now: ", warresult)
				if warresult == "AttackWins":
					print("********** warresult == AttackWins **********")
					print("We should be safe to do nothing piece wise from here")
				else:
					print("---------- warresult == DefendWins ----------")
					print("swap  pieces around and proceed?: ")
					print("Before pieve swap piece, info.piece:", piece, info.piece)
					var dwpiece = info.piece
					info.piece = piece
					piece = dwpiece
					#set_next_color()
					print("After pieve swap piece, info.piece:", piece, info.piece)
					#board.take_piece(piece)
					#move_piece(info.piece)
				#print("Did I just move the piece: ", piece)


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
	print("Do config stuff")
	#$c/ConfigPop.popup_rect = Rect2(Vector2.ZERO, Vector2(1024, 900))
	$c/ConfigPop.show()
	#configp.ConfigPop.popup_centered() # this does popup something.
	#$ConfigPop/ConfigPop.popup()
	
	#popup.popup_rect = Rect2(Vector2.ZERO, Vector2(800, 600)
	
	#$c/ConfigPop/M/VBox/VBoxContainer/HBoxContainer/Level0.grab_focus()
	#$c/ConfigPop/M2/VBox/VBoxContainer/HBoxContainer/Level0.grab_focus()
	#$c/VBox/VBoxContainer/HBoxContainer/Level0.grab_focus()
	#$Menu.visible = false
	#$ColorRect/BackPanel.visible = true
	#$Options.visible = true
	#$Options/VBoxContainer/HBoxContainer/Glinski.grab_focus()


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


func reset_board():
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

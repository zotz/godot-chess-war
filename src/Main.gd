extends Control

# drew's additions
var game_debug = true

# end drew's additions


onready var engine = $Engine
onready var fd = $c/FileDialog
onready var promote = $c/Promote
onready var board = $VBox/Board

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
var warresult
var battlechance
var l1_battlechancediv = 0.9
var zattackwon = true
var attack1
var attack1type
var defend1
var defend1type
var luck
#var rng = RandomNumberGenerator.new()
var battlecount = 0
var war_level = "Level1"

# end drew's additions


# states
enum { IDLE, CONNECTING, STARTING, PLAYER_TURN, ENGINE_TURN, PLAYER_WIN, ENGINE_WIN }
# events
enum { CONNECT, NEW_GAME, DONE, ERROR, MOVE }

func _ready():
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
		return "AttackWins"
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
		return "DefendWins"
		#temp pretend attacker won
		#return dpiece

func cwl2(apiece, dpiece):
	if game_debug: print("In Chess War L2")
	if game_debug: print("War Level from config is: ", war_level)
	print("The attacker is a ", apiece.color, apiece.type)
	print("The defender is a ", dpiece.color, dpiece.type)



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
				elif war_level == "Level2":
					if game_debug: print("\n\n-----In War Level: ", war_level)
					print("Attacker: ", apiece)
					attack1 = apiece.current_attack
					print("Attack1 is: ", attack1)
					attack1type = apiece.type
					print("attack1type is: ", attack1type)
					print("calling L2 active_piece, dpiece - ", active_piece, dpiece)
					warresult = cwl2(active_piece, dpiece)
				else:
					# should neve get here but just in case and
					# to make adding new levels easier
					print("If we got here, something went wrong, pretend.")
					warresult = "AttackWins"


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

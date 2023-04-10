extends PopupPanel

signal promotion_picked

var piece: Piece

func _ready():
	#print("In Promote")
	var path = "M/VBox/"
	for ch in "qbnr":
		var node: Button = get_node(path + ch)
		node.connect("button_down", self, "chosen", [ch])


func open(p: Piece):
	piece = p
	popup_centered()


func chosen(pick):
	emit_signal("promotion_picked", piece, pick)
	hide()
	hide()

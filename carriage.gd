class_name TrainCarriage
extends Control

@onready var art: TextureRect = $Art
@onready var stripe: ColorRect = $Stripe
@onready var tag: ColorRect = $Tag
@onready var icon: Label = $Icon
@onready var word_label: Label = $Word

var word: String = ""
var word_class: String = ""
var train_color: Color = Color(0.23, 0.74, 0.78)

func setup(p_word: String, p_class: String, train_color: Color, tex: Texture2D) -> void:
	word = p_word
	word_class = p_class
	self.train_color = train_color
	art.texture = tex
	stripe.color = train_color
	tag.color = class_color(p_class)
	icon.text = class_icon(p_class)
	word_label.text = p_word

func set_unified(color: Color) -> void:
	stripe.color = color

func class_color(p_class: String) -> Color:
	match p_class:
		"article": return Color("598cff")
		"noun": return Color("59bf73")
		"verb": return Color("f28c4d")
		"adjective": return Color("b373d9")
		"pronoun": return Color("f2c94d")
		"particle": return Color(0.6, 0.6, 0.6)
		_: return Color(0.6, 0.6, 0.6)

func class_icon(p_class: String) -> String:
	match p_class:
		"article": return "A"
		"noun": return "N"
		"verb": return "V"
		"adjective": return "D"
		"pronoun": return "P"
		"particle": return "T"
		_: return "?"

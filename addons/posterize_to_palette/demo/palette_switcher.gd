extends Node3D

@export var SWEETIE_16 : PackedColorArray = [Color("1a1c2c"), Color("5d275d"), Color("b13e53"),
	Color("ef7d57"), Color("ffcd75"), Color("a7f070"), Color("38b764"), Color("257179"),
	Color("29366f"), Color("3b5dc9"), Color("41a6f6"), Color("f4f4f4"), Color("94b0c2"),
	Color("566c86"), Color("333c57")]
# Nope, not gonna format that, cause that will turn into like 70 lines
@export var MODE_13H : PackedColorArray = [Color("#000000"), Color("#0000AA"), Color("#00AA00"), Color("#00AAAA"), Color("#AA0000"), Color("#AA00AA"), Color("#AA5500"), Color("#AAAAAA"), Color("#555555"), Color("#5555FF"), Color("#55FF55"), Color("#55FFFF"), Color("#FF5555"), Color("#FF55FF"), Color("#FFFF55"), Color("#FFFFFF"), Color("#000000"), Color("#101010"), Color("#202020"), Color("#353535"), Color("#454545"), Color("#555555"), Color("#656565"), Color("#757575"), Color("#8A8A8A"), Color("#9A9A9A"), Color("#AAAAAA"), Color("#BABABA"), Color("#CACACA"), Color("#DFDFDF"), Color("#EFEFEF"), Color("#FFFFFF"), Color("#0000FF"), Color("#4100FF"), Color("#8200FF"), Color("#BE00FF"), Color("#FF00FF"), Color("#FF00BE"), Color("#FF0082"), Color("#FF0041"), Color("#FF0000"), Color("#FF4100"), Color("#FF8200"), Color("#FFBE00"), Color("#FFFF00"), Color("#BEFF00"), Color("#82FF00"), Color("#41FF00"), Color("#00FF00"), Color("#00FF41"), Color("#00FF82"), Color("#00FFBE"), Color("#00FFFF"), Color("#00BEFF"), Color("#0082FF"), Color("#0041FF"), Color("#8282FF"), Color("#9E82FF"), Color("#BE82FF"), Color("#DF82FF"), Color("#FF82FF"), Color("#FF82DF"), Color("#FF82BE"), Color("#FF829E"), Color("#FF8282"), Color("#FF9E82"), Color("#FFBE82"), Color("#FFDF82"), Color("#FFFF82"), Color("#DFFF82"), Color("#BEFF82"), Color("#9EFF82"), Color("#82FF82"), Color("#82FF9E"), Color("#82FFBE"), Color("#82FFDF"), Color("#82FFFF"), Color("#82DFFF"), Color("#82BEFF"), Color("#829EFF"), Color("#BABAFF"), Color("#CABAFF"), Color("#DFBAFF"), Color("#EFBAFF"), Color("#FFBAFF"), Color("#FFBAEF"), Color("#FFBADF"), Color("#FFBACA"), Color("#FFBABA"), Color("#FFCABA"), Color("#FFDFBA"), Color("#FFEFBA"), Color("#FFFFBA"), Color("#EFFFBA"), Color("#DFFFBA"), Color("#CAFFBA"), Color("#BAFFBA"), Color("#BAFFCA"), Color("#BAFFDF"), Color("#BAFFEF"), Color("#BAFFFF"), Color("#BAEFFF"), Color("#BADFFF"), Color("#BACAFF"), Color("#000071"), Color("#1C0071"), Color("#390071"), Color("#550071"), Color("#710071"), Color("#710055"), Color("#710039"), Color("#71001C"), Color("#710000"), Color("#711C00"), Color("#713900"), Color("#715500"), Color("#717100"), Color("#557100"), Color("#397100"), Color("#1C7100"), Color("#007100"), Color("#00711C"), Color("#007139"), Color("#007155"), Color("#007171"), Color("#005571"), Color("#003971"), Color("#001C71"), Color("#393971"), Color("#453971"), Color("#553971"), Color("#613971"), Color("#713971"), Color("#713961"), Color("#713955"), Color("#713945"), Color("#713939"), Color("#714539"), Color("#715539"), Color("#716139"), Color("#717139"), Color("#617139"), Color("#557139"), Color("#457139"), Color("#397139"), Color("#397145"), Color("#397155"), Color("#397161"), Color("#397171"), Color("#396171"), Color("#395571"), Color("#394571"), Color("#515171"), Color("#595171"), Color("#615171"), Color("#695171"), Color("#715171"), Color("#715169"), Color("#715161"), Color("#715159"), Color("#715151"), Color("#715951"), Color("#716151"), Color("#716951"), Color("#717151"), Color("#697151"), Color("#617151"), Color("#597151"), Color("#517151"), Color("#517159"), Color("#517161"), Color("#517169"), Color("#517171"), Color("#516971"), Color("#516171"), Color("#515971"), Color("#000041"), Color("#100041"), Color("#200041"), Color("#310041"), Color("#410041"), Color("#410031"), Color("#410020"), Color("#410010"), Color("#410000"), Color("#411000"), Color("#412000"), Color("#413100"), Color("#414100"), Color("#314100"), Color("#204100"), Color("#104100"), Color("#004100"), Color("#004110"), Color("#004120"), Color("#004131"), Color("#004141"), Color("#003141"), Color("#002041"), Color("#001041"), Color("#202041"), Color("#282041"), Color("#312041"), Color("#392041"), Color("#412041"), Color("#412039"), Color("#412031"), Color("#412028"), Color("#412020"), Color("#412820"), Color("#413120"), Color("#413920"), Color("#414120"), Color("#394120"), Color("#314120"), Color("#284120"), Color("#204120"), Color("#204128"), Color("#204131"), Color("#204139"), Color("#204141"), Color("#203941"), Color("#203141"), Color("#202841"), Color("#2D2D41"), Color("#312D41"), Color("#352D41"), Color("#3D2D41"), Color("#412D41"), Color("#412D3D"), Color("#412D35"), Color("#412D31"), Color("#412D2D"), Color("#41312D"), Color("#41352D"), Color("#413D2D"), Color("#41412D"), Color("#3D412D"), Color("#35412D"), Color("#31412D"), Color("#2D412D"), Color("#2D4131"), Color("#2D4135"), Color("#2D413D"), Color("#2D4141"), Color("#2D3D41"), Color("#2D3541"), Color("#2D3141")]

# I don't want to duplate this whole script but there is no GDScript type for "Class" 🐀
# we'd have to wait for https://github.com/godotengine/godot-proposals/issues/10115 🐀
# or I could put the palette export and setter part into a shared parent class... but not right now
@export var runtime_shader : bool
var shader_object: Variant

var sweetie_button : Button
var mode13h_button : Button


# Buttons and shader reference initialized here 
func _ready() -> void:
	sweetie_button = $ShaderController/VBoxContainer/MarginContainer/VBoxContainer/SweetieButton as Button
	mode13h_button = $ShaderController/VBoxContainer/MarginContainer/VBoxContainer/Mode13hButton as Button
	if runtime_shader:
		shader_object = $PosterizeRuntime as PosterizeRuntime
	else:
		shader_object = $PosterizeWithLUT as PosterizeWithComputeLUT


# Toggles shader and the palette related buttons 🐀
func toggle_shader(toggled_on : bool) -> void:
	if shader_object != null:
		shader_object.visible = toggled_on
	if sweetie_button != null and mode13h_button != null:
		sweetie_button.disabled = not toggled_on
		mode13h_button.disabled = not toggled_on


# Switches the palette of the posterize shader
func switch_palette(toggled_on : bool, palette_code : String) -> void:
	if shader_object != null:
		if palette_code == "sweetie":
			shader_object.rgb_colors = SWEETIE_16
		if palette_code == "13h":
			shader_object.rgb_colors = MODE_13H


# Loads the other demo scene when the 'switch to' button is pressed 🐀
func switch_scene() -> void:
	if runtime_shader:
		get_tree().change_scene_to_file("res://addons/posterize_to_palette/demo/compute_LUT_demo.tscn")
	else:
		get_tree().change_scene_to_file("res://addons/posterize_to_palette/demo/runtime_demo.tscn")

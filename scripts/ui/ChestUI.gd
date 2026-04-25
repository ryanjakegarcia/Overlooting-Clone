class_name ChestUI
extends Control

signal item_picked(item)
signal closed

func _init() -> void:
	hide()
	z_index = 10
	mouse_filter = Control.MOUSE_FILTER_STOP

func open(items: Array) -> void:
	for c in get_children():
		c.queue_free()
	_build(items)
	show()

func _build(items: Array) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var win := Panel.new()
	win.custom_minimum_size = Vector2(580, 300)
	var ws := StyleBoxFlat.new()
	ws.bg_color = Color(0.10, 0.11, 0.14)
	ws.border_color = Color(0.60, 0.55, 0.30)
	ws.set_border_width_all(2)
	ws.set_corner_radius_all(8)
	win.add_theme_stylebox_override("panel", ws)
	center.add_child(win)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   18)
	margin.add_theme_constant_override("margin_right",  18)
	margin.add_theme_constant_override("margin_top",    14)
	margin.add_theme_constant_override("margin_bottom", 14)
	win.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "CHEST — CHOOSE ONE ITEM"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.85, 0.80, 0.55))
	vbox.add_child(title)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	for item in items:
		hbox.add_child(_make_card(item))

	var hint := Label.new()
	hint.text = "Click an item to take it. Others are discarded."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.40, 0.40, 0.45))
	vbox.add_child(hint)

func _make_card(item) -> Panel:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(165, 185)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var cs := StyleBoxFlat.new()
	cs.bg_color = item.get_rarity_color().darkened(0.55)
	cs.border_color = item.get_rarity_color()
	cs.set_border_width_all(2)
	cs.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", cs)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.set_offset(SIDE_LEFT,   8)
	vb.set_offset(SIDE_TOP,    8)
	vb.set_offset(SIDE_RIGHT,  -8)
	vb.set_offset(SIDE_BOTTOM, -8)
	card.add_child(vb)

	var rarity_lbl := Label.new()
	rarity_lbl.text = item.get_rarity_name().to_upper()
	rarity_lbl.add_theme_font_size_override("font_size", 10)
	rarity_lbl.add_theme_color_override("font_color", item.get_rarity_color().lightened(0.4))
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(rarity_lbl)

	var name_lbl := Label.new()
	name_lbl.text = item.display_name
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.82))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(name_lbl)

	var type_text: String = item.type.capitalize()
	if item.set_tag != "":
		type_text += "  [%s]" % item.set_tag.capitalize()
	var type_lbl := Label.new()
	type_lbl.text = type_text
	type_lbl.add_theme_font_size_override("font_size", 10)
	type_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.62))
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(type_lbl)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", item.get_rarity_color().darkened(0.2))
	vb.add_child(sep)

	var stats: Dictionary = item.get_stats_dict()
	for stat_name in stats:
		var sl := Label.new()
		sl.text = "%s  %s" % [stat_name, stats[stat_name]]
		sl.add_theme_font_size_override("font_size", 11)
		sl.add_theme_color_override("font_color", Color(0.80, 0.85, 0.75))
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(sl)

	card.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			item_picked.emit(item)
			hide()
			closed.emit()
	)
	card.mouse_entered.connect(func() -> void:
		cs.bg_color = item.get_rarity_color().darkened(0.35)
		cs.set_border_width_all(3)
	)
	card.mouse_exited.connect(func() -> void:
		cs.bg_color = item.get_rarity_color().darkened(0.55)
		cs.set_border_width_all(2)
	)

	return card

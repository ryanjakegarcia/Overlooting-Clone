extends VBoxContainer

signal area_entered(area_idx: int)

const AREA_DATA := [
	{"label": "1 - Rotwood Grove",        "color": Color(0.35, 0.60, 0.35)},
	{"label": "2 - Rotwood Hollow",       "color": Color(0.35, 0.60, 0.35)},
	{"label": "3 - Rotwood Depths",       "color": Color(0.28, 0.52, 0.28)},
	{"label": "4 - Ancient Boughs",       "color": Color(0.22, 0.45, 0.22)},
	{"label": "5 - BOSS: Verdant Horror", "color": Color(0.70, 0.22, 0.22)},
]

var _row_styles: Array = []
var _enter_btns: Array = []
var _status_lbls: Array = []
var _area_lbls: Array = []

func setup(areas_cleared: int) -> void:
	add_theme_constant_override("separation", 3)

	for i in range(5):
		var d: Dictionary = AREA_DATA[i]

		var rs := StyleBoxFlat.new()
		rs.set_corner_radius_all(4)
		rs.set_border_width_all(1)
		_row_styles.append(rs)

		var row := Panel.new()
		row.custom_minimum_size = Vector2(196, 36)
		row.add_theme_stylebox_override("panel", rs)
		add_child(row)

		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 4)
		hb.set_anchors_preset(Control.PRESET_FULL_RECT)
		hb.set_offset(SIDE_LEFT,   6)
		hb.set_offset(SIDE_RIGHT,  -6)
		hb.set_offset(SIDE_TOP,    2)
		hb.set_offset(SIDE_BOTTOM, -2)
		row.add_child(hb)

		var lbl := Label.new()
		lbl.text = d["label"]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 10)
		hb.add_child(lbl)
		_area_lbls.append(lbl)

		var slbl := Label.new()
		slbl.add_theme_font_size_override("font_size", 10)
		slbl.custom_minimum_size = Vector2(30, 0)
		slbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hb.add_child(slbl)
		_status_lbls.append(slbl)

		var btn := Button.new()
		btn.text = "Enter"
		btn.add_theme_font_size_override("font_size", 10)
		btn.custom_minimum_size = Vector2(52, 0)
		var cap_i := i
		btn.pressed.connect(func() -> void: area_entered.emit(cap_i))
		hb.add_child(btn)
		_enter_btns.append(btn)

	refresh(areas_cleared)

func refresh(areas_cleared: int) -> void:
	for i in range(5):
		var rs: StyleBoxFlat = _row_styles[i]
		var slbl: Label = _status_lbls[i]
		var lbl: Label = _area_lbls[i]
		var btn: Button = _enter_btns[i]
		var ac: Color = (AREA_DATA[i] as Dictionary)["color"]

		if i < areas_cleared:
			rs.bg_color     = Color(0.10, 0.18, 0.10)
			rs.border_color = ac.darkened(0.3)
			lbl.add_theme_color_override("font_color", Color(0.45, 0.55, 0.45))
			slbl.text = "DONE"
			slbl.add_theme_color_override("font_color", Color(0.38, 0.75, 0.42))
			btn.hide()
		elif i == areas_cleared:
			rs.bg_color     = ac.darkened(0.55)
			rs.border_color = ac
			lbl.add_theme_color_override("font_color", Color(0.92, 0.88, 0.70))
			slbl.text = "NOW"
			slbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.30))
			btn.show()
			btn.disabled = false
		else:
			rs.bg_color     = Color(0.08, 0.09, 0.10)
			rs.border_color = Color(0.20, 0.22, 0.26)
			lbl.add_theme_color_override("font_color", Color(0.28, 0.30, 0.34))
			slbl.text = "---"
			slbl.add_theme_color_override("font_color", Color(0.25, 0.25, 0.30))
			btn.hide()

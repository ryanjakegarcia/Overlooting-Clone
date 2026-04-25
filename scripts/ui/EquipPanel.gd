class_name EquipPanel
extends VBoxContainer

const SLOT_ORDER  := ["weapon", "helm", "chest", "boots", "ring"]
const SLOT_LABELS := {
	"weapon": "Weapon",
	"helm":   "Helm",
	"chest":  "Chest",
	"boots":  "Boots",
	"ring":   "Ring",
}

const C_EMPTY_BG     := Color(0.12, 0.13, 0.16)
const C_EMPTY_BORDER := Color(0.28, 0.30, 0.36)
const C_EMPTY_TEXT   := Color(0.38, 0.38, 0.42)

# _state is a RunState instance (untyped)
var _state = null
var _slot_styles: Dictionary = {}
var _slot_name_labels: Dictionary = {}

signal slot_clicked(slot_name)

func setup(state) -> void:
	_state = state
	_state.equip_changed.connect(_sync)
	_build()

func _build() -> void:
	add_theme_constant_override("separation", 5)
	for slot in SLOT_ORDER:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var slot_lbl := Label.new()
		slot_lbl.text = SLOT_LABELS[slot]
		slot_lbl.custom_minimum_size = Vector2(70, 0)
		slot_lbl.add_theme_font_size_override("font_size", 12)
		slot_lbl.add_theme_color_override("font_color", Color(0.65, 0.62, 0.55))
		slot_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(slot_lbl)

		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(180, 52)

		var style := StyleBoxFlat.new()
		style.bg_color = C_EMPTY_BG
		style.border_color = C_EMPTY_BORDER
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		panel.add_theme_stylebox_override("panel", style)

		var item_lbl := Label.new()
		item_lbl.text = "— empty —"
		item_lbl.add_theme_color_override("font_color", C_EMPTY_TEXT)
		item_lbl.add_theme_font_size_override("font_size", 11)
		item_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		item_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.add_child(item_lbl)

		panel.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
				slot_clicked.emit(slot)
		)

		row.add_child(panel)
		add_child(row)
		_slot_styles[slot] = style
		_slot_name_labels[slot] = item_lbl

func _sync() -> void:
	if _state == null:
		return
	for slot in SLOT_ORDER:
		var item = _state.equip_slots[slot]
		var style: StyleBoxFlat = _slot_styles[slot]
		var lbl: Label = _slot_name_labels[slot]
		if item != null:
			style.bg_color    = item.get_rarity_color()
			style.border_color = item.get_rarity_color().lightened(0.35)
			lbl.text = "%s\n[%s]" % [item.display_name, item.get_rarity_name()]
			lbl.add_theme_color_override("font_color", Color(0.06, 0.05, 0.04))
		else:
			style.bg_color    = C_EMPTY_BG
			style.border_color = C_EMPTY_BORDER
			lbl.text = "— empty —"
			lbl.add_theme_color_override("font_color", C_EMPTY_TEXT)

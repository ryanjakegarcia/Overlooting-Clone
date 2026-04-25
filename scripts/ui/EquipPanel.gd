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
var _slot_panels: Dictionary = {}
var _hover_slot: String = ""

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
		panel.mouse_filter = Control.MOUSE_FILTER_PASS

		var style := StyleBoxFlat.new()
		style.bg_color = C_EMPTY_BG
		style.border_color = C_EMPTY_BORDER
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		panel.add_theme_stylebox_override("panel", style)

		var item_lbl := Label.new()
		item_lbl.text = "— empty —"
		item_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		_slot_panels[slot] = panel

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

func _can_drop_data(_at_position: Vector2, data) -> bool:
	if _state == null or typeof(data) != TYPE_DICTIONARY:
		_clear_drag_highlight()
		return false
	if data.get("kind", "") != "backpack_item":
		_clear_drag_highlight()
		return false
	var item = data.get("item", null)
	if item == null:
		_clear_drag_highlight()
		return false

	var slot := _slot_under_mouse()
	if slot == "":
		_clear_drag_highlight()
		return false

	var valid := str(item.type) == slot
	_set_drag_highlight(slot, valid)
	return valid

func _drop_data(_at_position: Vector2, data) -> void:
	if _state == null or typeof(data) != TYPE_DICTIONARY:
		_clear_drag_highlight()
		return
	if data.get("kind", "") != "backpack_item":
		_clear_drag_highlight()
		return

	var item = data.get("item", null)
	var slot := _slot_under_mouse()
	if item == null or slot == "" or str(item.type) != slot:
		_clear_drag_highlight()
		return

	var prev = _state.equip_item(item, slot)
	if prev != null:
		_state.add_to_backpack(prev)
	_clear_drag_highlight()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_clear_drag_highlight()

func _slot_under_mouse() -> String:
	var point := get_global_mouse_position()
	for slot in SLOT_ORDER:
		var panel: Panel = _slot_panels.get(slot, null)
		if panel != null and panel.get_global_rect().has_point(point):
			return slot
	return ""

func _set_drag_highlight(slot: String, valid: bool) -> void:
	if _hover_slot == slot:
		return
	_clear_drag_highlight()
	_hover_slot = slot
	var style: StyleBoxFlat = _slot_styles[slot]
	if valid:
		style.border_color = Color(0.24, 0.78, 0.40)
		style.set_border_width_all(2)
	else:
		style.border_color = Color(0.85, 0.25, 0.25)
		style.set_border_width_all(2)

func _clear_drag_highlight() -> void:
	if _hover_slot == "":
		return
	var slot := _hover_slot
	_hover_slot = ""
	var style: StyleBoxFlat = _slot_styles[slot]
	var item = _state.equip_slots[slot] if _state != null else null
	if item != null:
		style.border_color = item.get_rarity_color().lightened(0.35)
	else:
		style.border_color = C_EMPTY_BORDER
	style.set_border_width_all(1)

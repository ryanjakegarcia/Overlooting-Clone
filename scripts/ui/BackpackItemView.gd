class_name BackpackItemView
extends Panel

signal left_clicked(item)
signal right_clicked(item, screen_pos)

var item = null
var source_grid = null

func bind_data(next_item, next_grid) -> void:
	item = next_item
	source_grid = next_grid

func _get_drag_data(_at_position: Vector2):
	if item == null or source_grid == null:
		return null
	source_grid.begin_drag(item)

	var preview := Panel.new()
	preview.custom_minimum_size = size
	preview.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = item.get_rarity_color()
	style.set_corner_radius_all(5)
	style.border_color = item.get_rarity_color().lightened(0.35)
	style.set_border_width_all(2)
	preview.add_theme_stylebox_override("panel", style)
	preview.modulate.a = 0.65

	var lbl := Label.new()
	lbl.text = item.display_name
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.add_child(lbl)

	set_drag_preview(preview)
	return {
		"kind": "backpack_item",
		"item": item,
	}

func _gui_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton):
		return
	if ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed:
		right_clicked.emit(item, get_global_mouse_position())
	elif ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
		left_clicked.emit(item)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and source_grid != null:
		source_grid.end_drag(get_viewport().gui_is_drag_successful())

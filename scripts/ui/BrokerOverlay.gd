class_name BrokerOverlay
extends Control

signal resolved

const COUNTDOWN_SEC := 3

var _state = null
var _grid  = null
var _target_row: int = -1
var _countdown_lbl: Label = null

func _init() -> void:
	hide()
	z_index = 8
	mouse_filter = Control.MOUSE_FILTER_STOP

func open(state, grid) -> void:
	_state = state
	_grid  = grid
	_target_row = randi() % state.GRID_ROWS
	for c in get_children():
		c.queue_free()
	_build()
	show()
	_run_countdown()

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(360, 240)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.10, 0.05, 0.05)
	ps.border_color = Color(0.75, 0.20, 0.20)
	ps.set_border_width_all(3)
	ps.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", ps)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.set_offset(SIDE_LEFT,   20)
	vb.set_offset(SIDE_TOP,    20)
	vb.set_offset(SIDE_RIGHT,  -20)
	vb.set_offset(SIDE_BOTTOM, -20)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "THE BROKER ARRIVES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.90, 0.28, 0.22))
	vb.add_child(title)

	var row_lbl := Label.new()
	row_lbl.text = "Row %d will be stolen" % (_target_row + 1)
	row_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row_lbl.add_theme_font_size_override("font_size", 14)
	row_lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.52))
	vb.add_child(row_lbl)

	_countdown_lbl = Label.new()
	_countdown_lbl.text = str(COUNTDOWN_SEC)
	_countdown_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_lbl.add_theme_font_size_override("font_size", 58)
	_countdown_lbl.add_theme_color_override("font_color", Color(0.90, 0.28, 0.22))
	vb.add_child(_countdown_lbl)

	var hint := Label.new()
	hint.text = "All items in this row are forfeit."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.48, 0.42, 0.38))
	vb.add_child(hint)

	if _grid != null:
		_grid.highlight_broker_row(_target_row)

func _run_countdown() -> void:
	for i in range(COUNTDOWN_SEC, 0, -1):
		if _countdown_lbl == null:
			return
		_countdown_lbl.text = str(i)
		var tw := create_tween()
		tw.tween_property(_countdown_lbl, "modulate:a", 0.35, 0.25)
		tw.tween_property(_countdown_lbl, "modulate:a", 1.00, 0.20)
		await get_tree().create_timer(1.0).timeout

	if _countdown_lbl != null:
		_countdown_lbl.text = "0"
	await get_tree().create_timer(0.45).timeout

	if _grid != null:
		_grid.clear_broker_highlight()
	if _state != null:
		_state.steal_row(_target_row)

	hide()
	resolved.emit()

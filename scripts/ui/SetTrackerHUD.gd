class_name SetTrackerHUD
extends HBoxContainer

# _state is a RunState instance (untyped)
var _state = null
var _set_labels: Dictionary = {}

const SETS := ["beast", "rogue", "royal"]
const SET_COLORS := {
	"beast": Color(0.91, 0.49, 0.24),
	"rogue": Color(0.36, 0.74, 0.39),
	"royal": Color(0.61, 0.35, 0.74),
}

func setup(state) -> void:
	_state = state
	_state.equip_changed.connect(_sync)
	_build()
	_sync()

func _build() -> void:
	add_theme_constant_override("separation", 12)
	for sid in SETS:
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", SET_COLORS[sid])
		add_child(lbl)
		_set_labels[sid] = lbl

func _sync() -> void:
	if _state == null:
		return
	var counts: Dictionary = { "beast": 0, "rogue": 0, "royal": 0 }
	for item in _state.get_all_equipped_items():
		var tag: String = str(item.set_tag)
		if counts.has(tag):
			counts[tag] += 1

	var h = _state.hero_stats
	_update("beast", counts["beast"], h.beast_t1, h.beast_t2)
	_update("rogue", counts["rogue"], h.rogue_t1, h.rogue_t2)
	_update("royal", counts["royal"], h.royal_t1, h.royal_t2)

func _update(sid: String, count: int, t1: bool, t2: bool) -> void:
	var lbl: Label = _set_labels[sid]
	if count == 0:
		lbl.text = sid.capitalize() + " –"
		lbl.modulate.a = 0.35
		return
	lbl.modulate.a = 1.0
	var bonus := ""
	if t2:   bonus = " ✓T2"
	elif t1: bonus = " ✓T1"
	lbl.text = "%s %d%s" % [sid.capitalize(), count, bonus]

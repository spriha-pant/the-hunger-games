extends Node2D

# ─────────────────────────────────────────────
# COLOURS
# ─────────────────────────────────────────────
const COL_BG           := Color(0.06, 0.04, 0.10)
const COL_PANEL        := Color(0.12, 0.10, 0.18, 0.96)
const COL_PANEL_INNER  := Color(0.16, 0.14, 0.24)
const COL_TEXT         := Color(0.95, 0.93, 0.88)
const COL_TEXT_DIM     := Color(0.55, 0.53, 0.50)
const COL_ACCENT       := Color(1.00, 0.85, 0.20)
const COL_RED          := Color(0.95, 0.25, 0.25)
const COL_ORANGE       := Color(1.00, 0.55, 0.10)
const COL_GREEN        := Color(0.20, 0.85, 0.35)
const COL_CYAN         := Color(0.10, 0.80, 0.95)
const COL_YELLOW       := Color(1.00, 0.85, 0.10)
const COL_BTN_MAIN     := Color(0.22, 0.22, 0.32)
const COL_BTN_PLAY     := Color(0.25, 0.55, 0.95)
const COL_BTN_SAVE     := Color(0.20, 0.55, 0.30)

const MAIN_MENU_SCENE  := "res://MainMenu.tscn"
const GAME_SCENE       := "res://node_2d.tscn"

# ─────────────────────────────────────────────
# NODE REFS
# ─────────────────────────────────────────────
var GM             : Node
var _report        : Dictionary = {}

var _hud           : CanvasLayer
var _overlay       : CanvasLayer

# Report card sections
var _lbl_title     : Label
var _lbl_rounds    : Label
var _lbl_cause     : Label
var _rtl_science   : RichTextLabel
var _rtl_stats     : RichTextLabel
var _rtl_log       : RichTextLabel

# Save UI
var _save_panel    : PanelContainer
var _name_input    : LineEdit
var _btn_save_confirm : Button
var _lbl_save_status  : Label

# Log scroll
var _log_scroll    : ScrollContainer
var _log_visible   : bool = false
var _btn_log       : Button

# ─────────────────────────────────────────────
# READY
# ─────────────────────────────────────────────
func _ready() -> void:
	GM = get_node("/root/GameManager")
	_report = GM.last_report
	_build_scene()
	_populate_report()

# ─────────────────────────────────────────────
# SCENE BUILDER
# ─────────────────────────────────────────────
func _build_scene() -> void:
	var vp : Vector2 = get_viewport_rect().size

	var bg              := ColorRect.new()
	bg.size              = vp
	bg.color             = COL_BG
	bg.mouse_filter      = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_hud       = CanvasLayer.new()
	_hud.layer = 10
	add_child(_hud)

	_overlay       = CanvasLayer.new()
	_overlay.layer = 20
	add_child(_overlay)

	_build_main_card(vp)
	_build_save_overlay(vp)

# ─────────────────────────────────────────────
# MAIN REPORT CARD
# ─────────────────────────────────────────────
func _build_main_card(vp: Vector2) -> void:
	# Outer scroll so nothing overflows on small screens
	var scroll              := ScrollContainer.new()
	scroll.size              = vp
	scroll.position          = Vector2.ZERO
	scroll.mouse_filter      = Control.MOUSE_FILTER_STOP
	_hud.add_child(scroll)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	outer.custom_minimum_size = Vector2(vp.x, 0)
	scroll.add_child(outer)

	# ── Header strip ──────────────────────────────────────────────────────────
	var header              := PanelContainer.new()
	var hstyle              := _panel_style(Color(0.18, 0.05, 0.08), 0)
	hstyle.set_content_margin_all(20.0)
	header.add_theme_stylebox_override("panel", hstyle)
	header.mouse_filter      = Control.MOUSE_FILTER_IGNORE
	outer.add_child(header)

	var hvbox := VBoxContainer.new()
	hvbox.add_theme_constant_override("separation", 6)
	hvbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(hvbox)

	var game_over_lbl := Label.new()
	game_over_lbl.text = "GAME OVER"
	game_over_lbl.add_theme_font_size_override("font_size", 40)
	game_over_lbl.add_theme_color_override("font_color", COL_RED)
	game_over_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	hvbox.add_child(game_over_lbl)

	_lbl_rounds = Label.new()
	_lbl_rounds.add_theme_font_size_override("font_size", 18)
	_lbl_rounds.add_theme_color_override("font_color", COL_TEXT_DIM)
	_lbl_rounds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_rounds.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	hvbox.add_child(_lbl_rounds)

	# ── Content area ──────────────────────────────────────────────────────────
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cpad := _pad_container(content, Vector2(20, 16))
	outer.add_child(cpad)

	# Left column — cause + science + stats
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 14)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	content.add_child(left)

	_build_section(left, "Hypothalamus Report Card",
		"What killed your mouse — and what the neuroscience says.")

	# Cause of death
	var cause_panel := _inner_panel()
	left.add_child(cause_panel)
	var cause_vbox := VBoxContainer.new()
	cause_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cause_panel.add_child(cause_vbox)

	var cause_head := _small_label("CAUSE OF DEATH", Color(0.60, 0.60, 0.60))
	cause_vbox.add_child(cause_head)

	_lbl_cause = Label.new()
	_lbl_cause.add_theme_font_size_override("font_size", 18)
	_lbl_cause.add_theme_color_override("font_color", COL_RED)
	_lbl_cause.mouse_filter    = Control.MOUSE_FILTER_IGNORE
	_lbl_cause.autowrap_mode   = TextServer.AUTOWRAP_WORD_SMART
	cause_vbox.add_child(_lbl_cause)

	# Science explanation
	var sci_panel := _inner_panel()
	left.add_child(sci_panel)
	var sci_vbox := VBoxContainer.new()
	sci_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sci_panel.add_child(sci_vbox)

	sci_vbox.add_child(_small_label("THE SCIENCE", Color(0.60, 0.60, 0.60)))

	_rtl_science = RichTextLabel.new()
	_rtl_science.bbcode_enabled      = true
	_rtl_science.fit_content         = true
	_rtl_science.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	_rtl_science.custom_minimum_size = Vector2(0, 60)
	_rtl_science.add_theme_font_size_override("normal_font_size", 14)
	_rtl_science.add_theme_color_override("default_color", COL_TEXT)
	sci_vbox.add_child(_rtl_science)

	# Final stats
	var stats_panel := _inner_panel()
	left.add_child(stats_panel)
	var stats_vbox := VBoxContainer.new()
	stats_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_panel.add_child(stats_vbox)

	stats_vbox.add_child(_small_label("FINAL STATS", Color(0.60, 0.60, 0.60)))

	_rtl_stats = RichTextLabel.new()
	_rtl_stats.bbcode_enabled      = true
	_rtl_stats.fit_content         = true
	_rtl_stats.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	_rtl_stats.add_theme_font_size_override("normal_font_size", 14)
	_rtl_stats.add_theme_color_override("default_color", COL_TEXT)
	stats_vbox.add_child(_rtl_stats)

	# Right column — decision log toggle + buttons
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	right.custom_minimum_size      = Vector2(220, 0)
	right.mouse_filter             = Control.MOUSE_FILTER_IGNORE
	content.add_child(right)

	_build_section(right, "Decision Log", "Every choice you made.")

	# Toggle log button
	_btn_log = Button.new()
	_btn_log.text               = "Show Log ▾"
	_btn_log.custom_minimum_size = Vector2(200, 36)
	_btn_log.mouse_filter       = Control.MOUSE_FILTER_STOP
	_btn_log.pressed.connect(_on_toggle_log)
	_style_flat(_btn_log, COL_BTN_MAIN)
	right.add_child(_btn_log)

	# Log scroll (hidden by default)
	_log_scroll              = ScrollContainer.new()
	_log_scroll.custom_minimum_size = Vector2(200, 260)
	_log_scroll.visible      = false
	_log_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	right.add_child(_log_scroll)

	_rtl_log                 = RichTextLabel.new()
	_rtl_log.bbcode_enabled       = true
	_rtl_log.fit_content          = true
	_rtl_log.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_rtl_log.custom_minimum_size  = Vector2(196, 0)
	_rtl_log.add_theme_font_size_override("normal_font_size", 12)
	_rtl_log.add_theme_color_override("default_color", COL_TEXT)
	_log_scroll.add_child(_rtl_log)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	right.add_child(spacer)

	# Action buttons
	_build_section(right, "What next?", "")

	var btn_save := Button.new()
	btn_save.text               = "💾  Save Report"
	btn_save.custom_minimum_size = Vector2(200, 44)
	btn_save.mouse_filter       = Control.MOUSE_FILTER_STOP
	btn_save.pressed.connect(_on_save_pressed)
	_style_big(_btn_log, COL_BTN_MAIN)   # restyle log btn to match
	_style_big(btn_save, COL_BTN_SAVE)
	right.add_child(btn_save)

	var btn_again := Button.new()
	btn_again.text               = "▶  Play Again"
	btn_again.custom_minimum_size = Vector2(200, 44)
	btn_again.mouse_filter       = Control.MOUSE_FILTER_STOP
	btn_again.pressed.connect(_on_play_again)
	_style_big(btn_again, COL_BTN_PLAY)
	right.add_child(btn_again)

	var btn_menu := Button.new()
	btn_menu.text               = "⌂  Main Menu"
	btn_menu.custom_minimum_size = Vector2(200, 44)
	btn_menu.mouse_filter       = Control.MOUSE_FILTER_STOP
	btn_menu.pressed.connect(_on_main_menu)
	_style_flat(btn_menu, COL_BTN_MAIN)
	right.add_child(btn_menu)

# ─────────────────────────────────────────────
# SAVE OVERLAY
# ─────────────────────────────────────────────
func _build_save_overlay(vp: Vector2) -> void:
	_save_panel          = PanelContainer.new()
	var style            := _panel_style(Color(0.14, 0.12, 0.22, 0.98), 14)
	style.border_width_left   = 2; style.border_width_right  = 2
	style.border_width_top    = 2; style.border_width_bottom = 2
	style.border_color        = Color(0.40, 0.40, 0.65)
	style.set_content_margin_all(28.0)
	_save_panel.add_theme_stylebox_override("panel", style)
	_save_panel.size         = Vector2(420, 220)
	_save_panel.position     = Vector2((vp.x - 420) * 0.5, (vp.y - 220) * 0.5)
	_save_panel.visible      = false
	_save_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(_save_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_save_panel.add_child(vbox)

	var title := Label.new()
	title.text = "Save your Report"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", COL_ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Enter a nickname to save this run to Past Reports."
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", COL_TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	sub.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sub)

	_name_input                     = LineEdit.new()
	_name_input.placeholder_text     = "Your nickname…"
	_name_input.custom_minimum_size  = Vector2(360, 40)
	_name_input.mouse_filter         = Control.MOUSE_FILTER_STOP
	_name_input.add_theme_font_size_override("font_size", 16)
	# Style the input box
	var input_style := _panel_style(Color(0.20, 0.18, 0.30), 6)
	input_style.set_content_margin_all(8.0)
	_name_input.add_theme_stylebox_override("normal", input_style)
	_name_input.add_theme_stylebox_override("focus",  input_style)
	_name_input.add_theme_color_override("font_color", COL_TEXT)
	_name_input.add_theme_color_override("font_placeholder_color", COL_TEXT_DIM)
	# Allow pressing Enter to confirm
	_name_input.text_submitted.connect(_on_name_submitted)
	vbox.add_child(_name_input)

	_lbl_save_status              = Label.new()
	_lbl_save_status.text          = ""
	_lbl_save_status.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_lbl_save_status.add_theme_font_size_override("font_size", 13)
	_lbl_save_status.add_theme_color_override("font_color", COL_GREEN)
	_lbl_save_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_lbl_save_status)

	var btn_row         := HBoxContainer.new()
	btn_row.alignment    = BoxContainer.ALIGNMENT_CENTER
	btn_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var btn_cancel              := Button.new()
	btn_cancel.text              = "Cancel"
	btn_cancel.custom_minimum_size = Vector2(110, 36)
	btn_cancel.mouse_filter      = Control.MOUSE_FILTER_STOP
	btn_cancel.pressed.connect(_on_save_cancel)
	_style_flat(btn_cancel, COL_BTN_MAIN)
	btn_row.add_child(btn_cancel)

	_btn_save_confirm              = Button.new()
	_btn_save_confirm.text         = "Save"
	_btn_save_confirm.custom_minimum_size = Vector2(110, 36)
	_btn_save_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	_btn_save_confirm.pressed.connect(_on_save_confirm)
	_style_big(_btn_save_confirm, COL_BTN_SAVE)
	btn_row.add_child(_btn_save_confirm)

# ─────────────────────────────────────────────
# POPULATE REPORT DATA
# ─────────────────────────────────────────────
func _populate_report() -> void:
	if _report.is_empty():
		_lbl_rounds.text  = "No report data found."
		return

	var rounds : int = int(_report.get("rounds_survived", 0))
	_lbl_rounds.text = "Survived %d round%s" % [rounds, "s" if rounds != 1 else ""]

	_lbl_cause.text = str(_report.get("cause_of_death", "Unknown"))

	# Science text — placeholder shown if not yet filled in
	var sci : String = str(_report.get("science", ""))
	if sci == "" or sci.ends_with("[Placeholder]") or sci.ends_with("[Placeholder: AgRP neuron science]"):
		_rtl_science.text = sci + "\n\n[color=#666666][i](Full scientific explanation coming soon.)[/i][/color]"
	else:
		_rtl_science.text = sci

	# Final stats with colour coding
	var fs   : Dictionary = _report.get("final_stats", {})
	var det  : float      = float(fs.get("detectability", 0))
	var adip : float      = float(fs.get("adiposity",     0))
	var temp : float      = float(fs.get("temperature",   37))
	var enrg : float      = float(fs.get("energy",        0))

	var det_col  : String = "#33ee66" if det  < 30 else ("#ffdd22" if det  < 60 else "#ff4444")
	var adip_col : String = "#33ee66" if adip > 30 and adip <= 100 else "#ffdd22"
	var temp_col : String = "#33ee66" if temp >= 36.5 and temp <= 40 else "#ff8833"
	var enrg_col : String = "#33ee66" if enrg > 30 else ("#ffdd22" if enrg > 10 else "#ff4444")

	_rtl_stats.text = (
		"[color=#aaaaaa]⚡ Energy[/color]        [color=%s]%.0f / 100[/color]\n" % [enrg_col, enrg] +
		"[color=#aaaaaa]👁 Detectability[/color]  [color=%s]%.0f%%[/color]\n"   % [det_col,  det]  +
		"[color=#aaaaaa]🌡 Temperature[/color]   [color=%s]%.1f°C[/color]\n"    % [temp_col, temp] +
		"[color=#aaaaaa]🫀 Fat (Adiposity)[/color] [color=%s]%.0f / 120[/color]" % [adip_col, adip]
	)

	# Decision log
	_populate_decision_log()

func _populate_decision_log() -> void:
	var log_arr : Array = _report.get("decisions_log", [])
	if log_arr.is_empty():
		_rtl_log.text = "[color=#666666]No decisions recorded.[/color]"
		return

	var text : String = ""
	for entry in log_arr:
		var d       : Dictionary = entry
		var rnd     : int        = int(d.get("round", 0))
		var cycle   : String     = str(d.get("cycle", "?"))
		var act     : String     = str(d.get("action", "?"))
		var res     : Dictionary = d.get("result", {})

		var act_col : String = "#aaddff"
		match act:
			"FORAGE":       act_col = "#ffdd55"
			"SUPER_FORAGE": act_col = "#ffaa22"
			"HIDE":         act_col = "#55ddaa"
			"REST":         act_col = "#88aaff"
			"TORPOR":       act_col = "#cc88ff"

		text += "[color=#666666]R%d %s[/color]  [color=%s]%s[/color]" % [rnd, cycle, act_col, act]

		# Compact deltas
		var de : float = float(res.get("delta_energy", 0))
		var da : float = float(res.get("delta_adiposity", 0))
		var dt : float = float(res.get("delta_temp", 0))
		var dd : float = float(res.get("delta_detect", 0))
		var parts : Array[String] = []
		if de != 0: parts.append(("%+.0f" % de) + "E")
		if da != 0: parts.append(("%+.0f" % da) + "F")
		if dt != 0: parts.append(("%+.1f" % dt) + "°")
		if dd != 0: parts.append(("%+.0f" % dd) + "%")
		if parts.size() > 0:
			text += "  [color=#555555]" + "  ".join(parts) + "[/color]"
		text += "\n"

	_rtl_log.text = text

# ─────────────────────────────────────────────
# BUTTON HANDLERS
# ─────────────────────────────────────────────
func _on_toggle_log() -> void:
	_log_visible          = not _log_visible
	_log_scroll.visible   = _log_visible
	_btn_log.text         = ("Hide Log ▴" if _log_visible else "Show Log ▾")

func _on_save_pressed() -> void:
	_name_input.text     = ""
	_lbl_save_status.text = ""
	_save_panel.visible  = true
	_name_input.grab_focus()

func _on_save_cancel() -> void:
	_save_panel.visible = false

func _on_name_submitted(text: String) -> void:
	_do_save(text)

func _on_save_confirm() -> void:
	_do_save(_name_input.text)

func _do_save(raw_name: String) -> void:
	var name : String = raw_name.strip_edges()
	if name == "":
		_lbl_save_status.text = "Please enter a nickname first."
		_lbl_save_status.add_theme_color_override("font_color", COL_ORANGE)
		return

	GM.save_report(_report, name)

	_lbl_save_status.text = "Saved as \"%s\"!" % name
	_lbl_save_status.add_theme_color_override("font_color", COL_GREEN)
	_btn_save_confirm.disabled = true

	# Auto-close after a moment
	await get_tree().create_timer(1.2).timeout
	_save_panel.visible        = false
	_btn_save_confirm.disabled = false

func _on_play_again() -> void:
	GM.start_new_game()
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_main_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

# ─────────────────────────────────────────────
# UI HELPERS
# ─────────────────────────────────────────────
func _build_section(parent: VBoxContainer, title: String, sub: String) -> void:
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", COL_ACCENT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)
	if sub != "":
		var s := Label.new()
		s.text = sub
		s.add_theme_font_size_override("font_size", 11)
		s.add_theme_color_override("font_color", COL_TEXT_DIM)
		s.mouse_filter   = Control.MOUSE_FILTER_IGNORE
		s.autowrap_mode  = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(s)

func _inner_panel() -> PanelContainer:
	var p        := PanelContainer.new()
	var style    := _panel_style(COL_PANEL_INNER, 8)
	style.set_content_margin_all(12.0)
	p.add_theme_stylebox_override("panel", style)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p

func _small_label(text: String, col: Color) -> Label:
	var l        := Label.new()
	l.text        = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", col)
	return l

func _pad_container(child: Control, margin: Vector2) -> MarginContainer:
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left",   int(margin.x))
	m.add_theme_constant_override("margin_right",  int(margin.x))
	m.add_theme_constant_override("margin_top",    int(margin.y))
	m.add_theme_constant_override("margin_bottom", int(margin.y))
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_child(child)
	return m

func _panel_style(bg: Color, radius: int) -> StyleBoxFlat:
	var s          := StyleBoxFlat.new()
	s.bg_color      = bg
	s.corner_radius_top_left     = radius
	s.corner_radius_top_right    = radius
	s.corner_radius_bottom_left  = radius
	s.corner_radius_bottom_right = radius
	return s

func _style_big(btn: Button, bg: Color) -> void:
	var s     := _panel_style(bg, 10)
	s.set_content_margin_all(10.0)
	var hover := _panel_style(bg.lightened(0.15), 10)
	hover.set_content_margin_all(10.0)
	btn.add_theme_stylebox_override("normal",  s)
	btn.add_theme_stylebox_override("pressed", s)
	btn.add_theme_stylebox_override("hover",   hover)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 15)

func _style_flat(btn: Button, bg: Color) -> void:
	var s     := _panel_style(bg, 8)
	s.set_content_margin_all(8.0)
	var hover := _panel_style(bg.lightened(0.15), 8)
	hover.set_content_margin_all(8.0)
	btn.add_theme_stylebox_override("normal",  s)
	btn.add_theme_stylebox_override("pressed", s)
	btn.add_theme_stylebox_override("hover",   hover)
	btn.add_theme_color_override("font_color", COL_TEXT)
	btn.add_theme_font_size_override("font_size", 13)

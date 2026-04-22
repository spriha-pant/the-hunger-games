# Main.gd  — attach to root Node2D in node_2d.tscn

extends Node2D

# ─────────────────────────────────────────────
# COLOURS
# ─────────────────────────────────────────────
const COL_BG_DAY       := Color(0.53, 0.81, 0.54)
const COL_BG_NIGHT     := Color(0.05, 0.07, 0.18)
const COL_PANEL        := Color(0.10, 0.10, 0.14, 0.88)
const COL_PANEL_LIGHT  := Color(0.18, 0.18, 0.25, 0.95)
const COL_TEXT         := Color(0.95, 0.95, 0.90)
const COL_TEXT_DIM     := Color(0.65, 0.65, 0.60)
const COL_ACCENT_DAY   := Color(1.00, 0.85, 0.20)
const COL_ACCENT_NIGHT := Color(0.50, 0.70, 1.00)
const COL_RED          := Color(0.95, 0.25, 0.25)
const COL_ORANGE       := Color(1.00, 0.55, 0.10)
const COL_YELLOW       := Color(1.00, 0.85, 0.10)
const COL_GREEN        := Color(0.20, 0.85, 0.35)
const COL_CYAN         := Color(0.10, 0.80, 0.95)
const COL_BTN          := Color(0.22, 0.22, 0.32)
const COL_BTN_ACTIVE   := Color(0.28, 0.50, 0.90)
const COL_T_GREEN      := Color(0.20, 0.85, 0.35)
const COL_T_YELLOW     := Color(1.00, 0.85, 0.10)
const COL_T_ORANGE     := Color(1.00, 0.55, 0.10)
const COL_T_RED        := Color(0.95, 0.25, 0.25)

# ─────────────────────────────────────────────
# NODE REFS
# ─────────────────────────────────────────────
var _bg            : ColorRect
var _hud           : CanvasLayer
var _overlay       : CanvasLayer

var _bar_energy    : ProgressBar
var _bar_detect    : ProgressBar
var _bar_temp      : ProgressBar
var _bar_adip      : ProgressBar
var _lbl_energy    : Label
var _lbl_detect    : Label
var _lbl_temp      : Label
var _lbl_adip      : Label
var _lbl_items     : Label
var _lbl_round     : Label
var _lbl_cycle     : Label
var _lbl_events    : Label
var _lbl_feedback  : Label

var _action_buttons : Array  = []
var _selected_idx   : int    = -1
var _timer_bar      : ProgressBar
var _lbl_timer      : Label
var _btn_submit     : Button
var _decision_panel : PanelContainer

var _decision_timer : Timer
var _decision_time  : float = 10.0
var _time_left      : float = 10.0

var _popup_panel    : PanelContainer
var _popup_title    : Label
var _popup_body     : RichTextLabel
var _popup_btn      : Button
var _popup_queue    : Array = []
var _popup_open     : bool  = false

var _feedback_timer : Timer

var GM : Node

var _debug_log      : RichTextLabel
var _debug_panel    : PanelContainer

# ─────────────────────────────────────────────
# READY
# ─────────────────────────────────────────────
func _ready() -> void:
	print("--- TERMINAL IS ALIVE ---") # Add this
	GM = get_node("/root/GameManager")
	_build_scene()
	_connect_signals()

	call_deferred("_start_game")

func _start_game() -> void:
	GM.start_new_game()

# ─────────────────────────────────────────────
# SCENE BUILDER
# ─────────────────────────────────────────────
func _build_scene() -> void:
	var vp : Vector2 = get_viewport_rect().size

	_bg              = ColorRect.new()
	_bg.size         = vp
	_bg.color        = COL_BG_DAY
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_hud       = CanvasLayer.new()
	_hud.layer = 10
	add_child(_hud)

	_overlay       = CanvasLayer.new()
	_overlay.layer = 20
	_overlay.follow_viewport_enabled = false 
	add_child(_overlay)

	_build_stat_bars(vp)
	_build_round_label(vp)
	_build_event_label(vp)
	_build_decision_panel(vp)
	_build_feedback_label(vp)
	_build_popup_panel(vp)
	_build_debug_panel(vp)

	_feedback_timer           = Timer.new()
	_feedback_timer.wait_time = 2.5
	_feedback_timer.one_shot  = true
	_feedback_timer.timeout.connect(_on_feedback_timeout)
	add_child(_feedback_timer)

	_decision_timer           = Timer.new()
	_decision_timer.wait_time = 0.1
	_decision_timer.one_shot  = false
	_decision_timer.timeout.connect(_on_decision_tick)
	add_child(_decision_timer)

# ── Stat bars ─────────────────────────────────────────────────────────────────
func _build_stat_bars(vp: Vector2) -> void:
	var panel        := PanelContainer.new()
	var style        := _panel_style(COL_PANEL, 10)
	style.set_content_margin_all(10.0)
	panel.add_theme_stylebox_override("panel", style)
	panel.position   = Vector2(10, 10)
	panel.custom_minimum_size = Vector2(190, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var e := _bar_row(vbox, "⚡ Energy",  COL_CYAN,   0.0,  100.0, 50.0)
	_bar_energy = e[0]; _lbl_energy = e[1]

	var d := _bar_row(vbox, "👁 Detect.", COL_GREEN,  0.0,  100.0,  0.0)
	_bar_detect = d[0]; _lbl_detect = d[1]

	var t := _bar_row(vbox, "🌡 Temp",   COL_ORANGE, 32.0,  42.0, 37.0)
	_bar_temp = t[0]; _lbl_temp = t[1]

	var a := _bar_row(vbox, "🫀 Fat",    COL_YELLOW,  0.0, 120.0, 55.0)
	_bar_adip = a[0]; _lbl_adip = a[1]

	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	_lbl_items              = Label.new()
	_lbl_items.text         = "🍞 0   🛡 0"
	_lbl_items.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl_items.add_theme_color_override("font_color", COL_TEXT)
	_lbl_items.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_lbl_items)

func _bar_row(parent: VBoxContainer, label_text: String,
		bar_color: Color, mn: float, mx: float, start: float) -> Array:
	var row              := HBoxContainer.new()
	row.mouse_filter      = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)

	var lbl              := Label.new()
	lbl.text              = label_text
	lbl.mouse_filter      = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_color_override("font_color", COL_TEXT_DIM)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.custom_minimum_size.x = 76
	row.add_child(lbl)

	var bar                   := ProgressBar.new()
	bar.min_value              = mn
	bar.max_value              = mx
	bar.value                  = start
	bar.show_percentage        = false
	bar.mouse_filter           = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size    = Vector2(60, 14)
	bar.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override("fill",       _bar_fill_style(bar_color))
	bar.add_theme_stylebox_override("background", _bar_fill_style(Color(0.15, 0.15, 0.20)))
	row.add_child(bar)

	var val              := Label.new()
	val.mouse_filter      = Control.MOUSE_FILTER_IGNORE
	val.add_theme_color_override("font_color", COL_TEXT)
	val.add_theme_font_size_override("font_size", 11)
	val.custom_minimum_size.x = 40
	row.add_child(val)

	return [bar, val]

# ── Round label ───────────────────────────────────────────────────────────────
func _build_round_label(vp: Vector2) -> void:
	_lbl_round              = Label.new()
	_lbl_round.text         = "Round 1 · Day"
	_lbl_round.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl_round.add_theme_font_size_override("font_size", 22)
	_lbl_round.add_theme_color_override("font_color", COL_ACCENT_DAY)
	_lbl_round.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_round.position     = Vector2(vp.x * 0.5 - 160, 12)
	_lbl_round.size         = Vector2(320, 34)
	_hud.add_child(_lbl_round)

	_lbl_cycle              = Label.new()
	_lbl_cycle.text         = "Starting…"
	_lbl_cycle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl_cycle.add_theme_font_size_override("font_size", 13)
	_lbl_cycle.add_theme_color_override("font_color", COL_TEXT_DIM)
	_lbl_cycle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_cycle.position     = Vector2(vp.x * 0.5 - 160, 46)
	_lbl_cycle.size         = Vector2(320, 22)
	_hud.add_child(_lbl_cycle)

# ── Events label ──────────────────────────────────────────────────────────────
func _build_event_label(vp: Vector2) -> void:
	_lbl_events              = Label.new()
	_lbl_events.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl_events.add_theme_font_size_override("font_size", 12)
	_lbl_events.add_theme_color_override("font_color", COL_ORANGE)
	_lbl_events.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_events.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	_lbl_events.position  = Vector2(vp.x - 220, 10)
	_lbl_events.size      = Vector2(210, 80)
	_hud.add_child(_lbl_events)

# ── Decision panel ────────────────────────────────────────────────────────────
func _build_decision_panel(vp: Vector2) -> void:
	_decision_panel          = PanelContainer.new()
	_decision_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style                := _panel_style(COL_PANEL, 12)
	style.set_content_margin_all(16.0)
	_decision_panel.add_theme_stylebox_override("panel", style)
	_decision_panel.custom_minimum_size = Vector2(700, 0)
	_decision_panel.position = Vector2((vp.x - 700) * 0.5, vp.y - 260)
	_decision_panel.visible  = false
	_hud.add_child(_decision_panel)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 10)
	_decision_panel.add_child(vbox)

	# Timer row
	var trow := HBoxContainer.new()
	trow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trow.add_theme_constant_override("separation", 8)
	vbox.add_child(trow)

	var head              := Label.new()
	head.text              = "Choose your action:"
	head.mouse_filter      = Control.MOUSE_FILTER_IGNORE
	head.add_theme_font_size_override("font_size", 15)
	head.add_theme_color_override("font_color", COL_TEXT)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trow.add_child(head)

	_lbl_timer              = Label.new()
	_lbl_timer.text         = "10s"
	_lbl_timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl_timer.add_theme_font_size_override("font_size", 15)
	_lbl_timer.add_theme_color_override("font_color", COL_T_GREEN)
	trow.add_child(_lbl_timer)

	_timer_bar                    = ProgressBar.new()
	_timer_bar.min_value          = 0.0
	_timer_bar.max_value          = 10.0
	_timer_bar.value              = 10.0
	_timer_bar.show_percentage    = false
	_timer_bar.mouse_filter       = Control.MOUSE_FILTER_IGNORE
	_timer_bar.custom_minimum_size = Vector2(120, 14)
	_timer_bar.add_theme_stylebox_override("fill",       _bar_fill_style(COL_T_GREEN))
	_timer_bar.add_theme_stylebox_override("background", _bar_fill_style(Color(0.15, 0.15, 0.20)))
	trow.add_child(_timer_bar)

	# Action buttons
	var brow           := HBoxContainer.new()
	brow.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	brow.add_theme_constant_override("separation", 8)
	brow.alignment      = BoxContainer.ALIGNMENT_CENTER
	brow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(brow)

	for i in range(5):
		var btn                  := Button.new()
		btn.custom_minimum_size   = Vector2(126, 80)
		btn.mouse_filter          = Control.MOUSE_FILTER_STOP
		_style_action(btn, false)
		btn.pressed.connect(_on_action_pressed.bind(i))
		brow.add_child(btn)
		_action_buttons.append(btn)

	# Submit button
	var srow       := HBoxContainer.new()
	srow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	srow.alignment  = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(srow)

	_btn_submit                    = Button.new()
	_btn_submit.text               = "Submit"
	_btn_submit.custom_minimum_size = Vector2(130, 34)
	_btn_submit.mouse_filter       = Control.MOUSE_FILTER_STOP
	_btn_submit.pressed.connect(_on_submit_pressed)
	_style_submit(_btn_submit)
	srow.add_child(_btn_submit)
	
	for child in _decision_panel.get_all_children() if _decision_panel.has_method("get_all_children") else []:
		if not child is Button:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE

# ── Feedback label ────────────────────────────────────────────────────────────
func _build_feedback_label(vp: Vector2) -> void:
	_lbl_feedback              = Label.new()
	_lbl_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl_feedback.add_theme_font_size_override("font_size", 16)
	_lbl_feedback.add_theme_color_override("font_color", COL_TEXT)
	_lbl_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_feedback.position      = Vector2(vp.x * 0.5 - 260, vp.y * 0.5 - 30)
	_lbl_feedback.size          = Vector2(520, 60)
	_lbl_feedback.visible       = false
	_hud.add_child(_lbl_feedback)

# ── Popup panel ───────────────────────────────────────────────────────────────
func _build_popup_panel(vp: Vector2) -> void:
	_popup_panel          = PanelContainer.new()
	var style             := _panel_style(COL_PANEL_LIGHT, 14)
	style.border_width_left   = 2; style.border_width_right  = 2
	style.border_width_top    = 2; style.border_width_bottom = 2
	style.border_color        = Color(0.40, 0.40, 0.65)
	style.set_content_margin_all(22.0)
	_popup_panel.add_theme_stylebox_override("panel", style)

	_popup_panel.custom_minimum_size = Vector2(580, 0)  # width locked; height auto
	_popup_panel.position = Vector2((vp.x - 580) * 0.5, (vp.y - 420) * 0.5)
	_popup_panel.visible      = false
	_popup_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(_popup_panel)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 12)
	_popup_panel.add_child(vbox)

	_popup_title              = Label.new()
	_popup_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_title.add_theme_font_size_override("font_size", 20)
	_popup_title.add_theme_color_override("font_color", COL_ACCENT_DAY)
	_popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_popup_title)

	var sep              := HSeparator.new()
	sep.mouse_filter      = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	_popup_body              = RichTextLabel.new()
	_popup_body.bbcode_enabled      = true
	_popup_body.fit_content         = true
	_popup_body.scroll_active       = false
	_popup_body.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	_popup_body.custom_minimum_size = Vector2(536, 0)
	_popup_body.add_theme_font_size_override("normal_font_size", 14)
	_popup_body.add_theme_color_override("default_color", COL_TEXT)
	vbox.add_child(_popup_body)

	var br         := HBoxContainer.new()
	br.alignment    = BoxContainer.ALIGNMENT_CENTER
	br.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(br)

	_popup_btn                    = Button.new()
	_popup_btn.text               = "Got it"
	_popup_btn.custom_minimum_size = Vector2(130, 40)
	_popup_btn.mouse_filter       = Control.MOUSE_FILTER_STOP
	_popup_btn.pressed.connect(_on_popup_btn)
	_style_submit(_popup_btn)
	br.add_child(_popup_btn)

# ─────────────────────────────────────────────
# CONNECT SIGNALS
# ─────────────────────────────────────────────
func _connect_signals() -> void:
	GM.phase_changed.connect(_on_phase_changed)
	GM.cycle_changed.connect(_on_cycle_changed)
	GM.stats_updated.connect(_on_stats_updated)
	GM.event_triggered.connect(_on_event_triggered)
	GM.action_result.connect(_on_action_result)
	GM.game_over.connect(_on_game_over)
	GM.item_gained.connect(_on_item_gained)
	GM.forced_action.connect(_on_forced_action)
	GM.predation_debug.connect(_on_predation_debug)


# ─────────────────────────────────────────────
# SIGNAL HANDLERS
# ─────────────────────────────────────────────
func _on_phase_changed(phase: String) -> void:
	match phase:
		"status_update":
			_lbl_cycle.text         = "Status Update"
			_decision_panel.visible = false
			_stop_timer()
			_show_status_popup()
		"decision":
			_lbl_cycle.text = "Decision Phase"
			_hide_popup()
			_show_decision_panel()
		"execution":
			_lbl_cycle.text         = "Execution"
			_decision_panel.visible = false
			_stop_timer()

func _on_cycle_changed(round_num: int, is_day: bool) -> void:
	_lbl_round.text = "Round %d · %s" % [round_num, "Day" if is_day else "Night"]
	_lbl_round.add_theme_color_override("font_color",
		COL_ACCENT_DAY if is_day else COL_ACCENT_NIGHT)
	_bg.color = COL_BG_DAY if is_day else COL_BG_NIGHT

func _on_stats_updated(stats: Dictionary) -> void:
	_bar_energy.value = float(stats["energy"])
	_lbl_energy.text  = "%.0f" % float(stats["energy"])

	var det : float   = float(stats["detectability"])
	_bar_detect.value = det
	_lbl_detect.text  = "%.0f%%" % det
	var dc := COL_GREEN
	if det >= 60.0:   dc = COL_RED
	elif det >= 30.0: dc = COL_YELLOW
	_lbl_detect.add_theme_color_override("font_color", dc)
	_bar_detect.add_theme_stylebox_override("fill", _bar_fill_style(dc))

	var temp : float  = float(stats["temperature"])
	_bar_temp.value   = temp
	_lbl_temp.text    = "%.1f°" % temp
	var ts            := str(stats["temp_state"])
	var tc            := COL_GREEN
	if ts in ["SEVERE_HOT", "SEVERE_COLD"]:       tc = COL_ORANGE
	elif ts in ["MODERATE_HOT", "MODERATE_COLD"]: tc = COL_YELLOW
	_lbl_temp.add_theme_color_override("font_color", tc)

	var adip : float  = float(stats["adiposity"])
	_bar_adip.value   = adip
	_lbl_adip.text    = "%.0f" % adip
	var ws            := str(stats["weight_state"])
	var ac            := COL_GREEN
	if ws == "OBESE":                              ac = COL_ORANGE
	elif ws in ["OVERWEIGHT", "UNDERWEIGHT"]:      ac = COL_YELLOW
	_lbl_adip.add_theme_color_override("font_color", ac)

	_lbl_items.text = "🍞 %d   🛡 %d" % [int(stats["food_rations"]), int(stats["shields"])]

	var evs : Array = stats["active_events"]
	_lbl_events.text = ("⚠ " + "\n".join(evs)) if evs.size() > 0 else ""

func _on_event_triggered(event_name: String, message: String) -> void:
	_queue_popup("Event: " + event_name, "[color=#ffaa33]" + message + "[/color]")

func _on_action_result(result: Dictionary) -> void:
	var parts : Array[String] = []
	var de    := float(result["delta_energy"])
	var da    := float(result["delta_adiposity"])
	var dt    := float(result["delta_temp"])
	var dd    := float(result["delta_detect"])
	if de != 0.0: parts.append(("+" if de > 0 else "") + "%.0f Energy" % de)
	if da != 0.0: parts.append(("+" if da > 0 else "") + "%.0f Fat"    % da)
	if dt != 0.0: parts.append(("+" if dt > 0 else "") + "%.1f°"       % dt)
	if dd != 0.0: parts.append(("+" if dd > 0 else "") + "%.0f%% Det." % dd)
	for n in (result["notes"] as Array):
		parts.append(str(n))
	if parts.size() > 0:
		_show_feedback("  ".join(parts))

func _on_game_over(_reason: String, report: Dictionary) -> void:
	_decision_panel.visible = false
	_stop_timer()
	GM.last_report = report          # store report for GameOver scene to read
	get_tree().change_scene_to_file("res://GameOver.tscn")
	_show_gameover_popup(report)

func _on_item_gained(item_name: String) -> void:
	match item_name:
		"food_ration":          _show_feedback("Found food rations! 🍞")
		"predator_shield":      _show_feedback("Found a predator shield! 🛡")
		"food_ration_consumed": _show_feedback("Food rations saved the mouse! 🍞")
		"shield_consumed":      _show_feedback("Predator shield blocked the attack! 🛡")

func _on_forced_action(_act: String, reason: String) -> void:
	_queue_popup("Forced Action!", reason)

# ─────────────────────────────────────────────
# STATUS UPDATE POPUP
# ─────────────────────────────────────────────
func _show_status_popup() -> void:
	var stats  : Dictionary = GM.get_stats_dict()
	var rnd    : int        = int(stats["round"])
	var is_day : bool       = bool(stats["is_day"])
	var body   : String     = ""

	body += "[b]Round %d — %s[/b]\n\n" % [rnd, "Day" if is_day else "Night"]

	match str(stats["weight_state"]):
		"OBESE":
			body += "Weight: [color=#ff8833]Obese[/color] — +20%% detectability, slower cooling, may be forced to forage.\n"
		"OVERWEIGHT":
			body += "Weight: [color=#ffdd22]Overweight[/color] — +10%% detectability, slower cooling.\n"
		"MODERATE":
			body += "Weight: [color=#33ee66]Moderate[/color] — no changes.\n"
		"UNDERWEIGHT":
			body += "Weight: [color=#ffdd22]Underweight[/color] — -10%% detectability, extra energy drain.\n"
		_:
			body += "Weight: [color=#ff3333]STARVING![/color]\n"

	var temp : float = float(stats["temperature"])
	match str(stats["temp_state"]):
		"SEVERE_HOT":    body += "Temp: [color=#ff8833]Overheating %.1f°C[/color] — torpor incoming!\n"  % temp
		"MODERATE_HOT":  body += "Temp: [color=#ffdd22]Warm %.1f°C[/color] — foraging gains halved.\n"   % temp
		"AMBIENT":       body += "Temp: [color=#33ee66]Normal %.1f°C[/color]\n"                           % temp
		"MODERATE_COLD": body += "Temp: [color=#ffdd22]Cool %.1f°C[/color] — foraging gains halved.\n"   % temp
		"SEVERE_COLD":   body += "Temp: [color=#66aaff]Too cold %.1f°C[/color] — torpor incoming!\n"     % temp

	var evs : Array = stats["active_events"]
	if evs.size() > 0:
		body += "\n[b]Active events:[/b]\n"
		for ev in evs:
			body += "  • [color=#ffaa33]" + str(ev) + "[/color]\n"
	else:
		body += "\n[color=#888888]No events active.[/color]\n"

	if is_day:
		body += "\n[color=#ff9999]Day: predators more active.[/color]"

	_queue_popup("Round %d — %s" % [rnd, "Day" if is_day else "Night"], body, "Got it")

# ─────────────────────────────────────────────
# POPUP QUEUE
# ─────────────────────────────────────────────
func _queue_popup(title: String, body: String, btn_lbl: String = "OK") -> void:
	_popup_queue.append({"title": title, "body": body, "btn": btn_lbl})
	if not _popup_open:
		_next_popup()

func _next_popup() -> void:
	if _popup_queue.is_empty():
		_popup_open = false

		# Always move forward if we just finished a status popup
		if GM.current_phase == GM.Phase.STATUS_UPDATE:
			GM.begin_decision_phase()
  
		return
	_popup_open          = true
	var d : Dictionary   = _popup_queue.pop_front()
	_popup_title.text    = str(d["title"])
	_popup_body.text     = str(d["body"])
	_popup_btn.text      = str(d["btn"])
	_popup_panel.visible = true

func _hide_popup() -> void:
	_popup_panel.visible = false
	_popup_open          = false

func _on_popup_btn() -> void:
	_popup_panel.visible = false
	_popup_open = false

	# Force next phase
	if GM.current_phase == GM.Phase.STATUS_UPDATE:
		GM.begin_decision_phase()
	else:
		_next_popup()

# ─────────────────────────────────────────────
# DECISION PANEL
# ─────────────────────────────────────────────
func _show_decision_panel() -> void:
	_selected_idx  = -1
	var available  : Array = GM.get_available_actions()
	_decision_time = GM.get_decision_time()

	for i in range(_action_buttons.size()):
		var btn : Button = _action_buttons[i]
		if i < available.size():
			btn.visible = true
			btn.text    = _action_label(available[i])
			_style_action(btn, false)
		else:
			btn.visible = false

	_decision_panel.visible = true
	_start_timer()

func _action_label(action: int) -> String:
	match action:
		0: return "🌾 Forage\n+Fat  -Energy\n+Detect."
		1: return "🌾🌾 Super Forage\n++Fat  --Energy\n++Detect."
		2: return "🪵 Hide\n-Detect.  +Energy\n-Fat"
		3: return "😴 Rest\n+Energy  -Fat\n(skips night)"
		4: return "🌀 Torpor\n++Energy  reset temp\n---Fat  (4 cycles)"
	return "?"

func _on_action_pressed(idx: int) -> void:
	var available : Array = GM.get_available_actions()
	if idx >= available.size():
		return
	_selected_idx = idx
	for i in range(_action_buttons.size()):
		_style_action(_action_buttons[i], i == idx)

func _on_submit_pressed() -> void:
	print("!!! THE BUTTON WAS ACTUALLY CLICKED !!!")
	if _selected_idx < 0:
		_show_feedback("Select an action first!")
		return
	_stop_timer()
	var available : Array = GM.get_available_actions()
	GM.submit_action(available[_selected_idx])

# ─────────────────────────────────────────────
# DECISION TIMER
# ─────────────────────────────────────────────
func _start_timer() -> void:
	_time_left            = _decision_time
	_timer_bar.max_value  = _decision_time
	_timer_bar.value      = _decision_time
	_decision_timer.start()

func _stop_timer() -> void:
	_decision_timer.stop()

func _on_decision_tick() -> void:
	_time_left -= 0.1
	if _time_left <= 0.0:
		_time_left = 0.0
		_stop_timer()
		_lbl_timer.text = "0s"
		_show_feedback("Time's up! Picking randomly…")
		await get_tree().create_timer(0.9).timeout
		GM.submit_random_action()
		return

	_timer_bar.value = _time_left
	_lbl_timer.text  = "%ds" % int(ceil(_time_left))

	var ratio : float = _time_left / _decision_time
	var fc    : Color
	if ratio > 0.60:   fc = COL_T_GREEN
	elif ratio > 0.35: fc = COL_T_YELLOW
	elif ratio > 0.15: fc = COL_T_ORANGE
	else:              fc = COL_T_RED
	_timer_bar.add_theme_stylebox_override("fill", _bar_fill_style(fc))
	_lbl_timer.add_theme_color_override("font_color", fc)

# ─────────────────────────────────────────────
# FEEDBACK
# ─────────────────────────────────────────────
func _show_feedback(text: String) -> void:
	_lbl_feedback.text    = text
	_lbl_feedback.visible = true
	_feedback_timer.start()

func _on_feedback_timeout() -> void:
	_lbl_feedback.visible = false

func _build_debug_panel(vp: Vector2) -> void:
	_debug_panel          = PanelContainer.new()
	var style             := _panel_style(Color(0.05, 0.05, 0.10, 0.92), 8)
	style.border_width_left   = 1; style.border_width_right  = 1
	style.border_width_top    = 1; style.border_width_bottom = 1
	style.border_color        = Color(0.30, 0.60, 0.30)
	style.set_content_margin_all(10.0)
	_debug_panel.add_theme_stylebox_override("panel", style)
	_debug_panel.size         = Vector2(320, 200)
	_debug_panel.position     = Vector2(vp.x - 334, vp.y - 214)
	_debug_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_debug_panel)
 
	var vbox              := VBoxContainer.new()
	vbox.mouse_filter      = Control.MOUSE_FILTER_IGNORE
	_debug_panel.add_child(vbox)
 
	var title             := Label.new()
	title.text             = "🐾 Predation Debug"
	title.mouse_filter     = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.40, 1.00, 0.40))
	vbox.add_child(title)
 
	vbox.add_child(_make_hsep())
 
	_debug_log             = RichTextLabel.new()
	_debug_log.bbcode_enabled     = true
	_debug_log.fit_content        = false
	_debug_log.mouse_filter       = Control.MOUSE_FILTER_IGNORE
	_debug_log.custom_minimum_size = Vector2(300, 155)
	_debug_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_debug_log.add_theme_font_size_override("normal_font_size", 12)
	_debug_log.add_theme_color_override("default_color", Color(0.85, 0.85, 0.85))
	_debug_log.text = "No predation checks yet."
	vbox.add_child(_debug_log)
 
func _on_predation_debug(info: Dictionary) -> void:
	var eff    : float = float(info["effective"])
	var rolled : float = float(info["rolled"])
	var caught : bool  = bool(info["caught"])
 
	var result_col : String = "[color=#ff4444]CAUGHT[/color]" if caught \
						 else "[color=#33ee66]SAFE[/color]"
 
	var text : String = ""
	text += "[b]Round %d — %s[/b]\n" % [int(info["round"]), str(info["cycle"])]
	text += "Action: %s\n" % str(info["action"])
	text += "Raw detect:    [color=#aaaaff]%.1f%%[/color]\n" % float(info["raw_detect"])
	text += "Weight bonus:  [color=#ffdd22]%+.0f%%[/color]\n" % float(info["weight_bonus"])
	text += "Season boost:  [color=#ff8833]%+.0f%%[/color]\n" % float(info["season_boost"])
	text += "─────────────────────\n"
	text += "Effective:     [b]%.1f%%[/b]\n" % eff
	text += "Rolled:        %.1f  (need ≥ %.1f to survive)\n" % [rolled, eff]
	text += "Result:        %s\n" % result_col
 
	_debug_log.text = text

# ─────────────────────────────────────────────
# GAME OVER
# ─────────────────────────────────────────────
func _show_gameover_popup(report: Dictionary) -> void:
	_popup_queue.clear()
	_popup_open = false

	var body : String = ""
	body += "[b][color=#ff4444]GAME OVER[/color][/b]\n\n"
	body += "Cause: [b]" + str(report["cause_of_death"]) + "[/b]\n\n"
	body += "[i]" + str(report["science"]) + "[/i]\n\n"
	body += "Rounds survived: [b]%d[/b]\n\n" % int(report["rounds_survived"])
	var fs : Dictionary = report["final_stats"]
	body += "Energy %.0f  |  Fat %.0f  |  Temp %.1f°  |  Detect. %.0f%%\n\n" % [
		float(fs["energy"]),      float(fs["adiposity"]),
		float(fs["temperature"]), float(fs["detectability"])
	]
	body += "[color=#aaaaaa]Press the button below to play again.[/color]"

	_popup_title.text    = "Game Over — Round %d" % int(report["rounds_survived"])
	_popup_body.text     = body
	_popup_btn.text      = "▶ Play Again"
	_popup_panel.visible = true
	_popup_open          = true

	# Swap the button's action to restart — disconnect old, connect new safely
	if _popup_btn.pressed.is_connected(_on_popup_btn):
		_popup_btn.pressed.disconnect(_on_popup_btn)
	if not _popup_btn.pressed.is_connected(_on_play_again):
		_popup_btn.pressed.connect(_on_play_again)

func _on_play_again() -> void:
	_popup_panel.visible = false
	_popup_open          = false
	_popup_queue.clear()

	# Restore the normal popup button callback
	if _popup_btn.pressed.is_connected(_on_play_again):
		_popup_btn.pressed.disconnect(_on_play_again)
	if not _popup_btn.pressed.is_connected(_on_popup_btn):
		_popup_btn.pressed.connect(_on_popup_btn)

	_bg.color        = COL_BG_DAY
	_lbl_events.text = ""
	GM.start_new_game()

# ─────────────────────────────────────────────
# STYLE HELPERS
# ─────────────────────────────────────────────
func _panel_style(bg: Color, radius: int) -> StyleBoxFlat:
	var s          := StyleBoxFlat.new()
	s.bg_color      = bg
	s.corner_radius_top_left     = radius
	s.corner_radius_top_right    = radius
	s.corner_radius_bottom_left  = radius
	s.corner_radius_bottom_right = radius
	return s

func _bar_fill_style(col: Color) -> StyleBoxFlat:
	var s     := StyleBoxFlat.new()
	s.bg_color = col
	s.corner_radius_top_left     = 3
	s.corner_radius_top_right    = 3
	s.corner_radius_bottom_left  = 3
	s.corner_radius_bottom_right = 3
	return s

func _make_hsep() -> HSeparator:
	var s          := HSeparator.new()
	s.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	return s

func _style_action(btn: Button, selected: bool) -> void:
	var s := _panel_style(COL_BTN_ACTIVE if selected else COL_BTN, 8)
	s.set_content_margin_all(8.0)
	if selected:
		s.border_width_left   = 2; s.border_width_right  = 2
		s.border_width_top    = 2; s.border_width_bottom = 2
		s.border_color        = Color(0.60, 0.80, 1.00)
	btn.add_theme_stylebox_override("normal",  s)
	btn.add_theme_stylebox_override("pressed", s)
	btn.add_theme_stylebox_override("hover",   s)
	btn.add_theme_color_override("font_color", COL_TEXT)
	btn.add_theme_font_size_override("font_size", 12)

func _style_submit(btn: Button) -> void:
	var s := _panel_style(Color(0.25, 0.55, 0.95), 8)
	s.set_content_margin_all(8.0)
	btn.add_theme_stylebox_override("normal",  s)
	btn.add_theme_stylebox_override("pressed", s)
	btn.add_theme_stylebox_override("hover",   s)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 14)

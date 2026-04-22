# MainMenu.gd

extends Node2D

# ─────────────────────────────────────────────
# COLOURS  (matching Main.gd palette)
# ─────────────────────────────────────────────
const COL_BG           := Color(0.07, 0.07, 0.12)
const COL_PANEL        := Color(0.13, 0.13, 0.20, 0.95)
const COL_TEXT         := Color(0.95, 0.95, 0.90)
const COL_TEXT_DIM     := Color(0.60, 0.60, 0.56)
const COL_ACCENT       := Color(1.00, 0.85, 0.20)
const COL_ACCENT2      := Color(0.50, 0.70, 1.00)
const COL_BTN          := Color(0.20, 0.20, 0.30)
const COL_BTN_PLAY     := Color(0.25, 0.55, 0.95)
const COL_BTN_REPORTS  := Color(0.20, 0.35, 0.55)
const COL_RED          := Color(0.95, 0.25, 0.25)
const COL_GREEN        := Color(0.20, 0.85, 0.35)
const COL_ORANGE       := Color(1.00, 0.55, 0.10)

const GAME_SCENE       := "res://node_2d.tscn"   # ← change if your game scene has a different name

# ─────────────────────────────────────────────
# STATE
# ─────────────────────────────────────────────
var _overlay      : CanvasLayer
var _reports_open : bool = false

# Explanation windows
const EXPLANATION_PAGES : Array = [
	{
		"title": "1 / 4 — Rounds",
		"body":
"This game works in [b]rounds[/b]. Each round has a [color=#ffdd22]Day[/color] cycle and a [color=#66aaff]Night[/color] cycle.

[color=#ffdd22]Days[/color] are hotter. There are [color=#ff6666]more predators during the day[/color] (+10% detectability when foraging).
[color=#66aaff]Nights[/color] are cooler and safer.

Each cycle has three phases:
  • [b]Status Update[/b] — see how your mouse is doing and what events are active.
  • [b]Decision[/b] — choose what to do for this cycle. You have limited time!
  • [b]Execution[/b] — your choice plays out. Hope for the best."
	},
	{
		"title": "2 / 4 — Actions",
		"body":
"Each cycle you pick one action:

[b]Forage[/b] — Hunt for food. +Fat, -Energy, +Detectability.
[b]Hide[/b] — Stay out of sight. -Detectability, +Energy, -Fat.
[b]Rest[/b] — Sleep it off. +Energy, -Fat. Skips the next cycle.

From [b]Round 7[/b] two more actions unlock:
[b]Super Forage[/b] — Forage harder. ++Fat, --Energy, ++Detectability.
[b]Torpor[/b] — Deep hibernation. ++Energy, resets temperature, ---Fat. Skips 4 cycles.

You get [color=#33ee66]10 seconds[/color] to decide in early rounds, [color=#ffdd22]5 seconds[/color] from Round 4 onwards. If time runs out, an action is picked randomly!"
	},
	{
		"title": "3 / 4 — Bodily Needs",
		"body":
"Keep an eye on four stats in the top-left corner:

[color=#10ccf0]⚡ Energy[/color] (0–100) — Needed to act. Hits 0? Forced to rest.

[color=#33dd55]👁 Detectability[/color] (0–100%) — How visible you are. Too high? A predator may catch you. [color=#ff4444]Caught = Game Over.[/color]

[color=#ff8820]🌡 Temperature[/color] (32–42°C) — Stay near 37°C. Too hot or too cold forces torpor.
  • >40°C or <33°C: forced torpor.
  • 38–40°C or 33–36°C: foraging gains halved.

[color=#ffdd22]🫀 Fat / Adiposity[/color] (0–120) — Your energy reserve.
  • >100: Obese — slower, more visible, may be forced to forage.
  • 81–100: Overweight — more visible.
  • 31–80: Moderate — ideal.
  • 1–30: Underweight — less visible but drains energy faster.
  • 0: [color=#ff4444]Starvation — Game Over.[/color]"
	},
	{
		"title": "4 / 4 — Events & Items",
		"body":
"[b]Events[/b] occur at the start of rounds and shake things up:

  • [color=#ffaa33]Famine[/color] — less food when foraging.
  • [color=#ffaa33]Predator Season[/color] — more predators lurking.
  • More events unlock from Round 7 and Round 11 (Heatwave, Coldwave, Blooming Season, and others).
  • From Round 15, multiple events can be active at once!

[b]Items[/b] appear from Round 11 onwards (10% chance each round):

  [color=#ffdd22]🍞 Food Rations[/color] — Auto-consumed if you starve, saving you once.
  [color=#66aaff]🛡 Predator Shield[/color] — Auto-consumed if a predator catches you, letting you escape.

Good luck — your hypothalamus is counting on you!"
	}
]

var _current_page    : int  = 0
var _explanation_open: bool = false

# Explanation panel nodes
var _exp_panel  : PanelContainer
var _exp_title  : Label
var _exp_body   : RichTextLabel
var _exp_back   : Button
var _exp_next   : Button   # becomes "Begin" on last page
var _exp_skip   : Button

# Reports panel nodes
var _rep_panel      : PanelContainer
var _rep_list       : VBoxContainer
var _rep_sort_btn   : Button
var _rep_close_btn  : Button
var _rep_sort_by_rounds : bool = false   # default: newest first

# ─────────────────────────────────────────────
# READY
# ─────────────────────────────────────────────
func _ready() -> void:
	_build_scene()

# ─────────────────────────────────────────────
# SCENE BUILDER
# ─────────────────────────────────────────────
func _build_scene() -> void:
	var vp : Vector2 = get_viewport_rect().size

	# Background
	var bg              := ColorRect.new()
	bg.size              = vp
	bg.color             = COL_BG
	bg.mouse_filter      = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Subtle decorative circles (purely visual)
	_add_deco_circles(vp)

	# Main canvas layer
	var hud       := CanvasLayer.new()
	hud.layer      = 10
	add_child(hud)

	_overlay       = CanvasLayer.new()
	_overlay.layer = 20
	add_child(_overlay)

	_build_main_panel(hud, vp)
	_build_explanation_panel(vp)
	_build_reports_panel(vp)

func _add_deco_circles(vp: Vector2) -> void:
	# A few large soft-glowing circles in the background for atmosphere
	var positions : Array = [
		Vector2(vp.x * 0.15, vp.y * 0.20),
		Vector2(vp.x * 0.85, vp.y * 0.75),
		Vector2(vp.x * 0.75, vp.y * 0.15),
	]
	var colours : Array = [
		Color(0.25, 0.45, 0.90, 0.06),
		Color(0.90, 0.70, 0.10, 0.05),
		Color(0.20, 0.70, 0.40, 0.05),
	]
	for i in range(positions.size()):
		# We approximate a circle with a square ColorRect + corner radius
		var cr          := ColorRect.new()
		cr.size          = Vector2(340, 340)
		cr.position      = (positions[i] as Vector2) - Vector2(170, 170)
		cr.color         = colours[i]
		cr.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		add_child(cr)

# ── Main panel (centre) ───────────────────────────────────────────────────────
func _build_main_panel(hud: CanvasLayer, vp: Vector2) -> void:
	var panel         := PanelContainer.new()
	var style         := _panel_style(COL_PANEL, 18)
	style.border_width_left   = 1; style.border_width_right  = 1
	style.border_width_top    = 1; style.border_width_bottom = 1
	style.border_color        = Color(0.35, 0.35, 0.55)
	style.set_content_margin_all(40.0)
	panel.add_theme_stylebox_override("panel", style)
	panel.size      = Vector2(520, 440)
	panel.position  = Vector2((vp.x - 520) * 0.5, (vp.y - 440) * 0.5)
	hud.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "The Hunger Games"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", COL_ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	# Subtitle
	var sub := Label.new()
	sub.text = "Play as the brain of a mouse.\nSurvive by balancing bodily needs\nin an increasingly harsh environment."
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", COL_TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	sub.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sub)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	spacer.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(spacer)

	# Play button
	var btn_play := Button.new()
	btn_play.text               = "▶  Play"
	btn_play.custom_minimum_size = Vector2(280, 54)
	btn_play.mouse_filter       = Control.MOUSE_FILTER_STOP
	btn_play.pressed.connect(_on_play_pressed)
	_style_big_btn(btn_play, COL_BTN_PLAY)
	vbox.add_child(_centre_btn(btn_play))

	# Past Reports button
	var btn_rep := Button.new()
	btn_rep.text               = "📋  Past Reports"
	btn_rep.custom_minimum_size = Vector2(280, 44)
	btn_rep.mouse_filter       = Control.MOUSE_FILTER_STOP
	btn_rep.pressed.connect(_on_reports_pressed)
	_style_big_btn(btn_rep, COL_BTN_REPORTS)
	vbox.add_child(_centre_btn(btn_rep))

	# Footer / credit
	var footer := Label.new()
	footer.text = "Barik Labs · IISc CNS · Science Gallery"
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", Color(0.40, 0.40, 0.40))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(footer)

# ── Explanation panel ─────────────────────────────────────────────────────────
func _build_explanation_panel(vp: Vector2) -> void:
	_exp_panel          = PanelContainer.new()
	var style           := _panel_style(Color(0.12, 0.12, 0.20, 0.97), 16)
	style.border_width_left   = 2; style.border_width_right  = 2
	style.border_width_top    = 2; style.border_width_bottom = 2
	style.border_color        = Color(0.40, 0.40, 0.65)
	style.set_content_margin_all(28.0)
	_exp_panel.add_theme_stylebox_override("panel", style)
	_exp_panel.size         = Vector2(660, 480)
	_exp_panel.position     = Vector2((vp.x - 660) * 0.5, (vp.y - 480) * 0.5)
	_exp_panel.visible      = false
	_exp_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(_exp_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_exp_panel.add_child(vbox)

	_exp_title = Label.new()
	_exp_title.add_theme_font_size_override("font_size", 18)
	_exp_title.add_theme_color_override("font_color", COL_ACCENT)
	_exp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_exp_title.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_exp_title)

	var sep          := HSeparator.new()
	sep.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	_exp_body              = RichTextLabel.new()
	_exp_body.bbcode_enabled      = true
	_exp_body.fit_content         = false
	_exp_body.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	_exp_body.custom_minimum_size = Vector2(604, 310)
	_exp_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_exp_body.add_theme_font_size_override("normal_font_size", 14)
	_exp_body.add_theme_color_override("default_color", COL_TEXT)
	vbox.add_child(_exp_body)

	# Button row: Back | Skip (right-aligned) | Next/Begin
	var brow        := HBoxContainer.new()
	brow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brow.add_theme_constant_override("separation", 10)
	vbox.add_child(brow)

	_exp_back = Button.new()
	_exp_back.text               = "◀ Back"
	_exp_back.custom_minimum_size = Vector2(110, 36)
	_exp_back.mouse_filter       = Control.MOUSE_FILTER_STOP
	_exp_back.pressed.connect(_on_exp_back)
	_style_flat_btn(_exp_back, COL_BTN)
	brow.add_child(_exp_back)

	# Spacer pushes Skip and Next to right
	var mid              := Control.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	brow.add_child(mid)

	_exp_skip = Button.new()
	_exp_skip.text               = "Skip →"
	_exp_skip.custom_minimum_size = Vector2(90, 36)
	_exp_skip.mouse_filter       = Control.MOUSE_FILTER_STOP
	_exp_skip.pressed.connect(_on_exp_skip)
	_style_flat_btn(_exp_skip, COL_BTN)
	brow.add_child(_exp_skip)

	_exp_next = Button.new()
	_exp_next.text               = "Next ▶"
	_exp_next.custom_minimum_size = Vector2(110, 36)
	_exp_next.mouse_filter       = Control.MOUSE_FILTER_STOP
	_exp_next.pressed.connect(_on_exp_next)
	_style_big_btn(_exp_next, COL_BTN_PLAY)
	brow.add_child(_exp_next)

# ── Reports panel ─────────────────────────────────────────────────────────────
func _build_reports_panel(vp: Vector2) -> void:
	_rep_panel          = PanelContainer.new()
	var style           := _panel_style(Color(0.12, 0.12, 0.20, 0.97), 16)
	style.border_width_left   = 2; style.border_width_right  = 2
	style.border_width_top    = 2; style.border_width_bottom = 2
	style.border_color        = Color(0.40, 0.40, 0.65)
	style.set_content_margin_all(24.0)
	_rep_panel.add_theme_stylebox_override("panel", style)
	_rep_panel.size         = Vector2(620, 460)
	_rep_panel.position     = Vector2((vp.x - 620) * 0.5, (vp.y - 460) * 0.5)
	_rep_panel.visible      = false
	_rep_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(_rep_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_rep_panel.add_child(vbox)

	# Header row
	var hrow         := HBoxContainer.new()
	hrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hrow.add_theme_constant_override("separation", 10)
	vbox.add_child(hrow)

	var title := Label.new()
	title.text = "Past Reports"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", COL_ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	hrow.add_child(title)

	_rep_sort_btn                  = Button.new()
	_rep_sort_btn.text              = "Sort: Newest"
	_rep_sort_btn.custom_minimum_size = Vector2(120, 30)
	_rep_sort_btn.mouse_filter      = Control.MOUSE_FILTER_STOP
	_rep_sort_btn.pressed.connect(_on_rep_sort)
	_style_flat_btn(_rep_sort_btn, COL_BTN)
	hrow.add_child(_rep_sort_btn)

	vbox.add_child(_make_hsep())

	# Scrollable list
	var scroll            := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(572, 300)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter        = Control.MOUSE_FILTER_STOP
	vbox.add_child(scroll)

	_rep_list              = VBoxContainer.new()
	_rep_list.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_rep_list.add_theme_constant_override("separation", 6)
	_rep_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rep_list)

	vbox.add_child(_make_hsep())

	# Close button
	var br         := HBoxContainer.new()
	br.alignment    = BoxContainer.ALIGNMENT_CENTER
	br.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(br)

	_rep_close_btn                  = Button.new()
	_rep_close_btn.text              = "Close"
	_rep_close_btn.custom_minimum_size = Vector2(120, 36)
	_rep_close_btn.mouse_filter      = Control.MOUSE_FILTER_STOP
	_rep_close_btn.pressed.connect(_on_rep_close)
	_style_flat_btn(_rep_close_btn, COL_BTN)
	br.add_child(_rep_close_btn)

# ─────────────────────────────────────────────
# BUTTON HANDLERS
# ─────────────────────────────────────────────
func _on_play_pressed() -> void:
	# Show explanation first
	_current_page     = 0
	_explanation_open = true
	_exp_panel.visible = true
	_refresh_exp_page()

func _on_reports_pressed() -> void:
	_rep_panel.visible = true
	_refresh_reports_list()

# ── Explanation navigation ────────────────────────────────────────────────────
func _on_exp_back() -> void:
	if _current_page > 0:
		_current_page -= 1
		_refresh_exp_page()

func _on_exp_next() -> void:
	if _current_page < EXPLANATION_PAGES.size() - 1:
		_current_page += 1
		_refresh_exp_page()
	else:
		# Last page — Begin!
		_exp_panel.visible = false
		_launch_game()

func _on_exp_skip() -> void:
	_exp_panel.visible = false
	_launch_game()

func _refresh_exp_page() -> void:
	var page : Dictionary = EXPLANATION_PAGES[_current_page]
	_exp_title.text = str(page["title"])
	_exp_body.text  = str(page["body"])

	# Back button only visible from page 2 onward
	_exp_back.visible = _current_page > 0

	# Last page: Next becomes "Begin"
	if _current_page == EXPLANATION_PAGES.size() - 1:
		_exp_next.text = "Begin! ▶"
		_exp_skip.visible = false
	else:
		_exp_next.text    = "Next ▶"
		_exp_skip.visible = true

# ── Reports ───────────────────────────────────────────────────────────────────
func _on_rep_sort() -> void:
	_rep_sort_by_rounds = not _rep_sort_by_rounds
	_rep_sort_btn.text  = "Sort: Top Scores" if _rep_sort_by_rounds else "Sort: Newest"
	_refresh_reports_list()

func _on_rep_close() -> void:
	_rep_panel.visible = false

func _refresh_reports_list() -> void:
	# Clear existing entries
	for child in _rep_list.get_children():
		child.queue_free()

	var GM     : Node          = get_node("/root/GameManager")
	var reports: Array[Dictionary] = []
	if _rep_sort_by_rounds:
		reports = GM.get_reports_by_rounds()
	else:
		reports = GM.get_reports_by_date()

	if reports.is_empty():
		var empty := Label.new()
		empty.text         = "No reports yet. Play a game first!"
		empty.add_theme_color_override("font_color", Color(0.50, 0.50, 0.50))
		empty.add_theme_font_size_override("font_size", 14)
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_rep_list.add_child(empty)
		return

	for i in range(reports.size()):
		var r   : Dictionary = reports[i]
		var row := _make_report_row(i + 1, r)
		_rep_list.add_child(row)

func _make_report_row(rank: int, r: Dictionary) -> PanelContainer:
	var panel        := PanelContainer.new()
	var style        := _panel_style(Color(0.16, 0.16, 0.26), 8)
	style.set_content_margin_all(10.0)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hbox         := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	# Rank / number
	var num := Label.new()
	num.text = "#%d" % rank
	num.add_theme_font_size_override("font_size", 14)
	num.add_theme_color_override("font_color", COL_ACCENT)
	num.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	num.custom_minimum_size.x = 32
	hbox.add_child(num)

	# Name + cause
	var info_col        := VBoxContainer.new()
	info_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_col)

	var name_lbl := Label.new()
	var pname    : String = str(r.get("player_name", ""))
	name_lbl.text = pname if pname != "" else "(anonymous)"
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", COL_TEXT)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_col.add_child(name_lbl)

	var cause_lbl := Label.new()
	cause_lbl.text = str(r.get("cause_of_death", "Unknown"))
	cause_lbl.add_theme_font_size_override("font_size", 11)
	cause_lbl.add_theme_color_override("font_color", COL_RED)
	cause_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_col.add_child(cause_lbl)

	# Rounds + timestamp
	var right_col        := VBoxContainer.new()
	right_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_col.alignment    = BoxContainer.ALIGNMENT_END
	hbox.add_child(right_col)

	var rounds_lbl := Label.new()
	rounds_lbl.text = "Round %d" % int(r.get("rounds_survived", 0))
	rounds_lbl.add_theme_font_size_override("font_size", 14)
	rounds_lbl.add_theme_color_override("font_color", COL_GREEN)
	rounds_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rounds_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	right_col.add_child(rounds_lbl)

	var time_lbl := Label.new()
	time_lbl.text = str(r.get("timestamp", ""))
	time_lbl.add_theme_font_size_override("font_size", 10)
	time_lbl.add_theme_color_override("font_color", COL_TEXT_DIM)
	time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	right_col.add_child(time_lbl)

	return panel

# ─────────────────────────────────────────────
# LAUNCH GAME
# ─────────────────────────────────────────────
func _launch_game() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)

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

func _style_big_btn(btn: Button, bg: Color) -> void:
	var s := _panel_style(bg, 10)
	s.set_content_margin_all(10.0)
	var hover := _panel_style(bg.lightened(0.15), 10)
	hover.set_content_margin_all(10.0)
	btn.add_theme_stylebox_override("normal",  s)
	btn.add_theme_stylebox_override("pressed", s)
	btn.add_theme_stylebox_override("hover",   hover)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 16)

func _style_flat_btn(btn: Button, bg: Color) -> void:
	var s := _panel_style(bg, 8)
	s.set_content_margin_all(8.0)
	var hover := _panel_style(bg.lightened(0.15), 8)
	hover.set_content_margin_all(8.0)
	btn.add_theme_stylebox_override("normal",  s)
	btn.add_theme_stylebox_override("pressed", s)
	btn.add_theme_stylebox_override("hover",   hover)
	btn.add_theme_color_override("font_color", COL_TEXT)
	btn.add_theme_font_size_override("font_size", 13)

func _centre_btn(btn: Button) -> HBoxContainer:
	var row        := HBoxContainer.new()
	row.alignment   = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(btn)
	return row

func _make_hsep() -> HSeparator:
	var s          := HSeparator.new()
	s.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	return s

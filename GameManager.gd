# GameManager.gd

extends Node

# ─────────────────────────────────────────────
# SIGNALS
# ─────────────────────────────────────────────
signal phase_changed(phase: String)
signal cycle_changed(round_num: int, is_day: bool)
signal stats_updated(stats: Dictionary)
signal event_triggered(event_name: String, message: String)
signal action_result(result: Dictionary)
signal game_over(reason: String, report: Dictionary)
signal item_gained(item_name: String)
signal forced_action(action: String, reason: String)
# debugging lines
signal predation_debug(info: Dictionary)   # ← debug signal for UI to display
var debug_no_predation : bool = false   # FIND set false to enable detectability; true to disable

# ─────────────────────────────────────────────
# ENUMS
# ─────────────────────────────────────────────
enum Phase       { STATUS_UPDATE, DECISION, EXECUTION }
enum WeightState { OBESE, OVERWEIGHT, MODERATE, UNDERWEIGHT, STARVED }
enum TempState   { SEVERE_HOT, MODERATE_HOT, AMBIENT, MODERATE_COLD, SEVERE_COLD }
enum Action      { FORAGE, SUPER_FORAGE, HIDE, REST, TORPOR, NONE }

# ─────────────────────────────────────────────
# CONSTANTS
# ─────────────────────────────────────────────
const ENERGY_MIN          : float = 0.0
const ENERGY_MAX          : float = 100.0
const ENERGY_START        : float = 50.0
const DETECT_MIN          : float = 0.0
const DETECT_MAX          : float = 100.0
const TEMP_MIN            : float = 32.0
const TEMP_MAX            : float = 42.0
const TEMP_BASE           : float = 37.0
const ADIPOSITY_MIN       : float = 0.0
const ADIPOSITY_MAX       : float = 120.0
const ADIPOSITY_START     : float = 55.0
const DECISION_TIME_EARLY : float = 10.0
const DECISION_TIME_LATE  : float = 5.0

# ─────────────────────────────────────────────
# DEBUG FLAG — set false to silence predation logs
# ─────────────────────────────────────────────
var debug_predation : bool = true

# ─────────────────────────────────────────────
# GAME STATE
# ─────────────────────────────────────────────
var round_number       : int   = 1
var is_day             : bool  = true
var current_phase      : Phase = Phase.STATUS_UPDATE

var energy             : float = ENERGY_START
var detectability      : float = 0.0   # raw — weight/season added dynamically
var temperature        : float = TEMP_BASE
var adiposity          : float = ADIPOSITY_START

var food_rations       : int   = 0
var predator_shields   : int   = 0

var active_events      : Array[String] = []
var event_durations    : Dictionary    = {}

var temp_drift_per_cycle   : float = 0.0
var temp_drift_rounds_left : int   = 0

var is_forced_rest     : bool = false
var is_forced_torpor   : bool = false
var is_forced_forage   : bool = false
var forced_skip_cycles : int  = 0

var session_reports    : Array[Dictionary] = []
var rounds_survived    : int  = 0
var decisions_log      : Array[Dictionary] = []
var chosen_action      : Action = Action.NONE

var last_report : Dictionary = {}

# ─────────────────────────────────────────────
# EFFECTIVE DETECTABILITY
# Raw detectability + weight bonus + predator season boost.
# This is what the UI shows and what predation rolls use.
# Never permanently written back to raw detectability.
# ─────────────────────────────────────────────
func _get_weight_detect_bonus() -> float:
	match get_weight_state():
		WeightState.OBESE:       return 20.0
		WeightState.OVERWEIGHT:  return 10.0
		WeightState.UNDERWEIGHT: return -10.0
	return 0.0

func get_effective_detectability() -> float:
	return clamp(detectability + _get_weight_detect_bonus() + _get_predator_season_detect_boost(),
		DETECT_MIN, DETECT_MAX)

# ─────────────────────────────────────────────
# NEW GAME
# ─────────────────────────────────────────────
func start_new_game() -> void:
	round_number           = 1
	is_day                 = true
	current_phase          = Phase.STATUS_UPDATE
	energy                 = ENERGY_START
	detectability          = 0.0
	temperature            = TEMP_BASE
	adiposity              = ADIPOSITY_START
	food_rations           = 0
	predator_shields       = 0
	active_events.clear()
	event_durations.clear()
	temp_drift_per_cycle   = 0.0
	temp_drift_rounds_left = 0
	is_forced_rest         = false
	is_forced_torpor       = false
	is_forced_forage       = false
	forced_skip_cycles     = 0
	rounds_survived        = 0
	decisions_log.clear()
	chosen_action          = Action.NONE

	_apply_round_base_detect()
	emit_signal("cycle_changed", round_number, is_day)
	begin_status_update()

# ─────────────────────────────────────────────
# STATUS UPDATE PHASE
# ─────────────────────────────────────────────
func begin_status_update() -> void:
	current_phase = Phase.STATUS_UPDATE

	# No events on round 1  (change #2)
	if is_day and round_number > 1:
		_tick_event_durations()
		_roll_events()
		_try_grant_item()

	if temp_drift_rounds_left > 0:
		temperature            = clamp(temperature + temp_drift_per_cycle, TEMP_MIN, TEMP_MAX)
		temp_drift_rounds_left -= 1
		if temp_drift_rounds_left == 0:
			temp_drift_per_cycle = 0.0

	_evaluate_forced_conditions()
	emit_signal("stats_updated", get_stats_dict())
	emit_signal("phase_changed", "status_update")

# ─────────────────────────────────────────────
# DECISION PHASE
# ─────────────────────────────────────────────
func begin_decision_phase() -> void:
	current_phase = Phase.DECISION

	if forced_skip_cycles > 0:
		forced_skip_cycles -= 1
		chosen_action = Action.NONE
		begin_execution_phase()
		return

	if is_forced_forage:
		is_forced_forage = false
		emit_signal("forced_action", "forage",
			"Your mouse's appetite is overpowering — it must forage!")
		chosen_action = Action.FORAGE
		begin_execution_phase()
		return

	if is_forced_rest:
		is_forced_rest = false
		emit_signal("forced_action", "rest",
			"Your mouse is exhausted — forced to rest.")
		chosen_action = Action.REST
		_apply_forced_rest()
		return

	if is_forced_torpor:
		is_forced_torpor = false
		emit_signal("forced_action", "torpor",
			"Your mouse's temperature is critical — entering torpor!")
		chosen_action = Action.TORPOR
		_apply_torpor()
		return

	emit_signal("phase_changed", "decision")

func submit_action(action: Action) -> void:
	chosen_action = action
	begin_execution_phase()

func submit_random_action() -> void:
	var available : Array[Action] = get_available_actions()
	submit_action(available[randi() % available.size()])

# ─────────────────────────────────────────────
# EXECUTION PHASE
# ─────────────────────────────────────────────
func begin_execution_phase() -> void:
	current_phase = Phase.EXECUTION

	var result : Dictionary = _apply_action(chosen_action)
	_clamp_stats()

	emit_signal("action_result", result)
	emit_signal("stats_updated", get_stats_dict())
	emit_signal("phase_changed", "execution")

	decisions_log.append({
		"round":  round_number,
		"cycle":  "Day" if is_day else "Night",
		"action": Action.keys()[chosen_action],
		"result": result
	})

	if _check_game_over(result):
		return
	_advance_cycle()

# ─────────────────────────────────────────────
# ACTION APPLICATION
# ─────────────────────────────────────────────
func _apply_action(action: Action) -> Dictionary:
	var result : Dictionary = {
		"action":          Action.keys()[action],
		"delta_energy":    0.0,
		"delta_adiposity": 0.0,
		"delta_temp":      0.0,
		"delta_detect":    0.0,
		"notes":           []
	}

	var forage_adip_mult   : float = _get_forage_adiposity_mult()
	var forage_energy_mult : float = _get_forage_energy_mult()

	match action:
		Action.FORAGE:
			var adip_gain : float = 10.0 * forage_adip_mult
			var ts        : TempState = get_temp_state()
			if ts == TempState.MODERATE_HOT or ts == TempState.MODERATE_COLD:
				adip_gain *= 0.5
				(result["notes"] as Array).append("Moderate temp stress: fat gain halved.")
			elif ts == TempState.SEVERE_HOT or ts == TempState.SEVERE_COLD:
				adip_gain *= 0.5
				(result["notes"] as Array).append("Severe temp stress: fat gain halved.")
			result["delta_adiposity"] = adip_gain
			result["delta_energy"]    = -10.0 * forage_energy_mult
			result["delta_temp"]      = 0.5
			result["delta_detect"]    = 10.0
			if is_day:
				result["delta_detect"] = float(result["delta_detect"]) + 5.0
				(result["notes"] as Array).append("Day: +5% extra detectability.")

		Action.SUPER_FORAGE:
			# Change #5: adiposity +30 (was +20)
			var adip_gain : float = 30.0 * forage_adip_mult
			if get_temp_state() != TempState.AMBIENT:
				adip_gain *= 0.5
				(result["notes"] as Array).append("Temp stress: fat gain halved.")
			result["delta_adiposity"] = adip_gain
			result["delta_energy"]    = -20.0 * forage_energy_mult
			result["delta_temp"]      = 1.0
			result["delta_detect"]    = 20.0
			if is_day:
				result["delta_detect"] = float(result["delta_detect"]) + 5.0

		Action.HIDE:
			# Change #5: reduce EFFECTIVE detectability by 75% rather than random flat amount
			var eff_before : float = get_effective_detectability()
			var reduction  : float = eff_before * 0.75
			# We want raw detectability to drop such that effective drops by 75%.
			# Since effective = raw + bonuses, reducing raw by the same amount
			# reduces effective by the same amount (bonuses don't change).
			detectability = clamp(detectability - reduction, DETECT_MIN, DETECT_MAX)
			result["delta_detect"]    = -reduction   # informational only; already applied above
			result["delta_energy"]    = 5.0
			result["delta_temp"]      = -0.25
			result["delta_adiposity"] = -5.0
			(result["notes"] as Array).append(
				"Hid: effective detectability reduced by 75%% (–%.0f%%)." % reduction)

		Action.REST:
			# Change #4: energy +15 (was +10)
			result["delta_energy"]    = 15.0
			result["delta_temp"]      = -0.5
			result["delta_adiposity"] = -10.0
			forced_skip_cycles        = 1

		Action.TORPOR:
			_apply_torpor()
			return result

		Action.NONE:
			pass

	# Apply deltas (HIDE already applied detectability above; others go through here)
	energy      = clamp(energy      + float(result["delta_energy"]),    ENERGY_MIN,    ENERGY_MAX)
	adiposity   = clamp(adiposity   + float(result["delta_adiposity"]), ADIPOSITY_MIN, ADIPOSITY_MAX)
	temperature = clamp(temperature + float(result["delta_temp"]),      TEMP_MIN,      TEMP_MAX)

	if action != Action.HIDE:   # HIDE already applied its detect change directly
		detectability = clamp(detectability + float(result["delta_detect"]), DETECT_MIN, DETECT_MAX)

	_add_weight_notes(result)
	return result

func _add_weight_notes(result: Dictionary) -> void:
	match get_weight_state():
		WeightState.OBESE:
			(result["notes"] as Array).append("Obese: +20% effective detectability.")
		WeightState.OVERWEIGHT:
			(result["notes"] as Array).append("Overweight: +10% effective detectability.")
		WeightState.UNDERWEIGHT:
			(result["notes"] as Array).append("Underweight: –10% effective detectability, extra energy drain.")
			energy = clamp(energy - 10.0, ENERGY_MIN, ENERGY_MAX)

func _apply_torpor() -> void:
	# Change : energy +30 (was +20), adiposity –20 (was –30)
	energy        = clamp(energy    + 30.0, ENERGY_MIN,    ENERGY_MAX)
	adiposity     = clamp(adiposity - 20.0, ADIPOSITY_MIN, ADIPOSITY_MAX)
	temperature   = TEMP_BASE
	detectability = 0.0
	forced_skip_cycles = 3

func _apply_forced_rest() -> void:
	# Change : energy +15 (was +10)
	energy        = clamp(energy      + 15.0, ENERGY_MIN,    ENERGY_MAX)
	temperature   = clamp(temperature -  0.5, TEMP_MIN,      TEMP_MAX)
	adiposity     = clamp(adiposity   - 10.0, ADIPOSITY_MIN, ADIPOSITY_MAX)
	forced_skip_cycles = 1
	_clamp_stats()
	emit_signal("stats_updated", get_stats_dict())
	emit_signal("phase_changed", "execution")
	var dummy : Dictionary = {}
	if _check_game_over(dummy):
		return
	_advance_cycle()

# ─────────────────────────────────────────────
# GAME OVER — predation uses effective detectability
# ─────────────────────────────────────────────
func _check_game_over(result: Dictionary) -> bool:
	# Starvation
	if adiposity <= ADIPOSITY_MIN:
		if food_rations > 0:
			food_rations -= 1
			adiposity     = 50.0
			emit_signal("item_gained", "food_ration_consumed")
			return false
		_trigger_game_over("starvation", result)
		return true

	# Predation
	var eff : float = 0.0 
	if not debug_no_predation:
		eff = get_effective_detectability()

	var rolled : float = randf() * 100.0          # 0–100
	var caught : bool  = rolled < eff

	if debug_predation:
		emit_signal("predation_debug", {
			"round":          round_number,
			"cycle":          "Day" if is_day else "Night",
			"action":         Action.keys()[chosen_action],
			"raw_detect":     detectability,
			"weight_bonus":   _get_weight_detect_bonus(),
			"season_boost":   _get_predator_season_detect_boost(),
			"effective":      eff,
			"rolled":         rolled,
			"threshold":      eff,
			"caught":         caught
		})

	if eff > 0.0 and caught:
		if predator_shields > 0:
			predator_shields -= 1
			detectability     = clamp(detectability - 30.0, DETECT_MIN, DETECT_MAX)
			emit_signal("item_gained", "shield_consumed")
			return false
		_trigger_game_over("predation", result)
		return true

	return false

func _trigger_game_over(reason: String, result: Dictionary) -> void:
	rounds_survived = round_number
	emit_signal("game_over", reason, _build_report(reason, result))

func _build_report(death_reason: String, _last_result: Dictionary) -> Dictionary:
	var cause_text   : String = ""
	var science_text : String = ""
	match death_reason:
		"starvation":
			cause_text   = "Starvation"
			science_text = "Your adiposity (fat) hit 0. No energy stores remained. [Placeholder: AgRP neuron science]"
		"predation":
			if get_weight_state() == WeightState.OBESE:
				cause_text   = "Predation (driven by obesity)"
				science_text = "Adiposity was %.0f (obese). AgRP neurons drove foraging when hiding was safer. [Placeholder]" % adiposity
			elif active_events.has("Predator Season"):
				cause_text   = "Predation (predator season)"
				science_text = "More predators were active. The brain misjudged danger. [Placeholder]"
			else:
				cause_text   = "Predation (bad luck)"
				science_text = "Sometimes life doesn't work even when you've done everything right. [Placeholder]"
	return {
		"player_name":     "",
		"rounds_survived": rounds_survived,
		"cause_of_death":  cause_text,
		"science":         science_text,
		"final_stats": {
			"energy":        energy,
			"detectability": get_effective_detectability(),
			"temperature":   temperature,
			"adiposity":     adiposity
		},
		"decisions_log": decisions_log.duplicate(),
		"timestamp":     Time.get_datetime_string_from_system()
	}

func save_report(report: Dictionary, player_name: String) -> void:
	report["player_name"] = player_name
	session_reports.append(report)

# ─────────────────────────────────────────────
# FORCED CONDITIONS
# ─────────────────────────────────────────────
func _evaluate_forced_conditions() -> void:
	if energy <= ENERGY_MIN:
		is_forced_rest = true
	var ts : TempState = get_temp_state()
	if ts == TempState.SEVERE_HOT or ts == TempState.SEVERE_COLD:
		is_forced_torpor = true
	if is_day and get_weight_state() == WeightState.OBESE and randf() < 0.5:
		is_forced_forage = true

# ─────────────────────────────────────────────
# CYCLE / ROUND ADVANCEMENT
# ─────────────────────────────────────────────
func _advance_cycle() -> void:
	if is_day:
		is_day = false
		emit_signal("cycle_changed", round_number, false)
		begin_status_update()
	else:
		round_number += 1
		is_day        = true
		_apply_round_base_detect()
		emit_signal("cycle_changed", round_number, true)
		begin_status_update()

func _apply_round_base_detect() -> void:
	var base : float = _get_base_detect_floor()
	if detectability < base:
		detectability = base

func _get_base_detect_floor() -> float:
	# Change #1:
	# Day:   5% at round 1 → 10% by round 10 → 15% by round 20
	# Night: 0% at round 1 →  5% by round 10 → 10% by round 20
	var progress : float = clamp(float(round_number - 1) / 19.0, 0.0, 1.0)
	if is_day:
		return lerp(5.0, 15.0, progress)
	return lerp(0.0, 10.0, progress)

# ─────────────────────────────────────────────
# EVENTS
# ─────────────────────────────────────────────
func _tick_event_durations() -> void:
	var to_remove : Array[String] = []
	for ev : String in event_durations.keys():
		event_durations[ev] = int(event_durations[ev]) - 1
		if int(event_durations[ev]) <= 0:
			to_remove.append(ev)
	for ev : String in to_remove:
		event_durations.erase(ev)
		active_events.erase(ev)

func _roll_events() -> void:
	_try_event("Famine",          0.15)
	_try_event("Extreme Famine",  0.05,  11)
	_try_event("Predator Season", _predator_season_chance())
	_try_event("Heatwave",        0.10,  7)
	_try_event("Coldwave",        0.10,  7)
	_try_event("Competitors",     0.10,  11)
	_try_event("Blooming Season", 0.10,  11)
	_try_event("Tribe Support",   0.03,  11)

func _predator_season_chance() -> float:
	return lerp(0.10, 0.30, clamp(float(round_number - 1) / 19.0, 0.0, 1.0))

func _try_event(event_name: String, chance: float, min_round: int = 1) -> void:
	if round_number < min_round or active_events.has(event_name):
		return
	var exclusions : Dictionary = {
		"Famine":         ["Blooming Season"],
		"Extreme Famine": ["Blooming Season"],
		"Blooming Season":["Famine", "Extreme Famine"],
		"Heatwave":       ["Coldwave"],
		"Coldwave":       ["Heatwave"]
	}
	if exclusions.has(event_name):
		for excl : String in (exclusions[event_name] as Array):
			if active_events.has(excl):
				return
	if randf() < chance:
		active_events.append(event_name)
		_apply_event_effect(event_name)
		emit_signal("event_triggered", event_name, _get_event_message(event_name))

func _get_event_message(event_name: String) -> String:
	match event_name:
		"Famine":          return "Food is getting harder to come by these days…"
		"Extreme Famine":  return "Where's all the food?"
		"Predator Season": return "Feels like something's looking to get me…"
		"Heatwave":        return "The world decided to get a bit too hot suddenly."
		"Coldwave":        return "The world decided to get a bit too cold suddenly."
		"Competitors":     return "Is it just me, or is it getting crowded in here?"
		"Blooming Season": return "Rejoice! There's so much food everywhere!"
		"Tribe Support":   return "There is strength in numbers."
	return ""

func _apply_event_effect(event_name: String) -> void:
	match event_name:
		"Heatwave":
			var d : int = randi_range(3, 5)
			temp_drift_per_cycle   =  0.3
			temp_drift_rounds_left = d * 2
			event_durations["Heatwave"] = d
		"Coldwave":
			var d : int = randi_range(3, 5)
			temp_drift_per_cycle   = -0.3
			temp_drift_rounds_left = d * 2
			event_durations["Coldwave"] = d
		"Tribe Support":
			food_rations += 1
			emit_signal("item_gained", "food_ration")
			event_durations["Tribe Support"] = randi_range(1, 2)
		_:
			event_durations[event_name] = randi_range(1, 2)

func _get_forage_adiposity_mult() -> float:
	if active_events.has("Extreme Famine"):  return 0.25
	if active_events.has("Famine"):          return 0.5
	if active_events.has("Blooming Season"): return 1.5
	if active_events.has("Tribe Support"):   return 1.25
	return 1.0

func _get_forage_energy_mult() -> float:
	if active_events.has("Competitors"):   return 1.5
	if active_events.has("Tribe Support"): return 0.75
	return 1.0

func _get_predator_season_detect_boost() -> float:
	# Change #3: boost is now 10–30% (was 30–60%), skewed by round number
	if not active_events.has("Predator Season"):
		return 0.0
	return lerp(10.0, 30.0, clamp(float(round_number - 1) / 19.0, 0.0, 1.0))

# ─────────────────────────────────────────────
# ITEMS
# ─────────────────────────────────────────────
func _try_grant_item() -> void:
	if round_number < 11 or randf() >= 0.10:
		return
	if randf() < 0.5:
		food_rations     += 1
		emit_signal("item_gained", "food_ration")
	else:
		predator_shields += 1
		emit_signal("item_gained", "predator_shield")

# ─────────────────────────────────────────────
# STATE HELPERS
# ─────────────────────────────────────────────
func get_weight_state() -> WeightState:
	if adiposity > 100.0: return WeightState.OBESE
	if adiposity > 80.0:  return WeightState.OVERWEIGHT
	if adiposity > 30.0:  return WeightState.MODERATE
	if adiposity > 0.0:   return WeightState.UNDERWEIGHT
	return WeightState.STARVED

func get_temp_state() -> TempState:
	if temperature > 40.0:  return TempState.SEVERE_HOT
	if temperature > 38.0:  return TempState.MODERATE_HOT
	if temperature >= 36.5: return TempState.AMBIENT
	if temperature > 33.0:  return TempState.MODERATE_COLD
	return TempState.SEVERE_COLD

func get_available_actions() -> Array[Action]:
	var actions : Array[Action] = [Action.FORAGE, Action.HIDE, Action.REST]
	if round_number >= 7:
		actions.append(Action.SUPER_FORAGE)
		actions.append(Action.TORPOR)
	return actions

func get_decision_time() -> float:
	return DECISION_TIME_EARLY if round_number <= 3 else DECISION_TIME_LATE

func _clamp_stats() -> void:
	energy        = clamp(energy,        ENERGY_MIN,    ENERGY_MAX)
	detectability = clamp(detectability, DETECT_MIN,    DETECT_MAX)
	temperature   = clamp(temperature,   TEMP_MIN,      TEMP_MAX)
	adiposity     = clamp(adiposity,     ADIPOSITY_MIN, ADIPOSITY_MAX)

func get_stats_dict() -> Dictionary:
	return {
		"round":         round_number,
		"is_day":        is_day,
		"energy":        energy,
		"detectability": get_effective_detectability(),
		"temperature":   temperature,
		"adiposity":     adiposity,
		"weight_state":  WeightState.keys()[get_weight_state()],
		"temp_state":    TempState.keys()[get_temp_state()],
		"food_rations":  food_rations,
		"shields":       predator_shields,
		"active_events": active_events.duplicate(),
		"phase":         Phase.keys()[current_phase]
	}

func get_reports_by_rounds() -> Array[Dictionary]:
	var sorted : Array[Dictionary] = session_reports.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["rounds_survived"]) > int(b["rounds_survived"])
	)
	return sorted

func get_reports_by_date() -> Array[Dictionary]:
	return session_reports.duplicate()

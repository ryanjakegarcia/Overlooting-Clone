class_name CombatEngine
extends RefCounted

const _Enemy = preload("res://scripts/core/Enemy.gd")

enum Phase { PLAYER_TURN, ENEMY_TURN, DONE }

var _hero       = null  # HeroStats
var _run_state  = null  # RunState
var _enemies: Array = []
var _enemy_defs: Array = []
var _phase: int = Phase.PLAYER_TURN

signal phase_changed(phase: int)
signal damage_dealt(target, amount: float, is_crit: bool, dtype: String)
signal hero_damaged(amount: float, dtype: String)
signal hero_healed(amount: float)
signal status_applied(target, stype: String, stacks: int)
signal enemy_died(enemy)
signal enemy_added(enemy)
signal combat_won
signal combat_lost
signal log_added(text: String)

func _init(run_state, start_enemies: Array, enemy_defs: Array) -> void:
	_run_state = run_state
	_hero = run_state.hero_stats
	_enemy_defs = enemy_defs
	for e in start_enemies:
		_add_enemy(e)

func start() -> void:
	_phase = Phase.PLAYER_TURN
	phase_changed.emit(_phase)
	log_added.emit("Combat begins!")

func get_phase() -> int:
	return _phase

func get_living_enemies() -> Array:
	var result: Array = []
	for e in _enemies:
		if not e.is_dead():
			result.append(e)
	return result

func get_all_enemies() -> Array:
	return _enemies

# ── Player Actions ─────────────────────────────────────────────────────────────

func player_attack(target_idx: int) -> void:
	if _phase != Phase.PLAYER_TURN:
		return
	var living: Array = get_living_enemies()
	if living.is_empty():
		return
	var idx: int = clampi(target_idx, 0, living.size() - 1)
	var target = living[idx]

	_do_hero_attack(target)
	if _check_win():
		return

	if _hero.roll_swiftness():
		var second_target = target if not target.is_dead() else _first_living()
		if second_target != null:
			_do_hero_attack(second_target)
			if _check_win():
				return

	_end_player_turn()

func player_defend() -> void:
	if _phase != Phase.PLAYER_TURN:
		return
	var gain: float = _hero.armor * 1.5 + _hero.defend_bonus_barrier
	_hero.barrier += gain
	_hero.changed.emit()
	log_added.emit("You brace — gain %.0f barrier" % gain)
	_end_player_turn()

func player_use_potion(slot_idx: int, target_idx: int = 0) -> void:
	if _phase != Phase.PLAYER_TURN:
		return
	if slot_idx >= _run_state.potions.size():
		return
	var potion: Dictionary = _run_state.potions[slot_idx]
	if potion.is_empty():
		return

	match potion.get("type", ""):
		"health":
			var amount: float = _hero.max_hp * 0.25
			_hero.heal(amount)
			hero_healed.emit(amount)
			log_added.emit("Health Potion restores %.0f HP" % amount)
		"wound_vial":
			var living: Array = get_living_enemies()
			if not living.is_empty():
				var idx: int = clampi(target_idx, 0, living.size() - 1)
				var target = living[idx]
				var stacks: int = 4
				if _hero.royal_t1:
					stacks += 1
				target.add_status("wound", stacks)
				status_applied.emit(target, "wound", stacks)
				log_added.emit("Wound Vial — %s takes %d Wound stacks" % [target.display_name, stacks])

	_run_state.potions[slot_idx] = {}

# ── Turn Flow ──────────────────────────────────────────────────────────────────

func _end_player_turn() -> void:
	_phase = Phase.ENEMY_TURN
	phase_changed.emit(_phase)
	_run_enemy_turns()

func _run_enemy_turns() -> void:
	# Hero poison ticks first
	if _hero.poison_stacks > 0:
		var pdmg: float = float(_hero.poison_stacks) * 2.0
		_hero.hp = maxf(0.0, _hero.hp - pdmg)
		_hero.poison_stacks = maxi(0, _hero.poison_stacks - 1)
		_hero.changed.emit()
		hero_damaged.emit(pdmg, "poison")
		log_added.emit("Poison deals %.0f damage to you (%d stacks left)" % [pdmg, _hero.poison_stacks])
		if _hero.is_dead():
			combat_lost.emit()
			_phase = Phase.DONE
			return

	for enemy in _enemies.duplicate():
		if enemy.is_dead():
			continue

		# Enemy poison tick
		var pdmg: float = enemy.tick_poison()
		if pdmg > 0.0:
			damage_dealt.emit(enemy, pdmg, false, "poison")
			log_added.emit("Poison deals %.0f to %s" % [pdmg, enemy.display_name])
			if enemy.is_dead():
				continue

		_execute_enemy_intent(enemy)

		if _hero.is_dead():
			combat_lost.emit()
			_phase = Phase.DONE
			return

	# All enemies advance intent for next round
	for enemy in _enemies:
		if not enemy.is_dead():
			enemy.advance_intent()

	_phase = Phase.PLAYER_TURN
	phase_changed.emit(_phase)

func _execute_enemy_intent(enemy) -> void:
	var intent = enemy.current_intent
	if intent == null:
		return

	match intent.type:
		_Enemy.IntentType.ATTACK:
			var dmg: float = float(intent.value)
			if enemy.is_boss:
				dmg += float(_count_living_saplings()) * 3.0
			var actual: float
			if enemy.is_charging:
				enemy.is_charging = false
				actual = _hero.take_hit_piercing(dmg)
				log_added.emit("%s CRASHES for %.0f (piercing)!" % [enemy.display_name, actual])
			else:
				actual = _hero.take_hit(dmg)
				log_added.emit("%s — %s — deals %.0f" % [enemy.display_name, intent.label, actual])
			_hero.add_rage(1)
			hero_damaged.emit(actual, "physical")

		_Enemy.IntentType.DEFEND:
			enemy.armor += float(intent.value)
			log_added.emit("%s — %s — gains %d armor" % [enemy.display_name, intent.label, intent.value])

		_Enemy.IntentType.CHARGE:
			enemy.is_charging = true
			enemy.charge_value = intent.value
			log_added.emit("%s — %s!" % [enemy.display_name, intent.label])

		_Enemy.IntentType.POISON_ATTACK:
			var dmg: float = float(intent.value)
			var actual: float = _hero.take_hit(dmg)
			_hero.add_rage(1)
			hero_damaged.emit(actual, "physical")
			if intent.poison_stacks > 0:
				_hero.poison_stacks += intent.poison_stacks
				_hero.changed.emit()
				status_applied.emit(null, "poison", intent.poison_stacks)
				log_added.emit("%s — %s — poisons you (%d stacks)" % [enemy.display_name, intent.label, intent.poison_stacks])
			else:
				log_added.emit("%s — %s — deals %.0f" % [enemy.display_name, intent.label, actual])

		_Enemy.IntentType.SUMMON:
			_do_summon(intent.summon_id)

# ── Helpers ────────────────────────────────────────────────────────────────────

func _do_hero_attack(target) -> void:
	if target == null or target.is_dead():
		return
	var dmg: float = _hero.get_attack_damage()
	var is_crit: bool = _hero.roll_crit()
	if is_crit:
		dmg *= 2.0
	var actual: float = target.take_damage(dmg)
	_run_state.total_damage_dealt += actual
	damage_dealt.emit(target, actual, is_crit, "physical")
	if is_crit:
		log_added.emit("CRIT! %s takes %.0f" % [target.display_name, actual])
	else:
		log_added.emit("%s takes %.0f" % [target.display_name, actual])

func _do_summon(enemy_id: String) -> void:
	for def in _enemy_defs:
		if def.get("id", "") == enemy_id:
			var new_enemy = _Enemy.new()
			new_enemy.init_from_definition(def)
			_add_enemy(new_enemy)
			enemy_added.emit(new_enemy)
			log_added.emit("A %s appears!" % new_enemy.display_name)
			return

func _add_enemy(enemy) -> void:
	_enemies.append(enemy)
	enemy.died.connect(func(e) -> void: _on_enemy_died(e))

func _on_enemy_died(enemy) -> void:
	enemy_died.emit(enemy)
	_run_state.total_kills += 1
	log_added.emit("%s is defeated!" % enemy.display_name)
	if enemy.phase2_death_aoe > 0 and enemy.in_phase2:
		var aoe: float = float(enemy.phase2_death_aoe)
		_hero.take_hit(aoe)
		hero_damaged.emit(aoe, "physical")
		log_added.emit("The %s explodes for %.0f!" % [enemy.display_name, aoe])

func _check_win() -> bool:
	for enemy in _enemies:
		if not enemy.is_dead():
			return false
	combat_won.emit()
	_phase = Phase.DONE
	return true

func _count_living_saplings() -> int:
	var count := 0
	for enemy in _enemies:
		if not enemy.is_dead() and enemy.id == "sapling":
			count += 1
	return count

func _first_living() -> Object:
	for enemy in _enemies:
		if not enemy.is_dead():
			return enemy
	return null

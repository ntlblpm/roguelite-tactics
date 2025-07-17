class_name UpgradeDefinitions
extends RefCounted

## Defines all available upgrades for classes and roster
## Contains upgrade names, descriptions, stat bonuses, and maximum levels

# Upgrade structure: { id, name, description, max_level, stat_bonus_per_level }
# stat_bonus_per_level format: { "health": 10, "damage": 5, etc. }

static func get_class_upgrades(character_class: String) -> Array[Dictionary]:
	"""Get all available upgrades for a specific class"""
	match character_class:
		"Swordsman":
			return _get_swordsman_upgrades()
		"Archer":
			return _get_archer_upgrades()
		"Pyromancer":
			return _get_pyromancer_upgrades()
		_:
			return []

static func get_roster_upgrades() -> Array[Dictionary]:
	"""Get all available roster upgrades"""
	return [
		{
			"id": "health_mastery",
			"name": "Health Mastery",
			"description": "Increases maximum health for all characters",
			"max_level": 10,
			"stat_bonus_per_level": {"max_health_points": 5}
		},
		{
			"id": "ability_efficiency",
			"name": "Ability Efficiency",
			"description": "Increases maximum ability points for all characters",
			"max_level": 5,
			"stat_bonus_per_level": {"max_ability_points": 1}
		},
		{
			"id": "mobility_training",
			"name": "Mobility Training",
			"description": "Increases maximum movement points for all characters",
			"max_level": 3,
			"stat_bonus_per_level": {"max_movement_points": 1}
		},
		{
			"id": "combat_veteran",
			"name": "Combat Veteran",
			"description": "Reduces damage taken by all characters",
			"max_level": 10,
			"stat_bonus_per_level": {"damage_reduction": 2}
		},
		{
			"id": "tactical_awareness",
			"name": "Tactical Awareness",
			"description": "Increases critical hit chance for all characters",
			"max_level": 8,
			"stat_bonus_per_level": {"critical_chance": 5}
		},
		{
			"id": "experience_gain",
			"name": "Experience Gain",
			"description": "Increases experience gained from combat",
			"max_level": 5,
			"stat_bonus_per_level": {"experience_multiplier": 10}
		}
	]

static func _get_swordsman_upgrades() -> Array[Dictionary]:
	"""Define Swordsman-specific upgrades"""
	return [
		{
			"id": "sword_mastery",
			"name": "Sword Mastery",
			"description": "Increases damage with sword attacks",
			"max_level": 15,
			"stat_bonus_per_level": {"weapon_damage": 3}
		},
		{
			"id": "heavy_armor_training",
			"name": "Heavy Armor Training",
			"description": "Increases armor effectiveness and reduces movement penalty",
			"max_level": 10,
			"stat_bonus_per_level": {"armor_bonus": 2, "max_health_points": 8}
		},
		{
			"id": "shield_wall",
			"name": "Shield Wall",
			"description": "Increases blocking effectiveness and damage reduction",
			"max_level": 8,
			"stat_bonus_per_level": {"block_chance": 5, "damage_reduction": 3}
		},
		{
			"id": "berserker_rage",
			"name": "Berserker Rage",
			"description": "Increases damage when health is low",
			"max_level": 6,
			"stat_bonus_per_level": {"low_health_damage": 8}
		},
		{
			"id": "stalwart_defense",
			"name": "Stalwart Defense",
			"description": "Reduces ability point cost for defensive abilities",
			"max_level": 5,
			"stat_bonus_per_level": {"defensive_ap_reduction": 1}
		},
		{
			"id": "weapon_expertise",
			"name": "Weapon Expertise",
			"description": "Increases critical hit chance and damage",
			"max_level": 12,
			"stat_bonus_per_level": {"critical_chance": 3, "critical_damage": 5}
		},
		{
			"id": "endurance_training",
			"name": "Endurance Training",
			"description": "Increases maximum health and health regeneration",
			"max_level": 10,
			"stat_bonus_per_level": {"max_health_points": 12, "health_regen": 1}
		},
		{
			"id": "combat_reflexes",
			"name": "Combat Reflexes",
			"description": "Increases dodge chance and counter-attack chance",
			"max_level": 8,
			"stat_bonus_per_level": {"dodge_chance": 4, "counter_chance": 3}
		}
	]

static func _get_archer_upgrades() -> Array[Dictionary]:
	"""Define Archer-specific upgrades"""
	return [
		{
			"id": "bow_mastery",
			"name": "Bow Mastery",
			"description": "Increases damage with ranged attacks",
			"max_level": 15,
			"stat_bonus_per_level": {"ranged_damage": 4}
		},
		{
			"id": "keen_eye",
			"name": "Keen Eye",
			"description": "Increases range and accuracy of attacks",
			"max_level": 10,
			"stat_bonus_per_level": {"attack_range": 1, "accuracy": 5}
		},
		{
			"id": "rapid_fire",
			"name": "Rapid Fire",
			"description": "Reduces ability point cost for ranged attacks",
			"max_level": 6,
			"stat_bonus_per_level": {"ranged_ap_reduction": 1}
		},
		{
			"id": "piercing_shots",
			"name": "Piercing Shots",
			"description": "Increases armor penetration and critical damage",
			"max_level": 8,
			"stat_bonus_per_level": {"armor_penetration": 5, "critical_damage": 8}
		},
		{
			"id": "evasion_training",
			"name": "Evasion Training",
			"description": "Increases movement speed and dodge chance",
			"max_level": 12,
			"stat_bonus_per_level": {"max_movement_points": 1, "dodge_chance": 6}
		},
		{
			"id": "hunter_instincts",
			"name": "Hunter Instincts",
			"description": "Increases critical chance and tracking abilities",
			"max_level": 10,
			"stat_bonus_per_level": {"critical_chance": 4, "detection_range": 1}
		},
		{
			"id": "multishot",
			"name": "Multishot",
			"description": "Chance to hit multiple targets with arrows",
			"max_level": 5,
			"stat_bonus_per_level": {"multishot_chance": 10}
		},
		{
			"id": "survival_training",
			"name": "Survival Training",
			"description": "Increases health and resistance to status effects",
			"max_level": 8,
			"stat_bonus_per_level": {"max_health_points": 8, "status_resistance": 8}
		}
	]

static func _get_pyromancer_upgrades() -> Array[Dictionary]:
	"""Define Pyromancer-specific upgrades"""
	return [
		{
			"id": "fire_mastery",
			"name": "Fire Mastery",
			"description": "Increases damage with fire spells",
			"max_level": 15,
			"stat_bonus_per_level": {"fire_damage": 5}
		},
		{
			"id": "mana_efficiency",
			"name": "Mana Efficiency",
			"description": "Reduces ability point cost for spells",
			"max_level": 8,
			"stat_bonus_per_level": {"spell_ap_reduction": 1}
		},
		{
			"id": "elemental_focus",
			"name": "Elemental Focus",
			"description": "Increases spell range and area of effect",
			"max_level": 10,
			"stat_bonus_per_level": {"spell_range": 1, "aoe_size": 1}
		},
		{
			"id": "burning_touch",
			"name": "Burning Touch",
			"description": "Adds burn damage over time to attacks",
			"max_level": 12,
			"stat_bonus_per_level": {"burn_damage": 3, "burn_duration": 1}
		},
		{
			"id": "arcane_intellect",
			"name": "Arcane Intellect",
			"description": "Increases maximum ability points and spell power",
			"max_level": 6,
			"stat_bonus_per_level": {"max_ability_points": 1, "spell_power": 4}
		},
		{
			"id": "fire_resistance",
			"name": "Fire Resistance",
			"description": "Reduces fire damage taken and immunity to burn",
			"max_level": 8,
			"stat_bonus_per_level": {"fire_resistance": 10, "burn_immunity": 12}
		},
		{
			"id": "explosion_expert",
			"name": "Explosion Expert",
			"description": "Increases critical chance and explosion damage",
			"max_level": 10,
			"stat_bonus_per_level": {"critical_chance": 5, "explosion_damage": 6}
		},
		{
			"id": "mage_armor",
			"name": "Mage Armor",
			"description": "Increases health and magical defense",
			"max_level": 8,
			"stat_bonus_per_level": {"max_health_points": 6, "magic_resistance": 8}
		}
	]

static func get_upgrade_by_id(character_class: String, upgrade_id: String) -> Dictionary:
	"""Get a specific upgrade definition by ID"""
	var upgrades: Array[Dictionary]
	
	if character_class == "Roster":
		upgrades = get_roster_upgrades()
	else:
		upgrades = get_class_upgrades(character_class)
	
	for upgrade in upgrades:
		if upgrade.id == upgrade_id:
			return upgrade
	
	return {} # Return empty dictionary if not found

static func calculate_total_stat_bonus(character_class: String, upgrade_id: String, level: int) -> Dictionary:
	"""Calculate the total stat bonus for an upgrade at a given level"""
	var upgrade: Dictionary = get_upgrade_by_id(character_class, upgrade_id)
	if upgrade.is_empty():
		return {}
	
	var total_bonus: Dictionary = {}
	var bonus_per_level: Dictionary = upgrade.stat_bonus_per_level
	
	for stat in bonus_per_level:
		total_bonus[stat] = bonus_per_level[stat] * level
	
	return total_bonus 
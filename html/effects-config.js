const EFFECTS_MAX_DISPLAY = 7

const ITEM_EFFECTS = {
  bread: [hp_restore(5), stamina_restore(10), deadeye_damage(5)],
  stew: [hp_restore(5), stamina_restore(5), deadeye_damage(5)],
  consumable_herb_red_raspberry: [po_hp(10), op_horse_stamina("II"), hp_restore(3), stamina_damage(5), food_restore(5), thirst_damage(7), po_stamina(5)]
}


/*********FUNCTIONS*********/
function hp_restore(level) {
	return {
		key: `hp_restore_${level}`,
		icon: `pl_hp_${level}.png`,
		color: "none",
		number: null
	};
}

function hp_damage(level) {
	return {
		key: `hp_damage_${level}`,
		icon: `pl_hp_damage_${level}.png`,
		color: "none",
		number: null
	};
}

function stamina_restore(level) {
	return {
		key: `stamina_restore_${level}`,
		icon: `pl_stamina_${level}.png`,
		color: "none",
		number: null
	};
}

function stamina_damage(level) {
	return {
		key: `stamina_damage_${level}`,
		icon: `pl_stamina_damage_${level}.png`,
		color: "none",
		number: null
	};
}

function deadeye_restore(level) {
	return {
		key: `deadeye_restore_${level}`,
		icon: `pl_deadeye_${level}.png`,
		color: "red",
		number: null
	};
}

function deadeye_damage(level) {
	return {
		key: `deadeye_damage_${level}`,
		icon: `pl_deadeye_damage_${level}.png`,
		color: "red",
		number: null
	};
}

function food_restore(level) {
	return {
		key: `food_restore_${level}`,
		icon: `pl_food_${level}.png`,
		color: "red",
		number: null
	};
}

function food_damage(level) {
	return {
		key: `food_damage_${level}`,
		icon: `pl_food_damage_${level}.png`,
		color: "red",
		number: null
	};
}

function thirst_restore(level) {
	return {
		key: `thirst_restore_${level}`,
		icon: `pl_thirst_${level}.png`,
		color: "red",
		number: null
	};
}

function thirst_damage(level) {
	return {
		key: `thirst_damage_${level}`,
		icon: `pl_thirst_damage_${level}.png`,
		color: "red",
		number: null
	};
}

//Overpowered
function op_hp(level) { //тут стринг надо указывать "I"
	return {
		key: `op_hp_${level}`,
		icon: `_health.png`,
		color: "red",
		ring: true,
		number: level
	};
}
function op_stamina(level) { //тут стринг надо указывать "I"
	return {
		key: `op_stamina_${level}`,
		icon: `_stamina.png`,
		color: "red",
		ring: true,
		number: level
	};
}
function op_deadeye(level) { //тут стринг надо указывать "I"
	return {
		key: `op_deadeye_${level}`,
		icon: `_deadeye.png`,
		color: "red",
		ring: true,
		number: level
	};
}
function op_horse_hp(level) { //тут стринг надо указывать "I"
	return {
		key: `op_horse_hp_${level}`,
		icon: `_health_horse.png`,
		color: "red",
		ring: true,
		number: level
	};
}
function op_horse_stamina(level) { //тут стринг надо указывать "I"
	return {
		key: `op_horse_stamina_${level}`,
		icon: `_stamina_horse.png`,
		color: "red",
		ring: true,
		number: level
	};
}


function po_hp(level) {
	return {
		key: `po_hp_${level}`,
		icon: `_health.png`,
		color: "red",
		ringTexture: `rpg_tank_${level}.png`,
		number: null
	};
}
function po_stamina(level) {
	return {
		key: `po_stamina_${level}`,
		icon: `_stamina.png`,
		color: "red",
		ringTexture: `rpg_tank_${level}.png`,
		number: null
	};
}
function po_deadeye(level) {
	return {
		key: `po_deadeye_${level}`,
		icon: `_deadeye.png`,
		color: "red",
		ringTexture: `rpg_tank_${level}.png`,
		number: null
	};
}
function po_horse_hp(level) {
	return {
		key: `po_horse_stamina_${level}`,
		icon: `_health_horse.png`,
		color: "red",
		ringTexture: `rpg_tank_${level}.png`,
		number: null
	};
}
function po_horse_stamina(level) {
	return {
		key: `po_horse_stamina_${level}`,
		icon: `_stamina_horse.png`,
		color: "red",
		ringTexture: `rpg_tank_${level}.png`,
		number: null
	};
}


return {

	Debug = false,

	Notify = {
        Enabled = true,
        Event = 'rNotify:ShowAdvancedRightNotification',
        Title = 'Вы использовали:',
        Dict = 'inventory_items',
        Color = 'COLOR_WHITE',
        Duration = 5000,
        ShowAmount = true,
    },

-- VERY IMPORTANT:
-- - the key must be the EXACT NAME of the item in VORP
-- - nativeName must be the RDR3 native name hashable with GetHashKey(...)
	WheelItems = {
		-- Examples: CHANGE them with the real names from your VORP inventory
		consumable_apricots_can = {
			nativeName = "consumable_apricots_can",
			useAmount = 1,
			notifyText = "Albicocche in Scatola",
		},
		consumable_baked_beans_can = {
			nativeName = "consumable_baked_beans_can",
			useAmount = 1,
			notifyText = "Fagioli Stufati",
		},
		consumable_big_game_meat_oregano_cooked = {
			nativeName = "consumable_big_game_meat_oregano_cooked",
			useAmount = 1,
			notifyText = "",
		},
		consumable_big_game_meat_thyme_cooked = {
			nativeName = "consumable_big_game_meat_thyme_cooked",
			useAmount = 1,
			notifyText = "",
		},
		consumable_big_game_meat_wild_mint_cooked = {
			nativeName = "consumable_big_game_meat_wild_mint_cooked",
			useAmount = 1,
			notifyText = "",
		},
		consumable_biscuit_box = {
			nativeName = "consumable_biscuit_box",
			useAmount = 1,
			notifyText = "Biscotti Assortiti",
		},
		consumable_brandy = {
			nativeName = "consumable_brandy",
			useAmount = 1,
			notifyText = "Brandy di Qualità",
		},
		consumable_brandy_used = {
			nativeName = "consumable_brandy_used",
			useAmount = 1,
			notifyText = "",
		},
		consumable_bread_chunk = {
			nativeName = "consumable_bread_chunk",
			useAmount = 1,
			notifyText = "",
		},
		bread = {
			nativeName = "consumable_bread_roll",
			useAmount = 1,
			notifyText = "",
		},
		consumable_candy_bag = {
			nativeName = "consumable_candy_bag",
			useAmount = 1,
			notifyText = "",
		},
		apple = {
			nativeName = "consumable_apple",
			useAmount = 1,
			notifyText = "Mela",
		},
		consumable_beets = {
			nativeName = "consumable_beets",
			useAmount = 1,
			notifyText = "",
		},
		carrot = {
			nativeName = "consumable_carrot",
			useAmount = 1,
			notifyText = "Carota",
		},
		consumable_celery = {
			nativeName = "consumable_celery",
			useAmount = 1,
			notifyText = "",
		},
		cheese = {
			nativeName = "consumable_cheese_wedge",
			useAmount = 1,
			notifyText = "",
		},
		consumable_chewing_tobacco = {
			nativeName = "consumable_chewing_tobacco",
			useAmount = 1,
			notifyText = "",
		},
		consumable_chewing_tobacco_used = {
			nativeName = "consumable_chewing_tobacco_used",
			useAmount = 1,
			notifyText = "",
		},
		consumable_chocolate_bar = {
			nativeName = "consumable_chocolate_bar",
			useAmount = 1,
			notifyText = "",
		},
		consumable_cigar = {
			nativeName = "consumable_cigar",
			useAmount = 1,
			notifyText = "",
		},
		consumable_cigarette_box = {
			nativeName = "consumable_cigarette_box",
			useAmount = 1,
			notifyText = "",
		},
		consumable_cigarette_box_cheap = {
			nativeName = "consumable_cigarette_box_cheap",
			useAmount = 1,
			notifyText = "",
		},
		consumable_cocaine_chewing_gum = {
			nativeName = "consumable_cocaine_chewing_gum",
			useAmount = 1,
			notifyText = "",
		},
		consumable_cocaine_chewing_gum_used = {
			nativeName = "consumable_cocaine_chewing_gum_used",
			useAmount = 1,
			notifyText = "",
		},
		corn = {
			nativeName = "consumable_corn",
			useAmount = 1,
			notifyText = "",
		},
		consumable_cornedbeef_can = {
			nativeName = "consumable_cornedbeef_can",
			useAmount = 1,
			notifyText = "",
		},
		consumable_crackers = {
			nativeName = "consumable_crackers",
			useAmount = 1,
			notifyText = "",
		},
		horsemeal = {
			nativeName = "consumable_crafted_super_meal",
			useAmount = 1,
			notifyText = "",
		},
		consumable_crustacean_meat_mint_cooked = {
			nativeName = "consumable_crustacean_meat_mint_cooked",
			useAmount = 1,
			notifyText = "",
		},
		consumable_crustacean_meat_oregano_cooked = {
			nativeName = "consumable_crustacean_meat_oregano_cooked",
			useAmount = 1,
			notifyText = "",
		},
		consumable_crustacean_meat_thyme_cooked = {
			nativeName = "consumable_crustacean_meat_thyme_cooked",
			useAmount = 1,
			notifyText = "",
		},
		consumable_exotic_bird_oregano_cooked = {
			nativeName = "consumable_exotic_bird_oregano_cooked",
			useAmount = 1,
			notifyText = "",
		},
		consumable_exotic_bird_thyme_cooked = {
			nativeName = "consumable_exotic_bird_thyme_cooked",
			useAmount = 1,
			notifyText = "",
		},
		consumable_exotic_bird_wild_mint_cooked = {
			nativeName = "consumable_exotic_bird_wild_mint_cooked",
			useAmount = 1,
			notifyText = "",
		},
		consumable_flakey_fish_oregano_cooked = {
			nativeName = "consumable_flakey_fish_oregano_cooked",
			useAmount = 1,
			notifyText = "",
		},
		consumable_flakey_fish_thyme_cooked = {
			nativeName = "consumable_flakey_fish_thyme_cooked",
			useAmount = 1,
			notifyText = "",
		},
		consumable_flakey_fish_wild_mint_cooked = {
			nativeName = "consumable_flakey_fish_wild_mint_cooked",
			useAmount = 1,
			notifyText = "",
		},
		consumable_game_meat_oregano_cooked = {
			nativeName = "consumable_game_meat_oregano_cooked",
			useAmount = 1,
			notifyText = "",
		},
		consumable_game_meat_thyme_cooked = {
			nativeName = "consumable_game_meat_thyme_cooked",
			useAmount = 1,
			notifyText = "",
		},
		consumable_game_meat_wild_mint_cooked = {
			nativeName = "consumable_game_meat_wild_mint_cooked",
			useAmount = 1,
			notifyText = "",
		},
		consumable_gin = {
			nativeName = "consumable_gin",
			useAmount = 1,
			notifyText = "",
		},
		consumable_gin_used = {
			nativeName = "consumable_gin_used",
			useAmount = 1,
			notifyText = "",
		},
		consumable_gristly_mutton_oregano_cooked = {
			nativeName = "consumable_gristly_mutton_oregano_cooked",
			useAmount = 1,
			notifyText = "",
		},
		consumable_gristly_mutton_thyme_cooked = {
			nativeName = "consumable_gristly_mutton_thyme_cooked",
			useAmount = 1,
			notifyText = "",
		},
		consumable_gristly_mutton_wild_mint_cooked = {
			nativeName = "consumable_gristly_mutton_wild_mint_cooked",
			useAmount = 1,
			notifyText = "",
		},
		horsehaycube = {
			nativeName = "consumable_haycube",
			useAmount = 1,
			notifyText = "",
		},
		consumable_herbivore_bait = {
			nativeName = "consumable_herbivore_bait",
			useAmount = 1,
			notifyText = "",
		},
		consumable_horse_medicine = {
			nativeName = "consumable_horse_medicine",
			useAmount = 1,
			notifyText = "",
		},
		consumable_horse_medicine_used = {
			nativeName = "consumable_horse_medicine_used",
			useAmount = 1,
			notifyText = "",
		},
		horse_reviver = {
			nativeName = "consumable_horse_reviver",
			useAmount = 1,
			notifyText = "",
		},
		horse_stimulant = {
			nativeName = "consumable_horse_stimulant",
			useAmount = 1,
			notifyText = "Stimolante per Cavalli",
		},
		consumable_horse_stimulant_used = {
			nativeName = "consumable_horse_stimulant_used",
			useAmount = 1,
			notifyText = "Stimolante per Cavalli (Aperto)",
		},
		consumable_jerky = {
			nativeName = "consumable_jerky",
			useAmount = 1,
			notifyText = "",
		},
		consumable_jerky_venison = {
			nativeName = "consumable_jerky_venison",
			useAmount = 1,
			notifyText = "",
		},
		consumable_kidneybeans_can = {
			nativeName = "consumable_kidneybeans_can",
			useAmount = 1,
			notifyText = "",
		},
		consumable_mature_venison_oregano_cooked = {
			nativeName = "consumable_mature_venison_oregano_cooked",
			useAmount = 1,
			notifyText = "",
		},
		consumable_mature_venison_thyme_cooked = {
			nativeName = "consumable_mature_venison_thyme_cooked",
			useAmount = 1,
			notifyText = "",
		},
		consumable_mature_venison_wild_mint_cooked = {
			nativeName = "consumable_mature_venison_wild_mint_cooked",
			useAmount = 1,
			notifyText = "",
		},
		consumable_medicine = {
			nativeName = "consumable_medicine",
			useAmount = 1,
			notifyText = "",
		},
		consumable_medicine_used = {
			nativeName = "consumable_medicine_used",
			useAmount = 1,
			notifyText = "",
		},
		consumable_moonshine = {
			nativeName = "consumable_moonshine",
			useAmount = 1,
			notifyText = "",
		},
		consumable_oat_cakes = {
			nativeName = "consumable_oat_cakes",
			useAmount = 1,
			notifyText = "",
		},
		consumable_offal = {
			nativeName = "consumable_offal",
			useAmount = 1,
			notifyText = "",
		},
		consumable_peach = {
			nativeName = "consumable_peach",
			useAmount = 1,
			notifyText = "",
		},
		consumable_peaches_can = {
			nativeName = "consumable_peaches_can",
			useAmount = 1,
			notifyText = "",
		},
		consumable_pear = {
			nativeName = "consumable_pear",
			useAmount = 1,
			notifyText = "",
		},
		consumable_peas_can = {
			nativeName = "consumable_peas_can",
			useAmount = 1,
			notifyText = "",
		},
		consumable_peppermint = {
			nativeName = "consumable_peppermint",
			useAmount = 1,
			notifyText = "",
		},
		consumable_pineapples_can = {
			nativeName = "consumable_pineapples_can",
			useAmount = 1,
			notifyText = "",
		},
		consumable_plump_bird_oregano_cooked = {
			nativeName = "consumable_plump_bird_oregano_cooked",
			useAmount = 1,
			notifyText = "",
		},
		consumable_plump_bird_thyme_cooked = {
			nativeName = "consumable_plump_bird_thyme_cooked",
			useAmount = 1,
			notifyText = "",
		},
		consumable_plump_bird_wild_mint_cooked = {
			nativeName = "consumable_plump_bird_wild_mint_cooked",
			useAmount = 1,
			notifyText = "",
		},
		consumable_potent_herbivore_bait = {
			nativeName = "consumable_potent_herbivore_bait",
			useAmount = 1,
			notifyText = "",
		},
		consumable_potent_horse_medicine = {
			nativeName = "consumable_potent_horse_medicine",
			useAmount = 1,
			notifyText = "",
		},
		consumable_potent_horse_stimulant = {
			nativeName = "consumable_potent_horse_stimulant",
			useAmount = 1,
			notifyText = "",
		},
		consumable_potent_medicine = {
			nativeName = "consumable_potent_medicine",
			useAmount = 1,
			notifyText = "",
		},
		consumable_potent_predator_bait = {
			nativeName = "consumable_potent_predator_bait",
			useAmount = 1,
			notifyText = "",
		},
		consumable_potent_restorative = {
			nativeName = "consumable_potent_restorative",
			useAmount = 1,
			notifyText = "",
		},
		consumable_potent_snake_oil = {
			nativeName = "consumable_potent_snake_oil",
			useAmount = 1,
			notifyText = "",
		},
		consumable_potent_tonic = {
			nativeName = "consumable_potent_tonic",
			useAmount = 1,
			notifyText = "",
		},
		consumable_predator_bait = {
			nativeName = "consumable_predator_bait",
			useAmount = 1,
			notifyText = "",
		},
		consumable_prime_beef_oregano_cooked = {
			nativeName = "consumable_prime_beef_oregano_cooked",
			useAmount = 1,
			notifyText = "",
		},
		consumable_prime_beef_thyme_cooked = {
			nativeName = "consumable_prime_beef_thyme_cooked",
			useAmount = 1,
			notifyText = "",
		},
		consumable_prime_beef_wild_mint_cooked = {
			nativeName = "consumable_prime_beef_wild_mint_cooked",
			useAmount = 1,
			notifyText = "",
		},
		consumable_restorative = {
			nativeName = "consumable_restorative",
			useAmount = 1,
			notifyText = "",
		},
		consumable_restorative_used = {
			nativeName = "consumable_restorative_used",
			useAmount = 1,
			notifyText = "",
		},
		consumable_rum = {
			nativeName = "consumable_rum",
			useAmount = 1,
			notifyText = "",
		},
		consumable_rum_used = {
			nativeName = "consumable_rum_used",
			useAmount = 1,
			notifyText = "",
		},
		consumable_salmon_can = {
			nativeName = "consumable_salmon_can",
			useAmount = 1,
			notifyText = "",
		},
		consumable_snake_oil = {
			nativeName = "consumable_snake_oil",
			useAmount = 1,
			notifyText = "",
		},
		consumable_snake_oil_used = {
			nativeName = "consumable_snake_oil_used",
			useAmount = 1,
			notifyText = "",
		},
		consumable_special_horse_medicine = {
			nativeName = "consumable_special_horse_medicine",
			useAmount = 1,
			notifyText = "",
		},
		consumable_special_horse_reviver_crafted = {
			nativeName = "consumable_special_horse_reviver_crafted",
			useAmount = 1,
			notifyText = "",
		},
		consumable_special_horse_stimulant_crafted = {
			nativeName = "consumable_special_horse_stimulant_crafted",
			useAmount = 1,
			notifyText = "",
		},
		consumable_strawberries_can = {
			nativeName = "consumable_strawberries_can",
			useAmount = 1,
			notifyText = "",
		},
		horse_brush = {
			nativeName = "kit_horse_brush",
			useAmount = 1,
			notifyText = "",
		},
		consumable_succulent_fish_oregano_cooked = {
			nativeName = "consumable_succulent_fish_oregano_cooked",
			useAmount = 1,
			notifyText = "",
		},
		consumable_succulent_fish_thyme_cooked = {
			nativeName = "consumable_succulent_fish_thyme_cooked",
			useAmount = 1,
			notifyText = "",
		},
		consumable_succulent_fish_wild_mint_cooked = {
			nativeName = "consumable_succulent_fish_wild_mint_cooked",
			useAmount = 1,
			notifyText = "",
		},
		sugarcube = {
			nativeName = "consumable_sugarcube",
			useAmount = 1,
			notifyText = "",
		},
		consumable_sweet_corn_can = {
			nativeName = "consumable_sweet_corn_can",
			useAmount = 1,
			notifyText = "",
		},
		consumable_tender_pork_oregano_cooked = {
			nativeName = "consumable_tender_pork_oregano_cooked",
			useAmount = 1,
			notifyText = "",
		},
		consumable_tender_pork_thyme_cooked = {
			nativeName = "consumable_tender_pork_thyme_cooked",
			useAmount = 1,
			notifyText = "",
		},
		consumable_tender_pork_wild_mint_cooked = {
			nativeName = "consumable_tender_pork_wild_mint_cooked",
			useAmount = 1,
			notifyText = "",
		},
		consumable_med_tonic_potent = {
			nativeName = "consumable_tonic",
			useAmount = 1,
			notifyText = "",
		},
		consumable_tonic_used = {
			nativeName = "consumable_tonic_used",
			useAmount = 1,
			notifyText = "",
		},
		consumable_whiskey = {
			nativeName = "consumable_whiskey",
			useAmount = 1,
			notifyText = "",
		},
		consumable_whiskey_used = {
			nativeName = "consumable_whiskey_used",
			useAmount = 1,
			notifyText = "",
		},
		campfire = {
			nativeName = "kit_camp",
			useAmount = 1,
			notifyText = "",
		},
		kit_camp_simple = {
			nativeName = "kit_camp_simple",
			useAmount = 1,
			notifyText = "",
		},
		stupka_item = {
			nativeName = "upgrade_upg_mortar_pestle",
			useAmount = 1,
			notifyText = "",
		},
		
		
		weapon_kit_binoculars = {
			nativeName = "WEAPON_KIT_BINOCULARS",
			useAmount = 1,
			notifyText = "",
		},
		weapon_kit_binoculars_improved = {
			nativeName = "WEAPON_KIT_BINOCULARS_IMPROVED",
			useAmount = 1,
			notifyText = "",
		},
		weapon_kit_camera = {
			nativeName = "WEAPON_KIT_CAMERA",
			useAmount = 1,
			notifyText = "",
		},
		weapon_kit_camera_advanced = {
			nativeName = "WEAPON_KIT_CAMERA_ADVANCED",
			useAmount = 1,
			notifyText = "",
		},
		weapon_kit_detector = {
			nativeName = "WEAPON_KIT_DETECTOR",
			useAmount = 1,
			notifyText = "",
		},
		weapon_kit_metal_detector = {
			nativeName = "WEAPON_KIT_METAL_DETECTOR",
			useAmount = 1,
			notifyText = "",
		},
		--часы(не менять)
		pocketwatch1 = {
			nativeName = "provision_pocket_watch_platinum",
			useAmount = 1,
			notifyText = "",
		},
		pocketwatch2 = {
			nativeName = "provision_pocket_watch_silver",
			useAmount = 1,
			notifyText = "",
		},
		pocketwatch3 = {
			nativeName = "provision_pocket_watch_gold",
			useAmount = 1,
			notifyText = "",
			showNotification = false,
		},
		pocketwatch4 = {
			nativeName = "provision_watch",
			useAmount = 1,
			notifyText = "",
			showNotification = false,
		},
		pocketwatch5 = {
			nativeName = "kit_player_pocketwatch",
			useAmount = 1,
			notifyText = "",
			showNotification = false,
		},
		pocketwatch6 = {
			nativeName = "kit_player_pocketwatch",
			useAmount = 1,
			notifyText = "",
			showNotification = false,
		},
		pocketwatch7 = {
			nativeName = "provision_pocket_watch_gold",
			useAmount = 1,
			notifyText = "",
			showNotification = false,
		},
		pocketwatch8 = {
			nativeName = "provision_pocket_watch_gold",
			useAmount = 1,
			notifyText = "",
			showNotification = false,
		},
		pocketwatch9 = {
			nativeName = "provision_watch",
			useAmount = 1,
			notifyText = "",
			showNotification = false,
		},
		
		--Эти предметы добавляются как Оружие в слот к ножу
		--Их не надо использовать автоматически- потому что в инвентаре может быть 2 фонаря- а в колесе только один
		--Поэтому просто выбираем нужный фонарь в инвентаре и используем.
		--weapon_melee_lantern = {
		--	nativeName = "WEAPON_MELEE_LANTERN",
		--	useAmount = 1,
		--	notifyText = "",
		--},
		--weapon_melee_davy_lantern = {
		--	nativeName = "WEAPON_MELEE_DAVY_LANTERN",
		--	useAmount = 1,
		--	notifyText = "",
		--},
		--weapon_melee_lantern_halloween = {
		--	nativeName = "WEAPON_MELEE_LANTERN_HALLOWEEN",
		--	useAmount = 1,
		--	notifyText = "",
		--},
		--weapon_melee_lantern_electric = {
		--	nativeName = "WEAPON_MELEE_LANTERN_ELECTRIC",
		--	useAmount = 1,
		--	notifyText = "",
		--},
		
	},
	
	Sync = {
        RequestOnClientStartDelayMs = 3000,
        UseCooldownMs = 350,
        ServerPollMs = 2000,
        RequestAfterUseMs = 700,
    },
	--Использование часов
	PocketWatches = {
		{ item = 'pocketwatch1',  prop = 's_inv_pocketwatch01x',    type = 'Inspect', promptLabel = 'provision_pocket_watch_platinum' },	--платиновые часы
		{ item = 'pocketwatch2',  prop = 's_inv_pocketwatch02x',    type = 'Inspect', promptLabel = 'provision_pocket_watch_silver' },		--серебрянные часы
		{ item = 'pocketwatch3',  prop = 's_inv_pocketwatch03x',    type = 'Inspect', promptLabel = 'provision_pocket_watch_gold' },		--золотые часы
		{ item = 'pocketwatch4',  prop = 's_inv_pocketwatch04x',    type = 'InspectZ', promptLabel = 'provision_watch' },					--старинные часы
		{ item = 'pocketwatch5',  prop = 's_inv_pocketwatch06x',    type = 'Inspect', promptLabel = 'kit_player_pocketwatch' },			--карманные часы
		{ item = 'pocketwatch6',  prop = 's_inv_pocketwatch07x',    type = 'InspectZ', promptLabel = 'kit_player_pocketwatch' },			--карманные часы
		{ item = 'pocketwatch7',  prop = 'S_POCKETWATCH_REUTLINGE', type = 'InspectZ', promptLabel = 'provision_pocket_watch_reutlinge' },	--карманные часы Reutlinge
		{ item = 'pocketwatch8',  prop = 'p_si_pocketWatch01x',     type = 'InspectZ', promptLabel = 'provision_pocket_watch_gold' },
		{ item = 'pocketwatch9',  prop = 's_OldPocketWatch01x',     type = 'Inspect',  promptLabel = 'provision_rc_slvcatcher_watch' },		--старые карманные часы
		--{ item = 'pocketwatch10', prop = 's_OldPocketWatch02x',     type = 'Inspect',  promptLabel = 'provision_rcm_pocket_watch' },		--сломанные часы
		{ item = 'compas1',       prop = 's_inv_compass01x',        type = 'InspectZ', promptLabel = 'provision_pearsons_naval_compass' },	--компас
		{ item = 'compas2',       prop = 's_compass02x',            type = 'InspectZ', promptLabel = 'provision_th_antique_brass_compass' },--сломаный компас
	}
}
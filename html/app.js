// фиксированный порядок категорий
/**
const CATEGORY_ORDER = [
    "all",
    "clothes",
    "weapons",
    "provision",
    "remedies",
    "ingridient",
    //"herbs",
    //"animals",
    "material",
    "kit",
    "valuable",
    "documents",
    "collections",
    "horse",
	"misc",
    "sell"
];

// подкатегория -> общая категория
const CATEGORY_MAP = {
  // Оружие
  weapon: "weapons",
  equipment: "weapons",
  weapon_thrown: "weapons",
  ammo: "weapons",

  // Провизия
  provision: "provision",
  pears: "provision",
  bread: "provision",
  water: "provision",

  // Одежда
  hat: "clothes",
  jacket: "clothes",
  boots: "clothes",
  clothes: "clothes",
  
  butcher_item_sb: "material",
  bt_item: "material",
  butcher_item: "material",
  fisher_item: "ingridient",
  traper_item: "ingridient",

  herbs: "ingridient",
  // Лекарства
  med: "remedies",
  bandage: "remedies",

  // По умолчанию
  default: "misc"
};
**/

const InventoryContainer = Vue.createApp({
    data() {
        return this.getInitialState();		
    },
    computed: {
		
		resolvedPlayerEffects() {
			return this.resolveItemEffects(this.selectedPlayerItemInfo)
		},
		
		resolvedOtherEffects() {
			return this.resolveItemEffects(this.selectedOtherItemInfo)
		},
		
		resolvedTradeEffects() {
			return this.resolveItemEffects(this.selectedTradeItemInfo)
		},
		
		
		
		
		
		
		
		
		
		
        playerWeight() {
            const weight = Object.values(this.playerInventory).reduce((total, item) => {
                if (item && item.weight !== undefined && item.amount !== undefined) {
                    return total + item.weight * item.amount;
                }
                return total;
            }, 0);
            return isNaN(weight) ? 0 : weight;
        },
		
		theirTradeWeight() {
			const weight = Object.values(this.theirTradeOffers).reduce((total, item) => {
				if (item && item.weight !== undefined && item.amount !== undefined) {
					return total + item.weight * item.amount;
				}
				return total;
			}, 0);
		
			return isNaN(weight) ? 0 : weight;
		},
		
		tradePlayerWeight() {
			if (!this.isTradeActive) return this.playerWeight;
			return this.playerWeight + this.theirTradeWeight;
		},
		
		tradeWeightBarClass() {
			const weightPercentage = (this.tradePlayerWeight / this.maxWeight) * 100;
		
			if (weightPercentage < 50) {
				return "low";
			} else if (weightPercentage < 75) {
				return "medium";
			} else {
				return "high";
			}
		},
		
		tradeInviteProgress() {
			if (!this.showTradeInvite || !this.tradeInviteEndsAt || !this.tradeInviteDuration) return 0;
			const left = Math.max(0, this.tradeInviteEndsAt - this.tradeInviteNow);
			return Math.min(100, Math.max(0, (left / this.tradeInviteDuration) * 100));
		},
		
        /*playerMoney() {
            let totalMoney = 0;
            Object.values(this.playerInventory).forEach((item) => {
                if (item && item.name === 'dollar' && item.amount !== undefined) {
                    totalMoney += item.amount * 100;
                } else if (item && item.name === 'cent' && item.amount !== undefined) {
                    totalMoney += item.amount;
                }
            });
            return totalMoney;
        },*/
		playerMoney() {
            return this.cash * 100;
        },
        otherInventoryWeight() {
            const weight = Object.values(this.otherInventory).reduce((total, item) => {
                if (item && item.weight !== undefined && item.amount !== undefined) {
                    return total + item.weight * item.amount;
                }
                return total;
            }, 0);
            return isNaN(weight) ? 0 : weight;
        },
        weightBarClass() {
            const weightPercentage = (this.playerWeight / this.maxWeight) * 100;
            if (weightPercentage < 50) {
                return "low";
            } else if (weightPercentage < 75) {
                return "medium";
            } else {
                return "high";
            }
        },
        otherWeightBarClass() {
            const weightPercentage = (this.otherInventoryWeight / this.otherInventoryMaxWeight) * 100;
            if (weightPercentage < 50) {
                return "low";
            } else if (weightPercentage < 75) {
                return "medium";
            } else {
                return "high";
            }
        },
        shouldCenterInventory() {
			return this.isOtherInventoryEmpty && !this.isTradeActive;
        },
		
		
		
		//availablePlayerCategories() {
		//	const cats = new Set();
		//	// пробегаем по слотам игрока и добавляем категории имеющихся предметов
		//		for (let slot = 1; slot <= this.totalSlots; slot++) {
		//			const item = this.getItemInSlot(slot, "player");
		//			if (item) cats.add(this.getMainCategory(item));
		//		}
		//	const arr = Array.from(cats);
		//	arr.sort(); // опционально
		//	arr.unshift("all"); // хотим, чтобы "Все" была первой
		//	return arr;
		//},
		

		//выбор категорий Продать и Купить
		currentShopModeTitle() {
			let hasBuy = false, hasSell = false;
		
			for (let slot = 1; slot <= this.otherInventorySlots; slot++) {
				const it = this.getItemInSlot(slot, "other");
				if (!it) continue;
				if (it.price) hasBuy = true;
				if (it.buyPrice) hasSell = true;
			}
			//Если нет вообще предметов пишем надпись
			if (!hasBuy && !hasSell) {
				return "Нет предметов";
			}
			//Если нет предметов для покупки выбираем категорию Продать
			if (this.currentShopMode === "buy" && !hasBuy) {
				this.currentShopMode = "sell";
			}
			//Если нет предметов для продажи выбираем категорию Купить
			if (this.currentShopMode === "sell" && !hasSell) {
				this.currentShopMode = "buy";
			}
		
			return this.currentShopMode === "buy" ? this.t.buy : this.t.sell;
		},
	
		
		
		availablePlayerCategories() {
			const cats = new Set();
		
			// пробегаем по слотам игрока и добавляем категории имеющихся предметов
			for (let slot = 1; slot <= this.totalSlots; slot++) {
				const item = this.getItemInSlot(slot, "player");
				if (!item) continue;
		
				// основная категория
				cats.add(this.getMainCategory(item));
		
				// дополнительная категория "sell"
				if (item.buyPrice) cats.add("sell");
			}
		
			// превращаем в массив
			const found = Array.from(cats);
		
			// возвращаем только те категории, которые есть в CATEGORY_ORDER, 
			// и в правильном порядке
			//return CATEGORY_ORDER.filter(cat => found.includes(cat) || cat === "all");
			return (this.categoryOrder || []).filter(cat => found.includes(cat) || cat === "all");
		},
		
		availableOtherCategories() {
			const cats = new Set();
			
			for (let slot = 1; slot <= this.otherInventorySlots; slot++) {
				const item = this.getItemInSlot(slot, "other");
				if (!item) continue;
				
				// 🔹 если магазин — фильтруем по режиму
				if (this.isShopInventory) {
					if (this.currentShopMode === "buy" && !item.price) continue;
					if (this.currentShopMode === "sell" && !item.buyPrice) continue;
				}
			
				// основная категория
				cats.add(this.getMainCategory(item));
			
				// дополнительная категория "sell"
				//if (item.price) cats.add("sell");
			}
			
			const found = Array.from(cats);
			
			//return CATEGORY_ORDER.filter(cat => found.includes(cat) || cat === "all");
			return (this.categoryOrder || []).filter(cat => found.includes(cat) || cat === "all");
		},
		
		filteredPlayerSlots() {
		// all — как раньше: все слоты
			if (this.currentPlayerCategory === "all") {
				return Array.from({ length: this.totalSlots }, (_, i) => i + 1);
			}
		
			const result = [];
			for (let slot = 1; slot <= this.totalSlots; slot++) {
				const item = this.getItemInSlot(slot, "player");
				if (!item) continue;
			
				if (this.currentPlayerCategory === "sell") {
				if (item.buyPrice) result.push(slot);
				} else {
					if (this.getMainCategory(item) === this.currentPlayerCategory) result.push(slot);
				}
			}
		
			// добиваем пустыми слотами: <25 -> до 25, >=25 -> до конца строки
			const minSlots = 25;
			const perRow = 5;
			if (result.length < minSlots) {
				while (result.length < minSlots) result.push(null);
			} else {
				const remainder = result.length % perRow;
				if (remainder > 0) {
					const toAdd = perRow - remainder;
					for (let i = 0; i < toAdd; i++) result.push(null);
				}
			}
		
			return result;
		},
		
		// слоты "другого" инвентаря, где предмет подходит под выбранную категорию
		filteredOtherSlots() {
			//if (this.currentOtherCategory === "all" && !this.isShopInventory && !this.isTradeInventory) {
			if (this.currentOtherCategory === "all" && !this.isShopInventory) {
				return Array.from({ length: this.otherInventorySlots }, (_, i) => i + 1);
			}
			
			const result = [];
		
			for (let slot = 1; slot <= this.otherInventorySlots; slot++) {
				const item = this.getItemInSlot(slot, "other");
				if (!item) continue;
		
				// 🔹 Если это магазин — фильтруем по режиму (buy/sell)
				if (this.isShopInventory) {
					if (this.currentShopMode === "buy" && !item.price) continue;
					if (this.currentShopMode === "sell" && !item.buyPrice) continue;
				}
		
				// 🔹 "all" = показываем все слоты (в рамках текущего режима)
				if (this.currentOtherCategory === "all") {
					result.push(slot);
					continue;
				}
		
				// 🔹 обычные категории
				if (this.getMainCategory(item) === this.currentOtherCategory) {
					result.push(slot);
				}
			}
		
			// 🔹 добиваем пустыми слотами
			const minSlots = 25;
			const perRow = 5;
			if (result.length < minSlots) {
				while (result.length < minSlots) result.push(null);
			} else {
				const remainder = result.length % perRow;
				if (remainder > 0) {
					const toAdd = perRow - remainder;
					for (let i = 0; i < toAdd; i++) result.push(null);
				}
			}
		
			return result;
		},
		
		myTradeRenderSlots() {
			return Array.from({ length: this.maxTradeSlots || 10 }, (_, i) => i + 1);
		},
		
		theirTradeRenderSlots() {
			return Array.from({ length: this.maxTradeSlots || 10 }, (_, i) => i + 1);
		},
		
/*		myTradeRenderSlots() {
			const result = [];
		
			for (let slot = 1; slot <= 10; slot++) {
				const item = this.getMyTradeItem(slot);
				if (!item) continue;
		
				result.push(slot);
			}
		
			const minSlots = 10;
			const perRow = 5;
		
			if (result.length < minSlots) {
				while (result.length < minSlots) result.push(null);
			} else {
				const remainder = result.length % perRow;
				if (remainder > 0) {
					const toAdd = perRow - remainder;
					for (let i = 0; i < toAdd; i++) result.push(null);
				}
			}
		
			return result;
		},
		

		theirTradeRenderSlots() {
			const result = [];
		
			for (let slot = 1; slot <= 10; slot++) {
				const item = this.getTheirTradeItem(slot);
				if (!item) continue;
		
				result.push(slot);
			}
		
			const minSlots = 10;
			const perRow = 5;
		
			if (result.length < minSlots) {
				while (result.length < minSlots) result.push(null);
			} else {
				const remainder = result.length % perRow;
				if (remainder > 0) {
					const toAdd = perRow - remainder;
					for (let i = 0; i < toAdd; i++) result.push(null);
				}
			}
		
			return result;
		},
*/

		// слоты "другого" инвентаря, где предмет подходит под выбранную категорию
/*		filteredTradeSlots() {
			if (this.currentTradeCategory === "all" && this.isTradeInventory) {
				return Array.from({ length: this.tradeInventorySlots }, (_, i) => i + 1);
			}
			
			const result = [];
		
			for (let slot = 1; slot <= this.tradeInventorySlots; slot++) {
				const item = this.getItemInSlot(slot, "trade");
				if (!item) continue;
		
				// 🔹 "all" = показываем все слоты (в рамках текущего режима)
				if (this.currentTradeCategory === "all") {
					result.push(slot);
					continue;
				}
		
				// 🔹 обычные категории
				if (this.getMainCategory(item) === this.currentTradeCategory) {
					result.push(slot);
				}
			}
		
			// 🔹 добиваем пустыми слотами
			const minSlots = 10;
			const perRow = 5;
			if (result.length < minSlots) {
				while (result.length < minSlots) result.push(null);
			} else {
				const remainder = result.length % perRow;
				if (remainder > 0) {
					const toAdd = perRow - remainder;
					for (let i = 0; i < toAdd; i++) result.push(null);
				}
			}
		
			return result;
		},
*/

		
		
		
		
		currentPlayerCategoryTitle() {
			return this.categoryTitle(this.currentPlayerCategory);
		},
		currentOtherCategoryTitle() {
			return this.categoryTitle(this.currentOtherCategory);
		},
		
		
//		//формат веса чтобы 2134->2.135 а если 2000->2.0
//		formattedSelectedWeight() {
//			if (!this.selectedPlayerItemInfo || !this.selectedPlayerItemInfo.weight) return null;
//	
//			const kg = this.selectedPlayerItemInfo.weight / 1000;
//			// Если число целое (например, 2), показываем 2.0
//			return kg % 1 === 0 ? kg.toFixed(1) : kg;
//		},
//		//формат веса для количества
//			formattedTotalSelectedWeight() {
//			if (!this.selectedPlayerItemInfo || !this.selectedPlayerItemInfo.weight) return null;
//	
//			const kg = (this.selectedPlayerItemInfo.weight * this.selectedPlayerItemInfo.amount) / 1000;
//			return kg % 1 === 0 ? kg.toFixed(1) : kg; // общий вес
//		},
    },
    watch: {
        //transferAmount(newVal) {
        //    if (newVal !== null && newVal < 1) this.transferAmount = 1;
        //},
		isOtherInventoryEmpty(val) {
			if (!val) {
				// если появился другой инвентарь, сбрасываем выделения
				this._gridClearAllSelections();
			}
		},
//		isTradeInventoryEmpty(val) {
//			if (!val) {
//				// если появился другой инвентарь, сбрасываем выделения
//				this._gridClearAllSelections();
//			}
//		},
		
		
		availablePlayerCategories(cats) {
			if (!cats.includes(this.currentPlayerCategory)) {
			this.currentPlayerCategory = cats[0] || "all";
			}
		},
		availableOtherCategories(cats) {
			if (!cats.includes(this.currentOtherCategory)) {
			this.currentOtherCategory = cats[0] || "all";
			}
		},
		
/**		
		resolvedPlayerEffects: {
			handler() {
				this.applyUniversalTint();
			},
			deep: true
		},
		resolvedOtherEffects: {
			handler() {
				this.applyUniversalTint();
			},
			deep: true
		},
		resolvedTradeEffects: {
			handler() {
				this.applyUniversalTint();
			},
			deep: true
		},
**/		
		
    },
    methods: {
        getInitialState() {
            return {
                // Config Options
                maxWeight: 0,
                totalSlots: 0,
                // Escape Key
                isInventoryOpen: false,
                additionalCloseKey: 'KeyI',
                // Single pane
                isOtherInventoryEmpty: true,
//				isTradeInventoryEmpty: false,//поставить false для редактирования TRADE инвентаря
                // Error handling
                errorSlot: null,
                // Player Inventory
                playerInventory: {},
                inventoryLabel: "Инвентарь",
                totalWeight: 0,
                // Other inventory
                otherInventory: {},
                otherInventoryName: "",
                otherInventoryLabel: "Drop",
                otherInventoryMaxWeight: 1000000,
                otherInventorySlots: 100,
                isShopInventory: false,
//				isTradeInventory: false,
                // Where item is coming from
                inventory: "",
                // Context Menu
                showContextMenu: false,
                contextMenuPosition: { top: "0px", left: "0px" },
                contextMenuItem: null,
                showSubmenu: false,
                // Hotbar
                showHotbar: false,
                hotbarItems: [],
                wasHotbarEnabled: false,
                // Notification box
                showNotification: false,
                notificationText: "",
                notificationImage: "",
                notificationType: "added",
                notificationAmount: 1,				
                notificationTimeout: null,
                // Required items box
                showRequiredItems: false,
                requiredItems: [],
                // Attachments
                selectedWeapon: null,
                showWeaponAttachments: false,
                selectedWeaponAttachments: [],
				playerId: null,
                playerName: null,
                // Dragging and dropping
                currentlyDraggingItem: null,
                currentlyDraggingSlot: null,
                dragStartX: 0,
                dragStartY: 0,
                ghostElement: null,
                dragStartInventoryType: "player",
                //transferAmount: null,
                busy: false,
                dragThreshold: 5,
                isMouseDown: false,
                mouseDownX: 0,
                mouseDownY: 0,
				
				categoryOrder: ["all", "clothes", "weapons", "provision", "remedies", "ingridient", "herbs", "animals", "material", "kit", "valuable", "documents", "collections", "horse", "misc", "sell"],
				categoryMap: { default: "misc" },
				
				nuiToken: null,
				
                // -------- Trade state --------
                tradeId: null,
                tradePartner: null,
                tradePartnerName: null,
                myTradeOffers: {},
                theirTradeOffers: {},
                myTradeAccepted: false,
                theirTradeAccepted: false,
                isTradeActive: false, //тут false по умолчанию
                isTradeComplete: false,
				maxTradeSlots: 10,
                // -----------------------------
				tradeRenderKey: 0,
				
				showTradeInvite: false,
				tradeInviteId: null,
				tradeInviteName: '',
				tradeInviteDuration: 30000,
				tradeInviteEndsAt: 0,
				tradeInviteNow: Date.now(),
				tradeInviteTimer: null,
				
				cash: 0,
				// -------- Localisation UI (fallback EN) --------
                t: {
                    title: 'RSG Inventory',
                    close: 'Close',
                    close_aria: 'Close inventory',
                    use: 'Use',
                    give: 'Give',
                    single: 'Single',
                    half: 'Half',
                    all: 'All',
                    amount: 'Amount',
                    amount_placeholder: 'amount',
                    drop: 'Drop',
                    copy_serial: 'Copy Serial',
                    sell: 'Sell',
                    satchel: 'Satchel',
                    weight: 'Weight',
                    id: 'ID',
                    cash: 'Cash',
                    received: 'Received',
                    used: 'Used',
                    removed: 'Removed',
					amount_start: 'Amount',
					amount_end: '',
					quality: 'Quality',
					serial: 'Serial Number',
					buy_price: "Buy Price",
					sell_price: "Sell Price",
					buy: "Buy",
					sellable: "Sellable",
					price: "Price",
					value: "Value",
					modifications: "Modifications",
					enter_ammount: "Enter amount",
					confirm: "Confirm",
					cancel: "Cancel",
					equipped: "Equipped",
					
					trade: 'Trade',
                    your_offer: 'Your Offer',
                    their_offer: 'Their Offer',
                    accept: 'Accept',
                    waiting: 'Waiting for other player...',
                    cancel: 'Cancel',
                    accepted: 'Accepted',
                    no_items_offered: 'No items offered',
					trade_request: ' wants to trade with you!',
					
					categories: {
						all: "All",
						clothes: "Clothes",
						weapons: "Weapons",
						provision: "Provision",
						remedies: "Remedies",
						ingridient: "Ingridient",
						material: "Material",
						kit: "Kit",
						valuable: "Valuable",
						documents: "Documents",
						herbs: "Herbs",
						animals: "Animals",
						collections: "Collections",
						horse: "Horse",
						sell: "Sell",
						misc: "Misc"
					}
                },
                // ----------------------------------------------
				
				notificationDescription: "",
				scrollBoundElements: [],
				selectedPlayerItemInfo: null, // хранение выбранного предмета игрока
				selectedOtherItemInfo: null, // хранение выбранного предмета 2 инвентарь
				selectedTradeItemInfo: null, //хранение выбраного предмета при трейде
				
				// текущая категория для каждого инвентаря
				currentPlayerCategory: "all",
				currentOtherCategory:  "all",
				
				currentShopMode: "buy",
				
				
				showAmountPrompt: false,
				tempTransferAmount: null,
				amountPromiseResolve: null,
				tempCurrentlyDraggingSlot: null,
				lastDragEvent: null //сохраняем нужные нам данные из эвента чтобы не терялся во время ввода
            };
        },
        validateToken(csrfToken) {
            return axios
                .post("https://rsg-core/validateCSRF", {
                    clientToken: csrfToken,
                })
                .then((response) => {
                    return response.data.valid;
                })
                .catch((error) => {
                    console.error("Error validating CSRF:", error);
                    return false;
                });
        },
        openInventory(data) {
            if (this.showHotbar) {
                this.wasHotbarEnabled = true;
                this.toggleHotbar(false);
            } else {
                this.wasHotbarEnabled = false;
            }

            this.isInventoryOpen = true;
            this.maxWeight = data.maxweight;
            this.totalSlots = data.slots;
			this.playerId = data.playerId || null;
			this.playerName = data.playerName || null;
            this.playerInventory = {};
            this.otherInventory = {};
			
			
			if (data.categories) {
				this.categoryOrder = data.categories.order || this.categoryOrder
				this.categoryMap = data.categories.map || this.categoryMap
			}
			
			
			
			// -------- Hydrating labels from Lua --------
            if (data.labels) {
                this.t = { ...this.t, ...data.labels };
                // Mets Г  jour les intitulГ©s visibles
                this.inventoryLabel = this.t.satchel || this.inventoryLabel;
            }
            // ----------------------------------------------------

            if (data.cash !== undefined) {
                this.cash = data.cash;
            }

            if (data.inventory) {
                if (Array.isArray(data.inventory)) {
                    data.inventory.forEach((item) => {
                        if (item && item.slot) {
                            this.playerInventory[item.slot] = item;
                        }
                    });
                } else if (typeof data.inventory === "object") {
                    for (const key in data.inventory) {
                        const item = data.inventory[key];
                        if (item && item.slot) {
                            this.playerInventory[item.slot] = item;
                        }
                    }
                }
            }

            if (data.other) {
                if (data.other && data.other.inventory) {
                    if (Array.isArray(data.other.inventory)) {
                        data.other.inventory.forEach((item) => {
                            if (item && item.slot) {
                                this.otherInventory[item.slot] = item;
                            }
                        });
                    } else if (typeof data.other.inventory === "object") {
                        for (const key in data.other.inventory) {
                            const item = data.other.inventory[key];
                            if (item && item.slot) {
                                this.otherInventory[item.slot] = item;
                            }
                        }
                    }
                }

                this.otherInventoryName = data.other.name;
                // If an "other" label is provided, use it, otherwise fallback to t.drop (or the existing one)
                this.otherInventoryLabel = data.other.label || this.t.drop || this.otherInventoryLabel;
                this.otherInventoryMaxWeight = data.other.maxweight;
                this.otherInventorySlots = data.other.slots;

                if (this.otherInventoryName.startsWith("shop-")) {
                    this.isShopInventory = true;
                } else {
                    this.isShopInventory = false;
                }

                this.isOtherInventoryEmpty = false;
            }
			
			// Tab title (if labels are provided)
            if (this.t && this.t.title) {
                document.title = this.t.title;
            }
			this.postData('playSound', {	soundSet: "HUD_PLAYER_MENU", soundName: "MENU_ENTER" });
        },
		
		
		//Покраска текстур. Чтобы покрасить в нужный цвет нужно только добавить fx-tint effect-red
		/**
		createEffectSvgFilter(filterName, rgb = { r: 255, g: 255, b: 255 }) {
			const safeId = String(filterName).replace(/[^a-zA-Z0-9_-]/g, "");
			const svgId = `svg-${safeId}`;
			const filterId = `filter-${safeId}`;
		
			if (!document.getElementById(svgId)) {
				const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
				svg.setAttribute("id", svgId);
				svg.setAttribute("xmlns", "http://www.w3.org/2000/svg");
				svg.setAttribute("style", "position:absolute;width:0;height:0;pointer-events:none;");
		
				svg.innerHTML = `
					<defs>
						<filter id="${filterId}">
							<feComponentTransfer color-interpolation-filters="sRGB">
								<feFuncR type="linear" slope="${rgb.r / 255}" />
								<feFuncG type="linear" slope="${rgb.g / 255}" />
								<feFuncB type="linear" slope="${rgb.b / 255}" />
								<feFuncA type="table" tableValues="0 1" />
							</feComponentTransfer>
						</filter>
					</defs>
				`;
		
				document.body.appendChild(svg);
			}
		
			return filterId;
		},

		updateEffectSvgFilter(filterName, rgb = { r: 255, g: 255, b: 255 }) {
			const safeId = String(filterName).replace(/[^a-zA-Z0-9_-]/g, "");
			const svgId = `svg-${safeId}`;
			const filterId = `filter-${safeId}`;
			const svg = document.getElementById(svgId);
		
			if (!svg) {
				return this.createEffectSvgFilter(filterName, rgb);
			}
		
			const filter = svg.querySelector(`#${filterId}`);
			if (filter) {
				filter.innerHTML = `
					<feComponentTransfer color-interpolation-filters="sRGB">
						<feFuncR type="linear" slope="${rgb.r / 255}" />
						<feFuncG type="linear" slope="${rgb.g / 255}" />
						<feFuncB type="linear" slope="${rgb.b / 255}" />
						<feFuncA type="table" tableValues="0 1" />
					</feComponentTransfer>
				`;
			}
		
			return filterId;
		},

		getTintRgbByClass(el) {
			if (el.classList.contains("effect-red")) {
				return { r: 150, g: 0, b: 0 };
			}
			if (el.classList.contains("effect-yellow")) {
				return { r: 255, g: 234, b: 114 };
			}
			if (el.classList.contains("effect-green")) {
				return { r: 110, g: 170, b: 80 };
			}
			if (el.classList.contains("effect-blue")) {
				return { r: 90, g: 140, b: 220 };
			}
			return null;
		},

		applyUniversalTint(rootSelector = document) {
			this.$nextTick(() => {
				const root = typeof rootSelector === "string"
					? document.querySelector(rootSelector) || document
					: rootSelector || document;
		
				const elements = root.querySelectorAll("img.fx-tint");
		
				elements.forEach((el, index) => {
					const rgb = this.getTintRgbByClass(el);
		
					if (!rgb) {
						el.style.filter = "none";
						el.style.webkitFilter = "none";
						return;
					}
		
					const key =
						el.dataset.effectKey ||
						el.dataset.tintKey ||
						el.className ||
						`fx-tint-${index}`;
		
					const filterId = this.updateEffectSvgFilter(`universal-${key}-${index}`, rgb);
		
					el.style.filter = `url(#${filterId})`;
					el.style.webkitFilter = `url(#${filterId})`;
				});
			});
		},		
**/		
/**
		resolveItemEffects(item) {
			if (!item || !item.name) return []
			
			const itemEffectKeys = ITEM_EFFECTS[item.name]
			if (!Array.isArray(itemEffectKeys) || !itemEffectKeys.length) return []
			
			return itemEffectKeys
				.slice(0, EFFECTS_MAX_DISPLAY)
				.map((effectKey) => {
				const effect = EFFECTS[effectKey]
				if (!effect) return null
			
				return {
					key: effectKey,
					icon: effect.icon,
					color: effect.color || "none",
					ring: !!effect.ring,
					number: effect.number || null
				}
			})
			.filter(Boolean)
		},
**/	
		resolveItemEffects(item) {
			if (!item || !item.name) return [];
		
			const itemEffects = ITEM_EFFECTS[item.name];
			if (!Array.isArray(itemEffects) || !itemEffects.length) return [];
		
			return itemEffects
				.slice(0, EFFECTS_MAX_DISPLAY)
				.map((effect) => {
					if (!effect || typeof effect !== "object") return null;
		
					return {
						key: effect.key,
						icon: effect.icon,
						color: effect.color || "none",
						//ring: !!effect.ring,
						ringTexture: effect.ringTexture || (effect.ring ? "overpowered.png" : null),
						number: effect.number ?? null
					};
				})
				.filter(Boolean);
		},
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		startTradeInviteTimer(duration = 30000) {
			this.clearTradeInviteTimer();
			this.tradeInviteDuration = duration;
			this.tradeInviteEndsAt = Date.now() + duration;
			this.tradeInviteNow = Date.now();
		
			this.tradeInviteTimer = setInterval(() => {
				this.tradeInviteNow = Date.now();
		
				if (this.tradeInviteNow >= this.tradeInviteEndsAt) {
					this.declineTradeInvite(true);
				}
			}, 100);
		},
		
		clearTradeInviteTimer() {
			if (this.tradeInviteTimer) {
				clearInterval(this.tradeInviteTimer);
				this.tradeInviteTimer = null;
			}
		},
		
		showTradeInviteUI(initiatorId, initiatorName, duration = 30000) {
			this.tradeInviteId = initiatorId;
			this.tradeInviteName = initiatorName;
			this.showTradeInvite = true;
			this.startTradeInviteTimer(duration);
		},
		
		hideTradeInviteUI() {
			this.clearTradeInviteTimer();
			this.showTradeInvite = false;
			this.tradeInviteId = null;
			this.tradeInviteName = '';
			this.tradeInviteEndsAt = 0;
			this.tradeInviteNow = Date.now();
		},
		
		acceptTradeInvite() {
			if (!this.tradeInviteId) return;
		
			axios.post('https://rsg-inventory/AcceptTradeRequest', {
				initiatorId: this.tradeInviteId
			}).catch((error) => {
				console.error('Error accepting trade request:', error);
			});
		
			this.hideTradeInviteUI();
		},
		
		declineTradeInvite(silent = false) {
			if (!this.tradeInviteId) {
				this.hideTradeInviteUI();
				return;
			}
		
			axios.post('https://rsg-inventory/DeclineTradeRequest', {
				initiatorId: this.tradeInviteId
			}).catch((error) => {
				console.error('Error declining trade request:', error);
			});
		
			this.hideTradeInviteUI();
		},
		
		
		/*
		updateInventory(data) {
            this.playerInventory = {};

            if (data.inventory) {
                if (Array.isArray(data.inventory)) {
                    data.inventory.forEach((item) => {
                        if (item && item.slot) {
                            this.playerInventory[item.slot] = item;
                        }
                    });
                } else if (typeof data.inventory === "object") {
                    for (const key in data.inventory) {
                        const item = data.inventory[key];
                        if (item && item.slot) {
                            this.playerInventory[item.slot] = item;
                        }
                    }
                }
            }
            
            // 3. УМНЫЙ СБРОС (Вставка функции clearInventorySelection)
            if (this.selectedPlayerItemInfo) {
                const slot = this.selectedPlayerItemInfo.slot;
                const newItem = this.playerInventory[slot];

                // Если предмет пропал ИЛИ изменился (другое имя)
                if (!newItem || newItem.name !== this.selectedPlayerItemInfo.name) {
                    // Вызываем вашу функцию очистки для инвентаря игрока
                    this.clearInventorySelection(this.playerInventory);
                } else {
                    // Если предмет остался, обновляем данные (кол-во)
                    this.selectedPlayerItemInfo = newItem;
                }
            }
        },*/
		updateInventory(data) {
			if (!data || !data.inventory) {
				return; // безопасно: не чистим UI, если пакет без inventory
			}
			const next = {};
			
			if (Array.isArray(data.inventory)) {
				data.inventory.forEach((item) => {
					if (item?.slot) next[item.slot] = item;
				});
			} else if (typeof data.inventory === "object") {
				for (const k in data.inventory) {
					const item = data.inventory[k];
					if (item?.slot) next[item.slot] = item;
				}
			}
		
			// 1) удалить отсутствующие слоты
			for (const slotStr in this.playerInventory) {
				const slot = Number(slotStr);
				if (!next[slot]) delete this.playerInventory[slot];
			}
		
			// 2) обновить/добавить слоты (важно: сохраняем ссылку на объект)
			for (const slotStr in next) {
				const slot = Number(slotStr);
				if (this.playerInventory[slot]) {
				Object.assign(this.playerInventory[slot], next[slot]);
				} else {
				this.playerInventory[slot] = next[slot];
				}
			}
		
			// 3) УМНЫЙ СБРОС (Вставка функции clearInventorySelection)
			if (this.selectedPlayerItemInfo) {
				const slot = this.selectedPlayerItemInfo.slot;
				const newItem = this.playerInventory[slot];
				
				//Если предмет пропал ИЛИ изменился (другое имя)
				if (!newItem || newItem.name !== this.selectedPlayerItemInfo.name) 
				{
					// Вызываем вашу функцию очистки для инвентаря игрока
					this.clearInventorySelection(this.playerInventory);
				} else {
					// Если предмет остался, обновляем данные (кол-во)
					this.selectedPlayerItemInfo = newItem;
				}
			}
		},
		
		isEquipped(item) {
			return !!(item?.info?._e || item?.info?._equipped || item?.info?.equipped);
		},

        async closeInventory() {
            let inventoryName = this.otherInventoryName;
            const wasHotbarEnabled = this.wasHotbarEnabled;
            let hotbarItems = []
			
			//const inviteState = {
			//	showTradeInvite: this.showTradeInvite,
			//	tradeInviteId: this.tradeInviteId,
			//	tradeInviteName: this.tradeInviteName,
			//	tradeInviteDuration: this.tradeInviteDuration,
			//	tradeInviteEndsAt: this.tradeInviteEndsAt,
			//	tradeInviteNow: this.tradeInviteNow,
			//	tradeInviteTimer: this.tradeInviteTimer,
			//};
			
            if (wasHotbarEnabled) {
                hotbarItems = Array(5).fill(null).map((_, index) => {
                    const item = this.playerInventory[index + 1];
                    return item !== undefined ? item : null;
                });
            }

            try {
                await axios.post("https://rsg-inventory/CloseInventory", { name: inventoryName });
                
				Object.assign(this, this.getInitialState());
				
				if (wasHotbarEnabled) {
                    this.toggleHotbar({
                        open: true,
                        items: hotbarItems,
                    });
                }
            } catch (error) {
                console.error("Error closing inventory:", error);
            }
			this.postData('playSound', { soundSet: "HUD_PLAYER_MENU",	soundName: "MENU_CLOSE"	});
        },
        //clearTransferAmount() {
        //    this.transferAmount = null;
        //},
        getItemInSlot(slot, inventoryType) {
            if (inventoryType === "player") {
                return this.playerInventory[slot] || null;
            } else if (inventoryType === "other") {
                return this.otherInventory[slot] || null;
            } else if (inventoryType === "trade-my") {
				return this.myTradeOffers?.[slot] || null;
			} else if (inventoryType === "trade-their") {
				return this.theirTradeOffers?.[slot] || null;
			}
            return null;
        },
		
		getMyTradeItem(slot) {
			return this.myTradeOffers?.[slot] || null;
		},
		
		getTheirTradeItem(slot) {
			return this.theirTradeOffers?.[slot] || null;
		},
/*		
		getItemInSlotPrice(slot, inventoryType) {
			if (inventoryType === "other") {
				const item = this.otherInventory[slot];
				return item?.buyPrice || null;
			}
		
			if (inventoryType === "player") {
				const playerItem = this.playerInventory[slot];
				if (!playerItem || !playerItem.name) return null;
		
				for (let otherSlot in this.otherInventory) {
					const otherItem = this.otherInventory[otherSlot];
					if (!otherItem || !otherItem.name || !otherItem.buyPrice) continue;
		
					if (otherItem.name === playerItem.name) {
						return otherItem.buyPrice;
					}
				}
			}
		
			return null;
		},
*/		
        getHotbarItemInSlot(slot) {
            return this.hotbarItems[slot - 1] || null;
        },
        containerMouseDownAction(event) {
            if (event.button === 0 && this.showContextMenu) {
                this.showContextMenu = false;
				//clearSelection();
            }
        },
        handleMouseDown(event, slot, inventory) {
            if (event.button === 1) return; // skip middle mouse
            event.preventDefault();
            const itemInSlot = this.getItemInSlot(slot, inventory);
            if (event.button === 0 && itemInSlot) { // 👈 при клике показываем инфо
				this.selectSlot(event, itemInSlot, inventory); // ✅ выделяем слот
				//запрещаем делить предметы в магазинах
                if (event.shiftKey && itemInSlot && !this.otherInventoryName.startsWith("shop-")) {
                    this.splitAndPlaceItem(itemInSlot, inventory);
                } else {
                    this.isMouseDown = true;
                    this.mouseDownX = event.clientX;
                    this.mouseDownY = event.clientY;
                    this.currentlyDraggingSlot = slot;
                    this.dragStartInventoryType = inventory;
                }
            } else if (event.button === 2 && itemInSlot) {
                this.selectSlot(event, itemInSlot, inventory); // ✅ выделяем слот
				if (this.otherInventoryName.startsWith("shop-")) {
					const amountToBuy = event.shiftKey ? itemInSlot.amount : 1;//с зажатым shift покупаем/продаем весь стак
					if (itemInSlot) {
						this.handlePurchase(itemInSlot.slot, itemInSlot, amountToBuy, inventory);
					}
                    return;
                }
                if (!this.isOtherInventoryEmpty) {                    
					if (inventory == "player") {
						this.selectedPlayerItemInfo = this.getItemInSlot(slot, "player") || null;
					} else if (inventory == "other") {
						this.selectedOtherItemInfo = this.getItemInSlot(slot, "other") || null;
					} else if (inventory === "trade-my" || inventory === "trade-their") {
						this.selectedTradeItemInfo = this.getItemInSlot(slot, inventory) || null;
						this.showContextMenu = false;//Запрещаем в трейде показ меню
						return;
					}
					const amountToMove = event.shiftKey ? itemInSlot.amount : 1;
					this.moveItemBetweenInventories(itemInSlot, inventory, amountToMove);//с зажатым shift перемещаем весь стак
                } else {
					//Запрещаем в трейде показ меню
					if (inventory === "trade-my" || inventory === "trade-their" || this.isTradeActive) {
						this.showContextMenu = false;
						return;
					}
					
					this.selectedPlayerItemInfo = this.getItemInSlot(slot, "player") || null;
                    this.showContextMenuOptions(event, itemInSlot);
                }
            }
        },
        moveItemBetweenInventories(item, sourceInventoryType, transferAmount) {
            if (this.busy) {
                return;
            }
			
            this.busy = true;
            const sourceInventory = sourceInventoryType === "player" ? this.playerInventory : this.otherInventory;
            const targetInventory = sourceInventoryType === "player" ? this.otherInventory : this.playerInventory;
            //const amountToTransfer = this.transferAmount !== null ? this.transferAmount : 1;
			//const amountToTransfer = transferAmount !== null && transferAmount !== null ? transferAmount : 1;
			const amountToTransfer = transferAmount;
            let targetSlot = null;

            const sourceItem = sourceInventory[item.slot];
            if (!sourceItem || sourceItem.amount < amountToTransfer) {
                this.inventoryError(item.slot);
                this.busy = false;
                return;
            }

            const totalWeightAfterTransfer = this.otherInventoryWeight + sourceItem.weight * amountToTransfer;
            if (totalWeightAfterTransfer > this.otherInventoryMaxWeight) {
                this.inventoryError(item.slot);
                this.busy = false;
                return;
            }

            if (this.playerInventory != targetInventory) {
                if (this.findNextAvailableSlot(targetInventory) > this.otherInventorySlots) {
                    this.inventoryError(item.slot);
                    this.busy = false;
                    return;
                }
            }

            if (item.unique) {
                targetSlot = this.findNextAvailableSlot(targetInventory);
                if (targetSlot === null) {
                    this.inventoryError(item.slot);
                    this.busy = false;
                    return;
                }

                const newItem = {
                    ...item,
                    inventory: sourceInventoryType === "player" ? "other" : "player",
                    amount: amountToTransfer,
                };
                targetInventory[targetSlot] = newItem;
                newItem.slot = targetSlot;
            } else {
                const targetItemKey = Object.keys(
                    targetInventory).find((key) => targetInventory[key] && targetInventory[key].name === item.name && targetInventory[key].info.quality === item.info.quality
                );
                const targetItem = targetInventory[targetItemKey];

                if (!targetItem) {
                    const newItem = {
                        ...item,
                        inventory: sourceInventoryType === "player" ? "other" : "player",
                        amount: amountToTransfer,
                    };

                    targetSlot = this.findNextAvailableSlot(targetInventory);
                    if (targetSlot === null) {
                        this.inventoryError(item.slot);
                        this.busy = false;
                        return;
                    }

                    targetInventory[targetSlot] = newItem;
                    newItem.slot = targetSlot;
                } else {
                    targetItem.amount += amountToTransfer;
                    targetSlot = targetItem.slot;
                }
            }

            sourceItem.amount -= amountToTransfer;
			
            if (sourceItem.amount <= 0) {
                delete sourceInventory[item.slot];				
				this.clearInventorySelection(sourceInventory);// снимаем выделение, т.к. слот пуст
            }
			
            this.postInventoryData(sourceInventoryType, sourceInventoryType === "player" ? "other" : "player", item.slot, targetSlot, sourceItem.amount, amountToTransfer);
        },
        startDrag(event, slot, inventoryType) {
            event.preventDefault();
            const item = this.getItemInSlot(slot, inventoryType);
            if (!item) return;
            const slotElement = event.target.closest(".item-slot");
            if (!slotElement) return;
            this.dragStartInventoryType = inventoryType;
            const ghostElement = this.createGhostElement(slotElement);
            document.body.appendChild(ghostElement);
            const offsetX = ghostElement.offsetWidth / 2;
            const offsetY = ghostElement.offsetHeight / 2;
            ghostElement.style.left = `${event.clientX - offsetX}px`;
            ghostElement.style.top = `${event.clientY - offsetY}px`;
            this.ghostElement = ghostElement;
            this.currentlyDraggingItem = item;
            this.currentlyDraggingSlot = slot;
            this.dragStartX = event.clientX;
            this.dragStartY = event.clientY;
            this.showContextMenu = false;
        },
        createGhostElement(slotElement) {
            const ghostElement = slotElement.cloneNode(true);
            ghostElement.style.position = "absolute";
            ghostElement.style.pointerEvents = "none";
            ghostElement.style.opacity = "0.7";
            ghostElement.style.zIndex = "1000";
            ghostElement.style.width = getComputedStyle(slotElement).width;
            ghostElement.style.height = getComputedStyle(slotElement).height;
            ghostElement.style.boxSizing = "border-box";
            //const amountElement = ghostElement.querySelector(".item-slot-amount p");
            //if (amountElement) {
            //    const isShop = this.otherInventoryName.indexOf("shop-") !== -1;
            //    if (this.transferAmount) {
            //        amountElement.textContent = `x${this.transferAmount}`;
            //    } else if (isShop && this.dragStartInventoryType == 'other') {
            //        amountElement.textContent = `x1`;
            //    }
            //}
            return ghostElement;
        },
        drag(event) {
            if (this.isMouseDown && !this.ghostElement) {
                const dx = Math.abs(event.clientX - this.mouseDownX);
                const dy = Math.abs(event.clientY - this.mouseDownY);
                if (dx >= this.dragThreshold || dy >= this.dragThreshold) {
                    this.startDrag(event, this.currentlyDraggingSlot, this.dragStartInventoryType);
                }
                return;
            }

            if (!this.currentlyDraggingItem || !this.ghostElement) return;

            const centeredX = event.clientX - this.ghostElement.offsetWidth / 2;
            const centeredY = event.clientY - this.ghostElement.offsetHeight / 2;
            this.ghostElement.style.left = `${centeredX}px`;
            this.ghostElement.style.top = `${centeredY}px`;
        },
        endDrag(event) {
            this.isMouseDown = false;
            if (!this.currentlyDraggingItem) {
                return;
            }
			//перенос в 1 инвентарь или покупка
            const targetPlayerItemSlotElement = event.target.closest(".player-inventory .item-slot");
            if (targetPlayerItemSlotElement) {
                const targetSlot = Number(targetPlayerItemSlotElement.dataset.slot);
                if (targetSlot && !(targetSlot === this.currentlyDraggingSlot && this.dragStartInventoryType === "player")) {
                    this.handleDropOnPlayerSlot(targetSlot);
                }
            }
			//перенос во 2 инвентарь когда он уже есть или продажа
            const targetOtherItemSlotElement = event.target.closest(".other-inventory .item-slot");
            if (targetOtherItemSlotElement) {
                const targetSlot = Number(targetOtherItemSlotElement.dataset.slot);                
				// 🔹 Обычный перенос (между слотами)
				if (targetSlot && !(targetSlot === this.currentlyDraggingSlot && this.dragStartInventoryType === "other")) {
					this.handleItemDrop("other", targetSlot);
                }
				// Магазин: у слотов нет data-slot из-за сортировки,
				// поэтому используем фиктивный слот 1 — он всё равно не играет роли.
				if (!targetSlot && this.isShopInventory) {
					//this.handleDropOnOtherSlot(1);
					this.handleItemDrop("other", 1);
				}
            }
			
			const targetTradeContainer = event.target.closest(".player-trade-item-grid");
            if (targetTradeContainer && this.dragStartInventoryType === "player" && this.isTradeActive) {
                this.handleDropOnTradeContainer();			
            }/* else {
				//перенос если 2 инвентарь еще не показан
                const targetInventoryContainer = event.target.closest(".inventory-container");
                if (targetInventoryContainer && !targetPlayerItemSlotElement && !targetOtherItemSlotElement && this.isOtherInventoryEmpty && !this.isTradeActive) {
                    this.handleDropOnInventoryContainer();
                }
            }*/
			
			//перенос если 2 инвентарь еще не показан
            const targetInventoryContainer = event.target.closest(".inventory-container");
            if (targetInventoryContainer && !targetPlayerItemSlotElement && !targetOtherItemSlotElement && this.isOtherInventoryEmpty && !this.isTradeActive) {
				this.handleDropOnInventoryContainer();
            }
            this.clearDragData();
        },
        handleDropOnPlayerSlot(targetSlot) {
			//перенос из трейда в инвентарь
			if (this.dragStartInventoryType === "trade-my") {
				this.handleDropFromTradeToPlayer(targetSlot);
				return;
			}
			
			
			//Покупка в магазине
            if (this.isShopInventory && this.dragStartInventoryType === "other") {
                //const { currentlyDraggingSlot, currentlyDraggingItem, transferAmount } = this;
				const { currentlyDraggingSlot, currentlyDraggingItem } = this;
                const targetInventory = this.getInventoryByType("player");
                const targetItem = targetInventory[targetSlot];
                if ((targetItem && targetItem.name !== currentlyDraggingItem.name)
                    || (targetItem && targetItem.name === currentlyDraggingItem.name && currentlyDraggingItem.unique)
                    || (targetItem && targetItem.name === currentlyDraggingItem.name && targetItem.info.quality && targetItem.info.quality !== 100)) {
                    this.inventoryError(currentlyDraggingSlot);
                    return;
                }
                //this.handlePurchase(currentlyDraggingSlot, currentlyDraggingItem, transferAmount, this.dragStartInventoryType, targetSlot);
				this.handleDropForBuyItem(targetSlot)
			} else {
				this.handleItemDrop("player", targetSlot);
            }
        },
        handleDropOnOtherSlot(targetSlot) {
			this.handleItemDrop("other", targetSlot);
        },
		
		async handleDropForBuyItem(targetSlot) {
			const item = this.currentlyDraggingItem;
			const DraggingSlot = this.currentlyDraggingSlot;
			try {				
				if (!item || !DraggingSlot) {
					this.clearDragData();
					throw new Error("Dragging item not found or invalid slot");
				}
				//проверка - можем ли купить в этой вкладке и вообще можем ли купить
				const isNormalMode = await axios.post("https://rsg-inventory/CheckPurchase", {
					item: item,
					shop: this.otherInventoryName,
					sourceinvtype: this.dragStartInventoryType,
					targetslot: targetSlot,
					shopMode: this.currentShopMode   // 🔹 передаём режим (buy/sell)
				});

				if (!isNormalMode.data) {
					//console.log("Неправильный shop-mode", this.currentShopMode, isNormalMode.data);
					return;
				}
		
				const sourceInventory = this.getInventoryByType(this.dragStartInventoryType);
				const sourceItem = sourceInventory[DraggingSlot];
				if (!sourceItem) {
					this.clearDragData();
					throw new Error("No item in the source slot to transfer");
				}
				
				let amountToTransfer = 1;				
				if (sourceItem.amount > 1) {
					amountToTransfer = await this.askForAmount();
					if (!amountToTransfer) {
						//console.log("❌ Отменено пользователем");
						this.clearDragData();
						return;
					}
				}
				// не даём указать больше, чем есть
				if (amountToTransfer > item.amount) {
					amountToTransfer = item.amount;
					//throw new Error("Insufficient amount of item in source inventory2");
				}
				
				this.handlePurchase(DraggingSlot, item, amountToTransfer, this.dragStartInventoryType, targetSlot);
			} catch (error) {
				console.error(error.message);
				this.inventoryError(DraggingSlot);
			} finally {
				this.clearDragData();
			}
	    },		
		async handleDropOnInventoryContainer() {
			const item = this.currentlyDraggingItem;
			const DraggingSlot = this.currentlyDraggingSlot;
			
			try {
				// Если нет предмета или слота — сразу выходим
				if (!item?.name || !DraggingSlot) {
					this.clearDragData();
					return;
				}
				
				let amountToGive = 1;
				// 💬 Проверяем, есть ли предмет и его количество
				if (item.amount > 1) {
					amountToGive = await this.askForAmount();
					
					// Если пользователь отменил ввод — выходим
					if (!amountToGive) {
						//console.log("❌ Отменено пользователем");
						this.clearDragData();
						return;
					}
				}
	
				// не даём указать больше, чем есть
				if (amountToGive > item.amount) {
					amountToGive = item.amount;
					//throw new Error("Insufficient amount of item in source inventory2");
				}
			
				const newItem = {
					...item,
					amount: amountToGive,
					slot: 1,
					inventory: "other",
				};
			
				
				const response = await axios.post("https://rsg-inventory/DropItem", {
					...newItem,
					fromSlot: item.slot,
				});
			
				if (response.data) {
					const remainingAmount = this.playerInventory[DraggingSlot].amount - amountToGive;
					if (remainingAmount <= 0) {
						delete this.playerInventory[DraggingSlot];
					} else {
						this.playerInventory[DraggingSlot].amount = remainingAmount;
					}
			
					this.otherInventory[1] = newItem;
					this.otherInventoryName = response.data;
					this.otherInventoryLabel = response.data;
					this.isOtherInventoryEmpty = false;
				}
			} catch (error) {
				console.error("❌ Drop failed:", error);
				this.inventoryError(item?.slot);
			} finally {
				this.showContextMenu = false;
			}
		},
		async handleDropOnTradeContainer() {
			const item = this.currentlyDraggingItem;
			const DraggingSlot = this.currentlyDraggingSlot;
			
			const sourceInventory = this.playerInventory;
			const sourceItem = sourceInventory[item.slot];
			//запрещаем перетаскивание если трейд мы подтвердили
			if (this.myTradeAccepted) {
				this.inventoryError(draggingSlot);
				return;
			}
			
			try {
				// Если нет предмета или слота — сразу выходим
				if (!item?.name || !DraggingSlot) {
					this.clearDragData();
					return;
				}
				//console.log("AMOUNT = ", item.amount)
				//console.log("NAME = ", item.name)
				let amountToGive = 1;
				// 💬 Проверяем, есть ли предмет и его количество
				if (item.amount > 1) {
					amountToGive = await this.askForAmount();
					
					// Если пользователь отменил ввод — выходим
					if (!amountToGive) {
						//console.log("❌ Отменено пользователем");
						this.clearDragData();
						return;
					}
				}
	
				// не даём указать больше, чем есть
				if (amountToGive > item.amount) {
					amountToGive = item.amount;
				}				
				
				const success = await this.addItemToTrade(item, amountToGive);
				if (!success) return; //если предмет не перенесся в сервер- то не уменьшаем количество и ничего не делаем
				
				//это чтобы визуально в инвентаре игрока после переноса менялось состояние
				sourceItem.amount -= amountToGive;
				if (sourceItem.amount <= 0) {
					delete sourceInventory[item.slot];				
					this.clearInventorySelection(sourceInventory);// снимаем выделение, т.к. слот пуст
				}
			} catch (error) {
				console.error("❌ Drop failed:", error);
				this.inventoryError(item?.slot);
			} finally {
				this.showContextMenu = false;
			}
			
		},
		
		/*
		async handleDropFromTradeToPlayer(targetSlot) {
			const item = this.currentlyDraggingItem;
			const draggingSlot = this.currentlyDraggingSlot;
		
			try {
				if (!item?.name || !draggingSlot) {
					return;
				}
		
				if (this.dragStartInventoryType !== "trade-my") {
					return;
				}
		
				if (this.myTradeAccepted) {
					this.inventoryError(draggingSlot);
					return;
				}
		
				let amountToGive = 1;
		
				if (item.amount > 1) {
					amountToGive = await this.askForAmount();
		
					if (!amountToGive) {
						return;
					}
				}
		
				if (amountToGive > item.amount) {
					amountToGive = item.amount;
				}
		
				const response = await axios.post("https://rsg-inventory/RemoveTradeItem", {
					tradeId: this.tradeId,
					tradeSlot: draggingSlot,
					targetSlot: targetSlot,
					amount: amountToGive,
					token: this.nuiToken
				});
		
				if (!response.data) {
					this.inventoryError(draggingSlot);
					return;
				}
		
				if (this.selectedTradeItemInfo && this.selectedTradeItemInfo.slot === draggingSlot) {
					this.selectedTradeItemInfo = null;
				}
		
				if (typeof this.clearTradeSelections === "function") {
					this.clearTradeSelections();
				}
			} catch (error) {
				console.error("Return item from trade failed:", error);
				this.inventoryError(draggingSlot);
			} finally {
				this.showContextMenu = false;
				this.clearDragData();
			}
		},*/
		
		async handleDropFromTradeToPlayer(targetSlot) {
			const item = this.currentlyDraggingItem;
			const draggingSlot = this.currentlyDraggingSlot;
		
			try {
				if (!item?.name || !draggingSlot) {
					return;
				}
		
				if (this.dragStartInventoryType !== "trade-my") {
					return;
				}
		
				if (this.myTradeAccepted) {
					this.inventoryError(draggingSlot);
					return;
				}
		
				const targetSlotNumber = parseInt(targetSlot, 10);
				if (isNaN(targetSlotNumber)) {
					this.inventoryError(draggingSlot);
					return;
				}
		
				const tradeItem = this.myTradeOffers[draggingSlot];
				if (!tradeItem) {
					this.inventoryError(draggingSlot);
					return;
				}
		
				let amountToGive = 1;
		
				if (tradeItem.amount > 1) {
					amountToGive = await this.askForAmount();
		
					if (!amountToGive) {
						return;
					}
				}
		
				if (amountToGive > tradeItem.amount) {
					amountToGive = tradeItem.amount;
				}
		
				const targetInventory = this.playerInventory;
				const targetItem = targetInventory[targetSlotNumber];
		
				// 🔹 Проверка локальной визуальной логики ДО запроса:
				// одинаковые unique нельзя стакать, разные предметы в занятый слот тоже нельзя
				if (targetItem) {
					if (tradeItem.name === targetItem.name && targetItem.unique) {
						this.inventoryError(draggingSlot);
						return;
					}
		
					if (
						tradeItem.name !== targetItem.name ||
						tradeItem.unique ||
						tradeItem.info?.quality != targetItem.info?.quality
					) {
						this.inventoryError(draggingSlot);
						return;
					}
				}
				
				const movedItem = {
					...tradeItem,
					amount: amountToGive,
					slot: targetSlotNumber
				};
		
				const response = await axios.post("https://rsg-inventory/RemoveTradeItem", {
					tradeId: this.tradeId,
					tradeSlot: draggingSlot,
					targetSlot: targetSlotNumber,
					amount: amountToGive,
					token: this.nuiToken
				});
		
				if (!response.data) {
					this.inventoryError(draggingSlot);
					return;
				}
		
				// Сначала рисуем в player inventory
				if (targetItem) {
					targetItem.amount += amountToGive;
					this.selectedPlayerItemInfo = targetItem;
				} else {
					targetInventory[targetSlotNumber] = movedItem;
					this.selectedPlayerItemInfo = targetInventory[targetSlotNumber];
				}
		
				// Потом обновляем/чистим trade slot
				if (tradeItem.amount > amountToGive) {
					//tradeItem.amount -= amountToGive; --уменьшать трейды не надо они через сервернй update уменьшаются
				} else {
					delete this.myTradeOffers[draggingSlot];
					this.clearInventorySelection(this.myTradeOffers);
					this.selectedTradeItemInfo = null;
				}
				
				// Ставим выделение в инвенторе игрока после переноса
				const safeEvent = {
					target: document.querySelector(`.player-inventory .item-slot[data-slot="${targetSlotNumber}"]`),
					currentTarget: document.querySelector(".player-inventory .item-grid")
				};
				this.selectSlot(safeEvent, targetInventory[targetSlotNumber], "player");
		
			} catch (error) {
				console.error("Return item from trade failed:", error);
				this.inventoryError(draggingSlot);
			} finally {
				this.showContextMenu = false;
				this.clearDragData();
			}
		},
		
		
		
		
		
		
		async handleItemDrop(targetInventoryType, targetSlot) {
			const DraggingSlot = this.currentlyDraggingSlot;
			// ✅ Сохраняем событие один раз, пока оно ещё "живое" для выделения слота
			if (event) {
				this.lastDragEvent = {
					target: event.target,
					currentTarget: event.currentTarget,
				};
			}
			
			try {
				const isShop = this.otherInventoryName.indexOf("shop-");
				// 🔹 Покупка в магазине
				if (this.dragStartInventoryType === "other" && targetInventoryType === "other" && isShop !== -1) {
					return;
				}
		
				const targetSlotNumber = parseInt(targetSlot, 10);
				if (isNaN(targetSlotNumber)) {
					throw new Error("Invalid target slot number");
				}
		
				const sourceInventory = this.getInventoryByType(this.dragStartInventoryType);
				const targetInventory = this.getInventoryByType(targetInventoryType);
		
				const sourceItem = sourceInventory[DraggingSlot];
				if (!sourceItem) {
					throw new Error("No item in the source slot to transfer");
				}
				//Проверка - можем ли мы продать в этой вкладке и вообще можем ли продать предмет в этот магазин
				//Только для предметов больше единицы. если меньше то сразу переносится и проверка выполняется полноценная ниже
				if (sourceItem.amount > 1 && this.dragStartInventoryType === "player" && targetInventoryType === "other" && isShop !== -1) {
					const isNormalMode = await axios.post("https://rsg-inventory/CheckPurchase", {
						item: sourceItem,
						shop: this.otherInventoryName,
						sourceinvtype: this.dragStartInventoryType,
						targetslot: targetSlot,
						shopMode: this.currentShopMode   // 🔹 передаём режим (buy/sell)
					});

					if (!isNormalMode.data) {
						//console.log("Неправильный shop-mode", this.currentShopMode, isNormalMode.data);
						return;
					}
				}
		
				// 🔹 Определяем количество предметов для переноса:
				// - если переносим между разными инвентарями и предметов больше 1 — спрашиваем количество у пользователя;
				// - если переносим внутри одного инвентаря или предмет один — переносим всё количество без запроса.
				let amountToTransfer = sourceItem.amount;				
				if (sourceItem.amount > 1 && this.dragStartInventoryType !== targetInventoryType) {
					amountToTransfer = await this.askForAmount();
					if (!amountToTransfer) {
						//console.log("❌ Отменено пользователем");
						this.clearDragData();
						return;
					}
				}
				
				
				//const amountToTransfer = this.transferAmount !== null ? this.transferAmount : await this.askForAmount();
				// 💬 Если количество не указано — показываем окно и выходим
				if (!amountToTransfer) {
					//console.log("❌ Отменено пользователем");
					this.clearDragData();
					return;
				}
				
				if (amountToTransfer > sourceItem.amount) {
					//throw new Error("Insufficient amount of item in source inventory");
					amountToTransfer = sourceItem.amount;
				}				
		
				// 🔹 Продажа в магазин
				if (this.dragStartInventoryType === "player" && targetInventoryType === "other" && isShop !== -1) {
					this.handlePurchase(
						DraggingSlot,
						sourceItem,
						//this.transferAmount !== null ? this.transferAmount : sourceItem.amount,
						amountToTransfer,
						this.dragStartInventoryType
					);
					return;
				}
		
				// 🔹 Проверка вместимости (только если переносим МЕЖДУ инвентарями)
				if (targetInventoryType !== this.dragStartInventoryType) {
					if (targetInventoryType == "other") {
						const totalWeightAfterTransfer = this.otherInventoryWeight + sourceItem.weight * amountToTransfer;
						if (totalWeightAfterTransfer > this.otherInventoryMaxWeight) {
							throw new Error("Insufficient weight capacity in target inventory");
						}
					}
					else if (targetInventoryType == "player") {
						const totalWeightAfterTransfer = this.playerWeight + sourceItem.weight * amountToTransfer;
						if (totalWeightAfterTransfer > this.maxWeight) {
							throw new Error("Insufficient weight capacity in player inventory");
						}
					}
				}
		
				const targetItem = targetInventory[targetSlotNumber];
		
				if (targetItem) {
					// 🔹 Случай 1: предметы одинаковые, но уникальные → нельзя стакать
					if (sourceItem.name === targetItem.name && targetItem.unique) {
						this.inventoryError(DraggingSlot);
						return;
					}
		
					// 🔹 Случай 2: предметы одинаковые (имя + качество) и НЕ уникальные → объединяем (stack)
					if (sourceItem.name === targetItem.name && !targetItem.unique && sourceItem.info.quality == targetItem.info.quality) {
						targetItem.amount += amountToTransfer; // увеличиваем количество в целевом слоте
						sourceItem.amount -= amountToTransfer; // уменьшаем в исходном
						if (sourceItem.amount <= 0) {
							delete sourceInventory[DraggingSlot]; // полностью перенесли → удаляем из исходного
							this.clearInventorySelection(sourceInventory);// снимаем выделение, т.к. слот пуст
							//console.log("delete", sourceItem.amount);
						}
						this.postInventoryData(this.dragStartInventoryType, targetInventoryType, DraggingSlot, targetSlotNumber, sourceItem.amount, amountToTransfer);
						if (targetInventoryType === this.dragStartInventoryType) {
							sourceItem.amount = targetItem.amount;//возвращаем количество чтобы при перетаскивании не менялось
						}
					} else {
						// 🔹 Случай 3: предметы разные → меняем их местами (swap)
						sourceInventory[DraggingSlot] = targetItem;
						targetInventory[targetSlotNumber] = sourceItem;
						sourceInventory[DraggingSlot].slot = DraggingSlot;
						targetInventory[targetSlotNumber].slot = targetSlotNumber;
						this.postInventoryData(this.dragStartInventoryType, targetInventoryType, DraggingSlot, targetSlotNumber, sourceItem.amount, targetItem.amount);
					}
				} else {
					// 🔹 Случай 4: целевой слот пустой → переносим туда предмет
					sourceItem.amount -= amountToTransfer;
					if (sourceItem.amount <= 0) {
						delete sourceInventory[DraggingSlot]; // удаляем из исходного если всё перенесли
					}
					// Если переносим между инвентарями и начальный слот пустой то снимаем выделение
					if (targetInventoryType !== this.dragStartInventoryType && sourceItem.amount <= 0) {
						this.clearInventorySelection(sourceInventory);// снимаем выделение, т.к. слот пуст
					}
					// создаём новый объект в целевом инвентаре
					targetInventory[targetSlotNumber] = { ...sourceItem, amount: amountToTransfer, slot: targetSlotNumber };
					this.postInventoryData(this.dragStartInventoryType, targetInventoryType, DraggingSlot, targetSlotNumber, sourceItem.amount, amountToTransfer);
				}
				//Это должно быть всегда внизу
				// ✅ Используем сохранённый lastDragEvent вместо исходного event
				const safeEvent = this.lastDragEvent || event;
				this.selectSlot(safeEvent, targetInventory[targetSlotNumber], targetInventoryType); //🔹 Подсветка слота (выделение)
			} catch (error) {
				console.error(error.message);
				this.inventoryError(DraggingSlot);
			} finally {
				this.clearDragData();
			}
		},
        clearDragData() {
            if (this.ghostElement) {
                document.body.removeChild(this.ghostElement);
                this.ghostElement = null;
            }
            this.currentlyDraggingItem = null;
            this.currentlyDraggingSlot = null;
			//console.log("❌ clearDragData");
        },
        getInventoryByType(inventoryType) {
            return inventoryType === "player" ? this.playerInventory : this.otherInventory;
        },        
        async handlePurchase(sourceSlot, sourceItem, transferAmount, sourceInventoryType, targetSlot = null) {
            if (this.busy) {
                return;
            }

            if (sourceItem.amount < 1) {
                this.inventoryError(sourceSlot);
				//TODO сюда надо добавить вывод оповещения что больше нет количества предмета для покупки.
				//console.error("Нет количества")
                return;
            }
            this.busy = true;
            try {
                const response = await axios.post("https://rsg-inventory/AttemptPurchase", {
                    item: sourceItem,
                    amount: transferAmount || 1,
                    shop: this.otherInventoryName,
                    sourceinvtype: sourceInventoryType,
                    targetslot: targetSlot,
					shopMode: this.currentShopMode   // 🔹 передаём режим (buy/sell)
                });

                if (response.data) {
                    if (!sourceItem.amount) {
                        this.busy = false;
                        return;
                    }

                    const amountToTransfer = transferAmount !== null ? transferAmount : 1;
                    if (sourceInventoryType == 'player') {
                        for (const key in this.otherInventory) {
                            const item = this.otherInventory[key];
                            if (item.name == sourceItem.name && item.amount) {
                                this.otherInventory[key].amount += amountToTransfer
                                break
                            }
                        }
                    } else {
                        if (sourceItem.amount < amountToTransfer) {
                            this.inventoryError(sourceSlot);
                            this.busy = false;
                            return;
                        }
                        sourceItem.amount -= amountToTransfer;
                    }

                    this.busy = false;
                } else {
                    this.inventoryError(sourceSlot);
                    this.busy = false;
                }
            } catch (error) {
                this.inventoryError(sourceSlot);
                this.busy = false;
            }
        },
        async dropItem(item, quantity) {
            this.showContextMenu = false;
			if (item && item.name) {
                const playerItemKey = Object.keys(this.playerInventory).find((key) =>
                    this.playerInventory[key] && this.playerInventory[key].slot === item.slot
                );

                if (playerItemKey) {
                    let amountToGive;

                    if (typeof quantity === "string") {
                        switch (quantity) {
                            case "half":
                                amountToGive = Math.ceil(item.amount / 2);
                                break;
                            case "all":
                                amountToGive = item.amount;
                                break;
                            case "enteramount":
                                //const amounttt = await axios.post("https://rsg-inventory/GiveItemAmount")
                                //amountToGive = amounttt.data;
								amountToGive = await this.askForAmount();
								if (!amountToGive) return;
                                break;
                            default:
                                console.error("Invalid quantity specified.");
                                return;
                        }
                    } else if (typeof quantity === "number" && quantity > 0) {
                        amountToGive = quantity;
                    } else {
                        console.error("Invalid quantity type specified.");
                        return;
                    }
					
                    if (amountToGive > item.amount) {
                        amountToGive = item.amount;
                    }

                    const newItem = {
                        ...item,
                        amount: amountToGive,
                        slot: 1,
                        inventory: "other",
                    };

                    try {
                        const response = await axios.post("https://rsg-inventory/DropItem", {
                            ...newItem,
                            fromSlot: item.slot,
                        });

                        if (response.data) {
                            const remainingAmount = this.playerInventory[playerItemKey].amount - amountToGive;
                            if (remainingAmount <= 0) {
                                delete this.playerInventory[playerItemKey];
                            } else {
                                this.playerInventory[playerItemKey].amount = remainingAmount;
                            }

                            this.otherInventory[1] = newItem;
                            this.otherInventoryName = response.data;
                            this.otherInventoryLabel = response.data;
                            this.isOtherInventoryEmpty = false;
                        }
                    } catch (error) {
                        this.inventoryError(item.slot);
                    }
                }
            }
        },
        async useItem(item) {
            if (!item || item.useable === false || this.isShopInventory) {
                return;
            }
            const playerItemKey = Object.keys(this.playerInventory).find((key) => this.playerInventory[key] && this.playerInventory[key].slot === item.slot);
            if (playerItemKey) {
                try {
                    if (item.shouldClose) {
                        this.closeInventory();
                    }
                    await axios.post("https://rsg-inventory/UseItem", {
                        inventory: "player",
                        item: item,
                    });
                } catch (error) {
                    console.error("Error using the item: ", error);
                }
            }
            this.showContextMenu = false;
			//clearSelection();
        },
        showContextMenuOptions(event, item) {
            event.preventDefault();
            if (this.contextMenuItem && this.contextMenuItem.name === item.name && this.showContextMenu) {
                this.showContextMenu = false;
				//clearSelection();
				
                this.contextMenuItem = null;
            } else {
                if (item.inventory === "other") {
                    const matchingItemKey = Object.keys(this.playerInventory).find((key) => this.playerInventory[key].name === item.name);
                    const matchingItem = this.playerInventory[matchingItemKey];

                    if (matchingItem && matchingItem.unique) {
                        const newItemKey = Object.keys(this.playerInventory).length + 1;
                        const newItem = {
                            ...item,
                            inventory: "player",
                            amount: 1,
                        };
                        this.playerInventory[newItemKey] = newItem;
                    } else if (matchingItem) {
                        matchingItem.amount++;
                    } else {
                        const newItemKey = Object.keys(this.playerInventory).length + 1;
                        const newItem = {
                            ...item,
                            inventory: "player",
                            amount: 1,
                        };
                        this.playerInventory[newItemKey] = newItem;
                    }
                    item.amount--;

                    if (item.amount <= 0) {
                        const itemKey = Object.keys(this.otherInventory).find((key) => this.otherInventory[key] === item);
                        if (itemKey) {
                            delete this.otherInventory[itemKey];
                        }
                    }
                }
                const menuLeft = event.clientX;
                const menuTop = event.clientY;
                this.showContextMenu = true;
                this.contextMenuPosition = {
                    top: `${menuTop}px`,
                    left: `${menuLeft}px`,
                };
                this.contextMenuItem = item;
				
				const slot = event.target.closest(".item-slot");
				if (!slot) return;
				lockedSlot = slot;
				//moveSelectedToSlot(slot);
            }
        },
        async giveItem(item, quantity) {
            this.showContextMenu = false;
			if (item && item.name) {
                const selectedItem = item;
                const playerHasItem = Object.values(this.playerInventory).some((invItem) => invItem && invItem.name === selectedItem.name);

                if (playerHasItem) {
                    let amountToGive;
                    if (typeof quantity === "string") {
                        switch (quantity) {
                            case "half":
                                amountToGive = Math.ceil(selectedItem.amount / 2);
                                break;
                            case "all":
                                amountToGive = selectedItem.amount;
                                break;
                            case "enteramount":
                                //const amounttt = await axios.post("https://rsg-inventory/GiveItemAmount")
                                //amountToGive = amounttt.data;
								amountToGive = await this.askForAmount();
								if (!amountToGive) return;
                                break;
                            default:
                                console.error("Invalid quantity specified.");
                                return;
                        }
                    } else {
                        amountToGive = quantity;
                    }

                    if (amountToGive > selectedItem.amount) {
                        console.error("Specified quantity exceeds available amount.");
                        return;
                    }

                    try {
                        const response = await axios.post("https://rsg-inventory/GiveItem", {
                            item: selectedItem,
                            amount: amountToGive,
                            slot: selectedItem.slot,
                            info: selectedItem.info,
                        });
                        if (!response.data) return;

                        this.playerInventory[selectedItem.slot].amount -= amountToGive;
                        if (this.playerInventory[selectedItem.slot].amount === 0) {
                            delete this.playerInventory[selectedItem.slot];
                        }
                    } catch (error) {
                        console.error("An error occurred while giving the item:", error);
                    }
                } else {
                    console.error("Player does not have the item in their inventory. Item cannot be given.");
                }
            }
        },
        findNextAvailableSlot(inventory) {
            for (let slot = 1; slot <= this.totalSlots; slot++) {
                if (!inventory[slot]) {
                    return slot;
                }
            }
            return null;
        },
        async splitAndPlaceItem(item, inventoryType, splitamount = 'half') {
			this.showContextMenu = false;
            const inventoryRef = inventoryType === "player" ? this.playerInventory : this.otherInventory;
            let amount = 1;
            if (item && item.amount > 1) {
                if (splitamount == 'half') {
                    amount = Math.ceil(item.amount / 2);
                } else if (splitamount == 'enteramount') {
                    //const inputAmount = await axios.post("https://rsg-inventory/GiveItemAmount")
                    //amount = inputAmount.data;
					amount = await this.askForAmount();
					if (!amount) return;

                    if (amount < 1) {
                        amount = 1;
                    } else if (amount > item.amount) {
                        amount = item.amount;
                    }
                }

                const originalSlot = Object.keys(inventoryRef).find((key) => inventoryRef[key] === item);
                if (originalSlot !== undefined) {
                    const newItem = { ...item, amount: amount };
                    const nextSlot = this.findNextAvailableSlot(inventoryRef);
                    if (nextSlot !== null) {
                        inventoryRef[nextSlot] = newItem;
                        inventoryRef[originalSlot] = { ...item, amount: item.amount - amount };
                        this.postInventoryData(inventoryType, inventoryType, originalSlot, nextSlot, item.amount, newItem.amount);
                    }
                }
            }
        },
        toggleHotbar(data) {
            if (data.open) {
                this.hotbarItems = data.items;
                this.showHotbar = true;
            } else {
                this.showHotbar = false;
                this.hotbarItems = [];
            }
        },
        showItemNotification(itemData) {
			const item = itemData.item || {};
            const rawType = (itemData.type || '').toLowerCase();
			
			if (itemData.labels) {
                this.t = { ...this.t, ...itemData.labels };
            }
			
            this.notificationText = item.label || "";
            this.notificationImage = item.image ? "images/" + item.image : "";
			
			// Robust mapping of types to localized labels
			const typeMap = {
                add: this.t.received,
                added: this.t.received,
                receive: this.t.received,
			    
                use: this.t.used,
                used: this.t.used,
			    
                drop: this.t.removed,
                remove: this.t.removed,
                removed: this.t.removed
            };
			// Displayed text (localized)
            this.notificationType = typeMap[rawType] || this.t[rawType] || (rawType ? rawType.charAt(0).toUpperCase() + rawType.slice(1) : "");
			// Stable CSS class (non-localized) to preserve your .type-add / .type-use / .type-remove styles
			this.notificationClass = (rawType === 'added') ? 'add'
            : (rawType === 'removed') ? 'remove'
            : (rawType === 'use' || rawType === 'used') ? 'use'
            : (rawType === 'drop') ? 'remove'
            : rawType;
            this.notificationAmount = itemData.amount || 1;
			const desc = item.info?.description || item.description || "";
			this.notificationDescription = typeof desc === 'string' ? desc : '';
            this.showNotification = true;

            if (this.notificationTimeout) {
                clearTimeout(this.notificationTimeout);
            }

            this.notificationTimeout = setTimeout(() => {
                this.showNotification = false;
				this.notificationDescription = "";
                this.notificationTimeout = null;
            }, 3000);
        },
        showRequiredItem(data) {
            if (data.toggle) {
                this.requiredItems = data.items;
                this.showRequiredItems = true;
            } else {
                setTimeout(() => {
                    this.showRequiredItems = false;
                    this.requiredItems = [];
                }, 100);
            }
        },
//        inventoryError(slot) {
//            const slotElement = document.getElementById(`slot-${slot}`);
//            if (slotElement) {
//                slotElement.style.backgroundColor = "red";
//            }
//            axios.post("https://rsg-inventory/PlayDropFail", {}).catch((error) => {
//                console.error("Error playing drop fail:", error);
//            });
//            setTimeout(() => {
//                if (slotElement) {
//                    slotElement.style.backgroundColor = "";
//                }
//            }, 1000);
//        },
		inventoryError(slot) {
			const slotElement = document.querySelector(`[data-inventory="other"] [data-slot="${slot}"]`);
			if (slotElement) {
				slotElement.style.background = "#DB11114D";
			}
		
			axios.post("https://rsg-inventory/PlayDropFail", {}).catch((error) => {
				console.error("Error playing drop fail:", error);
			});
		
			setTimeout(() => {
				if (slotElement) {
					slotElement.style.background = "#ffffff1a";
				}
			}, 1000);
		},
		shopError(itemInSlot) {
			axios.post("https://rsg-inventory/ShowShopError", JSON.stringify({
				item: itemInSlot
			}), {
				headers: {
					"Content-Type": "application/json"
				}
			}).catch((error) => {
				console.error("Ошибка при вызове ShowShopError:", error);
			});
		},
        copySerial() {
            if (!this.contextMenuItem) {
                return;
            }
            const item = this.contextMenuItem;
            if (item) {
                const el = document.createElement("textarea");
                el.value = item.info.serie;
                document.body.appendChild(el);
                el.select();
                document.execCommand("copy");
                document.body.removeChild(el);
				this.showContextMenu = false;
				//clearSelection();
            }
        },
		
		async attachNotepad(item) {
			if (!item || item.name !== 'notepad') return;
		
			try {
				await axios.post("https://rsg-inventory/attachNotepad", {
					item: item,
					slot: item.slot
				});
			} catch (error) {
				console.error("Error attach notepad:", error);
			}
			this.closeInventory();
			this.showContextMenu = false;
		},
		async renameNotepad(item) {
			if (!item || item.name !== 'notepad') return;
		
			try {
				await axios.post("https://rsg-inventory/renameNotepad", {
					item: item,
					slot: item.slot
				});
			} catch (error) {
				console.error("Error rename notepad:", error);
			}
		
			this.showContextMenu = false;
		},
		
        openWeaponAttachments() {
			this.showContextMenu = false;	
			//clearSelection();
			
            if (!this.contextMenuItem) {
                return;
            }
            if (!this.showWeaponAttachments) {
                this.selectedWeapon = this.contextMenuItem;
                this.showWeaponAttachments = true;
                axios
                    .post("https://rsg-inventory/GetWeaponData", JSON.stringify({ weapon: this.selectedWeapon.name, ItemData: this.selectedWeapon }))
                    .then((response) => {
                        const data = response.data;
                        if (data.AttachmentData !== null && data.AttachmentData !== undefined) {
                            if (data.AttachmentData.length > 0) {
                                this.selectedWeaponAttachments = data.AttachmentData;
                            }
                        }
                    })
                    .catch((error) => {
                        console.error(error);
                    });
            } else {
                this.showWeaponAttachments = false;
                this.selectedWeapon = null;
                this.selectedWeaponAttachments = [];
            }
        },
        removeAttachment(attachment) {
            if (!this.selectedWeapon) {
                return;
            }
            const index = this.selectedWeaponAttachments.indexOf(attachment);
            if (index !== -1) {
                this.selectedWeaponAttachments.splice(index, 1);
            }
            axios
                .post("https://rsg-inventory/RemoveAttachment", JSON.stringify({ AttachmentData: attachment, WeaponData: this.selectedWeapon }))
                .then((response) => {
                    this.selectedWeapon = response.data.WeaponData;
                    if (response.data.Attachments) {
                        this.selectedWeaponAttachments = response.data.Attachments;
                    }
                    const nextSlot = this.findNextAvailableSlot(this.playerInventory);
                    if (nextSlot !== null) {
                        response.data.itemInfo.amount = 1;
                        this.playerInventory[nextSlot] = response.data.itemInfo;
                    }
                })
                .catch((error) => {
                    console.error(error);
                    this.selectedWeaponAttachments.splice(index, 0, attachment);
                });
        },
        generateTooltipContent(item) {
            if (!item) {
                return "";
            }

            let content = `<div class="custom-tooltip"><div class="tooltip-header">${item.label}</div><hr class="tooltip-divider">`;
			
			// Проверяем, является ли предмет одеждой
			if (this.isClothingItem(item)) {
				// Для одежды - упрощённый tooltip
				const info = item.info || {};
				const equipped = info._e || info._equipped || info.equipped;
				
				if (equipped) {
					content += `<div class="tooltip-info" style="color: #FFD700; font-weight: bold;"> ${this.t.equipped || 'Надето'}</div>`;
				}
				
				// Показываем описание если есть
				const description = item.info?.description?.replace(/\n/g, "<br>") 
					|| item.description?.replace(/\n/g, "<br>") 
					|| "";
				
				if (description) {
					content += `<div class="tooltip-description">${description}</div>`;
				}
				
			} else {
				// Для остальных предметов - стандартная логика
				const description = item.info?.description?.replace(/\n/g, "<br>") 
					|| item.description?.replace(/\n/g, "<br>") 
					|| "No description available.";
			
				const renderInfo = (obj, indent = 0) => {
					let html = "";
					// Поля которые нужно скрыть (технические)
					const hiddenFields = [
						'description', 'lastUpdate', 'componentshash', 'components',
						// Поля одежды (на случай если предмет не определился как одежда)
						'_c', '_h', '_m', '_t', '_g', '_e', '_category', '_hash', 
						'_model', '_texture', '_isMale', '_equipped',
						'category', 'hash', 'model', 'texture', 'isMale', 'equipped'
					];
					
					for (const [key, value] of Object.entries(obj)) {
						if (hiddenFields.includes(key)) continue;
			
						//const padding = "&nbsp;".repeat(indent * 4);
	
						if (typeof value === "object" && value !== null && !Array.isArray(value)) {
							html += `<div class="tooltip-info"><span class="tooltip-info-key">${this.formatKey(key)}</span></div>`;
							html += renderInfo(value, indent + 1);
						} else {
							let displayValue = value;
							if (typeof value === "number") { //если это номер- то для качества округляем и приписываем %
								displayValue = `${value.toFixed(2)} %`;
							}
							html += `<div class="tooltip-info"><span class="tooltip-info-key">${this.formatKey(key)}</span>${displayValue}</div>`;
						}
					}

					return html;
				};
				
				if (item.info && Object.keys(item.info).length > 0) {
					content += renderInfo(item.info);
				}
			
				content += `<div class="tooltip-description">${description}</div>`;
			}
			
			// Общие поля для всех предметов
			if (item.amount !== undefined && item.amount > 1) {
				content += `<div class="tooltip-info-price"><span class="tooltip-info-price-key">${this.t.amount}:</span><span class="tooltip-info-amount"> ${item.amount}</span><span class="tooltip-info-price-dollar"> ${this.t.amount_end}</span></div>`;
			}
			
			if (item.price !== undefined && item.price > 0) {
				content += `<div class="tooltip-info-price"><span class="tooltip-info-price-key">${this.t.buy_price}:</span><span class="tooltip-info-price"> ${(item.price).toFixed(2)}</span><span class="tooltip-info-price-dollar"> ${" $"}</span></div>`;
			}
			if (item.buyPrice !== undefined && item.buyPrice > 0) {
				content += `<div class="tooltip-info-price"><span class="tooltip-info-price-key">${this.t.sell_price}:</span><span class="tooltip-info-byprice"> ${(item.buyPrice).toFixed(2)}</span><span class="tooltip-info-price-dollar"> ${" $"}</span></div>`;
			}
			
            content += `<div class="tooltip-weight"><i class="fas fa-weight-hanging"></i> ${item.weight != null ? (item.weight / 1000).toFixed(1) : "N/A"}kg</div>`;
            content += `</div>`;
        
            return content;
        },
		
		// Добавьте эту новую функцию в methods (после generateTooltipContent):
		isClothingItem(item) {
			if (!item) return false;
			
			// Список имён предметов одежды
			const clothingItems = [
				'clothing_item',
				'clothing_hats',
				'clothing_shirts_full',
				'clothing_pants',
				'clothing_boots',
				'clothing_vests',
				'clothing_coats',
				'clothing_coats_closed',
				'clothing_gloves',
				'clothing_neckwear',
				'clothing_masks',
				'clothing_eyewear',
				'clothing_gunbelts',
				'clothing_satchels',
				'clothing_skirts',
				'clothing_chaps',
				'clothing_spurs',
				'clothing_suspenders',
				'clothing_belts',
				'clothing_cloaks',
				'clothing_ponchos',
				'clothing_neckties',
				'clothing_gauntlets',
				'clothing_holsters_knife',
				'clothing_loadouts',
				'clothing_holsters_left',
				'clothing_holsters_right',
				'clothing_holsters_crossdraw',
				'clothing_aprons',
				'clothing_boot_accessories',
				'clothing_spats',
				'clothing_jewelry_rings_right',
				'clothing_jewelry_rings_left',
				'clothing_jewelry_bracelets',
				'clothing_talisman_holster',
				'clothing_talisman_wrist',
				'clothing_belt_buckles',
				'clothing_bows',
				'clothing_hair_accessories',
				'clothing_dresses',
			];
			
			// Проверка по имени предмета
			if (item.name && clothingItems.includes(item.name)) return true;
			
			// Проверка по префиксу имени
			if (item.name && item.name.startsWith('clothing_')) return true;
			
			// Проверка по наличию характерных полей одежды в info
			if (item.info) {
				const hasClothingFields = item.info._c !== undefined || 
										item.info._category !== undefined || 
										item.info._h !== undefined ||
										item.info._m !== undefined;
				if (hasClothingFields) return true;
			}
			
			// Проверка по типу предмета
			if (item.type === 'clothes' || item.type === 'clothing') return true;
			
			return false;
		},
        /**formatKey(key) {
            return key.replace(/_/g, " ").charAt(0).toUpperCase() + key.slice(1);
        },**/

		formatKey(key) {
			let formattedKey = key.replace(/_/g, " ");
			formattedKey = formattedKey.charAt(0).toUpperCase() + formattedKey.slice(1);
		
			// Список ключей локализации, которые нужно заменять
			const map = {
				Serie: "serial",
				Quality: "quality_full",
			};
		
			for (const endWord in map) {
				if (formattedKey.endsWith(endWord)) {
		
					// Берём строку из this.t, например this.t.serial
					const locKey = map[endWord];
					const localized = this.t[locKey] || endWord;
		
					formattedKey =
						formattedKey.slice(0, -endWord.length) + localized;
				}
			}
		
			return formattedKey;
		},
		
		
		async postData(eventName, data = {}) {
			try {
				const response = await axios.post(`https://rsg-inventory/${eventName}`, data);
				
				// Axios автоматически парсит JSON и кладет его в .data
				// Мы возвращаем структуру, к которой вы привыкли
				return {
					ok: true,
					data: response.data
				};
			} catch (error) {
				console.error(`[NUI] Erro ao postar para ${eventName}:`, error);
				return { 
					ok: false, 
					message: error.message 
				};
			}
		},
		
		
        postInventoryData(fromInventory, toInventory, fromSlot, toSlot, fromAmount, toAmount) {
            this.busy = true;
            let fromInventoryName = fromInventory === "other" ? this.otherInventoryName : fromInventory;
            let toInventoryName = toInventory === "other" ? this.otherInventoryName : toInventory;

            axios
                .post("https://rsg-inventory/SetInventoryData", {
                    fromInventory: fromInventoryName,
                    toInventory: toInventoryName,
                    fromSlot,
                    toSlot,
                    fromAmount,
                    toAmount,
                })
                .then((response) => {
                    this.clearDragData();
                    this.busy = false;
                })
                .catch((error) => {
                    console.error("Error posting inventory data:", error);
                    this.busy = false;
                });
        },

        // -------- Trade Methods --------
        openTrade(data) {
            this.isInventoryOpen = true;
            this.maxWeight = data.maxweight || 0;
            this.totalSlots = data.slots || 0;
            this.playerId = data.playerId || null;
            this.playerName = data.playerName || null;
            this.cash = data.cash || 0;
            this.playerInventory = {};
            this.otherInventory = {};
            this.isOtherInventoryEmpty = true;
			this.maxTradeSlots = data.maxTradeSlots || 10;

            if (data.labels) {
                this.t = { ...this.t, ...data.labels };
                this.inventoryLabel = this.t.satchel || this.inventoryLabel;
            }

            if (data.inventory) {
                if (Array.isArray(data.inventory)) {
                    data.inventory.forEach((item) => {
                        if (item && item.slot) {
                            this.playerInventory[item.slot] = item;
                        }
                    });
                } else if (typeof data.inventory === "object") {
                    for (const key in data.inventory) {
                        const item = data.inventory[key];
                        if (item && item.slot) {
                            this.playerInventory[item.slot] = item;
                        }
                    }
                }
            }

            this.tradeId = data.tradeId;
            this.tradePartner = data.partnerId;
            this.tradePartnerName = data.partnerName;
            this.myTradeOffers = {};
            this.theirTradeOffers = {};
            this.myTradeAccepted = false;
            this.theirTradeAccepted = false;
            this.isTradeActive = true;
            this.isTradeComplete = false;

            //this.$nextTick(() => {
            //    this.attachGridScrollListeners();
            //});
			this.postData('playSound', {	soundSet: "HUD_PLAYER_MENU", soundName: "MENU_ENTER" });
        },
/*        updateTrade(data) {
            const tradeData = data.tradeData;
            const myId = Number(this.playerId);
            const isInitiator = Number(tradeData.initiator) === myId;
            this.myTradeAccepted = isInitiator ? tradeData.initiatorAccepted : tradeData.targetAccepted;
            this.theirTradeAccepted = isInitiator ? tradeData.targetAccepted : tradeData.initiatorAccepted;
            this.myTradeOffers = isInitiator ? tradeData.initiatorItems : tradeData.targetItems;
            this.theirTradeOffers = isInitiator ? tradeData.targetItems : tradeData.initiatorItems;
			console.log('myTradeOffers keys', Object.keys(this.myTradeOffers));
			console.log('myTradeOffers raw', this.myTradeOffers);
        },
*/
		updateTrade(data) {
			const tradeData = data.tradeData;
			const myId = Number(this.playerId);
			const isInitiator = Number(tradeData.initiator) === myId;
		
			this.myTradeAccepted = isInitiator ? tradeData.initiatorAccepted : tradeData.targetAccepted;
			this.theirTradeAccepted = isInitiator ? tradeData.targetAccepted : tradeData.initiatorAccepted;
		
			const rawMyItems = isInitiator ? tradeData.initiatorItems : tradeData.targetItems;
			const rawTheirItems = isInitiator ? tradeData.targetItems : tradeData.initiatorItems;
		
			const normalizedMy = {};
			const normalizedTheir = {};
		
			if (Array.isArray(rawMyItems)) {
				rawMyItems.forEach((item) => {
					if (item && item.slot) {
						normalizedMy[item.slot] = item;
					}
				});
			} else if (rawMyItems && typeof rawMyItems === "object") {
				for (const key in rawMyItems) {
					const item = rawMyItems[key];
					if (item && item.slot) {
						normalizedMy[item.slot] = item;
					}
				}
			}
		
			if (Array.isArray(rawTheirItems)) {
				rawTheirItems.forEach((item) => {
					if (item && item.slot) {
						normalizedTheir[item.slot] = item;
					}
				});
			} else if (rawTheirItems && typeof rawTheirItems === "object") {
				for (const key in rawTheirItems) {
					const item = rawTheirItems[key];
					if (item && item.slot) {
						normalizedTheir[item.slot] = item;
					}
				}
			}
		
			this.myTradeOffers = normalizedMy;
			this.theirTradeOffers = normalizedTheir;
		},


        cancelTradeUI() {
            this.isTradeActive = false;
            this.isTradeComplete = false;
            this.tradeId = null;
            this.tradePartner = null;
            this.tradePartnerName = null;
            this.myTradeOffers = {};
            this.theirTradeOffers = {};
            this.myTradeAccepted = false;
            this.theirTradeAccepted = false;
			this.closeInventory();
			console.log("Trade Canceled")
        },
        completeTradeUI() {
            this.isTradeActive = false;
            this.isTradeComplete = true;
            this.tradeId = null;
            this.tradePartner = null;
            this.tradePartnerName = null;
            this.myTradeOffers = {};
            this.theirTradeOffers = {};
            this.myTradeAccepted = false;
            this.theirTradeAccepted = false;
            this.closeInventory();
			console.log("Trade Completed")
        },
        async addItemToTrade(item, amount) {
            if (!this.isTradeActive || !this.tradeId) return;
            const amountToAdd = amount !== undefined ? amount : item.amount;
            if (amountToAdd < 1 || amountToAdd > item.amount) return;
			
			try {
				const response = await axios.post("https://rsg-inventory/AddTradeItem", {
					tradeId: this.tradeId,
					item: item,
					amount: amountToAdd,
				});
			
				this.showContextMenu = false;
				return response?.data === true || response?.data?.ok === true;
			} catch (error) {
				console.error("Error adding item to trade:", error);
				return false;
			}
        },
        async addItemToTradeWithPrompt(item) {
            if (!this.isTradeActive || !this.tradeId) return;
            try {
                const response = await axios.post("https://rsg-inventory/GiveItemAmount");
                const amount = response.data;
                if (amount && amount > 0 && amount <= item.amount) {
                    this.addItemToTrade(item, amount);
                }
            } catch (error) {
                console.error("Error getting trade amount:", error);
            }
            this.showContextMenu = false;
        },
        removeItemFromTrade(tradeSlot) {
            if (!this.isTradeActive || !this.tradeId) return;
            axios.post("https://rsg-inventory/RemoveTradeItem", {
                tradeId: this.tradeId,
                tradeSlot: tradeSlot,
            }).catch((error) => {
                console.error("Error removing item from trade:", error);
            });
        },
        confirmTrade() {
            if (!this.isTradeActive || !this.tradeId) return;
            axios.post("https://rsg-inventory/ConfirmTrade", {
                tradeId: this.tradeId,
            }).catch((error) => {
                console.error("Error confirming trade:", error);
            });
        },
        cancelTrade() {
            if (!this.isTradeActive || !this.tradeId) return;
            axios.post("https://rsg-inventory/CancelTrade", {
                tradeId: this.tradeId,
            }).catch((error) => {
                console.error("Error cancelling trade:", error);
            });
        },
        initiateTrade(targetId) {
            axios.post("https://rsg-inventory/InitiateTrade", {
                targetId: targetId,
            }).catch((error) => {
                console.error("Error initiating trade:", error);
            });
        },

		_gridSetupScrollSnap() {
            const containers = document.querySelectorAll(".item-grid");
            if (containers.length === 0) return;
            containers.forEach((container) => {
                if (!container._selected) {
                    const selected = document.createElement("div");
                    selected.className = "item-selected";
                    selected.style.opacity = "0";
                    document.body.appendChild(selected);
                    container._selected = selected;
                }
                container.removeEventListener("wheel", this._gridOnWheelScroll);
                container.addEventListener("wheel", this._gridOnWheelScroll, { passive: false });
                container.removeEventListener("mouseover", this._gridOnHoverSlot);
                container.addEventListener("mouseover", this._gridOnHoverSlot);
                container.removeEventListener("mouseleave", this._gridClearHighlight);
                container.addEventListener("mouseleave", this._gridClearHighlight);
                container.addEventListener("scroll", this.gridUpdateSelectedPosition, true);
                container.addEventListener("resize", this.gridUpdateSelectedPosition);
                //container.removeEventListener("click", this._gridOnClickSlot);
                //container.addEventListener("click", this._gridOnClickSlot);
            });
        },
        _gridOnWheelScroll(event) {
            event.preventDefault();
            const container = event.currentTarget;
            const cellHeight = (9.0 * Math.min(window.innerWidth, window.innerHeight)) / 100;
            const direction = Math.sign(event.deltaY);
            container.scrollBy({ top: direction * cellHeight, behavior: "instant" });
        },
        _gridEnsureHoverEl() {
            if (!this._gridHoverHighlightEl) {
                const highlight = document.createElement("div");
                highlight.className = "item-highlight";
                highlight.style.opacity = "0";
                document.body.appendChild(highlight);
                this._gridHoverHighlightEl = highlight;
            }
            return this._gridHoverHighlightEl;
        },
        _gridOnHoverSlot(e) {
            const slot = e.target.closest(".item-slot");
            if (!slot) return;
            const highlight = this._gridEnsureHoverEl();
            const rect = slot.getBoundingClientRect();
            const offset = 2.5;
            const correction = 4.0;
            highlight.style.top = `${rect.top + window.scrollY - correction}px`;
            highlight.style.left = `${rect.left + window.scrollX - correction}px`;
            highlight.style.width = `${rect.width + offset * 2 + correction}px`;
            highlight.style.height = `${rect.height + offset * 2 + correction}px`;
            highlight.style.opacity = "1";
        },
        _gridMoveSelectedToSlot(container, slot) {
			if (!container || !slot) return; // если не передали контейнер или слот
			// если слот пустой → ничего не делаем, оставляем старое выделение
			//const itemImg = slot.querySelector("img");
			//if (!itemImg) return;
			
            const selected = container._selected;
            const rect = slot.getBoundingClientRect();
            const offset = 2.5;
            const correction = 4.0;
            selected.style.top = `${rect.top + window.scrollY - correction}px`;
            selected.style.left = `${rect.left + window.scrollX - correction}px`;
            selected.style.width = `${rect.width + offset * 2 + correction}px`;
            selected.style.height = `${rect.height + offset * 2 + correction}px`;
            selected.style.opacity = "1";
        },
        gridUpdateSelectedPosition(event) {
            const container = event.currentTarget;
            const slot = container._lockedSlot;
            if (!slot) return;
            const selected = container._selected;
            const rect = slot.getBoundingClientRect();
            const containerRect = container.getBoundingClientRect();
            const offset = 2.5;
            const correction = 4.0;
            const isInView = rect.bottom > containerRect.top && rect.top < containerRect.bottom && rect.right > containerRect.left && rect.left < containerRect.right;
            if (!isInView) {
                selected.style.opacity = "0";
                return;
            }
            selected.style.top = `${rect.top + window.scrollY - correction}px`;
            selected.style.left = `${rect.left + window.scrollX - correction}px`;
            selected.style.width = `${rect.width + offset * 2 + correction}px`;
            selected.style.height = `${rect.height + offset * 2 + correction}px`;
            selected.style.opacity = "1";
        },
        //_gridOnClickSlot(e) {
        //    const container = e.currentTarget;
        //    const slot = e.target.closest(".item-slot");
        //    if (!slot) return;
        //    container._lockedSlot = slot;
        //    this._gridMoveSelectedToSlot(container, slot);
        //},
		// 🔹 Сбрасывает выделение везде
        _gridClearAllSelections() {
            document.querySelectorAll('.item-selected').forEach(el => el.remove());
            document.querySelectorAll('.item-grid').forEach(container => {
                container._lockedSlot = null;
                container._selected = null;
            });
        },
		// 🔹 Сбрасывает выделение только в указанном инвентаре
		clearInventorySelection(sourceInventory) {
			let invType = null;

			if (sourceInventory === this.playerInventory) {
				invType = "player";
				this.selectedPlayerItemInfo = null;
			} else if (sourceInventory === this.otherInventory) {
				invType = "other";
				this.selectedOtherItemInfo = null;
			} else if (sourceInventory === this.myTradeOffers) {
				invType = "trade-my";
				this.selectedTradeItemInfo = null;
			} else if (sourceInventory === this.theirTradeOffers) {
				invType = "trade-their";
				this.selectedTradeItemInfo = null;
			}
		
			if (!invType) return;
	
			document.querySelectorAll(`.item-grid[data-inventory="${invType}"]`).forEach(grid => {
				grid._lockedSlot = null;
				if (grid._selected) {
					grid._selected.style.opacity = "0";
				}
			});
		},
        _gridClearHighlight() {
            const el = this._gridHoverHighlightEl;
            if (el) el.style.opacity = "0";
        },
        _gridSetupObserver() {
            if (this._gridDomObserver) {
                try { this._gridDomObserver.disconnect(); } catch (_) {}
            }
            const cb = () => {
                const hasGrid = !!document.querySelector('.item-grid');
                if (hasGrid) {
                    this._gridSetupScrollSnap();
                } else {
                    this._gridClearHighlight();
                    this._gridClearAllSelections();
                }
            };
            const observer = new MutationObserver(cb);
            observer.observe(document.body, { childList: true, subtree: true });
            this._gridDomObserver = observer;
        },
		// Универсальный метод выделения слота
		selectSlot(event, itemInSlot, inventory) {
			if (itemInSlot && itemInSlot.label) {  // нет предмета предмета → ничего не делаем, оставляем старое выделение
				const grid = event.currentTarget.closest(".item-grid") || event.target.closest(".item-grid");
				const slotEl = event.currentTarget.closest(".item-slot") || event.target.closest(".item-slot");
		
				if (grid && slotEl && typeof slotEl.getBoundingClientRect === "function") {
					grid._lockedSlot = slotEl;
					this._gridMoveSelectedToSlot(grid, slotEl);
				}
				
				if (inventory === "player") {
					this.selectedPlayerItemInfo = itemInSlot;
					//console.log("Инвентарь: player", grid);
				}
				else if (inventory == "other") {
					this.selectedOtherItemInfo = itemInSlot;
				}
				else if (inventory === "trade-my" || inventory === "trade-their") {
					//сбрасываем выделение в обоих сетках
					this.clearInventorySelection(this.myTradeOffers);
					this.clearInventorySelection(this.theirTradeOffers);
					
					this.selectedTradeItemInfo = itemInSlot;
					//ставим выделение только в последней кликнутой.
					grid._lockedSlot = slotEl;
					if (grid._selected) {
						grid._selected.style.opacity = "1";
					}				
					this.gridUpdateSelectedPosition({ currentTarget: grid });
				}
				// Звук переключения (BUMPERLEFT/RIGHT)
				this.postData('playSound', { soundSet: 'HUD_PLAYER_MENU', soundName: 'SELECT' });
			}
		},		
		// Универсальная функция форматирования веса
		formatWeight(item, withAmount = false) {
			if (!item || !item.weight) return null;
	
			let grams = item.weight;
			if (withAmount && item.amount) {
				grams = grams * item.amount;
			}
	
			const kg = grams / 1000;
			return kg % 1 === 0 ? kg.toFixed(1) : kg;
		},
		
		
		// вернуть общую категорию по предмету
/**		getMainCategory(item) {
		// возвращаем основную категорию по типу (не помещаем сюда "sell")
			if (!item || !item.type) return CATEGORY_MAP.default;
			return CATEGORY_MAP[item.type] || CATEGORY_MAP.default;
		},
**/		
		getMainCategory(item) {
			// возвращаем основную категорию по типу (не помещаем сюда "sell")
			const map = this.categoryMap || {};
			const def = map.default || "misc";
			
			if (!item || !item.type) return def;
			return map[item.type] || def;
		},
		
		// красивое имя для центра
		categoryTitle(cat) {
			return this.t.categories?.[cat] || cat;
		},
		
		// прямой выбор категории по клику
		setPlayerCategory(cat) {
			if (this.availablePlayerCategories.includes(cat)) {
				this.currentPlayerCategory = cat;
				// 🔹 Сбрасываем выделение и инфо при смене категории
				this.clearInventorySelection(this.playerInventory);
				this.postData('playSound', { soundSet: 'HUD_PLAYER_MENU', soundName: 'BUMPER_LEFT' });
			}
		},
		setOtherCategory(cat) {
			if (this.availableOtherCategories.includes(cat)) {
				this.currentOtherCategory = cat;
				// 🔹 Сбрасываем выделение и инфо при смене категории
				this.clearInventorySelection(this.otherInventory);
				this.postData('playSound', { soundSet: 'HUD_PLAYER_MENU', soundName: 'BUMPER_LEFT' });
			}
		},
		
		
		cycleShopMode(direction) {
			const modes = [];
			let hasBuy = false, hasSell = false;
		
			for (let slot = 1; slot <= this.otherInventorySlots; slot++) {
			const it = this.getItemInSlot(slot, "other");
			if (!it) continue;
			if (it.price) hasBuy = true;
			if (it.buyPrice) hasSell = true;
			}
		
			if (hasBuy) modes.push("buy");
			if (hasSell) modes.push("sell");
			if (!modes.length) return;
		
			let idx = modes.indexOf(this.currentShopMode);
			if (idx === -1) idx = 0;
			const next = (idx + direction + modes.length) % modes.length;
			this.currentShopMode = modes[next];
			this.currentOtherCategory = "all"; // сбрасываем категорию при смене режима
			this.clearInventorySelection(this.otherInventory); // убираем выделение
		},
		
		
		
		
		
		// циклическое переключение (direction: +1 вправо, -1 влево)
		cyclePlayerCategory(direction) {
			const cats = this.availablePlayerCategories;
			if (!cats.length) return;
			const idx = Math.max(0, cats.indexOf(this.currentPlayerCategory));
			const next = (idx + direction + cats.length) % cats.length;
			this.currentPlayerCategory = cats[next];
			// 🔹 Сбрасываем выделение и инфо при смене категории
			this.clearInventorySelection(this.playerInventory);
			this.postData('playSound', { soundSet: 'HUD_PLAYER_MENU', soundName: 'BUMPER_LEFT' });
		},
		cycleOtherCategory(direction) {
			const cats = this.availableOtherCategories;
			if (!cats.length) return;
			const idx = Math.max(0, cats.indexOf(this.currentOtherCategory));
			const next = (idx + direction + cats.length) % cats.length;
			this.currentOtherCategory = cats[next];
			// 🔹 Сбрасываем выделение и инфо при смене категории
			this.clearInventorySelection(this.otherInventory);
			this.postData('playSound', { soundSet: 'HUD_PLAYER_MENU', soundName: 'BUMPER_LEFT' });
		},
		// нажатие на кнопки клавиатуры для переключения категорий
		_onKeyCat(e) {
		// используем e.code (чтобы не зависеть от раскладки)
			switch (e.code) {
				case "KeyQ": this.cyclePlayerCategory(-1); break;
				case "KeyE": this.cyclePlayerCategory(1); break;
				case "KeyA":
					if (this.isShopInventory) this.cycleShopMode(-1);
					else this.cycleOtherCategory(-1);
					break;
				case "KeyD":
					if (this.isShopInventory) this.cycleShopMode(1);
					else this.cycleOtherCategory(1);
					break;
			}
		},
		
		
		askForAmount() {
			return new Promise((resolve) => {				
				this.tempTransferAmount = null;
				this.showAmountPrompt = true;
				this.postData('playSound', { soundSet: "Study_Sounds", soundName: "show_info" });
				//устанавливаем фокус на строке ввода после открытия
				this.$nextTick(() => {
					this.$refs.amountInput.focus();
				});
		
				// сохраняем resolve, чтобы потом вызвать при нажатии OK
				this.amountPromiseResolve = resolve;
			});
		},
		
		// 🟢 Подтверждение
		confirmAmount() {
			if (this.tempTransferAmount <= 0) return;
		
			this.showAmountPrompt = false;
			this.postData('playSound', { soundSet: "Study_Sounds", soundName: "hide_info" });
		
			if (this.amountPromiseResolve) {
				this.amountPromiseResolve(this.tempTransferAmount);
				this.amountPromiseResolve = null;
			}
		},
	
		// 🔴 Отмена
		cancelAmount() {
			this.showAmountPrompt = false;
			this.postData('playSound', { soundSet: "Study_Sounds", soundName: "hide_info" });
			
			if (this.amountPromiseResolve) {
				this.amountPromiseResolve(null);
				this.amountPromiseResolve = null;
			}

			this.clearDragData();
		},
		
		
		
		
    },
    mounted() {
		//this.applyUniversalTint();//покраска текстур
		
		
        // Inject CSRF token into all outgoing NUI callback calls
        axios.interceptors.request.use((config) => {
            if (config.url && config.url.startsWith("https://rsg-inventory/")) {
                const token = window.nuiToken;
                if (token && typeof config.data === "object" && config.data !== null) {
                    config.data.token = token;
                }
            }
            return config;
        });
		
        window.addEventListener("keyup", (event) => {
            const code = event.code;
			
			if (this.showTradeInvite) {
				if (code === 'Escape') {
					this.declineTradeInvite();
					return;
				}
		
				if (code === 'Enter' || code === 'NumpadEnter') {
					this.acceptTradeInvite();
					return;
				}
			}
			
            if (!this.showAmountPrompt && !this.isTradeActive) { //если не показано окно ввода количества и не трейд
				if (code === "Escape" || code === "Tab" || code === this.additionalCloseKey) {
					if (this.isInventoryOpen) {
						this.closeInventory();
					}
				}
			} else if (this.showAmountPrompt) { //если показано окно ввода количества
				if (code === "Escape") {
					this.cancelAmount();
				} else if (code === "Enter" || code === "NumpadEnter") {
					this.confirmAmount();
				}
			} else if (this.isTradeActive) { //если это трейд
				if (code === "Escape" || code === "Tab" || code === this.additionalCloseKey) {
					if (this.isInventoryOpen) {
						this.cancelTrade();
					}
				} else if (code === "Enter" || code === "NumpadEnter") {
					//Запрещаем подтеверждать трейд пока ничего нет для передачи у обоих
					const noItemsToTrade =	Object.keys(this.myTradeOffers).length === 0 &&	Object.keys(this.theirTradeOffers).length === 0;
					if (noItemsToTrade) {
						return;
					}
					this.confirmTrade();
				}
			}
        });

        window.addEventListener("message", async (event) => {
            // Store callback token for NUI callback CSRF validation
            if (event.data.invToken) {
                this.nuiToken = event.data.invToken;
                window.nuiToken = event.data.invToken;
            }
            switch (event.data.action) {
                case "open":
                    let isValid = await this.validateToken(event.data.token)
                    if (isValid) {
                        this.openInventory(event.data);
                    }
                    break;
                case "close":
                    this.closeInventory();
                    break;
                case "update":
                    if (this.validateToken(event.data.token)) {
                        this.updateInventory(event.data);
                    }
                    break;
                case "toggleHotbar":
                    if (this.validateToken(event.data.token)) {
                        this.toggleHotbar(event.data);
                    }
                    break;
                case "itemBox":
                    this.showItemNotification(event.data);
                    break;
                case "requiredItem":
                    this.showRequiredItem(event.data);
                    break;
                case "updateHotbar":
                    if (this.validateToken(event.data.token)) {
                        this.hotbarItems = event.data.items;
                    }
                    break;
				case "updateMoney":
					this.cash = event.data.cash;
					break;
				
				case "openTrade":
                    if (await this.validateToken(event.data.token)) {
                        this.openTrade(event.data);
                    }
                    break;
                case "updateTrade":
                    if (await this.validateToken(event.data.token)) {
                        this.updateTrade(event.data);
                    }
                    break;
                case "cancelTrade":
                    if (await this.validateToken(event.data.token)) {
                        this.cancelTradeUI();
                    }
                    break;
                case "completeTrade":
                    if (await this.validateToken(event.data.token)) {
                        this.completeTradeUI();
                    }
                    break;
					
					
					
				case 'showTradeInvite':
					if (await this.validateToken(event.data.token)) {
						if (event.data.labels) {
							this.t = { ...this.t, ...event.data.labels };
						}
						this.showTradeInviteUI(
							event.data.initiatorId,
							event.data.initiatorName,
							event.data.duration || 30000
						);
						//this.postData('playSound', {	soundSet: "RDRO_Notoriety_Sounds", soundName: "Defense_Enabled" });
						this.postData('playSound', {	soundSet: "HUD_MAIL_SOUNDSET", soundName: "MAIL" });
					}
					break;
				
				case 'hideTradeInvite':
					if (await this.validateToken(event.data.token)) {
						this.hideTradeInviteUI();
					}
					break;
					
					
					
					
                default:
                    console.warn(`Unexpected action: ${event.data.action}`);
            }
        });
		window.addEventListener("keydown", this._onKeyCat);
		this._gridEnsureHoverEl();
        this._gridSetupScrollSnap();
        this._gridSetupObserver();		
    },
    beforeUnmount() {
        window.removeEventListener("mousemove", () => { });
        window.removeEventListener("keydown", () => { });
        window.removeEventListener("message", () => { });
		window.removeEventListener("keydown", this._onKeyCat);
		
		// === Дополнено: очистка нижнего кода ===
        if (this._gridDomObserver) {
            try { this._gridDomObserver.disconnect(); } catch (_) {}
            this._gridDomObserver = null;
        }
        this._gridClearHighlight();
        this._gridClearAllSelections();
		
		
    },
	/*updated() {
		this.applyUniversalTint();//покраска текстур
	},*/
});

InventoryContainer.use(FloatingVue);
InventoryContainer.mount("#app");






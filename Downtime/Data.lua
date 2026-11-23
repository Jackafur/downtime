local _, ns = ...

-- What the menu can show. Spells are matched by name against your spellbook, and only spells you know are shown, so a spell the
-- game does not have (or you have not learned yet) is skipped without any error. Items are shown only while you carry them.
-- Rows appear top to bottom: your class's own rows first, then the rows everyone gets. A spell is shown once, in the first row
-- that claims it. Which rows are shown is chosen in /downtime options ("default = false" means a row starts switched off).
--
-- A row can have:
--   names       spells by exact name, in this order
--   patterns    every spell in your spellbook whose name matches, in spellbook order
--   exclude     spell names the patterns skip
--   items       item families: each one is a button for the best one you carry (ids from best to worst)
--   itemsFirst  the items come before the spells in the row
--   targetSlot  a click uses the item on this equipment slot (16 main hand, 17 off hand), for rogue poisons; the row is only
--               shown while a weapon is in that slot

-- Rogue poisons, best rank first. The last four are WoW Forever's.
local POISONS = {
	{ label = "Instant Poison", ids = { 8928, 8927, 8926, 6950, 6949, 6947 } },
	{ label = "Deadly Poison", ids = { 20844, 8985, 8984, 2893, 2892 } },
	{ label = "Crippling Poison", ids = { 3776, 3775 } },
	{ label = "Mind-numbing Poison", ids = { 9186, 6951, 5237 } },
	{ label = "Wound Poison", ids = { 10922, 10921, 10920, 10918 } },
	{ label = "Occult Poison", ids = { 234444, 226374 } },
	{ label = "Sebacious Poison", ids = { 217345 } },
	{ label = "Numbing Poison", ids = { 217346 } },
	{ label = "Atrophic Poison", ids = { 217347 } },
}

ns.Data = {
	classes = {
		-- The warlock menu, as LockMenu had it.
		WARLOCK = {
			shardItem = 6265,
			rows = {
				{
					label = "Demons",
					text = "Demons (summon your pet)",
					names = { "Summon Imp", "Summon Voidwalker", "Summon Succubus", "Summon Incubus", "Summon Felhunter", "Summon Felguard" },
					-- Any other "Summon ..." spell you know also lands here, except the mounts, which go to Utility.
					patterns = { "^Summon " },
					exclude = { ["Summon Felsteed"] = true, ["Summon Dreadsteed"] = true },
				},
				{
					label = "Buffs",
					text = "Buffs (armor, breath, invisibility)",
					names = { "Demon Skin", "Demon Armor", "Fel Armor", "Detect Invisibility", "Unending Breath", "Shadow Ward", "Soul Link" },
				},
				{
					label = "Utility",
					text = "Utility (summoning portal, rituals, mounts)",
					names = { "Ritual of Summoning", "Ritual of Souls", "Eye of Kilrogg", "Sense Demons", "Health Funnel", "Fel Domination",
						"Summon Felsteed", "Summon Dreadsteed" },
				},
				{
					label = "Stones",
					text = "Stones (make healthstone, soulstone and more)",
					names = { "Create Healthstone", "Create Soulstone", "Create Firestone", "Create Spellstone" },
				},
				{
					label = "Curses",
					text = "Curses and banes",
					default = false,
					-- Every "Curse of ..." and "Bane of ..." you know, so changed curses appear without being listed.
					patterns = { "^Curse of ", "^Bane of " },
				},
				{
					label = "Control",
					text = "Control (fear, banish, howl, death coil)",
					default = false,
					names = { "Fear", "Banish", "Howl of Terror", "Death Coil", "Enslave Demon" },
				},
				{
					label = "Use",
					text = "The healthstone and soulstone you carry",
					items = {
						{ label = "Healthstone", ids = { 22105, 22104, 22103, 19013, 19012, 9421, 19011, 19010, 5510, 19009, 19008, 5509, 19007, 19006, 5511, 19005, 19004, 5512 } },
						{ label = "Soulstone", ids = { 22116, 16896, 16895, 16893, 16892, 5232 } },
					},
				},
			},
		},
		-- One press puts a poison on that hand.
		ROGUE = {
			rows = {
				{ label = "Main hand", text = "Poisons for your main hand (a click puts it on)", items = POISONS, targetSlot = 16 },
				{ label = "Off hand", text = "Poisons for your off hand (while you hold an off-hand weapon)", items = POISONS, targetSlot = 17 },
			},
		},
		PALADIN = {
			rows = {
				{
					label = "Blessings",
					text = "Blessings (might, wisdom, kings, salvation, light, sanctuary)",
					names = { "Blessing of Might", "Blessing of Wisdom", "Blessing of Kings", "Blessing of Salvation", "Blessing of Light",
						"Blessing of Sanctuary" },
				},
				{
					label = "Greater",
					text = "Greater blessings (the whole group's class)",
					patterns = { "^Greater Blessing of " },
				},
				{
					label = "Auras",
					text = "Auras",
					default = false,
					patterns = { " Aura$" },
				},
				{ label = "Utility", text = "Utility (redemption)", names = { "Redemption" } },
			},
		},
		MAGE = {
			rows = {
				{ label = "Conjure", text = "Conjure (water, food, mana gems)", patterns = { "^Conjure " } },
				{
					label = "Buffs",
					text = "Buffs (intellect, armor, magic)",
					names = { "Arcane Intellect", "Arcane Brilliance", "Frost Armor", "Ice Armor", "Mage Armor", "Molten Armor", "Dampen Magic",
						"Amplify Magic", "Slow Fall" },
				},
				{ label = "Teleports", text = "Teleports (yourself)", patterns = { "^Teleport: " } },
				{ label = "Portals", text = "Portals (for the group)", patterns = { "^Portal: " } },
			},
		},
		PRIEST = {
			rows = {
				{
					label = "Buffs",
					text = "Buffs (fortitude, spirit, shadow protection, inner fire)",
					names = { "Power Word: Fortitude", "Prayer of Fortitude", "Divine Spirit", "Prayer of Spirit", "Shadow Protection",
						"Prayer of Shadow Protection", "Inner Fire", "Fear Ward", "Touch of Weakness", "Shadowguard" },
				},
				{ label = "Utility", text = "Utility (resurrection, levitate, mind vision)", names = { "Resurrection", "Levitate", "Mind Vision" } },
			},
		},
		DRUID = {
			rows = {
				{ label = "Buffs", text = "Buffs (mark of the wild, thorns)", names = { "Mark of the Wild", "Gift of the Wild", "Thorns", "Omen of Clarity" } },
				{ label = "Utility", text = "Utility (rebirth)", names = { "Rebirth" } },
			},
		},
		SHAMAN = {
			rows = {
				{
					label = "Weapons",
					text = "Weapon enchants (rockbiter, flametongue, frostbrand, windfury)",
					names = { "Rockbiter Weapon", "Flametongue Weapon", "Frostbrand Weapon", "Windfury Weapon" },
					patterns = { " Weapon$" },
				},
				{
					label = "Utility",
					text = "Utility (shields, water walking and breathing, ancestral spirit, far sight)",
					names = { "Lightning Shield", "Water Shield", "Water Walking", "Water Breathing", "Ancestral Spirit", "Far Sight" },
				},
			},
		},
		HUNTER = {
			rows = {
				{
					label = "Pet",
					text = "Pet (call, dismiss, revive, mend, feed, tame, train)",
					names = { "Call Pet", "Dismiss Pet", "Revive Pet", "Mend Pet", "Feed Pet", "Tame Beast", "Beast Training" },
				},
			},
		},
		-- Warriors have no spells for between fights, so they get the rows everyone gets.
	},

	-- The rows everyone gets, after the class's own.
	shared = {
		{
			label = "Camp",
			text = "Camp: the campfire kit, camp objects and sleeping bag you carry",
			itemsFirst = true,
			names = { "Basic Campfire" },
			items = {
				{ label = "Campfire Kit", ids = { 279974, 279961, 279981 } }, -- Expert, Journeyman, Basic
				-- WoW Forever's camp objects, one button each (a profession places its own).
				{ label = "Camp Tent", ids = { 279978 } },
				{ label = "Tanning Rack", ids = { 279941 } },
				{ label = "Sewing Machine", ids = { 279945 } },
				{ label = "Sharpening Wheel", ids = { 279944 } },
				{ label = "Anvil", ids = { 279988 } },
				{ label = "Master Forge", ids = { 279955 } },
				{ label = "First Aid Kit", ids = { 279968 } },
				{ label = "Toxin Study", ids = { 279940 } },
				{ label = "Plague Doctor's Laboratory", ids = { 279951 } },
				{ label = "Incense Candle", ids = { 279962 } },
				{ label = "Greenhouse", ids = { 279964 } },
				{ label = "Seed Hybridizer", ids = { 279947 } },
				{ label = "Faction Banner", ids = { 279972, 279973 } },
				{ label = "Spinning Wheel", ids = { 279943 } },
				{ label = "Loom", ids = { 279959 } },
				{ label = "Fish Bowl", ids = { 279967 } },
				{ label = "Fishing Rack", ids = { 279965 } },
				{ label = "Fishing Hut", ids = { 279966 } },
				{ label = "Enchanted Lute", ids = { 279976 } },
				{ label = "Lodestone", ids = { 279960 } },
				{ label = "Rock Garden", ids = { 279948 } },
				{ label = "Molten Foundry", ids = { 279952 } },
				{ label = "Camp Chair", ids = { 279979 } },
				{ label = "Trapper's Workbench", ids = { 279938 } },
				{ label = "Field Guide", ids = { 279969 } },
				{ label = "Mana Well", ids = { 279956 } },
				{ label = "Fermenter", ids = { 279970 } },
				{ label = "Alchemy Laboratory", ids = { 279990 } },
				{ label = "Arcane Salvager", ids = { 279985 } },
				-- The Cozy Sleeping Bag (rested XP, from the Cozy Sleeping Bag quest chain).
				{ label = "Sleeping Bag", ids = { 211527 } },
			},
		},
		{
			label = "Hearths",
			text = "Hearths: your hearthstone, engineering teleports, Astral Recall, Teleport: Moonglade",
			itemsFirst = true,
			names = { "Astral Recall", "Teleport: Moonglade" },
			items = {
				{ label = "Hearthstone", ids = { 6948 } },
				{ label = "Dimensional Ripper - Everlook", ids = { 18984 } },
				{ label = "Ultrasafe Transporter: Gadgetzan", ids = { 18986 } },
				{ label = "EZ-Thro Field Transporter: Gadgetzan", ids = { 260819 } },
				{ label = "SAF-T Emergency Ripper: Everlook", ids = { 260820 } },
				{ label = "EZ and SAF Field Transporter: Mt. Hyjal", ids = { 260821 } },
				{ label = "Dimensional Transporter - Mt. Hyjal", ids = { 260823 } },
			},
		},
		{
			label = "Professions",
			text = "Professions: opens each one's window, plus Disenchant and Fishing",
			names = { "Alchemy", "Blacksmithing", "Enchanting", "Engineering", "Leatherworking", "Tailoring", "Jewelcrafting", "Inscription",
				"Cooking", "First Aid", "Smelting", "Poisons", "Disenchant", "Prospecting", "Fishing" },
		},
	},

	-- Spells to add at the end of the menu, by exact name. (The options window has a box for this too.)
	extra = {},
}

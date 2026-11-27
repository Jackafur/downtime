local _, ns = ...

BINDING_HEADER_DOWNTIME = "Downtime"
_G["BINDING_NAME_CLICK DowntimeKey:LeftButton"] = "Downtime - Menu (toggle or hold, see /downtime options)"

local Data, DB = ns.Data, ns.DB
local shardItem = ns.section and ns.section.shardItem -- warlocks: the soul shard count at the top
local GAP, PAD, LABEL_W, HEADER_H, SECTION_GAP = 4, 10, 76, 22, 13

local menu, dirty = nil, true
local buttons, labels = {}, {}
local shardText
local holdToken = 0
local keyBtn, armRelease, clearRelease -- the key's secure button and the two functions that load a spell onto it (see below)
local closeAfterFight, toldInFight = false, false

-- The menu holds secure buttons, so the game counts it as a protected frame: in a fight no addon may show, hide or move it.
-- Downtime is for between fights, so it never tries: in a fight the key does not open the menu, the menu closes as a fight
-- starts (the game still allows that then), and a close asked for in a fight waits for the fight's end.
local function closeMenu()
	if not (menu and menu:IsShown()) then return end
	if InCombatLockdown() then
		closeAfterFight = true
		return
	end
	menu:Hide()
end

local function secret(v)
	return issecretvalue and issecretvalue(v) or false
end

-- Spell information by ID or by name, from whichever API this client has. Returns name, icon, spell ID.
local function spellInfo(idOrName)
	if C_Spell and C_Spell.GetSpellInfo then
		local ok, info = pcall(C_Spell.GetSpellInfo, idOrName)
		if ok and type(info) == "table" and info.name then return info.name, info.iconID or info.originalIconID, info.spellID end
	end
	if GetSpellInfo then
		local ok, name, _, icon, _, _, _, id = pcall(GetSpellInfo, idOrName)
		if ok and name then return name, icon, id end
	end
end

-- Every spell name in the spellbook (highest spell ID kept per name). Returns the set, the names in book order, and whether
-- the book could be read at all.
local function scanSpellbook()
	local known, order, readable = {}, {}, false
	local function add(name, id)
		if type(name) ~= "string" or secret(name) then return end
		if known[name] == nil then
			known[name] = id or true
			order[#order + 1] = name
		elseif type(id) == "number" and (type(known[name]) ~= "number" or id > known[name]) then
			known[name] = id
		end
	end
	pcall(function()
		local SB = C_SpellBook
		local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
		if SB and SB.GetNumSpellBookSkillLines and SB.GetSpellBookSkillLineInfo and SB.GetSpellBookItemName and bank ~= nil then
			for line = 1, SB.GetNumSpellBookSkillLines() do
				local li = SB.GetSpellBookSkillLineInfo(line)
				if type(li) == "table" and li.itemIndexOffset and li.numSpellBookItems then
					readable = true
					for i = li.itemIndexOffset + 1, li.itemIndexOffset + li.numSpellBookItems do
						local name = SB.GetSpellBookItemName(i, bank)
						local id, future = nil, false
						if SB.GetSpellBookItemInfo then
							local item = SB.GetSpellBookItemInfo(i, bank)
							if type(item) == "table" then
								id = item.spellID
								future = (Enum and Enum.SpellBookItemType and item.itemType == Enum.SpellBookItemType.FutureSpell) or false
							end
						end
						if not future then add(name, id) end
					end
				end
			end
		elseif GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemName then
			for tab = 1, GetNumSpellTabs() do
				local _, _, offset, count = GetSpellTabInfo(tab)
				readable = true
				for i = offset + 1, offset + count do
					add((GetSpellBookItemName(i, BOOKTYPE_SPELL or "spell")))
				end
			end
		end
	end)
	return known, order, readable and #order > 0
end

local function itemCount(id)
	if C_Item and C_Item.GetItemCount then
		local ok, n = pcall(C_Item.GetItemCount, id)
		if ok and type(n) == "number" then return n end
	end
	if GetItemCount then
		local ok, n = pcall(GetItemCount, id)
		if ok and type(n) == "number" then return n end
	end
	return 0
end

local function itemIcon(id)
	if C_Item and C_Item.GetItemIconByID then
		local ok, icon = pcall(C_Item.GetItemIconByID, id)
		if ok and icon then return icon end
	end
	if GetItemIcon then
		local ok, icon = pcall(GetItemIcon, id)
		if ok and icon then return icon end
	end
	return 134400
end

local function showTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	local ok = false
	if self.kind == "spell" and self.spellID and GameTooltip.SetSpellByID then
		ok = pcall(GameTooltip.SetSpellByID, GameTooltip, self.spellID)
	elseif self.kind == "item" and self.itemID and GameTooltip.SetItemByID then
		ok = pcall(GameTooltip.SetItemByID, GameTooltip, self.itemID)
	end
	if not ok then GameTooltip:SetText(self.label or "?") end
	if self.targetSlot then
		GameTooltip:AddLine(self.targetSlot == 17 and "Click: put it on your off hand" or "Click: put it on your main hand", 0.4, 0.8, 1)
	end
	GameTooltip:Show()
end

local function newButton(index)
	local b = CreateFrame("Button", "DowntimeButton" .. index, menu, "SecureActionButtonTemplate")
	b:RegisterForClicks("LeftButtonUp")
	b:SetAttribute("useOnKeyDown", false)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetAllPoints()
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	b.count:SetPoint("BOTTOMRIGHT", -2, 2)
	b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
	b.cooldown:SetAllPoints()
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetColorTexture(1, 1, 1, 0.25)
	b:SetScript("OnEnter", function(self)
		showTooltip(self)
		if armRelease then armRelease(self) end
	end)
	b:SetScript("OnLeave", function()
		GameTooltip:Hide()
		if clearRelease then clearRelease() end
	end)
	-- After a cast the menu closes, if that is switched on (in a fight: after it, see closeMenu).
	b:SetScript("PostClick", function() if DB.close then closeMenu() end end)
	return b
end

local function updateButtons()
	if shardItem then shardText:SetText("Shards: " .. itemCount(shardItem)) end
	for _, b in ipairs(buttons) do
		if b:IsShown() then
			if b.kind == "item" then
				local n = itemCount(b.itemID)
				b.count:SetText(n > 1 and n or "")
				pcall(function()
					local start, duration
					if C_Container and C_Container.GetItemCooldown then
						start, duration = C_Container.GetItemCooldown(b.itemID)
					elseif GetItemCooldown then
						start, duration = GetItemCooldown(b.itemID)
					end
					if start and duration then b.cooldown:SetCooldown(start, duration) end
				end)
			elseif b.kind == "spell" then
				pcall(function()
					local start, duration
					if C_Spell and C_Spell.GetSpellCooldown then
						local info = C_Spell.GetSpellCooldown(b.spellID or b.spellName)
						if type(info) == "table" then start, duration = info.startTime, info.duration end
					elseif GetSpellCooldown then
						start, duration = GetSpellCooldown(b.spellName)
					end
					if start and duration then b.cooldown:SetCooldown(start, duration) end
				end)
			end
		end
	end
end

-- The two opacity settings. Changing a frame's opacity is allowed in combat.
local function applyLook()
	if not menu then return end
	menu:SetBackdropColor(0, 0, 0, DB.bg)
	menu:SetAlpha(DB.alpha)
end

-- The spells listed in the options box, plus any in Data.lua.
local function extraNames()
	local names = {}
	for _, n in ipairs(Data.extra or {}) do names[#names + 1] = n end
	for n in (DB.extra or ""):gmatch("[^,]+") do
		n = n:match("^%s*(.-)%s*$")
		if n ~= "" then names[#names + 1] = n end
	end
	return names
end

-- Is a weapon in this equipment slot? (Poisons only go on weapons, not on a shield or an off-hand book.)
local function weaponIn(slot)
	local id = GetInventoryItemID and GetInventoryItemID("player", slot)
	if not id then return false end
	if C_Item and C_Item.GetItemInfoInstant then
		local ok, _, _, _, _, _, classID = pcall(C_Item.GetItemInfoInstant, id)
		if ok and classID then return classID == 2 end
	end
	return true
end

-- Works out what to show and lays it out. Out of combat only, because it changes the secure buttons.
local function rebuild()
	if InCombatLockdown() then
		dirty = true
		return
	end
	dirty = false
	local SIZE = DB.size

	local known, order, haveBook = scanSpellbook()
	local function isKnown(name)
		if haveBook then return known[name] ~= nil end
		return spellInfo(name) ~= nil
	end
	local used = {}
	local function spellEntry(name)
		if used[name] then return nil end
		used[name] = true
		local id = type(known[name]) == "number" and known[name] or nil
		local _, icon, sid = spellInfo(id or name)
		return { kind = "spell", name = name, spellID = id or sid, icon = icon or 134400 }
	end

	local rows = {}
	for _, r in ipairs(ns.rows) do
		local row = r.row
		if ns.RowOn(r.key) and not (row.targetSlot and not weaponIn(row.targetSlot)) then
			local entries = {}
			local function addSpells()
				for _, name in ipairs(row.extra and extraNames() or row.names or {}) do
					if isKnown(name) then
						local e = spellEntry(name)
						if e then entries[#entries + 1] = e end
					end
				end
				if haveBook and row.patterns then
					for _, name in ipairs(order) do
						if not (row.exclude and row.exclude[name]) then
							for _, pattern in ipairs(row.patterns) do
								if name:find(pattern) then
									local e = spellEntry(name)
									if e then entries[#entries + 1] = e end
									break
								end
							end
						end
					end
				end
			end
			-- Each item family is one button, for the best one you carry.
			local function addItems()
				for _, family in ipairs(row.items or {}) do
					for _, id in ipairs(family.ids) do
						if itemCount(id) > 0 then
							entries[#entries + 1] = { kind = "item", name = family.label, itemID = id, icon = itemIcon(id), targetSlot = row.targetSlot }
							break
						end
					end
				end
			end
			if row.itemsFirst then
				addItems()
				addSpells()
			else
				addSpells()
				addItems()
			end
			if #entries > 0 then rows[#rows + 1] = { label = row.label, entries = entries, class = r.class } end
		end
	end

	-- Buttons and labels are reused. Whatever is left over is hidden. A thin line parts the class's rows from everyone's.
	local n, widest, y, lineAt = 0, 0, HEADER_H + PAD, nil
	for r, row in ipairs(rows) do
		if r > 1 and rows[r - 1].class and not row.class then
			lineAt = y + (SECTION_GAP - 2 * GAP) / 2
			y = y + SECTION_GAP - GAP
		end
		labels[r] = labels[r] or menu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		labels[r]:ClearAllPoints()
		labels[r]:SetPoint("TOPLEFT", menu, "TOPLEFT", PAD, -(y + SIZE / 2 - 5))
		labels[r]:SetText(row.label)
		labels[r]:Show()
		for c, e in ipairs(row.entries) do
			n = n + 1
			local b = buttons[n] or newButton(n)
			buttons[n] = b
			b:SetSize(SIZE, SIZE)
			b.kind, b.label, b.targetSlot = e.kind, e.name, e.targetSlot
			b.spellID, b.spellName, b.itemID = e.spellID, e.kind == "spell" and e.name or nil, e.itemID
			b.icon:SetTexture(e.icon)
			b.count:SetText("")
			pcall(b.cooldown.Clear, b.cooldown)
			if e.kind == "spell" then
				b:SetAttribute("type", "spell")
				b:SetAttribute("spell", e.name)
				b:SetAttribute("item", nil)
			else
				b:SetAttribute("type", "item")
				b:SetAttribute("item", "item:" .. e.itemID)
				b:SetAttribute("spell", nil)
			end
			-- A poison: after using it, the game's own button code puts it on the weapon in this slot.
			b:SetAttribute("target-slot", e.targetSlot)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", menu, "TOPLEFT", PAD + LABEL_W + (c - 1) * (SIZE + GAP), -y)
			b:Show()
		end
		if #row.entries > widest then widest = #row.entries end
		y = y + SIZE + GAP
	end
	for i = n + 1, #buttons do buttons[i]:Hide() end
	for i = #rows + 1, #labels do labels[i]:Hide() end

	if #rows == 0 then
		menu:SetSize(250, HEADER_H + PAD * 2 + 16)
	else
		menu:SetSize(PAD * 2 + LABEL_W + widest * (SIZE + GAP) - GAP, y - GAP + PAD)
	end
	if lineAt then
		menu.line:ClearAllPoints()
		menu.line:SetPoint("TOPLEFT", menu, "TOPLEFT", PAD, -lineAt)
		menu.line:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -PAD, -lineAt)
	end
	menu.line:SetShown(lineAt ~= nil)
	menu.empty:SetShown(#rows == 0)
	updateButtons()
end

local function createMenu()
	menu = CreateFrame("Frame", "DowntimeFrame", UIParent, "BackdropTemplate")
	menu:SetFrameStrata("DIALOG")
	menu:SetClampedToScreen(true)
	menu:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8", edgeFile = "Interface\\BUTTONS\\WHITE8X8", edgeSize = 1 })
	-- The border in a dimmed class color (LockMenu's purple when the game has none).
	local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[ns.CLASS]
	if color then
		menu:SetBackdropBorderColor(color.r * 0.75, color.g * 0.75, color.b * 0.75, 1)
	else
		menu:SetBackdropBorderColor(0.45, 0.3, 0.65, 1)
	end
	local title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", PAD, -6)
	title:SetText("Downtime")
	shardText = menu:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	shardText:SetPoint("TOPRIGHT", -PAD, -8)
	shardText:SetShown(shardItem ~= nil)
	menu.line = menu:CreateTexture(nil, "ARTWORK")
	menu.line:SetColorTexture(1, 1, 1, 0.15)
	menu.line:SetHeight(1)
	menu.line:Hide()
	menu.empty = menu:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	menu.empty:SetPoint("TOPLEFT", PAD, -(HEADER_H + PAD))
	menu.empty:SetText("Nothing to show. Check /downtime options")
	menu.empty:Hide()
	-- Esc closes the menu through a stand-in frame that is shown while the menu is: the game's Esc hides every frame on its
	-- list, in a fight too, and the menu itself must not be hidden in a fight (see closeMenu).
	local escape = CreateFrame("Frame", "DowntimeEscape", UIParent)
	escape:Hide()
	escape:SetScript("OnHide", closeMenu)
	table.insert(UISpecialFrames, "DowntimeEscape")
	menu:SetScript("OnShow", function()
		escape:Show()
		updateButtons()
	end)
	menu:SetScript("OnHide", function() escape:Hide() end)
	menu:Hide()
	applyLook()
end

-- Opens the menu where it is set to open, out of a fight only (see closeMenu). In a fight one chat line says so, once a fight.
local function open()
	if InCombatLockdown() then
		if not toldInFight then
			toldInFight = true
			print("Downtime: the menu opens after the fight")
		end
		return
	end
	if dirty then rebuild() end
	closeAfterFight = false
	menu:ClearAllPoints()
	if DB.cursor then
		local x, y = GetCursorPosition()
		local scale = UIParent:GetEffectiveScale()
		menu:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
	else
		menu:SetPoint("CENTER", UIParent, "CENTER", 0, -80)
	end
	menu:Show()
end

function Downtime_Toggle()
	if not menu then return end
	if menu:IsShown() then closeMenu() else open() end
end

-- The key is a secure button that the key binding clicks when the key goes down and again when it comes up. In toggle mode
-- only the press counts. In hold mode the press opens the menu and the release closes it. If a release is ever missed (the
-- game window lost focus), the menu closes by itself after 90 seconds.
--
-- Cast on release: while the menu is open, pointing at a spell copies that spell onto this button's attributes, and the
-- release click then casts it through the game's own secure code. (An addon cannot cast by itself, and the snippets other
-- addons use for this do not work in this client.) The attributes of a secure button can only be changed out of combat, and
-- they are cleared as a fight starts, so a release in a fight casts nothing.
keyBtn = CreateFrame("Button", "DowntimeKey", UIParent, "SecureActionButtonTemplate")
keyBtn:RegisterForClicks("AnyDown", "AnyUp")
keyBtn:SetAttribute("useOnKeyDown", false) -- a spell loaded on it is cast when the key comes up

clearRelease = function()
	if InCombatLockdown() then return end
	keyBtn:SetAttribute("type", nil)
	keyBtn:SetAttribute("spell", nil)
	keyBtn:SetAttribute("item", nil)
	keyBtn:SetAttribute("target-slot", nil)
end

armRelease = function(b)
	if not (DB.hold and DB.release) or InCombatLockdown() then return end
	keyBtn:SetAttribute("type", b:GetAttribute("type"))
	keyBtn:SetAttribute("spell", b:GetAttribute("spell"))
	keyBtn:SetAttribute("item", b:GetAttribute("item"))
	keyBtn:SetAttribute("target-slot", b:GetAttribute("target-slot"))
end

keyBtn:SetScript("PreClick", function(_, _, down)
	if DB.hold then
		if down then
			holdToken = holdToken + 1
			clearRelease()
			if not menu:IsShown() then open() end
			local token = holdToken
			if C_Timer and C_Timer.After then
				C_Timer.After(90, function()
					if holdToken == token then closeMenu() end
				end)
			end
		end
	elseif down then
		Downtime_Toggle()
	end
end)

keyBtn:SetScript("PostClick", function(_, _, down)
	if DB.hold and not down then
		holdToken = holdToken + 1
		closeMenu()
		clearRelease()
	end
end)

local function report()
	local _, order, haveBook = scanSpellbook()
	print("Downtime: spellbook readable=" .. tostring(haveBook) .. ", spells found=" .. #order
		.. ", C_SpellBook=" .. tostring(C_SpellBook ~= nil) .. ", C_Spell=" .. tostring(C_Spell ~= nil) .. ", class=" .. tostring(ns.CLASS))
	local shown = 0
	for _, b in ipairs(buttons) do
		if b:IsShown() then shown = shown + 1 end
	end
	print("Downtime: " .. shown .. " buttons on the menu, mode " .. (DB.hold and "hold" or "toggle"))
	if haveBook then print("Downtime: " .. table.concat(order, ", ")) end
end

createMenu()

ns.OnChange(function(key)
	if key == "bg" or key == "alpha" then
		applyLook()
	elseif key == "hold" or key == "close" or key == "cursor" or key == "release" then
		return
	else
		dirty = true
		if not InCombatLockdown() then rebuild() end
		applyLook()
	end
end)
ns.Rebuild = function() dirty = true rebuild() end

-- Downtime was LockMenu. LockMenu's key opens Downtime from now on, unless Downtime already has a key. The keys live in one of
-- two sets, the account's or the character's own, and a character sees and saves only the set it uses, so each set moves its
-- key on the first login of a character that uses it, with LockMenu switched on or off. The game loads the keys a little
-- after login (BINDINGS_LOADED), and keys only change out of a fight, so the move waits for both. LockMenu is switched off
-- (for every character, from the next reload) only once this character's set is done: its key moved, or no key to move.
local OLD_BINDING, BINDING = "CLICK LockMenuKey:LeftButton", "CLICK DowntimeKey:LeftButton"
local keysLoaded, loggedIn, keysDone = false, false, false

-- Returns true once this character's key set is done, false to try again on a later event.
local function takeOverLockMenuKey()
	if not (GetBindingKey and SetBinding and SaveBindings) then return true end
	local keys = { GetBindingKey(OLD_BINDING) }
	local own = GetBindingKey(BINDING)
	if own then return true end
	-- Before the keys are loaded nothing is bound, so "no LockMenu key" only counts once they are.
	if #keys == 0 then return keysLoaded end
	if InCombatLockdown() then return false end
	for _, key in ipairs(keys) do SetBinding(key, BINDING) end
	SaveBindings(GetCurrentBindingSet and GetCurrentBindingSet() or 1)
	print("Downtime: your LockMenu key (" .. table.concat(keys, ", ") .. ") opens Downtime now")
	return true
end

-- Switches LockMenu off for every character and saves that at once, because closing the game's AddOns list with Cancel puts
-- back whatever was not saved.
local function retireLockMenu()
	local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
	local disable = (C_AddOns and C_AddOns.DisableAddOn) or DisableAddOn
	local save = (C_AddOns and C_AddOns.SaveAddOns) or SaveAddOns
	if not (isLoaded and disable) then return end
	local ok, loaded = pcall(isLoaded, "LockMenu")
	if not (ok and loaded) then return end
	pcall(disable, "LockMenu")
	if save then pcall(save) end
	print("Downtime: LockMenu is now Downtime, so LockMenu is switched off from your next reload. You can delete its folder.")
end

local lockMenuKey = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "BINDINGS_LOADED", "UPDATE_BINDINGS", "PLAYER_REGEN_ENABLED" }) do
	pcall(lockMenuKey.RegisterEvent, lockMenuKey, e)
end
lockMenuKey:SetScript("OnEvent", function(self, event)
	if event == "BINDINGS_LOADED" or event == "UPDATE_BINDINGS" then keysLoaded = true end
	if event == "PLAYER_LOGIN" then loggedIn = true end
	if keysDone or not loggedIn then return end
	local ok, done = pcall(takeOverLockMenuKey)
	-- (Saving the keys can send UPDATE_BINDINGS straight back here, which may already have finished.)
	if keysDone or (ok and not done) then return end
	keysDone = true
	self:UnregisterAllEvents()
	-- An error leaves LockMenu as it is, for the next login to try again.
	if ok then retireLockMenu() end
end)

local events = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
	"BAG_UPDATE_DELAYED", "SPELL_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN", "PLAYER_EQUIPMENT_CHANGED" }) do
	pcall(events.RegisterEvent, events, e)
end
local pendingBags = false
events:SetScript("OnEvent", function(_, event, slot)
	if event == "SPELL_UPDATE_COOLDOWN" or event == "BAG_UPDATE_COOLDOWN" then
		if menu:IsShown() then updateButtons() end
	elseif event == "BAG_UPDATE_DELAYED" then
		dirty = true
		if not pendingBags and C_Timer and C_Timer.After then
			pendingBags = true
			C_Timer.After(0.4, function()
				pendingBags = false
				if menu:IsShown() then rebuild() end
			end)
		end
	elseif event == "PLAYER_EQUIPMENT_CHANGED" then
		-- Only the weapon slots change what the menu shows (the poison rows), and only for a rogue.
		if (slot == 16 or slot == 17) and ns.CLASS == "ROGUE" then
			dirty = true
			if menu:IsShown() and not InCombatLockdown() then rebuild() end
		end
	elseif event == "PLAYER_REGEN_DISABLED" then
		-- A fight starts: the game still lets an addon close the menu now, and then not until the fight is over. A spell
		-- loaded for cast on release is let go too.
		holdToken = holdToken + 1
		clearRelease()
		closeMenu()
	elseif event == "PLAYER_REGEN_ENABLED" then
		toldInFight = false
		if closeAfterFight then
			closeAfterFight = false
			closeMenu()
		end
		if dirty then rebuild() end
	else
		dirty = true
		if not InCombatLockdown() then rebuild() end
	end
end)

SLASH_DOWNTIME1 = "/downtime"
SLASH_DOWNTIME2 = "/dt"
SlashCmdList["DOWNTIME"] = function(msg)
	msg = (msg or ""):lower():match("^%s*(.-)%s*$")
	if msg == "scan" or msg == "report" then
		rebuild()
		report()
	elseif msg == "rebuild" then
		rebuild()
		print("Downtime: rebuilt")
	elseif msg == "options" or msg == "config" or msg == "settings" or msg == "opt" then
		if ns.OpenOptions then ns.OpenOptions() else print("Downtime: the options window did not load") end
	else
		Downtime_Toggle()
	end
end

local ADDON, ns = ...
local Data = ns.Data

ns.CLASS = select(2, UnitClass("player"))
ns.section = Data.classes[ns.CLASS] -- nil for a class with no rows of its own (warriors)

-- The rows this character's menu can show, in menu order: the class's own, then everyone's, then Extra. A class row's key starts
-- with the class ("WARLOCK:Demons"), so two classes' rows of the same name are switched on and off apart.
ns.rows = {}
local function addRow(row, key, class)
	ns.rows[#ns.rows + 1] = { key = key, row = row, class = class, text = row.text or row.label, default = row.default ~= false }
end
if ns.section then
	for _, row in ipairs(ns.section.rows) do addRow(row, ns.CLASS .. ":" .. row.label, true) end
end
for _, row in ipairs(Data.shared) do addRow(row, row.label, false) end
addRow({ label = "Extra", text = "Extra spells (from the box below)", extra = true }, "Extra", false)

local DEFAULTS = {
	hold = false,     -- false: the key toggles the menu. true: hold to show, release to hide.
	release = false,  -- with hold: on release, cast the spell the mouse is on (out of combat)
	close = true,     -- close the menu after casting
	cursor = true,    -- open at the mouse (otherwise near the middle of the screen)
	size = 36,        -- button size
	bg = 0.88,        -- background opacity
	alpha = 1,        -- opacity of the whole menu
	extra = "",       -- extra spell names, separated by commas
}

-- The settings live in DowntimeDB, the saved file (one for the whole account). Only what differs from a default is in it; rows
-- holds the rows switched away from their default, by key. The game fills DowntimeDB just before ADDON_LOADED, so until then
-- (and on a fresh install) every setting reads its default.
local saved
local DB = setmetatable({}, {
	__index = function(_, k)
		if saved and saved[k] ~= nil then return saved[k] end
		return DEFAULTS[k]
	end,
	__newindex = function() error("Downtime: change settings with ns.Set") end,
})
ns.DB, ns.DEFAULTS = DB, DEFAULTS

local function rowDefault(key)
	for _, r in ipairs(ns.rows) do
		if r.key == key then return r.default end
	end
	-- Another class's row (LockMenu's settings are copied on whichever character logs in first): its default is in Data.lua.
	local class, label = key:match("^(%u+):(.+)$")
	local section = class and Data.classes[class]
	if section then
		for _, row in ipairs(section.rows) do
			if row.label == label then return row.default ~= false end
		end
	end
	return true
end

function ns.RowOn(key)
	local v = saved and saved.rows and saved.rows[key]
	if v == nil then return rowDefault(key) end
	return v
end

-- Listeners hear about every change: the menu redraws and the options window updates its controls.
local listeners = {}
function ns.OnChange(fn) listeners[#listeners + 1] = fn end
local function fire(key)
	for _, fn in ipairs(listeners) do
		local ok, err = pcall(fn, key)
		if not ok then print("Downtime: " .. tostring(err)) end
	end
end

local function ensureSaved()
	if not saved then
		saved = { settingsVersion = 1 }
		DowntimeDB = saved
	end
	saved.settingsVersion = 1
	return saved
end

-- Changes one setting, saves it and tells the listeners.
function ns.Set(key, value)
	local s = ensureSaved()
	if value == DEFAULTS[key] then s[key] = nil else s[key] = value end
	fire(key)
end

-- Switches a row on or off, saves it and tells the listeners.
function ns.SetRowOn(key, on)
	local s = ensureSaved()
	s.rows = s.rows or {}
	if on == rowDefault(key) then s.rows[key] = nil else s.rows[key] = on end
	fire("rows")
end

-- A saved file someone edited by hand, or an older one: anything of the wrong kind goes back to its default.
local function clean(s)
	for k, d in pairs(DEFAULTS) do
		if s[k] ~= nil and type(s[k]) ~= type(d) then s[k] = nil end
	end
	if type(s.rows) ~= "table" then s.rows = nil end
	if s.rows then
		for k, v in pairs(s.rows) do
			if type(v) ~= "boolean" then s.rows[k] = nil end
		end
	end
	if s.size then s.size = math.max(24, math.min(56, math.floor(s.size + 0.5))) end
	if s.bg then s.bg = math.max(0, math.min(1, s.bg)) end
	if s.alpha then s.alpha = math.max(0.2, math.min(1, s.alpha)) end
	if type(s.extra) == "string" then s.extra = s.extra:gsub("[\r\n]", "") end
end

-- Downtime was LockMenu, which kept its settings in an account macro, "LockMenu data", because the Forever beta never read
-- saved files back, and a second copy in a setting of its own, LockMenucfg (for when the macro could not be made, say with every
-- macro slot full). On the first login with Downtime they are copied over once. Both are left alone, so going back to LockMenu
-- keeps them too.
local OLD_MACRO, OLD_CVAR = "LockMenu data", "LockMenucfg"
local MACRO_TRIES = 5 -- macro updates to wait for the macro before giving up for this session
local OLD_ROWS = { "Demons", "Buffs", "Utility", "Stones", "Curses", "Control", "Use", "Extra" } -- LockMenu's bit order
local OLD_FIELDS = { h = "hold", l = "release", c = "close", m = "cursor", s = "size", b = "bg", a = "alpha", x = "extra" }

local function readOldMacro()
	if not (GetMacroIndexByName and GetMacroBody) then return nil end
	local ok, index = pcall(GetMacroIndexByName, OLD_MACRO)
	if not ok or not index or index == 0 then return nil end
	local ok2, body = pcall(GetMacroBody, index)
	if not ok2 or type(body) ~= "string" then return nil end
	return (body:gsub("^#[^\n]*\n", ""):match("^%s*(.-)%s*$"))
end

-- LockMenu's second copy. It is registered first, as LockMenu did (with ""), so the game hands back the value it kept; only
-- with LockMenu installed, so nobody else gets that setting.
local function readOldCVar()
	local exists = C_AddOns and C_AddOns.DoesAddOnExist
	if exists then
		local ok, yes = pcall(exists, "LockMenu")
		if ok and not yes then return nil end
	end
	local get = (C_CVar and C_CVar.GetCVar) or GetCVar
	if not get then return nil end
	local register = (C_CVar and C_CVar.RegisterCVar) or RegisterCVar
	if register then pcall(register, OLD_CVAR, "") end
	local ok, value = pcall(get, OLD_CVAR)
	if not ok or type(value) ~= "string" then return nil end
	value = value:match("^%s*(.-)%s*$")
	if value ~= "" then return value end
end

-- Are the account macros in yet? (LockMenu's macro is one of them. At login they arrive a little after the first events.)
local function accountMacrosIn()
	if not GetNumMacros then return false end
	local ok, account = pcall(GetNumMacros)
	return ok and type(account) == "number" and account > 0
end

local function copyOld(body)
	local s = ensureSaved()
	for part in body:gmatch("[^;]+") do
		local code, value = part:match("^(%a)=(.*)$")
		local key = OLD_FIELDS[code]
		if key then
			local d = DEFAULTS[key]
			if type(d) == "boolean" then
				s[key] = value == "1"
			elseif type(d) == "number" then
				s[key] = tonumber(value)
			else
				s[key] = value
			end
			if s[key] == d then s[key] = nil end
		elseif code == "r" and tonumber(value) then
			local mask = math.floor(tonumber(value))
			s.rows = s.rows or {}
			for i, label in ipairs(OLD_ROWS) do
				local rowKey = label == "Extra" and "Extra" or "WARLOCK:" .. label
				local on = math.floor(mask / 2 ^ (i - 1)) % 2 == 1
				if on ~= rowDefault(rowKey) then s.rows[rowKey] = on end
			end
		end
	end
	clean(s)
end

local loader = CreateFrame("Frame")
local LOOK_EVENTS = { "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "UPDATE_MACROS" }
pcall(loader.RegisterEvent, loader, "ADDON_LOADED")
for _, e in ipairs(LOOK_EVENTS) do
	pcall(loader.RegisterEvent, loader, e)
end
local loaded, macroUpdates = false, 0
local function stopLooking()
	for _, e in ipairs(LOOK_EVENTS) do pcall(loader.UnregisterEvent, loader, e) end
end
loader:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" then
		if name ~= ADDON then return end
		loaded = true
		if type(DowntimeDB) == "table" then
			saved = DowntimeDB
			clean(saved)
			fire("all")
		end
		return
	end
	if not loaded then return end
	if saved and saved.settingsVersion then
		stopLooking()
		return
	end
	-- No saved file yet: look for LockMenu's macro, at every macro update until the account macros are in. When they are
	-- and the macro is not among them, or after a few updates, LockMenu's second copy is read instead.
	local body = readOldMacro()
	if not body and event == "UPDATE_MACROS" then
		macroUpdates = macroUpdates + 1
		if accountMacrosIn() or macroUpdates >= MACRO_TRIES then body = readOldCVar() end
		if not body and macroUpdates >= MACRO_TRIES then
			stopLooking()
			return
		end
	end
	if body then
		stopLooking()
		copyOld(body)
		print("Downtime: your LockMenu settings were copied over")
		fire("all")
	end
end)

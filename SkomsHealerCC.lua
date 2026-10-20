local addonName, ns = ...

-- SkomsHealerCC: a big icon, a timer and a sound when an enemy crowd control lands on your healer.
-- Inspired by the WeakAura "Healer cc (colored borders)" by Elsyn. The crowd control list is the one of SkomsPlateBuffs,
-- checked against the 3.3.5a client data; healers are found with LibGroupTalents-1.0 (their talents), because 3.3.5
-- has no role for arena or battleground teammates.

local pairs, ipairs, tonumber, tostring, type, select = pairs, ipairs, tonumber, tostring, type, select
local GetTime, UnitAura, UnitExists, UnitIsPlayer, UnitIsUnit, UnitClass, UnitName =
	GetTime, UnitAura, UnitExists, UnitIsPlayer, UnitIsUnit, UnitClass, UnitName
local GetNumPartyMembers, GetNumRaidMembers, GetSpellInfo, IsInInstance = GetNumPartyMembers, GetNumRaidMembers, GetSpellInfo, IsInInstance
local strfind, strlower = string.find, string.lower

local function SetShown(obj, show)
	if show then obj:Show() else obj:Hide() end
end

local LGT, LSM -- resolved at login: WeakAuras / DBM may carry them and load later

local defaults = {
	profile = {
		enabled = true,
		scope = "arena",          -- arena, pvp (arena + battlegrounds), always
		includeDisarm = false,
		includeRoots = false,
		guessByClass = true,      -- until talents are known, priest / druid / paladin / shaman count as healers
		extraHealers = "",        -- names, separated by commas
		size = 70,
		point = "CENTER", relPoint = "CENTER", x = -135, y = 170,
		showTitle = true,
		titleText = "HEALER CC",
		showTimer = true,
		showSpellName = false,
		colorBorder = true,
		sound = true,
		soundName = "default",
		announce = false,
	}
}

local P = defaults.profile
local db

local HEALER_CLASSES = { PRIEST = true, DRUID = true, PALADIN = true, SHAMAN = true }
local BORDER = {
	Magic = { 0, 0.83, 1 }, Curse = { 0.59, 0, 1 }, Disease = { 0.55, 0.68, 0 }, Poison = { 0, 0.6, 0 },
	none = { 1, 0.09, 0 },
}

-- ---------------------------------------------------------------------------------------------------------
-- crowd control sets
-- ---------------------------------------------------------------------------------------------------------
local ccIds, ccNames = {}, {}

local function BuildSets()
	for k in pairs(ccIds) do ccIds[k] = nil end
	for k in pairs(ccNames) do ccNames[k] = nil end
	local function add(set)
		for id in pairs(set) do
			ccIds[id] = true
			local name = GetSpellInfo(id)
			if name then ccNames[name] = true end   -- ranks and variants that are not listed still match by name
		end
	end
	add(ns.CC.hard)
	if P.includeDisarm then add(ns.CC.disarm) end
	if P.includeRoots then add(ns.CC.root) end
end

local function IsCC(spellId, name)
	return ccIds[spellId] or (name and ccNames[name]) or false
end

-- ---------------------------------------------------------------------------------------------------------
-- who is a healer
-- ---------------------------------------------------------------------------------------------------------
local function InExtraList(unit)
	local list = P.extraHealers
	if not list or list == "" then return false end
	local name = UnitName(unit)
	if not name then return false end
	name = strlower(name)
	for entry in list:gmatch("[^,]+") do
		local trimmed = entry:gsub("^%s+", ""):gsub("%s+$", "")
		if strlower(trimmed) == name then return true end
	end
	return false
end

-- the order Tsoukie's !!!ClassicAPI uses for the raid frame roles: the game's own assignment, the class, then talents
local CANNOT_HEAL = { HUNTER = true, ROGUE = true, MAGE = true, WARLOCK = true, WARRIOR = true, DEATHKNIGHT = true }

local function IsHealer(unit)
	if not UnitExists(unit) or not UnitIsPlayer(unit) or UnitIsUnit(unit, "player") then return false end
	if InExtraList(unit) then return true end
	-- 1. a role assigned by a group finder is definitive (it is empty in arena and battleground groups)
	if UnitGroupRolesAssigned then
		local tank, heal, damage = UnitGroupRolesAssigned(unit)
		if heal then return true end
		if tank or damage then return false end
	end
	-- 2. classes that cannot heal
	local class = select(2, UnitClass(unit))
	if CANNOT_HEAL[class] then return false end
	-- 3. the talents (LibGroupTalents)
	if LGT then
		local ok, role = pcall(LGT.GetUnitRole, LGT, unit)
		if ok and role then return role == "healer" end
	end
	-- 4. talents not known yet
	if P.guessByClass then
		return HEALER_CLASSES[class] and true or false
	end
	return false
end

local healerUnits = {}

local function ForEachGroupUnit(fn)
	local raid = GetNumRaidMembers()
	if raid and raid > 0 then
		for i = 1, raid do fn("raid" .. i) end
	else
		for i = 1, (GetNumPartyMembers() or 0) do fn("party" .. i) end
	end
end

local function RebuildHealers()
	for k in pairs(healerUnits) do healerUnits[k] = nil end
	ForEachGroupUnit(function(unit)
		if IsHealer(unit) then healerUnits[unit] = true end
	end)
end

-- ---------------------------------------------------------------------------------------------------------
-- the display
-- ---------------------------------------------------------------------------------------------------------
local f = CreateFrame("Frame", "SkomsHealerCCFrame", UIParent)
f:SetFrameStrata("HIGH")
f:SetWidth(70)
f:SetHeight(70)
f:Hide()

f.icon = f:CreateTexture(nil, "ARTWORK")
f.icon:SetAllPoints(f)
f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

f.cd = CreateFrame("Cooldown", nil, f)
f.cd:SetAllPoints(f)

local backdrop = { edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 3 }
f.outline = CreateFrame("Frame", nil, f)
f.outline:SetPoint("TOPLEFT", f, "TOPLEFT", -5, 5)
f.outline:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 5, -5)
f.outline:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 4 })
f.outline:SetBackdropBorderColor(0, 0, 0, 1)
f.border = CreateFrame("Frame", nil, f)
f.border:SetPoint("TOPLEFT", f, "TOPLEFT", -3, 3)
f.border:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 3, -3)
f.border:SetBackdrop(backdrop)
f.border:SetFrameLevel(f.outline:GetFrameLevel() + 1)

f.timer = f:CreateFontString(nil, "OVERLAY")
f.timer:SetFont("Fonts\\FRIZQT__.TTF", 30, "OUTLINE")
f.timer:SetPoint("TOP", f, "BOTTOM", 0, -8)
f.title = f:CreateFontString(nil, "OVERLAY")
f.title:SetFont("Fonts\\FRIZQT__.TTF", 24, "OUTLINE")
f.title:SetPoint("BOTTOM", f, "TOP", 0, 10)
f.title:SetTextColor(1, 0.1, 0.1)
f.spell = f:CreateFontString(nil, "OVERLAY")
f.spell:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")

local current       -- what is shown: { icon, name, spellId, duration, expiration, dispel }
local testing       -- fake CC for the Test button / unlock
local lastAlert     -- spellId of the last alerted CC, so a refresh does not alert again

local function ApplyLayout()
	local size = P.size
	f:SetWidth(size)
	f:SetHeight(size)
	f.timer:SetFont("Fonts\\FRIZQT__.TTF", math.max(14, math.floor(size * 0.45)), "OUTLINE")
	f.title:SetFont("Fonts\\FRIZQT__.TTF", math.max(12, math.floor(size * 0.34)), "OUTLINE")
	f.title:SetText(P.titleText or "")
	SetShown(f.title, P.showTitle)
	f.spell:ClearAllPoints()
	f.spell:SetPoint("TOP", P.showTimer and f.timer or f, P.showTimer and "BOTTOM" or "BOTTOM", 0, -2)
	f:ClearAllPoints()
	f:SetPoint(P.point or "CENTER", UIParent, P.relPoint or P.point or "CENTER", P.x or 0, P.y or 0)
end

local function Present(best)
	f.icon:SetTexture(best.icon)
	if best.duration and best.duration > 0 then
		CooldownFrame_SetTimer(f.cd, best.expiration - best.duration, best.duration, 1)
	end
	local c = (P.colorBorder and BORDER[best.dispel or "none"]) or BORDER.none
	f.border:SetBackdropBorderColor(c[1], c[2], c[3], 1)
	f.spell:SetText(P.showSpellName and best.name or "")
	SetShown(f.timer, P.showTimer)
	if not f:IsShown() then
		f:SetAlpha(0)
		f:Show()
		UIFrameFadeIn(f, 0.2, 0, 1)
	end
end

local function PlayAlert(best)
	if P.sound then
		if P.soundName == "default" or not LSM then
			PlaySound("RaidWarning")
		else
			local path = LSM:Fetch("sound", P.soundName, true)
			if path then PlaySoundFile(path) else PlaySound("RaidWarning") end
		end
	end
	if P.announce and (GetNumPartyMembers() or 0) > 0 and (GetNumRaidMembers() or 0) == 0 then
		SendChatMessage("HEALER CC: " .. (best.name or "?"), "PARTY")
	end
end

local function HideIt()
	current = nil
	if f:IsShown() then f:Hide() end
end

-- ---------------------------------------------------------------------------------------------------------
-- scanning
-- ---------------------------------------------------------------------------------------------------------
local scopeOK = false

local function UpdateScope()
	local _, kind = IsInInstance()
	if P.scope == "always" then
		scopeOK = true
	elseif P.scope == "pvp" then
		scopeOK = (kind == "arena" or kind == "pvp")
	else
		scopeOK = (kind == "arena")
	end
end

-- the crowd control on `unit` that lasts longest
local function ScanUnit(unit, best)
	for i = 1, 40 do
		local name, _, icon, _, dispel, duration, expiration, _, _, _, spellId = UnitAura(unit, i, "HARMFUL")
		if not name then break end
		if expiration and expiration > 0 and IsCC(spellId, name) then
			if not best or expiration > best.expiration then
				best = { icon = icon, name = name, spellId = spellId, duration = duration, expiration = expiration,
				         dispel = dispel or "none", unit = unit }
			end
		end
	end
	return best
end

local function Refresh()
	if testing then
		if testing.expiration > GetTime() then
			current = testing
			Present(testing)
			return
		end
		testing = nil
	end
	if not P.enabled or not scopeOK then
		HideIt()
		lastAlert = nil
		return
	end
	local best
	for unit in pairs(healerUnits) do
		best = ScanUnit(unit, best)
	end
	if not best then
		HideIt()
		lastAlert = nil
		return
	end
	current = best
	Present(best)
	if lastAlert ~= best.spellId then
		lastAlert = best.spellId
		PlayAlert(best)
	end
end

local elapsedSince = 0
f:SetScript("OnUpdate", function(self, elapsed)
	elapsedSince = elapsedSince + elapsed
	if elapsedSince < 0.1 then return end
	elapsedSince = 0
	if not current then return end
	local left = current.expiration - GetTime()
	if left <= 0 then
		Refresh()
		return
	end
	f.timer:SetText(left >= 10 and ("%d"):format(left) or ("%.1f"):format(left))
end)

-- ---------------------------------------------------------------------------------------------------------
-- test, unlock
-- ---------------------------------------------------------------------------------------------------------
local function StartTest(seconds)
	testing = {
		icon = select(3, GetSpellInfo(118)) or "Interface\\Icons\\Spell_Nature_Polymorph",
		name = "Polymorph", spellId = 118, duration = seconds, expiration = GetTime() + seconds, dispel = "Magic",
	}
	PlayAlert(testing)
	Refresh()
end

local function SetLocked(locked)
	P.locked = locked
	if locked then
		f:EnableMouse(false)
		testing = nil
		Refresh()
	else
		f:EnableMouse(true)
		testing = { icon = select(3, GetSpellInfo(118)) or "Interface\\Icons\\Spell_Nature_Polymorph", name = "Drag me",
		            spellId = 118, duration = 3600, expiration = GetTime() + 3600, dispel = "Magic" }
		Refresh()
	end
end

f:SetMovable(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", function(self) if not P.locked then self:StartMoving() end end)
f:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	local point, _, relPoint, x, y = self:GetPoint()
	P.point, P.relPoint, P.x, P.y = point, relPoint, x, y
end)

-- ---------------------------------------------------------------------------------------------------------
-- options
-- ---------------------------------------------------------------------------------------------------------
local function Apply()
	BuildSets()
	ApplyLayout()
	UpdateScope()
	RebuildHealers()
	Refresh()
end

local function SoundValues()
	local values = { default = "Raid Warning (default)" }
	if LSM then
		for _, name in ipairs(LSM:List("sound")) do values[name] = name end
	end
	return values
end

local function Options()
	local function get(info) return P[info[#info]] end
	local function set(info, v) P[info[#info]] = v; Apply() end
	return {
		type = "group",
		name = "SkomsHealerCC",
		get = get,
		set = set,
		args = {
			enabled = { type = "toggle", name = "Enabled", order = 1 },
			scope = {
				type = "select", name = "Where", order = 2,
				values = { arena = "Arena only", pvp = "Arena and battlegrounds", always = "Everywhere (to test)" },
			},
			header1 = { type = "header", name = "Which healer, which crowd control", order = 10 },
			guessByClass = {
				type = "toggle", order = 11, width = "full",
				name = "Count priests, druids, paladins and shamans as healers until their talents are known",
				desc = "Talents are read with LibGroupTalents when the teammate is in range. Until then this guess is used.",
			},
			extraHealers = {
				type = "input", order = 12, width = "full", name = "Always treat these players as healers (names, separated by commas)",
			},
			includeDisarm = { type = "toggle", order = 13, name = "Disarms" },
			includeRoots = { type = "toggle", order = 14, name = "Roots" },
			header2 = { type = "header", name = "Look", order = 20 },
			size = { type = "range", name = "Icon size", order = 21, min = 30, max = 160, step = 2 },
			showTitle = { type = "toggle", name = "Show the title", order = 22 },
			titleText = { type = "input", name = "Title", order = 23 },
			showTimer = { type = "toggle", name = "Show the timer", order = 24 },
			showSpellName = { type = "toggle", name = "Show the spell name", order = 25 },
			colorBorder = {
				type = "toggle", order = 26, width = "full",
				name = "Border colour by the type of the effect",
				desc = "Magic blue, curse purple, disease green, poison dark green, physical red.",
			},
			unlock = {
				type = "toggle", order = 27, name = "Unlock to move",
				desc = "Shows a sample you can drag. Lock it again when you are done.",
				get = function() return not P.locked end,
				set = function(_, v) SetLocked(not v) end,
			},
			test = { type = "execute", order = 28, name = "Test", func = function() StartTest(8) end },
			header3 = { type = "header", name = "Alert", order = 30 },
			sound = { type = "toggle", name = "Play a sound", order = 31 },
			soundName = {
				type = "select", name = "Sound", order = 32, values = SoundValues,
				disabled = function() return not P.sound end,
			},
			announce = {
				type = "toggle", order = 33, width = "full", name = "Say it in party chat",
				desc = "Sends \"HEALER CC: <spell>\" to the party (not in raid groups).",
			},
		},
	}
end

-- ---------------------------------------------------------------------------------------------------------
-- start
-- ---------------------------------------------------------------------------------------------------------
local events = CreateFrame("Frame")
local function OnProfileChanged() P = db.profile; Apply() end

events:SetScript("OnEvent", function(self, event, arg1)
	if event == "PLAYER_LOGIN" then
		LGT = LibStub("LibGroupTalents-1.0", true)
		LSM = LibStub("LibSharedMedia-3.0", true)
		db = LibStub("AceDB-3.0"):New("SkomsHealerCCDB", defaults, true)
		db.RegisterCallback(ns, "OnProfileChanged", OnProfileChanged)
		db.RegisterCallback(ns, "OnProfileCopied", OnProfileChanged)
		db.RegisterCallback(ns, "OnProfileReset", OnProfileChanged)
		P = db.profile
		local options = Options()
		local profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(db)
		LibStub("AceConfig-3.0"):RegisterOptionsTable("SkomsHealerCC", options)
		LibStub("AceConfigDialog-3.0"):AddToBlizOptions("SkomsHealerCC", "SkomsHealerCC")
		LibStub("AceConfig-3.0"):RegisterOptionsTable("SkomsHealerCCProfiles", profiles)
		LibStub("AceConfigDialog-3.0"):AddToBlizOptions("SkomsHealerCCProfiles", "Profiles", "SkomsHealerCC")
		if LGT and LGT.RegisterCallback then
			LGT.RegisterCallback(ns, "LibGroupTalents_RoleChange", function() RebuildHealers(); Refresh() end)
			LGT.RegisterCallback(ns, "LibGroupTalents_Update", function() RebuildHealers(); Refresh() end)
		end
		P.locked = true
		Apply()
	elseif event == "UNIT_AURA" then
		if healerUnits[arg1] then Refresh() end
	else
		-- zone change, roster change
		UpdateScope()
		RebuildHealers()
		Refresh()
	end
end)
for _, e in ipairs{ "PLAYER_LOGIN", "UNIT_AURA", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
                    "PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE", "PARTY_MEMBER_ENABLE", "PARTY_MEMBER_DISABLE" } do
	events:RegisterEvent(e)
end

SLASH_SKOMSHEALERCC1 = "/shcc"
SLASH_SKOMSHEALERCC2 = "/skomshealercc"
SlashCmdList["SKOMSHEALERCC"] = function(msg)
	msg = strlower(msg or "")
	if msg == "test" then
		StartTest(8)
	elseif msg == "unlock" then
		SetLocked(false)
	elseif msg == "lock" then
		SetLocked(true)
	else
		InterfaceOptionsFrame_OpenToCategory("SkomsHealerCC")
		InterfaceOptionsFrame_OpenToCategory("SkomsHealerCC")
	end
end

-- for tests
ns.IsCC, ns.IsHealer, ns.ScanUnit, ns.BuildSets, ns.RebuildHealers = IsCC, IsHealer, ScanUnit, BuildSets, RebuildHealers

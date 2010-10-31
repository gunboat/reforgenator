
Reforgenator = LibStub("AceAddon-3.0"):NewAddon("Reforgenator", "AceConsole-3.0", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("Reforgenator", false)
local RI = LibStub("LibReforgingInfo-1.0")
local version = "0.0.1"

local debugFrame = tekDebug and tekDebug:GetFrame("Reforgenator")

local function Set(list)
    local set = {}
    for _, l in ipairs(list) do set[tostring(l)] = true end
    return set
end

local INVENTORY_SLOTS = {
    "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot",
    "ChestSlot", "ShirtSlot", "TabardSlot", "WristSlot", "HandsSlot",
    "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot",
    "Trinket0Slot", "Trinket1Slot", "MainHandSlot", "SecondaryHandSlot",
    "RangedSlot" }

local COMBAT_RATINGS = {
    CR_WEAPON_SKILL = 1,
    CR_DEFENSE_SKILL = 2,
    CR_DODGE = 3,
    CR_PARRY = 4,
    CR_BLOCK = 5,
    CR_HIT_MELEE = 6,
    CR_HIT_RANGED = 7,
    CR_HIT_SPELL = 8,
    CR_CRIT_MELEE = 9,
    CR_CRIT_RANGED = 10,
    CR_CRIT_SPELL = 11,
    CR_HIT_TAKEN_MELEE = 12,
    CR_HIT_TAKEN_RANGED = 13,
    CR_HIT_TAKEN_SPELL = 14,
    COMBAT_RATING_RESILIENCE_CRIT_TAKEN = 15,
    COMBAT_RATING_RESILIENCE_PLAYER_DAMAGE_TAKEN = 16,
    CR_CRIT_TAKEN_SPELL = 17,
    CR_HASTE_MELEE = 18,
    CR_HASTE_RANGED = 19,
    CR_HASTE_SPELL = 20,
    CR_WEAPON_SKILL_MAINHAND = 21,
    CR_WEAPON_SKILL_OFFHAND = 22,
    CR_WEAPON_SKILL_RANGED = 23,
    CR_EXPERTISE = 24,
    CR_ARMOR_PENETRATION = 25,
    CR_MASTERY = 26
}

local ITEM_STATS = Set {
    "ITEM_MOD_CRIT_RATING_SHORT",
    "ITEM_MOD_DODGE_RATING_SHORT",
    "ITEM_MOD_EXPERTISE_RATING_SHORT",
    "ITEM_MOD_HASTE_RATING_SHORT",
    "ITEM_MOD_HIT_RATING_SHORT",
    "ITEM_MOD_MASTERY_RATING_SHORT",
    "ITEM_MOD_PARRY_RATING_SHORT",
    "ITEM_MOD_SPIRIT_RATING_SHORT",
}

local options = {
    type = 'group',
    name = "Reforgenator",
    handler = Reforgenator,
    desc = "Calculate what to reforge",
    args = { 
    },
}

local defaults = {
    profile = {
        orientation = 1,
    }
}

local profileOptions = {
    name = "Profiles",
    type = "group",
    childGroups = "tab",
    args = {},
}

function Reforgenator:Debug(...)
    if debugFrame then
        debugFrame:AddMessage(string.join(", ", ...))
    else
	self:Print(string.join(", ", ...))
    end
end

local function table_print (tt, indent, done)
    done = done or {}
    indent = indent or 0
    if type(tt) == "table" then
        local sb = {}
        for key, value in pairs (tt) do
            table.insert(sb, string.rep (" ", indent)) -- indent it
            if type (value) == "table" and not done [value] then
                done [value] = true
                table.insert(sb, "{");
                table.insert(sb, table_print (value, indent + 2, done))
                table.insert(sb, string.rep (" ", indent)) -- indent it
                table.insert(sb, "},\n");
            elseif "number" == type(key) then
                table.insert(sb, string.format("\"%s\",\n", tostring(value)))
            else
                table.insert(sb, string.format("%s=\"%s\",\n", tostring (key), tostring(value)))
            end
        end
        return table.concat(sb)
    else
        return tt
    end
end

local function to_string( tbl )
    if  "nil"       == type( tbl ) then
        return tostring(nil)
    elseif  "table" == type( tbl ) then
        return table_print(tbl)
    elseif  "string" == type( tbl ) then
        return tbl
    else
        return tostring(tbl)
    end
end

function Reforgenator:Dump(name, t)
    if type(t) == "table" then
        for k,v in next,t do
            self:Debug(name.."["..k.."]="..to_string(v))
        end
    else
        self:Debug(name.."=" .. to_string(t))
    end
end

function Reforgenator:deepCopy(o)
    local lut = {}
    local function _copy(o)
        if type(o) ~= "table" then
            return o
        elseif lut[o] then
            return lut[o]
        end
        local result = {}
        lut[o] = result
        for k,v in pairs(o) do
            result[_copy(k)] = _copy(v)
        end
        return setmetatable(result, getmetatable(o))
    end
    return _copy(o)
end

local Dequeue = {}
function Dequeue:new()
    local result = {first = 0, last = -1, maxSize = -1}
    setmetatable(result, self)
    self.__index = self
    return result
end

function Dequeue:pushLeft(value)
    local first = self.first - 1
    self.first = first
    self[first] = value
    local size = self.last - first + 1
    if size > self.maxSize then
	self.maxSize = size
    end
end

function Dequeue:pushRight(value)
    local last = self.last + 1
    self.last = last
    self[last] = value
    local size = last - self.first + 1
    if size > self.maxSize then
	self.maxSize = size
    end
end

function Dequeue:isEmpty()
    return self.first > self.last
end

function Dequeue:popLeft()
    local first = self.first
    if first > self.last then error("dequeue is empty") end
    local value = self[first]
    self[first] = nil
    self.first = first + 1
    return value
end

function Dequeue:popRight()
    local last = self.last
    if self.first > last then error("dequeue is empty") end
    local value = self[last]
    self[last] = nil
    self.last = last - 1
    return value
end

local SolutionContext = {}

function SolutionContext:new()
    local result = { items={}, changes={}, excessRating={} }
    setmetatable(result, self)
    self.__index = self
    return result
end

function Reforgenator:OnInitialize()
    self:Debug("OnInitialize called")

    Reforgenator.db = LibStub("AceDB-3.0"):New("ReforgenatorDB", defaults, "Default")

    LibStub("AceConfig-3.0"):RegisterOptionsTable("Reforgenator", options)

    Reforgenator.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Reforgenator", "Reforgenator")

    self:RegisterChatCommand("reforgenator", "ShowState")
end

function Reforgenator:ShowState()
    self:Debug("in ShowState")

    -- Get the character's current ratings
    local meleeHit = GetCombatRating(COMBAT_RATINGS.CR_HIT_MELEE)
    local rangedHit = GetCombatRating(COMBAT_RATINGS.CR_HIT_RANGED)
    local spellHit = GetCombatRating(COMBAT_RATINGS.CR_HIT_SPELL)
    local expertise = GetCombatRating(COMBAT_RATINGS.CR_EXPERTISE)
    local mastery = GetCombatRating(COMBAT_RATINGS.CR_MASTERY)

    self:Debug("melee hit = " .. meleeHit)
    self:Debug("ranged hit = " .. rangedHit)
    self:Debug("spell hit = " .. spellHit)
    self:Debug("expertise = " .. expertise)
    self:Debug("mastery = " .. mastery)

    local meleeHitCap = self:CalculateMeleeHitCap()
    local expertiseCap = self:CalculateExpertiseCap()

    -- Get the current state of the equipment
    soln = SolutionContext:new()
    for k,v in ipairs(INVENTORY_SLOTS) do
        local itemLink = GetInventoryItemLink("player", GetInventorySlotInfo(v))
        if itemLink then
            local stats = {}
            GetItemStats(itemLink, stats)
	    local entry = {}
	    entry.itemLink = itemLink

	    if RI:IsItemReforged(itemLink) then
		entry.reforged = true
	    else
		entry.reforged = nil
	    end

	    for k,v in pairs(stats) do
		if ITEM_STATS[k] then
		    entry[k] = v
		end
	    end

	    soln.items[#soln.items + 1] = entry
        end
    end
    self:Dump("current", soln)

    -- Reforge for hit cap
    soln = self:OptimizeSolution("ITEM_MOD_HIT_RATING_SHORT", meleeHit, meleeHitCap, math.floor(meleeHitCap * 1.1), soln)

    -- Reforge for expertise
    soln = self:OptimizeSolution("ITEM_MOD_EXPERTISE_RATING_SHORT", expertise, expertiseCap, math.floor(expertiseCap * 1.1), soln)

    -- Reforge for mastery
    soln = self:OptimizeSolution("ITEM_MOD_MASTERY_RATING_SHORT", mastery, 999, 999, soln)

    for k,v in ipairs(soln.changes) do
	self:Debug("changed: " .. to_string(v))
	self:Print("reforge " .. v.itemLink .. " to change " .. _G[v.reforgedFrom] .. " to " .. _G[v.reforgedTo])
    end
end

function Reforgenator:OnEnable()
    self:Print("v"..version.." loaded")
end

function Reforgenator:CalculateMeleeHitCap()
    local hitCap = 247

    -- Mods to hit: Draenei get 1% bonus
    local race, raceEn = UnitRace("player")
    if raceEn == "Draenei" then
	hitCap = 216
    end

    self:Debug("calculated hit cap = " .. hitCap)

    return hitCap
end

function Reforgenator:CalculateExpertiseCap()
    -- Mods to expertise:
    --   (7.6887 rating per)
    --   DKs get +6 expertise from "veteran of the third war"
    --   Orcs get +3 for axes and fist weapons
    --   Dwarves get +3 for maces
    --   Humans get +3 for swords and maces
    --   Gnomes get +3 for daggers and 1H swords
    local expertiseCap = 177

    local className, classNameEN = UnitClass("player")
    self:Debug("classNameEN="..classNameEN)
    if classNameEN == "DEATHKNIGHT" then
	self:Debug("reducing expertise for DK")
	expertiseCap = expertiseCap - 46
    end

    local mainHandLink = GetInventoryItemLink("player", GetInventorySlotInfo("MainHandSlot"))
    local _, _, _, _, _, itemType, itemSubType = GetItemInfo(mainHandLink)
    self:Debug("itemType="..itemType..", itemSubType="..itemSubType)

    local raceName, raceNameEN = UnitRace("player")
    self:Debug("raceNameEN="..raceNameEN)
    if raceNameEN == "Orc" then
	if itemSubType == "One-Handed Axes"
		or itemSubType == "Two-Handed Axes"
		or itemSubType == "Fist Weapons" then
	    self:Debug("reducing expertise for Orc with axe or fist")
	    expertiseCap = expertiseCap - 23
	end
    elseif raceNameEN == "Dwarf" then
	if itemSubType == "One-Handed Maces"
		or itemSubType == "Two-Handed Maces" then
	    self:Debug("reducing expertise for Dwarf with mace")
	    expertiseCap = expertiseCap - 23
	end
    elseif raceNameEN == "Human" then
	if itemSubType == "One-Handed Swords"
		or itemSubType == "Two-Handed Swords"
		or itemSubType == "One-Handed Maces"
		or itemSubType == "Two-Handed Maces" then
	    self:Debug("reducing expertise for Human with sword or mace")
	    expertiseCap = expertiseCap - 23
	end
    elseif raceNameEN == "Gnome" then
	if itemSubType == "One-Handed Swords"
		or itemSubType == "Daggers" then
	    self:Debug("reducing expertise for Gnome with dagger or 1H sword")
	    expertiseCap = expertiseCap - 23
	end
    end

    self:Debug("calculated expertise cap = " .. expertiseCap)
    return expertiseCap

end

-- This is the ordering for tanks
local StatDesirability = {
    ["ITEM_MOD_HIT_RATING_SHORT"] = 1,
    ["ITEM_MOD_EXPERTISE_RATING_SHORT"] = 2,
    ["ITEM_MOD_MASTERY_RATING_SHORT"] = 3,
    ["ITEM_MOD_DODGE_RATING_SHORT"] = 4,
    ["ITEM_MOD_PARRY_RATING_SHORT"] = 5,
    ["ITEM_MOD_CRIT_RATING_SHORT"] = 6,
    ["ITEM_MOD_HASTE_RATING_SHORT"] = 7,
    ["ITEM_MOD_SPIRIT_RATING_SHORT"] = 8,
}

function Reforgenator:PotentialLossFromRating(item, rating)
    local pool = item[rating]
    local potentialLoss = math.floor(pool * 0.4)
    return potentialLoss
end

function Reforgenator:GetBestReforge(item, desiredRating, excessRating)
    self:Debug("### GetBestReforge")
    self:Debug("### item="..to_string(item))
    self:Debug("### desiredRating="..desiredRating)
    self:Debug("### excessRating="..to_string(excessRating))

    if item.reforged then
	self:Debug("already reforged")
	return nil
    end

    if item[desiredRating] then
	self:Debug("item already has desired rating")
	return nil
    end

    local candidates = {}

    local desiredRank = StatDesirability[desiredRating]
    for k,v in pairs(item) do
	if StatDesirability[k] and StatDesirability[k] > desiredRank then
	    local loss = self:PotentialLossFromRating(item, k)
	    self:Debug("loss from "..k.."="..loss)
	    candidates[#candidates + 1] = {k, loss}
	end
    end

    for k,v in pairs(excessRating) do
	if item[k] then
	    local loss = self:PotentialLossFromRating(item, k)
	    self:Debug("loss from "..k.."="..loss..",excess="..excessRating[k])
	    if loss < excessRating[k] then
		candidates[#candidates + 1] = {k, loss}
	    end
	end
    end

    if #candidates == 0 then
	self:Debug("no reforgable attributes on item")
	return nil
    end

    table.sort(candidates, function(a,b) return a[2] > b[2] end)

    self:Debug("suggestedRating="..candidates[1][1])
    self:Debug("delta="..candidates[1][2])

    return { item=item, suggestedRating=candidates[1][1], delta=candidates[1][2] }
end

function Reforgenator:ReforgeItem(suggestion, desiredStat, excessRating)
    self:Debug("### ReforgeItem")
    self:Debug("### suggestion="..to_string(suggestion))
    self:Debug("### desiredStat="..desiredStat)
    self:Debug("### excessRating="..to_string(excessRating))

    local result = {}
    local sr = suggestion.suggestedRating

    for k,v in pairs(suggestion.item) do
	result[k] = v
    end
    result.reforged = true
    result.reforgedFrom = sr
    result.reforgedTo = desiredStat

    result[desiredStat] = suggestion.delta
    result[sr] = result[sr] - suggestion.delta

    if excessRating[sr] then
	excessRating[sr] = excessRating[sr] - suggestion.delta
	if excessRating[sr] == 0 then
	    excessRating[sr] = nil
	end
    end

    return result
end

function Reforgenator:OptimizeSolution(rating, currentValue, lowerBound, upperBound, ancestor)
    self:Debug("######### Optimize Solution for " .. rating .. " #######")
    soln = SolutionContext:new()

    for k,v in pairs(ancestor.excessRating) do
	soln.excessRating[k] = v
    end
    for k,v in ipairs(ancestor.changes) do
	soln.changes[#soln.changes + 1] = v
    end

    -- already over cap?
    if currentValue > lowerBound then
	soln.excessRating[rating] = currentValue - lowerBound
	for k,v in ipairs(ancestor.items) do
	    soln.items[#soln.items + 1] = v
	end
	return soln
    end

    -- okay, so we actually have to do something now
    unforged = {}
    for k,v in ipairs(ancestor.items) do
	local suggestion = self:GetBestReforge(v, rating, soln.excessRating)
	if suggestion then
	    unforged[#unforged + 1] = suggestion
	else
	    soln.items[#soln.items + 1] = v
	end
    end

    table.sort(unforged, function(a,b) return a.delta > b.delta end)

    -- unforged is now sorted by the amount of gain that could be had from
    -- reforging the item, and soln.items contains all the items that
    -- can't be reforged to the desired rating

    val = currentValue
    newList = {}
    for k,v in ipairs(unforged) do
	if val + v.delta <= lowerBound then
	    val = val + v.delta
	    v.item = self:ReforgeItem(v, rating, soln.excessRating)
	    soln.changes[#soln.changes + 1] = v.item
	    soln.items[#soln.items + 1] = v.item
	    self:Dump("val", val)
	else
	    newList[#newList + 1] = v
	end
    end
    unforged = newList

    if #unforged > 0 then
	local v = unforged[#unforged]
	local under = math.abs(lowerBound - val)
	local over = math.abs(lowerBound - val + v.delta)
	if over < under then
	    v.item = self:ReforgeItem(v, rating, soln.excessRating)
	    soln.items[#soln.items + 1] = v.item
	    soln.changes[#soln.changes + 1] = v.item
	    unforged[#unforged] = nil
	end
    end

    for k,v in ipairs(unforged) do
	soln.items[#soln.items + 1] = v.item
    end

    return soln
end


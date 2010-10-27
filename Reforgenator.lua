
Reforgenator = LibStub("AceAddon-3.0"):NewAddon("Reforgenator", "AceConsole-3.0", "AceEvent-3.0")
local RI = LibStub("LibReforgingInfo-1.0")
local L = LibStub("AceLocale-3.0"):GetLocale("Reforgenator", false)
local version = "0.0.1"

local debugFrame = tekDebug and tekDebug:GetFrame("Reforgenator")

local function Set(list)
    local set = {}
    for _, l in ipairs(list) do set[tostring(l)] = true end
    return set
end

local INVENTORY_SLOTS = Set {
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
    end
end

function Reforgenator:OnInitialize()
    self:Print("OnInitialize called")

    Reforgenator.db = LibStub("AceDB-3.0"):New("ReforgenatorDB", defaults, "Default")

    LibStub("AceConfig-3.0"):RegisterOptionsTable("Reforgenator", options)

    Reforgenator.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Reforgenator", "Reforgenator")

    self:RegisterChatCommand("reforgenator", "ShowState")
end

function Reforgenator:ShowState()
    self:Print("in ShowState")

    local ri = LibReforgingInfo

    -- Get the character's current ratings
    local meleeHit = GetCombatRating(COMBAT_RATINGS.CR_HIT_MELEE)
    local rangedHit = GetCombatRating(COMBAT_RATINGS.CR_HIT_RANGED)
    local spellHit = GetCombatRating(COMBAT_RATINGS.CR_HIT_SPELL)
    local expertise = GetCombatRating(COMBAT_RATINGS.CR_EXPERTISE)

    self:Print("melee hit = " .. meleeHit)
    self:Print("ranged hit = " .. rangedHit)
    self:Print("spell hit = " .. spellHit)
    self:Print("expertise = " .. expertise)

    -- Get the current state of the equipment
    local eqipmentSet = {}
    for k,v in pairs(INVENTORY_SLOTS) do
        local itemLink = GetInventoryItemLink("player", GetInventorySlotInfo(k))
        if itemLink then
            local stats = {}
            GetItemStats(itemLink, stats)
	    local Item = {}
	    Item.itemLink = itemLink

	    if RI:IsItemReforged(itemString) then
		Item.reforged = true
	    else
		Item.reforged = nil
	    end

	    for k,v in pairs(stats) do
		if ITEM_STATS[k] then
		    Item[k] = v
		end
	    end

            table.insert(eqipmentSet, Item)
        end
    end
    local Base = {}
    Base.deltaHit = 0
    Base.items = equipmentSet

    -- Reforge for hit cap
    if meleeHit < 246 then
	-- Construct an equipment set optimized for hit
	soln = self:OptimizeSolution("ITEM_MOD_HIT_RATING_SHORT", meleeHit, 246, 300, Base)
	self:Print("best solution is X")
    else
    end

    self:Print("all done")
end

-- construct an empty context
-- put all the items in the uninspecteditems list
-- push the context onto the stack
-- while the stack is not empty:
--   Pop a context off the stack
--   remove the first item from the uninspectedItems list
--   construct "A" clone
--   construct "B" clone
--   push the item onto A.inspectedItems and push the context
--   if the item is reforgable and reforging doesn't put us too far over cap
--     push the reforged item onto B.inspectedItems and push the context
function Reforgenator:OptimizeSolution(rating, currentValue, lowerBound, upperBound, ancestor)
    local dequeue = self:NewDequeue()
    local solutions = {}

    local Context = {}
    Context.delta = 0
    Context.items = {}
    Context.uninspectedItems = self:ShallowCopy(ancestor.items)
    self:PushRight(dequeue, Context)

    while #dequeue > 0 do
	local opt_A = self:PopLeft(dequeue)
	if #opt_A.uninspectedItems = 0 then
	    table.insert(solutions, opt_A)
	else
	    local item = table.remove(opt_A.uninspectedItems, 1)
	    local opt_B = self:DeepCopy(opt_A)
	    table.insert(opt_A.items, item)
	    self:PushRight(dequeue, opt_A)

	    if self:CanReforge(item) then
		item = self:ReforgeItem(item, rating)
		item_B.delta = item_B.delta + item[rating]
		if currentValue + item_B.delta < upperBound then
		    table.insert(opt_B.inspectedItems, item)
		    self:PushRight(dequeue, opt_B)
		end
	    end
	end
    end
    self:Print("dequeue.maxSize="..dequeue.maxSize)
    self:Print("#solutions="..#solutions)

    -- Okay, so now "solutions" has all the reforged combinations. Choose the
    -- best one. And by "best" we mean "smallest value larger than upperBound"
    local bestSolution = {}
    local bestSolutionValue = 9999
    for k,v in pairs(solutions) do
	local value = currentValue + v.delta
	if value > lowerBound && value < bestSolutionValue then
	    bestSolution = v;
	    bestSolutionValue = hit
	end
    end

    return bestSolution
end

function Reforgenator:CanReforge(item, desiredStat)
    if item.reforged then
	return nil
    end

    if item[desiredStat] then
	return nil
    end

    return true
end

local StatDesirability = {
    "ITEM_MOD_HIT_RATING_SHORT" = 1,
    "ITEM_MOD_EXPERTISE_RATING_SHORT" = 2,
    "ITEM_MOD_MASTERY_RATING_SHORT" = 3,
    "ITEM_MOD_DODGE_RATING_SHORT" = 4,
    "ITEM_MOD_PARRY_RATING_SHORT" = 5,
    "ITEM_MOD_CRIT_RATING_SHORT" = 6,
    "ITEM_MOD_HASTE_RATING_SHORT" = 7,
    "ITEM_MOD_SPIRIT_RATING_SHORT" = 8,
}

function Reforgenator:ReforgeItem(item, desiredStat)
    local result = {}
    local loserStat = nil
    local loserStatValue = 0
    for k,v in pairs(item) do
	result[k] = v
	if StatDesirability[k] > loserStatValue then
	    loserStat = k
	    loserStatValue = StatDesirability[k]
	end
    end

    result.reforged = true
    local pool = result[loserStat]
    result[loserStat] = int(pool * 0.6)
    result[desiredStat] = pool - result[loserStat]
    return result
end

function Reforgenator:OnEnable()
    self:Print("v"..version.." loaded")
end

function Reforgenator:ShallowCopy(tbl)
    local result = {}
    for k,v in pairs(tbl) do
	result[k] = v
    end
    return result
end

function Reforgenator:DeepCopy(tbl)
    local result = {}
    for k,v in pairs(tbl) do
	if type(v) = "table" then
	    result[k] = self:DeepCopy(v)
	else
	    result[k] = v
	end
    end
    return result
end

function Reforgenator:NewDequeue()
    return {first = 0, last = -1, maxSize = -1}
end

function Reforgenator:PushLeft(dequeue, value)
    local first = dequeue.first - 1
    dequeue.first = first
    dequeue[first] = value
    if #dequeue > dequeue.maxSize then
	dequeue.maxSize = #dequeue
    end
end

function Reforgenator:PushRight(dequeue, value)
    local last = dequeue.last + 1
    dequeue.last = last
    dequeue[last] = value
    if #dequeue > dequeue.maxSize then
	dequeue.maxSize = #dequeue
    end
end

function Reforgenator:PopLeft(dequeue)
    local first = dequeue.first
    if first > dequeue.last then error("dequeue is empty") end
    local value = dequeue[first]
    dequeue[first] = nil
    dequeue.first = first + 1
    return value
end

function Reforgenator:PopRight(dequeue)
    local last = dequeue.last
    if dequeue.first > last then error("dequeue is empty") end
    local value = dequeue[last]
    dequeue[last] = nil
    dequeue.last = last - 1
    return value
end

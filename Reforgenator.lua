
Reforgenator = LibStub("AceAddon-3.0"):NewAddon("Reforgenator", "AceConsole-3.0", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("Reforgenator", false)
local version = "0.0.1"

local debugFrame = tekDebug and tekDebug:GetFrame("Reforgenator")

local INVENTORY_SLOTS = { "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot",
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

    -- Get the character's current ratings
    local meleeHit = GetCombatRating(COMBAT_RATINGS.CR_HIT_MELEE)
    local expertise = GetCombatRating(COMBAT_RATINGS.CR_EXPERTISE)

    self:Print("melee hit = " .. meleeHit)
    self:Print("expertise = " .. expertise)

    -- Get the current state of the equipment
    local vals = {}
    for k,v in ipairs(INVENTORY_SLOTS) do
        self:Print("v="..v)
        local info = GetInventorySlotInfo(v)
        self:Print("info="..info)
        local item = GetInventoryItemLink("player", info)
        if item then
            self:Print("item="..item)
            local stats = {}
            GetItemStats(item, stats)
            table.insert(vals, {item=item, stats=stats})
        else
            self:Print("there's no item in slot "..info)
        end
    end

    self:Print("ok, so that's it then")

    for k,v in ipairs(vals) do
        self:Print("checking item = " .. v.item)
        for k2,v2 in pairs(v.stats) do
            self:Print("    stat["..k2.."]="..v2)
        end
    end

    self:Print("all done")
end

function Reforgenator:OnEnable()
    self:Print("v"..version.." loaded")
end

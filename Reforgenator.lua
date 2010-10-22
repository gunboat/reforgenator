
Reforgenator = LibStub("AceAddon-3.0"):NewAddon("Reforgenator", "AceConsole-3.0", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("Reforgenator", false)
local version = "0.0.1"
Reforgenator.reforgingInfo = LibStub("LibReforgingInfo-1.0")

local debugFrame = tekDebug and tekDebug:GetFrame("Reforgenator")

local INVENTORY_SLOTS = { "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot",
    "ChestSlot", "ShirtSlot", "TabardSlot", "WristSlot", "HandsSlot",
    "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot",
    "Trinket0Slot", "Trinket1Slot", "MainHandSlot", "SecondaryHandSlot", 
    "RangedSlot" }

local options = {
    type = 'group',
    name = "Reforgenator",
    handler = Reforgenator,
    desc = "Calculate what to reforge",
    args = {
        orientation = {
            name = "Orientation",
            desc = "Orientation of the popup window",
            type = "select",
            values = ClamStacker.OrientationChoices,
            set = function(info, val) ClamStacker.db.profile.orientation = val; Reforgenator:BAG_UPDATE() end,
            get = function(info) return ClamStacker.db.profile.orientation end
        },
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
    Reforgenator.orientation = L["ORIENTATION_HORIZONTAL"]
    defaults.profile.orientation = L["ORIENTATION_HORIZONTAL"]

    Reforgenator.db = LibStub("AceDB-3.0"):New("ReforgenatorDB", defaults, "Default")

    LibStub("AceConfig-3.0"):RegisterOptionsTable("Reforgenator", options)

    Reforgenator.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Reforgenator", "Reforgenator")

    self:RegisterChatCommand("reforgenator", "ChatCommand")
end

function Reforgenator:ChatCommand(input)
    if input:trim() == "config" then
	InterfaceOptionsFrame_OpenToCategory(Reforgenator.optionsFrame)
	return
    end

    -- Get the current state of the equipment
    local ri = Reforgenator.reforgingInfo
    vals = {}
    for k,v in ipairs(INVENTORY_SLOTS) do
	vals[slot] = {}
	local item = GetInventoryItemLink("player", GetInventorySlotInfo(v))
	-- get item attributes
	if ri:IsItemReforged(item) then
	    local reforgeID = ri:GetReforgeID(item)
	    local plus, minus = ri:GetReforgedStatNames(reforgeID)
	else
	end

    end
end

function Reforgenator:OnEnable()
    self:Print("v"..version.." loaded")
end

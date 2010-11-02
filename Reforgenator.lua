
Reforgenator = LibStub("AceAddon-3.0"):NewAddon("Reforgenator", "AceConsole-3.0", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("Reforgenator", false)
local RI = LibStub("LibReforgingInfo-1.0")
local version = "0.0.11"

function Reforgenator:OnEnable()
    self:Print("v"..version.." loaded")
end

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

function Reforgenator:OnInitialize()
    self:Debug("### OnInitialize")

    Reforgenator.db = LibStub("AceDB-3.0"):New("ReforgenatorDB", defaults, "Default")

    LibStub("AceConfig-3.0"):RegisterOptionsTable("Reforgenator", options)

    Reforgenator.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Reforgenator", "Reforgenator")

    LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject("Reforgenator", {
        launcher = true,
        icon = "Interface\\Icons\\INV_Misc_EngGizmos_06",
        text = "Reforgenator",
        OnClick = function(frame, button)
            if button == "RightButton" then
                InterfaceOptionsFrame_OpenToCategory(Reforgenator.optionsFrame)
            else
                Reforgenator:ShowState()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("Reforgenator |cff00ff00(v"..version..")|r");
            tooltip:AddLine("|cffffff00".."left-click to figure out what to reforge")
            tooltip:AddLine("|cffffff00".."right-click to configure")
        end
    })

    self:RegisterChatCommand("reforgenator", "ShowState")

    tinsert(UISpecialFrames, "ReforgenatorPanel")
end

function Reforgenator:MessageFrame_OnLoad(widget)
end

function Reforgenator:OnDragStart(widget, button, ...)
    self:Debug("### OnDragStart")
    self:Debug("widget.ID="..widget:GetID())

    GameTooltip:Hide()
    PickupInventoryItem(widget:GetID())
end

function Reforgenator:OnEnter(widget)
    self:Debug("### OnEnter")
    self:Debug("### widget.ID="..widget:GetID())

    if widget:GetID() ~= 0 then
	GameTooltip:SetOwner(widget, "ANCHOR_RIGHT")
	GameTooltip:SetHyperlink(GetInventoryItemLink("player", widget:GetID()))
	GameTooltip:Show()
    end
end

function Reforgenator:OnCheckbox(widget)
    self:Debug("### OnCheckbox")
    self:Debug("### widget.ID="..widget:GetID())

    local id = widget:GetID()
    table.remove(self.changes, id)
    self:UpdateWindow()
end

function Reforgenator:UpdateWindow()
    for i = 1,4 do
	if i <= #self.changes then
	    self:UpdateWindowItem(i, self.changes[i])
	else
	    self:UpdateWindowItem(i, nil)
	end
    end

    if #self.changes == 0 then
	if ReforgenatorPanel:IsVisible() then
	    ReforgenatorPanel:Hide()
	end
    else
	if not ReforgenatorPanel:IsVisible() then
	    ReforgenatorPanel:Show()
	end
    end 
end

function Reforgenator:UpdateWindowItem(index, itemDescriptor)
    self:Debug("### UpdateWindowItem")

    if not itemDescriptor then
	_G["ReforgenatorPanel_Item" .. index]:Hide()
	_G["ReforgenatorPanel_Item" .. index .. "Checked"]:Hide()
	return
    end

    local texture = select(10, GetItemInfo(itemDescriptor.itemLink))
    _G["ReforgenatorPanel_Item" .. index .. "IconTexture"]:SetTexture(texture)
    _G["ReforgenatorPanel_Item" .. index]:SetID(itemDescriptor.slotInfo)
    _G["ReforgenatorPanel_Item" .. index .. "Checked"]:SetChecked(nil)

    local msg = "- " .. _G[itemDescriptor.reforgedFrom] .. "\n"
	    .. "+ " .. _G[itemDescriptor.reforgedTo]
    _G["ReforgenatorPanel_Item" .. index .. "Name"]:SetText(msg)

    _G["ReforgenatorPanel_Item" .. index]:Show()
    _G["ReforgenatorPanel_Item" .. index .. "Checked"]:Show()
end

local debugFrame = tekDebug and tekDebug:GetFrame("Reforgenator")

function Reforgenator:Debug(...)
    if debugFrame then
        debugFrame:AddMessage(string.join(", ", ...))
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

local SolutionContext = {}

function SolutionContext:new()
    local result = { items={}, changes={}, excessRating={} }
    setmetatable(result, self)
    self.__index = self
    return result
end

local PlayerModel = {}

function PlayerModel:new()
    local result = { className="", primaryTab=0, race="" }
    setmetatable(result, self)
    self.__index = self
    return result
end

function Reforgenator:GetPlayerModel()
    local playerModel = PlayerModel:new()

    local function getPrimaryTab()
	local primary = { tab=nil, points = 0, isUnlocked=true }
	for i = 1, GetNumTalentTabs() do
	    local _,_,_,_,points,_,_,isUnlocked = GetTalentTabInfo(i)
	    if points > primary.points then
		primary = {tab=i, points=points, isUnlocked=isUnlocked }
	    end
	end

	return primary.tab
    end

    playerModel.className = select(2, UnitClass("player"))
    playerModel.primaryTab = getPrimaryTab()
    playerModel.race = select(2, UnitRace("player"))

    return playerModel
end

local ReforgeModel = {}

function ReforgeModel:new()
    local result = { statRank={}, reforgeOrder={} }
    setmetatable(result, self)
    self.__index = self
    return result
end

function Invert(list)
    local invertedList = {}
    for k,v in ipairs(list) do
	invertedList[v] = k
    end
    return invertedList
end

function Reforgenator:TankModel(playerModel)
    local model = ReforgeModel:new()
    model.statRank = Invert {
	"ITEM_MOD_HIT_RATING_SHORT",
	"ITEM_MOD_EXPERTISE_RATING_SHORT",
	"ITEM_MOD_MASTERY_RATING_SHORT",
	"ITEM_MOD_DODGE_RATING_SHORT",
	"ITEM_MOD_PARRY_RATING_SHORT",
	"ITEM_MOD_CRIT_RATING_SHORT",
	"ITEM_MOD_HASTE_RATING_SHORT",
	"ITEM_MOD_SPIRIT_RATING_SHORT",
    }

    model.reforgeOrder = {
	{ rating="ITEM_MOD_HIT_RATING_SHORT",
	    cap=self:CalculateMeleeHitCap(playerModel) },
	{ rating="ITEM_MOD_EXPERTISE_RATING_SHORT",
	    cap=self:CalculateExpertiseCap(playerModel) },
	{ rating="ITEM_MOD_MASTERY_RATING_SHORT",
	    cap=9999 },
    }

    return model
end

function Reforgenator:HunterModel(playerModel)
    local model = ReforgeModel:new()
    model.statRank = Invert {
	"ITEM_MOD_HIT_RATING_SHORT",
	"ITEM_MOD_MASTERY_RATING_SHORT",
	"ITEM_MOD_CRIT_RATING_SHORT",
	"ITEM_MOD_HASTE_RATING_SHORT",
	"ITEM_MOD_EXPERTISE_RATING_SHORT",
	"ITEM_MOD_DODGE_RATING_SHORT",
	"ITEM_MOD_PARRY_RATING_SHORT",
	"ITEM_MOD_SPIRIT_RATING_SHORT",
    }

    model.reforgeOrder = {
	{ rating="ITEM_MOD_HIT_RATING_SHORT",
	    cap=self:CalculateRangedHitCap(playerModel) },
	{ rating="ITEM_MOD_MASTERY_RATING_SHORT",
	    cap=9999 },
    }

    return model
end

function Reforgenator:BoomkinModel(playerModel)
    local model = ReforgeModel:new()
    model.statRank = Invert {
	"ITEM_MOD_SPIRIT_RATING_SHORT",
	"ITEM_MOD_HIT_RATING_SHORT",
	"ITEM_MOD_HASTE_RATING_SHORT",
	"ITEM_MOD_CRIT_RATING_SHORT",
	"ITEM_MOD_MASTERY_RATING_SHORT",
	"ITEM_MOD_EXPERTISE_RATING_SHORT",
	"ITEM_MOD_DODGE_RATING_SHORT",
	"ITEM_MOD_PARRY_RATING_SHORT",
    }

    model.reforgeOrder = {
	{ rating="ITEM_MOD_HIT_RATING_SHORT",
	    cap=self:CalculateSpellHitCap(playerModel) },
	{ rating="ITEM_MOD_HASTE_RATING_SHORT",
	    cap=9999 },
    }

    model.useSpellHit = true

    return model
end

function Reforgenator:FuryModel(playerModel)
    local model = ReforgeModel:new()
    model.statRank = Invert {
	"ITEM_MOD_HIT_RATING_SHORT",
	"ITEM_MOD_EXPERTISE_RATING_SHORT",
	"ITEM_MOD_CRIT_RATING_SHORT",
	"ITEM_MOD_HASTE_RATING_SHORT",
	"ITEM_MOD_DODGE_RATING_SHORT",
	"ITEM_MOD_PARRY_RATING_SHORT",
	"ITEM_MOD_SPIRIT_RATING_SHORT",
	"ITEM_MOD_MASTERY_RATING_SHORT",
    }

    model.reforgeOrder = {
	{ rating="ITEM_MOD_HIT_RATING_SHORT",
	    cap=self:CalculateMeleeHitCap(playerModel) },
	{ rating="ITEM_MOD_EXPERTISE_RATING_SHORT",
	    cap=self:CalculateExpertiseCap(playerModel) },
	{ rating="ITEM_MOD_HIT_RATING_SHORT",
	    cap=self:CalculateDWMeleeHitCap(playerModel) },
    }

    return model
end

function Reforgenator:RogueModel(playerModel)
    local model = ReforgeModel:new()
    model.statRank = Invert {
	"ITEM_MOD_HIT_RATING_SHORT",
	"ITEM_MOD_EXPERTISE_RATING_SHORT",
	"ITEM_MOD_HASTE_RATING_SHORT",
	"ITEM_MOD_CRIT_RATING_SHORT",
	"ITEM_MOD_DODGE_RATING_SHORT",
	"ITEM_MOD_PARRY_RATING_SHORT",
	"ITEM_MOD_SPIRIT_RATING_SHORT",
	"ITEM_MOD_MASTERY_RATING_SHORT",
    }

    model.reforgeOrder = {
	{ rating="ITEM_MOD_HIT_RATING_SHORT",
	    cap=self:CalculateSpellHitCap(playerModel) },
	{ rating="ITEM_MOD_EXPERTISE_RATING_SHORT",
	    cap=self:CalculateExpertiseCap(playerModel) },
	{ rating="ITEM_MOD_HASTE_RATING_SHORT",
	    cap=9999 },
    }

    model.useSpellHit = true

    return model
end

function Reforgenator:CatModel(playerModel)
    local model = ReforgeModel:new()
    model.statRank = Invert {
	"ITEM_MOD_HIT_RATING_SHORT",
	"ITEM_MOD_EXPERTISE_RATING_SHORT",
	"ITEM_MOD_CRIT_RATING_SHORT",
	"ITEM_MOD_MASTERY_RATING_SHORT",
	"ITEM_MOD_HASTE_RATING_SHORT",
	"ITEM_MOD_DODGE_RATING_SHORT",
	"ITEM_MOD_PARRY_RATING_SHORT",
	"ITEM_MOD_SPIRIT_RATING_SHORT",
    }

    model.reforgeOrder = {
	{ rating="ITEM_MOD_HIT_RATING_SHORT",
	    cap=self:CalculateMeleeHitCap(playerModel) },
	{ rating="ITEM_MOD_EXPERTISE_RATING_SHORT",
	    cap=self:CalculateExpertiseCap(playerModel) },
	{ rating="ITEM_MOD_CRIT_RATING_SHORT",
	    cap=9999 },
    }

    return model
end

function Reforgenator:AffWarlockModel(playerModel)
    local model = ReforgeModel:new()
    model.statRank = Invert {
	"ITEM_MOD_HIT_RATING_SHORT",
	"ITEM_MOD_HASTE_RATING_SHORT",
	"ITEM_MOD_MASTERY_RATING_SHORT",
	"ITEM_MOD_SPIRIT_RATING_SHORT",
	"ITEM_MOD_CRIT_RATING_SHORT",
	"ITEM_MOD_EXPERTISE_RATING_SHORT",
	"ITEM_MOD_DODGE_RATING_SHORT",
	"ITEM_MOD_PARRY_RATING_SHORT",
    }

    model.reforgeOrder = {
	{ rating="ITEM_MOD_HIT_RATING_SHORT",
	    cap=self:CalculateSpellHitCap(playerModel) },
	{ rating="ITEM_MOD_HASTE_RATING_SHORT",
	    cap=9999 },
	{ rating="ITEM_MOD_MASTERY_RATING_SHORT",
	    cap=9999 },
    }

    model.useSpellHit = true

    return model
end

function Reforgenator:DestroWarlockModel(playerModel)
    local model = ReforgeModel:new()
    model.statRank = Invert {
	"ITEM_MOD_HIT_RATING_SHORT",
	"ITEM_MOD_MASTERY_RATING_SHORT",
	"ITEM_MOD_CRIT_RATING_SHORT",
	"ITEM_MOD_HASTE_RATING_SHORT",
	"ITEM_MOD_SPIRIT_RATING_SHORT",
	"ITEM_MOD_EXPERTISE_RATING_SHORT",
	"ITEM_MOD_DODGE_RATING_SHORT",
	"ITEM_MOD_PARRY_RATING_SHORT",
    }

    model.reforgeOrder = {
	{ rating="ITEM_MOD_HIT_RATING_SHORT",
	    cap=self:CalculateSpellHitCap(playerModel) },
	{ rating="ITEM_MOD_MASTERY_RATING_SHORT",
	    cap=9999 },
    }

    model.useSpellHit = true

    return model
end

function Reforgenator:DemoWarlockModel(playerModel)
    local model = ReforgeModel:new()
    model.statRank = Invert {
	"ITEM_MOD_HIT_RATING_SHORT",
	"ITEM_MOD_CRIT_RATING_SHORT",
	"ITEM_MOD_HASTE_RATING_SHORT",
	"ITEM_MOD_MASTERY_RATING_SHORT",
	"ITEM_MOD_SPIRIT_RATING_SHORT",
	"ITEM_MOD_EXPERTISE_RATING_SHORT",
	"ITEM_MOD_DODGE_RATING_SHORT",
	"ITEM_MOD_PARRY_RATING_SHORT",
    }

    model.reforgeOrder = {
	{ rating="ITEM_MOD_HIT_RATING_SHORT",
	    cap=self:CalculateSpellHitCap(playerModel) },
	{ rating="ITEM_MOD_CRIT_RATING_SHORT",
	    cap=9999 },
	{ rating="ITEM_MOD_HASTE_RATING_SHORT",
	    cap=9999 },
	{ rating="ITEM_MOD_MASTERY_RATING_SHORT",
	    cap=9999 },
    }

    model.useSpellHit = true

    return model
end


function Reforgenator:CalculateMeleeHitCap(playerModel)
    local hitCap = 247

    -- Mods to hit: Draenei get 1% bonus
    if playerModel.race == "Draenei" then
	hitCap = hitCap - 31
    end

    -- Fury warriors get 3% bonus from Precision
    if playerModel.class == "WARRIOR" and playerModel.primaryTab == 2 then
	hitCap = hitCap - 93
    end

    -- Rogues get varying amounts based on Precision talent
    if playerModel.className == "ROGUE" then
	local pointsInPrecision = select(5, GetTalentInfo(2,3))
	hitCap = hitCap - math.floor(30.7548 * 2 * pointsInPrecision)
    end

    self:Debug("calculated melee hit cap = " .. hitCap)

    return hitCap
end

function Reforgenator:CalculateDWMeleeHitCap(playerModel)
    local hitCap = 831

    -- Mods to hit: Draenei get 1% bonus
    if playerModel.race == "Draenei" then
	hitCap = hitCap - 31
    end

    -- Fury warriors get 3% bonus from Precision
    if playerModel.class == "WARRIOR" and playerModel.primaryTab == 2 then
	hitCap = hitCap - 93
    end

    -- Rogues get varying amounts based on Precision talent
    if playerModel.className == "ROGUE" then
	local pointsInPrecision = select(5, GetTalentInfo(2,3))
	hitCap = hitCap - math.floor(30.7548 * 2 * pointsInPrecision)
    end

    self:Debug("calculated DW melee hit cap = " .. hitCap)

    return hitCap
end

function Reforgenator:CalculateRangedHitCap(playerModel)
    local hitCap = 247

    -- Mods to hit: Draenei get 1% bonus
    if playerModel.race == "Draenei" then
	hitCap = 216
    end

    self:Debug("calculated ranged hit cap = " .. hitCap)

    return hitCap
end

function Reforgenator:CalculateSpellHitCap(playerModel)
    local hitCap = 446

    -- Mods to hit: Draenei get 1% bonus
    if playerModel.race == "Draenei" then
	hitCap = hitCap - 27
    end

    -- Rogues get varying amounts based on Precision talent
    if playerModel.className == "ROGUE" then
	local pointsInPrecision = select(5, GetTalentInfo(2,3))
	hitCap = hitCap - math.floor(26.232 * 2 * pointsInPrecision)
    end

    self:Debug("calculated spell hit cap = " .. hitCap)

    return hitCap
end

function Reforgenator:CalculateExpertiseCap(playerModel)
    -- Mods to expertise:
    --   (7.6887 rating per)
    --   DKs get +6 expertise from "veteran of the third war"
    --   Orcs get +3 for axes and fist weapons
    --   Dwarves get +3 for maces
    --   Humans get +3 for swords and maces
    --   Gnomes get +3 for daggers and 1H swords
    --   Paladins with "Seal of Truth" glyphed get +10 expertise
    local expertiseCap = 177

    if playerModel.className == "DEATHKNIGHT" then
	self:Debug("reducing expertise for DK")
	expertiseCap = expertiseCap - 46
    end

    if playerModel.className == "PALADIN" then
	local hasGlyph = nil
	for i = 1,GetNumGlyphSockets() do
	    local _,_,_,glyphSpellID = GetGlyphSocketInfo(i)
	    self:Debug("glyph socket "..i.." has "..(glyphSpellID or "nil"))
	    if glyphSpellID and glyphSpellID == 56416 then
		hasGlyph = true
	    end
	end

	if hasGlyph then
	    self:Debug("reducing expertise for Glyph of Seal of Truth")
	    expertiseCap = expertiseCap - 77
	end
    end

    local mainHandLink = GetInventoryItemLink("player", GetInventorySlotInfo("MainHandSlot"))
    local _, _, _, _, _, itemType, itemSubType = GetItemInfo(mainHandLink)
    self:Debug("itemType="..itemType..", itemSubType="..itemSubType)

    if playerModel.race == "Orc" then
	if itemSubType == "One-Handed Axes"
		or itemSubType == "Two-Handed Axes"
		or itemSubType == "Fist Weapons" then
	    self:Debug("reducing expertise for Orc with axe or fist")
	    expertiseCap = expertiseCap - 23
	end
    elseif playerModel.race == "Dwarf" then
	if itemSubType == "One-Handed Maces"
		or itemSubType == "Two-Handed Maces" then
	    self:Debug("reducing expertise for Dwarf with mace")
	    expertiseCap = expertiseCap - 23
	end
    elseif playerModel.race == "Human" then
	if itemSubType == "One-Handed Swords"
		or itemSubType == "Two-Handed Swords"
		or itemSubType == "One-Handed Maces"
		or itemSubType == "Two-Handed Maces" then
	    self:Debug("reducing expertise for Human with sword or mace")
	    expertiseCap = expertiseCap - 23
	end
    elseif playerModel.race == "Gnome" then
	if itemSubType == "One-Handed Swords"
		or itemSubType == "Daggers" then
	    self:Debug("reducing expertise for Gnome with dagger or 1H sword")
	    expertiseCap = expertiseCap - 23
	end
    end

    self:Debug("calculated expertise cap = " .. expertiseCap)
    return expertiseCap
end

function Reforgenator:GetPlayerReforgeModel(playerModel)
    if playerModel.className == "HUNTER" then
	return self:HunterModel(playerModel)
    end

    if playerModel.className == "ROGUE" then
	return self:RogueModel(playerModel)
    end

    if playerModel.className == "WARRIOR" then
	if playerModel.primaryTab == 2 then
	    return self:FuryModel(playerModel)
	elseif playerModel.primaryTab == 3 then
	    return self:TankModel(playerModel)
	end
    end

    if playerModel.className == "DEATHKNIGHT" then
	if playerModel.primaryTab == 1 then
	    return self:TankModel(playerModel)
	end
    end

    if playerModel.className == "DRUID" then
	if playerModel.primaryTab == 2 then
	    local form = GetShapeshiftFormID()
	    if not form then
		self:MessageBox("Please shift into your combat form and re-run the Reforgenator")
		return nil
	    end
	    if form == 5 then
		return self:TankModel(playerModel)
	    elseif form == 1 then
		return self:CatModel(playerModel)
	    end
	elseif playerModel.primaryTab == 1 then
	    return self:BoomkinModel(playerModel)
	end
    end

    if playerModel.className == "PALADIN" then
	if playerModel.primaryTab == 2 then
	    return self:TankModel(playerModel)
	end
    end

    if playerModel.className == "WARLOCK" then
	if playerModel.primaryTab == 1 then
	    return self:AffWarlockModel(playerModel)
	elseif playerModel.primaryTab == 2 then
	    return self:DemoWarlockModel(playerModel)
	else
	    return self:DestroWarlockModel(playerModel)
	end
    end

    self:MessageBox("Your class/spec isn't supported yet.")
    return nil
end

function Reforgenator:MessageBox(msg)
    SetPortraitTexture(ReforgenatorPortrait, "player")
    ReforgenatorMessageText:SetText(msg)
    ReforgenatorMessageFrame:Show()
end

function Reforgenator:ShowState()
    self:Debug("in ShowState")

    local playerModel = self:GetPlayerModel()

    local model = self:GetPlayerReforgeModel(playerModel)
    if not model then
	return
    end

    --
    -- Get the character's current ratings
    local playerStats = {
	["ITEM_MOD_HIT_RATING_SHORT"] = GetCombatRating(COMBAT_RATINGS.CR_HIT_MELEE),
	["ITEM_MOD_EXPERTISE_RATING_SHORT"] = GetCombatRating(COMBAT_RATINGS.CR_EXPERTISE),
	["ITEM_MOD_MASTERY_RATING_SHORT"] = GetCombatRating(COMBAT_RATINGS.CR_MASTERY),
	["ITEM_MOD_DODGE_RATING_SHORT"] = 0,
	["ITEM_MOD_PARRY_RATING_SHORT"] = 0,
	["ITEM_MOD_CRIT_RATING_SHORT"] = 0,
	["ITEM_MOD_HASTE_RATING_SHORT"] = 0,
	["ITEM_MOD_SPIRIT_RATING_SHORT"] = 0,
    }

    if model.useSpellHit then
	playerStats.ITEM_MOD_HIT_RATING_SHORT = GetCombatRating(COMBAT_RATINGS.CR_HIT_SPELL)
    end

    self:Debug("hit = " .. playerStats.ITEM_MOD_HIT_RATING_SHORT)
    self:Debug("expertise = " .. playerStats.ITEM_MOD_EXPERTISE_RATING_SHORT)
    self:Debug("mastery = " .. playerStats.ITEM_MOD_MASTERY_RATING_SHORT)


    -- Get the current state of the equipment
    soln = SolutionContext:new()
    for k,v in ipairs(INVENTORY_SLOTS) do
	local slotInfo = GetInventorySlotInfo(v)
        local itemLink = GetInventoryItemLink("player", slotInfo)
        if itemLink then
            local stats = {}
            GetItemStats(itemLink, stats)
	    local entry = {}
	    entry.itemLink = itemLink
	    entry.slotInfo = slotInfo
	    entry.itemLevel = select(4, GetItemInfo(itemLink))

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


    for _, entry in ipairs(model.reforgeOrder) do
	soln = self:OptimizeSolution(entry.rating, playerStats[entry.rating], entry.cap, model.statRank, soln)
    end

    -- Populate the window with the things to change
    if #soln.changes == 0 then
	self:MessageBox("Reforgenator has no suggestions for your gear")
    else
	for k,v in ipairs(soln.changes) do
	    self:Debug("changed: " .. to_string(v))
	    self:Print("reforge " .. v.itemLink .. " to change " .. _G[v.reforgedFrom] .. " to " .. _G[v.reforgedTo])
	end
    end

    self.changes = soln.changes
    self:Debug("#self.changes="..#self.changes)
    self:UpdateWindow()

    self:Debug("all done")
end

function Reforgenator:PotentialLossFromRating(item, rating)
    local pool = item[rating]
    local potentialLoss = math.floor(pool * 0.4)
    return potentialLoss
end

function Reforgenator:GetBestReforge(item, desiredRating, excessRating, statRank)
    if item.itemLevel < 200 then
	self:Debug(item.itemLink.." is too low a level to reforge")
	return nil
    end

    if item.reforged then
	self:Debug(item.itemLink.." already reforged")
	return nil
    end

    if item[desiredRating] then
	self:Debug(item.itemLink.." already has desired rating")
	return nil
    end

    self:Debug("### GetBestReforge")
    self:Debug("### item="..item.itemLink)
    self:Debug("### desiredRating="..desiredRating)
    self:Debug("### excessRating="..to_string(excessRating))

    local candidates = {}

    local desiredRank = statRank[desiredRating] or 0
    for k,v in pairs(item) do
	if statRank[k] and statRank[k] > desiredRank then
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

function Reforgenator:OptimizeSolution(rating, currentValue, desiredValue, statRank, ancestor)
    self:Debug("### Optimize Solution")
    self:Debug("### rating="..rating)
    self:Debug("### currentValue="..currentValue)
    self:Debug("### desiredValue="..desiredValue)

    soln = SolutionContext:new()

    for k,v in pairs(ancestor.excessRating) do
	soln.excessRating[k] = v
    end
    for k,v in ipairs(ancestor.changes) do
	soln.changes[#soln.changes + 1] = v
    end

    -- already over cap?
    if currentValue > desiredValue then
	soln.excessRating[rating] = currentValue - desiredValue
	for k,v in ipairs(ancestor.items) do
	    soln.items[#soln.items + 1] = v
	end
	return soln
    end

    -- If we are coming back to try to hit a hard cap, we might have
    -- previously said we had an excess of our now-desired rating, so
    -- clear it out
    if soln.excessRating[rating] then
	self:Debug("zeroing out previous excess for "..rating)
	soln.excessRating[rating] = nil
    end

    unforged = {}
    for k,v in ipairs(ancestor.items) do
	local suggestion = self:GetBestReforge(v, rating, soln.excessRating, statRank)
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
	if val + v.delta <= desiredValue then
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
	local under = math.abs(desiredValue - val)
	local over = math.abs(desiredValue - val + v.delta)
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


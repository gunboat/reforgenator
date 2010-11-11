
Reforgenator = LibStub("AceAddon-3.0"):NewAddon("Reforgenator", "AceConsole-3.0", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("Reforgenator", false)
local RI = LibStub("LibReforgingInfo-1.0")
local version = "0.0.23"

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

local function Set(list)
    local set = {}
    for _, l in ipairs(list) do set[tostring(l)] = true end
    return set
end

function Invert(list)
    local invertedList = {}
    for k,v in ipairs(list) do
        invertedList[v] = k
    end
    return invertedList
end

function Reforgenator:OnEnable()
    self:Print("v"..version.." loaded")
end

local options = {
    type = 'group',
    name = "Reforgenator",
    handler = Reforgenator,
    desc = "Calculate what to reforge",
    args = { 
        useMinimap = {
            name = "Use minimap button",
            desc = "Show a button on the minimap",
            type = "toggle",
            set = function(info, val)
                Reforgenator:Debug("### useMinimap")
                Reforgenator:Debug("### val="..to_string(val))
                if val then
                    Reforgenator.db.profile.minimap.hide = false
                    Reforgenator.minimapIcon:Show("Reforgenator")
                else
                    Reforgenator.db.profile.minimap.hide = true
                    Reforgenator.minimapIcon:Hide("Reforgenator")
                end
            end,
            get = function(info)
                return not Reforgenator.db.profile.minimap.hide
            end,
        },
    },
}

local maintOptions = {
    type = 'group',
    name = "Reforgenator",
    handler = Reforgenator,
    desc = "Calculate what to reforge",
    args = {
        resetDatabase = {
            name = 'Reload built-in models',
            desc = 'Reload the built-in models from the addon',
            type = 'execute',
            func = function(info)
                Reforgenator:LoadDefaultModels()
            end,
        },
    },
}

local defaults = {
    profile = {
        minimap = {
            hide = false,
        },
    },
    global = {
        nextModelID = 1,
    }
}

local profileOptions = {
    name = "Profiles",
    type = "group",
    childGroups = "tab",
    args = {},
}

function Reforgenator:ModelEditorPanel_OnLoad(panel)
    self:Debug("### ModelEditorPanel_OnLoad")
end

function Reforgenator:OnInitialize()
    self:Debug("### OnInitialize")

    Reforgenator.db = LibStub("AceDB-3.0"):New("ReforgenatorDB", defaults, "Default")

    Reforgenator:InitializeConstants()

    Reforgenator:InitializeWidgets()

    LibStub("AceConfig-3.0"):RegisterOptionsTable("Reforgenator", options)
    Reforgenator.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Reforgenator", "Reforgenator")

    LibStub("AceConfig-3.0"):RegisterOptionsTable("Reforgenator Maintenance", maintOptions)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Reforgenator Maintenance", "Maintenance", "Reforgenator")

    local panel = ReforgenatorModelEditorFrame
    panel.name = 'Models'
    panel.parent = Reforgenator.optionsFrame.name
    InterfaceOptions_AddCategory(panel)

    local broker = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject("Reforgenator", {
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
    Reforgenator.minimapIcon = LibStub("LibDBIcon-1.0")
    Reforgenator.minimapIcon:Register("Reforgenator", broker, Reforgenator.db.profile.minimap)

    self:Debug("### minimap.hide="..(to_string(Reforgenator.db.profile.minimap.hide or "nil")))
    if Reforgenator.db.profile.minimap.hide then
        Reforgenator.minimapIcon:Hide("Reforgenator")
    else
        Reforgenator.minimapIcon:Show("Reforgenator")
    end

    self:RegisterChatCommand("reforgenator", "ShowState")

    tinsert(UISpecialFrames, "ReforgenatorPanel")

    if not Reforgenator.db.global.models then
        self:LoadDefaultModels()
    end

end

function Reforgenator:InitializeConstants()
    Reforgenator.constants = {}
    local c = Reforgenator.constants

    c.INVENTORY_SLOTS = {
        "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot",
        "ChestSlot", "ShirtSlot", "TabardSlot", "WristSlot", "HandsSlot",
        "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot",
        "Trinket0Slot", "Trinket1Slot", "MainHandSlot", "SecondaryHandSlot",
        "RangedSlot" }

    c.COMBAT_RATINGS = {
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

    c.ITEM_STATS = Set {
        "ITEM_MOD_CRIT_RATING_SHORT",
        "ITEM_MOD_DODGE_RATING_SHORT",
        "ITEM_MOD_EXPERTISE_RATING_SHORT",
        "ITEM_MOD_HASTE_RATING_SHORT",
        "ITEM_MOD_HIT_RATING_SHORT",
        "ITEM_MOD_MASTERY_RATING_SHORT",
        "ITEM_MOD_PARRY_RATING_SHORT",
        "ITEM_MOD_SPIRIT_SHORT",
    }

    c.STAT_CAPS = {
        ["MeleeHitCap"] = function(m) return Reforgenator:CalculateMeleeHitCap(m) end,
        ["SpellHitCap"] = function(m) return Reforgenator:CalculateSpellHitCap(m) end,
        ["DWHitCap"] = function(m) return Reforgenator:CalculateDWMeleeHitCap(m) end,
        ["RangedHitCap"] = function(m) return Reforgenator:CalculateRangedHitCap(m) end,
        ["ExpertiseSoftCap"] = function(m) return Reforgenator:CalculateExpertiseSoftCap(m) end,
        ["ExpertiseHardCap"] = function(m) return Reforgenator:CalculateExpertiseHardCap(m) end,
        ["MaximumPossible"] = function(m) return Reforgenator:CalculateMaximumValue(m) end,
        ["1SecGCD"] = function(m) return Reforgenator:HasteTo1SecGCD(m) end,
        ["Fixed"] = function(m,a) return a end,
    }

end

function Reforgenator:InitializeWidgets()
    self:Debug("### InitializeWidgets")

end

function Reforgenator:MessageFrame_OnLoad(widget)
end

function Reforgenator:OnClick(widget, button, ...)
    self:Debug("### OnClick")
    self:Debug("widget.ID="..widget:GetID())

    GameTooltip:Hide()
    PickupInventoryItem(widget:GetID())
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

function Reforgenator:ModelSelection_OnLoad()
    self:Debug("### ModelSelection_OnLoad")
end

function Reforgenator:ModelEditorFrame_OnShow(widget)
    self:Debug("### ModelEditorFrame_OnShow")

    for i = 1, 4 do
        local stem = "ModelEditorRule"..i
        _G[stem]:Show()

        local stat = _G[stem.."_Stat"]
        Reforgenator:RuleTemplateStat_OnLoad(stat)
        stat:Show()

        local scheme = _G[stem.."_Scheme"]
        Reforgenator:RuleTemplateScheme_OnLoad(scheme)
        scheme:Show()
    end
end

function Reforgenator:ModelEditorScrollbar_Update()
    self:Debug("### ModelEditorScrollbar_Update")

    local sb = ReforgenatorModelBrowseScrollFrame
    local models = Reforgenator.db.global.models

    local keys = {}
    for k,v in pairs(models) do
	keys[#keys + 1] = k
    end
    table.sort(keys)

    FauxScrollFrame_Update(sb, #keys, 6, 16)

    for line = 1, 6 do
	local button = _G["ModelEditorNameButton" .. line]
	local buttonText = _G["ModelEditorNameButton" .. line .. "Name"]
	local linePlusOffset = line + FauxScrollFrame_GetOffset(sb)
	if linePlusOffset < #keys then
	    buttonText:SetText(keys[linePlusOffset])
	    if Reforgenator.selectedModelName and Reforgenator.selectedModelName == keys[linePlusOffset] then
		button:LockHighlight()
            else
                button:UnlockHighlight()
	    end
	    button:Show()
	else
	    button:Hide()
	end
    end
end

function Reforgenator:ModelEditorName_OnClick(widget, button)
    self:Debug("### ModelEditorName_OnClick")
    for i=1,6 do
        local b = _G["ModelEditorNameButton" .. i]
        if b:GetID() == widget:GetID() then
	    local t = _G["ModelEditorNameButton" .. i .. "Name"]
	    Reforgenator.selectedModelName = t:GetText()
            self:ModelEditor_UpdateFields()
            b:LockHighlight()
        else
            b:UnlockHighlight()
        end
    end
end

function Reforgenator:ModelEditor_UpdateFields()
    local name = Reforgenator.selectedModelName
    if not name then
        return
    end

    local models = Reforgenator.db.global.models
    -- ReforgenatorModelEditorModelName:SetText(name)
end

function Reforgenator:RuleTemplateStat_OnLoad(widget)
    self:Debug("### RuleTemplateStat_OnLoad")
    local func = function() Reforgenator:RuleTemplateStat_OnInitialize() end
    UIDropDownMenu_Initialize(widget, func)
end

function Reforgenator:RuleTemplateStat_OnInitialize()
    self:Debug("### RuleTemplateStat_OnInitialize")
    for k,v in pairs(Reforgenator.constants.ITEM_STATS) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = _G[k]
        UIDropDownMenu_AddButton(info)
    end
end

function Reforgenator:RuleTemplateScheme_OnLoad(widget)
    self:Debug("### RuleTemplateScheme_OnLoad")
    local func = function() Reforgenator:RuleTemplateScheme_OnInitialize() end
    UIDropDownMenu_Initialize(widget, func)
end

function Reforgenator:RuleTemplateScheme_OnInitialize()
    self:Debug("### RuleTemplateScheme_OnInitialize")
    for k,v in pairs(Reforgenator.constants.STAT_CAPS) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = k
        UIDropDownMenu_AddButton(info)
    end
end

function Reforgenator:GetPlayerKey()
    local key = GetUnitName("player").."-"..GetRealmName()
    return key
end

function Reforgenator:ModelSelection_OnInitialize()
    self:Debug("### ModelSelection_OnInitialize")

    local db = Reforgenator.db

    local class = select(2, UnitClass("player"))
    local key = self:GetPlayerKey()

    local function clearPlayerFromModels()
        for k,v in pairs(db.global.models) do
            if v.PerCharacterOptions[key] then
                v.PerCharacterOptions[key] = nil
            end
        end
    end

    local displayOrder = {}
    for k,v in pairs(db.global.models) do
        if v.class == class then
            displayOrder[#displayOrder+1] = k
        end
    end
    table.sort(displayOrder)
    self:Debug("### displayOrder="..to_string(displayOrder))

    local info = UIDropDownMenu_CreateInfo()
    for _,k in ipairs(displayOrder) do
        info.text = k
        info.func = function(self)
            Reforgenator:Debug("### chose "..self.value)
            clearPlayerFromModels()
            db.global.models[self.value].PerCharacterOptions[key] = true
            UIDropDownMenu_SetSelectedName(ReforgenatorPanel_ModelSelection, self.value)
            Reforgenator:ShowState()
        end
        info.checked = nil
        UIDropDownMenu_AddButton(info)
    end
end

function Reforgenator:ModelSelection_OnShow()
    local db = Reforgenator.db
    local func = function() Reforgenator:ModelSelection_OnInitialize() end
    UIDropDownMenu_Initialize(ReforgenatorPanel_ModelSelection, func)
    UIDropDownMenu_SetWidth(ReforgenatorPanel_ModelSelection, 230)

    UIDropDownMenu_ClearAll(ReforgenatorPanel_ModelSelection)

    local key = self:GetPlayerKey()
    for k,v in pairs(db.global.models) do
        if v.PerCharacterOptions[key] then
            UIDropDownMenu_SetSelectedName(ReforgenatorPanel_ModelSelection, k)
        end
    end
end

local debugFrame = tekDebug and tekDebug:GetFrame("Reforgenator")

function Reforgenator:Debug(...)
    if debugFrame then
        debugFrame:AddMessage(string.join(", ", ...))
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

    local function getMainHandWeaponType()
        local mainHandLink = GetInventoryItemLink("player", GetInventorySlotInfo("MainHandSlot"))
        local _, _, _, _, _, itemType, itemSubType = GetItemInfo(mainHandLink)
        self:Debug("itemType="..itemType..", itemSubType="..itemSubType)
        return itemSubType
    end

    playerModel.className = select(2, UnitClass("player"))
    playerModel.primaryTab = getPrimaryTab()
    playerModel.race = select(2, UnitRace("player"))
    playerModel.mainHandWeaponType = getMainHandWeaponType()

    return playerModel
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

function Reforgenator:ExpertiseMods(playerModel)
    --   (7.6887 rating per)
    --   DKs get +6 expertise from "veteran of the third war"
    --   Orcs get +3 for axes and fist weapons
    --   Dwarves get +3 for maces
    --   Humans get +3 for swords and maces
    --   Gnomes get +3 for daggers and 1H swords
    --   Paladins with "Seal of Truth" glyphed get +10 expertise
    --   Enh shamans get +4 for each point in Unleashed Rage
    local reduction = 0;

    if playerModel.className == "DEATHKNIGHT" and playerModel.primaryTab == 1 then
        self:Debug("reducing expertise for blood DK")
        reduction = reduction + 46
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
            reduction = reduction + 77
        end
    end

    if playerModel.race == "Orc" then
        if playerModel.mainHandWeaponType == "One-Handed Axes"
                or playerModel.mainHandWeaponType == "Two-Handed Axes"
                or playerModel.mainHandWeaponType == "Fist Weapons" then
            self:Debug("reducing expertise for Orc with axe or fist")
            reduction = reduction + 23
        end
    elseif playerModel.race == "Dwarf" then
        if playerModel.mainHandWeaponType == "One-Handed Maces"
                or playerModel.mainHandWeaponType == "Two-Handed Maces" then
            self:Debug("reducing expertise for Dwarf with mace")
            reduction = reduction + 23
        end
    elseif playerModel.race == "Human" then
        if playerModel.mainHandWeaponType == "One-Handed Swords"
                or playerModel.mainHandWeaponType == "Two-Handed Swords"
                or playerModel.mainHandWeaponType == "One-Handed Maces"
                or playerModel.mainHandWeaponType == "Two-Handed Maces" then
            self:Debug("reducing expertise for Human with sword or mace")
            reduction = reduction + 23
        end
    elseif playerModel.race == "Gnome" then
        if playerModel.mainHandWeaponType == "One-Handed Swords"
                or playerModel.mainHandWeaponType == "Daggers" then
            self:Debug("reducing expertise for Gnome with dagger or 1H sword")
            reduction = reduction + 23
        end
    end

    if playerModel.className == "SHAMAN" then
        local pointsInUnleashedRage = select(5, GetTalentInfo(2,16))
        reduction = reduction + math.floor(4 * pointsInUnleashedRage * 7.6887)
    end

    return reduction
end

function Reforgenator:CalculateExpertiseSoftCap(playerModel)
    local expertiseCap = 177

    expertiseCap = expertiseCap - self:ExpertiseMods(playerModel)
    self:Debug("calculated expertise cap = " .. expertiseCap)
    return expertiseCap
end

function Reforgenator:CalculateExpertiseHardCap(playerModel)
    local expertiseCap = 431

    expertiseCap = expertiseCap - self:ExpertiseMods(playerModel)
    self:Debug("calculated expertise cap = " .. expertiseCap)
    return expertiseCap
end

function Reforgenator:HasteTo1SecGCD(playerModel)
    local hasteCap = 1640
    local reduction = 0

    if playerModel.className == "PRIEST" then
        local pointsInDarkness = select(5, GetTalentInfo(3,1))
        reduction = reduction + pointsInDarkness * 40
    end

    if playerModel.className == "DRUID" then
        local moonkinForm = select(5, GetTalentInfo(1,8))
        reduction = reduction + moonkinForm * 5 * 40
    end

    return hasteCap - reduction
end

function Reforgenator:CalculateMaximumValue(playerModel)
    return 9999
end

local ReforgeModel = {}

function ReforgeModel:new()
    local result = { name='', statRank={}, reforgeOrder={} }
    setmetatable(result, self)
    self.__index = self
    return result
end

function Reforgenator:TankModel()
    local model = ReforgeModel:new()
    model.readOnly = true
    model.statRank = Invert {
        "ITEM_MOD_HIT_RATING_SHORT",
        "ITEM_MOD_EXPERTISE_RATING_SHORT",
        "ITEM_MOD_MASTERY_RATING_SHORT",
        "ITEM_MOD_DODGE_RATING_SHORT",
        "ITEM_MOD_PARRY_RATING_SHORT",
        "ITEM_MOD_CRIT_RATING_SHORT",
        "ITEM_MOD_HASTE_RATING_SHORT",
        "ITEM_MOD_SPIRIT_SHORT",
    }

    model.reforgeOrder = {
        { rating="ITEM_MOD_HIT_RATING_SHORT", cap="MeleeHitCap" },
        { rating="ITEM_MOD_EXPERTISE_RATING_SHORT", cap="ExpertiseSoftCap" },
        { rating="ITEM_MOD_MASTERY_RATING_SHORT", cap="MaximumPossible" },
    }

    return model
end

function Reforgenator:HunterModel()
    local model = ReforgeModel:new()
    model.readOnly = true
    model.statRank = Invert {
        "ITEM_MOD_HIT_RATING_SHORT",
        "ITEM_MOD_MASTERY_RATING_SHORT",
        "ITEM_MOD_CRIT_RATING_SHORT",
        "ITEM_MOD_HASTE_RATING_SHORT",
        "ITEM_MOD_EXPERTISE_RATING_SHORT",
        "ITEM_MOD_DODGE_RATING_SHORT",
        "ITEM_MOD_PARRY_RATING_SHORT",
        "ITEM_MOD_SPIRIT_SHORT",
    }

    model.reforgeOrder = {
        { rating="ITEM_MOD_HIT_RATING_SHORT", cap="RangedHitCap" },
        { rating="ITEM_MOD_MASTERY_RATING_SHORT", cap="MaximumPossible" },
    }

    return model
end

function Reforgenator:BoomkinModel()
    local model = ReforgeModel:new()
    model.readOnly = true
    model.statRank = Invert {
        "ITEM_MOD_SPIRIT_SHORT",
        "ITEM_MOD_HIT_RATING_SHORT",
        "ITEM_MOD_HASTE_RATING_SHORT",
        "ITEM_MOD_CRIT_RATING_SHORT",
        "ITEM_MOD_MASTERY_RATING_SHORT",
        "ITEM_MOD_EXPERTISE_RATING_SHORT",
        "ITEM_MOD_DODGE_RATING_SHORT",
        "ITEM_MOD_PARRY_RATING_SHORT",
    }

    model.reforgeOrder = {
        { rating="ITEM_MOD_HIT_RATING_SHORT", cap="SpellHitCap" },
        { rating="ITEM_MOD_HASTE_RATING_SHORT", cap="1SecGCD" },
        { rating="ITEM_MOD_MASTERY_RATING_SHORT", cap="MaximumPossible" },
    }

    model.useSpellHit = true

    return model
end

function Reforgenator:FuryModel()
    local model = ReforgeModel:new()
    model.readOnly = true
    model.statRank = Invert {
        "ITEM_MOD_HIT_RATING_SHORT",
        "ITEM_MOD_EXPERTISE_RATING_SHORT",
        "ITEM_MOD_CRIT_RATING_SHORT",
        "ITEM_MOD_HASTE_RATING_SHORT",
        "ITEM_MOD_DODGE_RATING_SHORT",
        "ITEM_MOD_PARRY_RATING_SHORT",
        "ITEM_MOD_SPIRIT_SHORT",
        "ITEM_MOD_MASTERY_RATING_SHORT",
    }

    model.reforgeOrder = {
        { rating="ITEM_MOD_HIT_RATING_SHORT", cap="MeleeHitCap" },
        { rating="ITEM_MOD_EXPERTISE_RATING_SHORT", cap="ExpertiseSoftCap" },
        { rating="ITEM_MOD_HIT_RATING_SHORT", cap="DWHitCap" },
    }

    return model
end

function Reforgenator:ArmsModel()
    local model = ReforgeModel:new()
    model.readOnly = true
    model.statRank = Invert {
        "ITEM_MOD_HIT_RATING_SHORT",
        "ITEM_MOD_CRIT_RATING_SHORT",
        "ITEM_MOD_EXPERTISE_RATING_SHORT",
        "ITEM_MOD_HASTE_RATING_SHORT",
        "ITEM_MOD_DODGE_RATING_SHORT",
        "ITEM_MOD_PARRY_RATING_SHORT",
        "ITEM_MOD_SPIRIT_SHORT",
        "ITEM_MOD_MASTERY_RATING_SHORT",
    }

    model.reforgeOrder = {
        { rating="ITEM_MOD_HIT_RATING_SHORT", cap="MeleeHitCap" },
        { rating="ITEM_MOD_CRIT_RATING_SHORT", cap="MaximumPossible" },
    }

    return model
end

function Reforgenator:RogueModel()
    local model = ReforgeModel:new()
    model.readOnly = true
    model.statRank = Invert {
        "ITEM_MOD_HIT_RATING_SHORT",
        "ITEM_MOD_EXPERTISE_RATING_SHORT",
        "ITEM_MOD_HASTE_RATING_SHORT",
        "ITEM_MOD_CRIT_RATING_SHORT",
        "ITEM_MOD_DODGE_RATING_SHORT",
        "ITEM_MOD_PARRY_RATING_SHORT",
        "ITEM_MOD_SPIRIT_SHORT",
        "ITEM_MOD_MASTERY_RATING_SHORT",
    }

    model.reforgeOrder = {
        { rating="ITEM_MOD_HIT_RATING_SHORT", cap="SpellHitCap" },
        { rating="ITEM_MOD_EXPERTISE_RATING_SHORT", cap="ExpertiseSoftCap" },
        { rating="ITEM_MOD_HASTE_RATING_SHORT", cap="MaximumPossible" },
    }

    model.useSpellHit = true

    return model
end

function Reforgenator:CatModel()
    local model = ReforgeModel:new()
    model.readOnly = true
    model.statRank = Invert {
        "ITEM_MOD_HIT_RATING_SHORT",
        "ITEM_MOD_EXPERTISE_RATING_SHORT",
        "ITEM_MOD_CRIT_RATING_SHORT",
        "ITEM_MOD_MASTERY_RATING_SHORT",
        "ITEM_MOD_HASTE_RATING_SHORT",
        "ITEM_MOD_DODGE_RATING_SHORT",
        "ITEM_MOD_PARRY_RATING_SHORT",
        "ITEM_MOD_SPIRIT_SHORT",
    }

    model.reforgeOrder = {
        { rating="ITEM_MOD_HIT_RATING_SHORT", cap="MeleeHitCap" },
        { rating="ITEM_MOD_EXPERTISE_RATING_SHORT", cap="ExpertiseSoftCap" },
        { rating="ITEM_MOD_CRIT_RATING_SHORT", cap="MaximumPossible" },
    }

    return model
end

function Reforgenator:AffWarlockModel()
    local model = ReforgeModel:new()
    model.readOnly = true
    model.statRank = Invert {
        "ITEM_MOD_HIT_RATING_SHORT",
        "ITEM_MOD_HASTE_RATING_SHORT",
        "ITEM_MOD_MASTERY_RATING_SHORT",
        "ITEM_MOD_SPIRIT_SHORT",
        "ITEM_MOD_CRIT_RATING_SHORT",
        "ITEM_MOD_EXPERTISE_RATING_SHORT",
        "ITEM_MOD_DODGE_RATING_SHORT",
        "ITEM_MOD_PARRY_RATING_SHORT",
    }

    model.reforgeOrder = {
        { rating="ITEM_MOD_HIT_RATING_SHORT", cap="SpellHitCap" },
        { rating="ITEM_MOD_HASTE_RATING_SHORT", cap="MaximumPossible" },
        { rating="ITEM_MOD_MASTERY_RATING_SHORT", cap="MaximumPossible" },
    }

    model.useSpellHit = true

    return model
end

function Reforgenator:DestroWarlockModel()
    local model = ReforgeModel:new()
    model.readOnly = true
    model.statRank = Invert {
        "ITEM_MOD_HIT_RATING_SHORT",
        "ITEM_MOD_MASTERY_RATING_SHORT",
        "ITEM_MOD_CRIT_RATING_SHORT",
        "ITEM_MOD_HASTE_RATING_SHORT",
        "ITEM_MOD_SPIRIT_SHORT",
        "ITEM_MOD_EXPERTISE_RATING_SHORT",
        "ITEM_MOD_DODGE_RATING_SHORT",
        "ITEM_MOD_PARRY_RATING_SHORT",
    }

    model.reforgeOrder = {
        { rating="ITEM_MOD_HIT_RATING_SHORT", cap="SpellHitCap" },
        { rating="ITEM_MOD_MASTERY_RATING_SHORT", cap="MaximumPossible" },
    }

    model.useSpellHit = true

    return model
end

function Reforgenator:DemoWarlockModel()
    local model = ReforgeModel:new()
    model.readOnly = true
    model.statRank = Invert {
        "ITEM_MOD_HIT_RATING_SHORT",
        "ITEM_MOD_CRIT_RATING_SHORT",
        "ITEM_MOD_HASTE_RATING_SHORT",
        "ITEM_MOD_MASTERY_RATING_SHORT",
        "ITEM_MOD_SPIRIT_SHORT",
        "ITEM_MOD_EXPERTISE_RATING_SHORT",
        "ITEM_MOD_DODGE_RATING_SHORT",
        "ITEM_MOD_PARRY_RATING_SHORT",
    }

    model.reforgeOrder = {
        { rating="ITEM_MOD_HIT_RATING_SHORT", cap="SpellHitCap" },
        { rating="ITEM_MOD_CRIT_RATING_SHORT", cap="MaximumPossible" },
        { rating="ITEM_MOD_HASTE_RATING_SHORT", cap="MaximumPossible" },
        { rating="ITEM_MOD_MASTERY_RATING_SHORT", cap="MaximumPossible" },
    }

    model.useSpellHit = true

    return model
end

function Reforgenator:TwoHandFrostDKModel()
    local model = ReforgeModel:new()
    model.readOnly = true
    model.statRank = Invert {
        "ITEM_MOD_HIT_RATING_SHORT",
        "ITEM_MOD_EXPERTISE_RATING_SHORT",
        "ITEM_MOD_HASTE_RATING_SHORT",
        "ITEM_MOD_MASTERY_RATING_SHORT",
        "ITEM_MOD_CRIT_RATING_SHORT",
        "ITEM_MOD_DODGE_RATING_SHORT",
        "ITEM_MOD_PARRY_RATING_SHORT",
        "ITEM_MOD_SPIRIT_SHORT",
    }

    model.reforgeOrder = {
        { rating="ITEM_MOD_HIT_RATING_SHORT", cap="MeleeHitCap" },
        { rating="ITEM_MOD_EXPERTISE_RATING_SHORT", cap="ExpertiseSoftCap" },
        { rating="ITEM_MOD_HASTE_RATING_SHORT", cap="MaximumPossible" },
        { rating="ITEM_MOD_MASTERY_RATING_SHORT", cap="MaximumPossible" },
    }

    return model
end

function Reforgenator:DWFrostDKModel()
    local model = ReforgeModel:new()
    model.readOnly = true
    model.statRank = Invert {
        "ITEM_MOD_HIT_RATING_SHORT",
        "ITEM_MOD_EXPERTISE_RATING_SHORT",
        "ITEM_MOD_MASTERY_RATING_SHORT",
        "ITEM_MOD_HASTE_RATING_SHORT",
        "ITEM_MOD_CRIT_RATING_SHORT",
        "ITEM_MOD_DODGE_RATING_SHORT",
        "ITEM_MOD_PARRY_RATING_SHORT",
        "ITEM_MOD_SPIRIT_SHORT",
    }

    model.reforgeOrder = {
        { rating="ITEM_MOD_HIT_RATING_SHORT", cap="MeleeHitCap" },
        { rating="ITEM_MOD_EXPERTISE_RATING_SHORT", cap="ExpertiseSoftCap" },
        { rating="ITEM_MOD_MASTERY_RATING_SHORT", cap="MaximumPossible" },
        { rating="ITEM_MOD_HASTE_RATING_SHORT", cap="MaximumPossible" },
    }

    return model
end

function Reforgenator:UnholyDKModel()
    local model = ReforgeModel:new()
    model.readOnly = true
    model.statRank = Invert {
        "ITEM_MOD_HIT_RATING_SHORT",
        "ITEM_MOD_HASTE_RATING_SHORT",
        "ITEM_MOD_CRIT_RATING_SHORT",
        "ITEM_MOD_MASTERY_RATING_SHORT",
        "ITEM_MOD_EXPERTISE_RATING_SHORT",
        "ITEM_MOD_DODGE_RATING_SHORT",
        "ITEM_MOD_PARRY_RATING_SHORT",
        "ITEM_MOD_SPIRIT_SHORT",
    }

    model.reforgeOrder = {
        { rating="ITEM_MOD_HIT_RATING_SHORT", cap="MeleeHitCap" },
        { rating="ITEM_MOD_HASTE_RATING_SHORT", cap="MaximumPossible" },
        { rating="ITEM_MOD_CRIT_RATING_SHORT", cap="MaximumPossible" },
        { rating="ITEM_MOD_MASTERY_RATING_SHORT", cap="MaximumPossible" },
    }

    return model
end

function Reforgenator:ArcaneMageModel()
    local model = ReforgeModel:new()
    model.readOnly = true
    model.statRank = Invert {
        "ITEM_MOD_HIT_RATING_SHORT",
        "ITEM_MOD_HASTE_RATING_SHORT",
        "ITEM_MOD_CRIT_RATING_SHORT",
        "ITEM_MOD_MASTERY_RATING_SHORT",
        "ITEM_MOD_SPIRIT_SHORT",
        "ITEM_MOD_EXPERTISE_RATING_SHORT",
        "ITEM_MOD_DODGE_RATING_SHORT",
        "ITEM_MOD_PARRY_RATING_SHORT",
    }

    model.reforgeOrder = {
        { rating="ITEM_MOD_HIT_RATING_SHORT", cap="SpellHitCap" },
        { rating="ITEM_MOD_HASTE_RATING_SHORT", cap="MaximumPossible" },
        { rating="ITEM_MOD_CRIT_RATING_SHORT", cap="MaximumPossible" },
        { rating="ITEM_MOD_MASTERY_RATING_SHORT", cap="MaximumPossible" },
    }

    model.useSpellHit = true

    return model
end

function Reforgenator:FrostMageModel()
    local model = ReforgeModel:new()
    model.readOnly = true
    model.statRank = Invert {
        "ITEM_MOD_HIT_RATING_SHORT",
        "ITEM_MOD_HASTE_RATING_SHORT",
        "ITEM_MOD_CRIT_RATING_SHORT",
        "ITEM_MOD_MASTERY_RATING_SHORT",
        "ITEM_MOD_SPIRIT_SHORT",
        "ITEM_MOD_EXPERTISE_RATING_SHORT",
        "ITEM_MOD_DODGE_RATING_SHORT",
        "ITEM_MOD_PARRY_RATING_SHORT",
    }

    model.reforgeOrder = {
        { rating="ITEM_MOD_HIT_RATING_SHORT", cap="SpellHitCap" },
        { rating="ITEM_MOD_HASTE_RATING_SHORT", cap="MaximumPossible" },
        { rating="ITEM_MOD_CRIT_RATING_SHORT", cap="MaximumPossible" },
        { rating="ITEM_MOD_MASTERY_RATING_SHORT", cap="MaximumPossible" },
    }

    model.useSpellHit = true

    return model
end

function Reforgenator:FireMageModel()
    local model = ReforgeModel:new()
    model.readOnly = true
    model.statRank = Invert {
        "ITEM_MOD_HIT_RATING_SHORT",
        "ITEM_MOD_CRIT_RATING_SHORT",
        "ITEM_MOD_HASTE_RATING_SHORT",
        "ITEM_MOD_MASTERY_RATING_SHORT",
        "ITEM_MOD_SPIRIT_SHORT",
        "ITEM_MOD_EXPERTISE_RATING_SHORT",
        "ITEM_MOD_DODGE_RATING_SHORT",
        "ITEM_MOD_PARRY_RATING_SHORT",
    }

    model.reforgeOrder = {
        { rating="ITEM_MOD_HIT_RATING_SHORT", cap="SpellHitCap" },
        { rating="ITEM_MOD_CRIT_RATING_SHORT", cap="MaximumPossible" },
        { rating="ITEM_MOD_HASTE_RATING_SHORT", cap="MaximumPossible" },
        { rating="ITEM_MOD_MASTERY_RATING_SHORT", cap="MaximumPossible" },
    }

    model.useSpellHit = true

    return model
end

function Reforgenator:RetPallyModel()
    local model = ReforgeModel:new()
    model.readOnly = true
    model.statRank = Invert {
        "ITEM_MOD_HIT_RATING_SHORT",
        "ITEM_MOD_EXPERTISE_RATING_SHORT",
        "ITEM_MOD_HASTE_RATING_SHORT",
        "ITEM_MOD_MASTERY_RATING_SHORT",
        "ITEM_MOD_CRIT_RATING_SHORT",
        "ITEM_MOD_DODGE_RATING_SHORT",
        "ITEM_MOD_PARRY_RATING_SHORT",
        "ITEM_MOD_SPIRIT_SHORT",
    }

    model.reforgeOrder = {
        { rating="ITEM_MOD_HIT_RATING_SHORT", cap="MeleeHitCap" },
        { rating="ITEM_MOD_EXPERTISE_RATING_SHORT", cap="ExpertiseSoftCap" },
        { rating="ITEM_MOD_HASTE_RATING_SHORT", cap="Fixed", userdata=751 },
        { rating="ITEM_MOD_MASTERY_RATING_SHORT", cap="MaximumPossible" },
    }

    return model
end

function Reforgenator:ShadowPriestModel()
    local model = ReforgeModel:new()
    model.readOnly = true
    model.statRank = Invert {
        "ITEM_MOD_HIT_RATING_SHORT",
        "ITEM_MOD_HASTE_RATING_SHORT",
        "ITEM_MOD_EXPERTISE_RATING_SHORT",
        "ITEM_MOD_MASTERY_RATING_SHORT",
        "ITEM_MOD_CRIT_RATING_SHORT",
        "ITEM_MOD_DODGE_RATING_SHORT",
        "ITEM_MOD_PARRY_RATING_SHORT",
        "ITEM_MOD_SPIRIT_SHORT",
    }

    model.reforgeOrder = {
        { rating="ITEM_MOD_HIT_RATING_SHORT", cap="SpellHitCap" },
        { rating="ITEM_MOD_HASTE_RATING_SHORT", cap="1SecGCD" },
        { rating="ITEM_MOD_MASTERY_RATING_SHORT", cap="MaximumPossible" },
    }

    model.useSpellHit = true

    return model
end

function Reforgenator:ElementalModel()
    local model = ReforgeModel:new()
    model.readOnly = true
    model.statRank = Invert {
        "ITEM_MOD_SPIRIT_SHORT",
        "ITEM_MOD_HIT_RATING_SHORT",
        "ITEM_MOD_MASTERY_RATING_SHORT",
        "ITEM_MOD_HASTE_RATING_SHORT",
        "ITEM_MOD_CRIT_RATING_SHORT",
        "ITEM_MOD_EXPERTISE_RATING_SHORT",
        "ITEM_MOD_DODGE_RATING_SHORT",
        "ITEM_MOD_PARRY_RATING_SHORT",
    }

    model.reforgeOrder = {
        { rating="ITEM_MOD_HIT_RATING_SHORT", cap="SpellHitCap" },
        { rating="ITEM_MOD_MASTERY_RATING_SHORT", cap="MaximumPossible" },
    }

    model.useSpellHit = 1

    return model
end

function Reforgenator:EnhancementModel()
    local model = ReforgeModel:new()
    model.readOnly = true
    model.statRank = Invert {
        "ITEM_MOD_SPIRIT_SHORT",
        "ITEM_MOD_HIT_RATING_SHORT",
        "ITEM_MOD_MASTERY_RATING_SHORT",
        "ITEM_MOD_HASTE_RATING_SHORT",
        "ITEM_MOD_CRIT_RATING_SHORT",
        "ITEM_MOD_EXPERTISE_RATING_SHORT",
        "ITEM_MOD_DODGE_RATING_SHORT",
        "ITEM_MOD_PARRY_RATING_SHORT",
    }

    model.reforgeOrder = {
        { rating="ITEM_MOD_HIT_RATING_SHORT", cap="SpellHitCap" },
        { rating="ITEM_MOD_EXPERTISE_RATING_SHORT", cap="ExpertiseSoftCap" },
        { rating="ITEM_MOD_MASTERY_RATING_SHORT", cap="MaximumPossible" },
    }

    model.useSpellHit = true

    return model
end

function Reforgenator:TreeModel()
    local model = ReforgeModel:new()
    model.readOnly = true
    model.statRank = Invert {
        "ITEM_MOD_SPIRIT_SHORT",
        "ITEM_MOD_HASTE_RATING_SHORT",
        "ITEM_MOD_MASTERY_RATING_SHORT",
        "ITEM_MOD_CRIT_RATING_SHORT",
        "ITEM_MOD_EXPERTISE_RATING_SHORT",
        "ITEM_MOD_DODGE_RATING_SHORT",
        "ITEM_MOD_PARRY_RATING_SHORT",
        "ITEM_MOD_HIT_RATING_SHORT",
    }

    model.reforgeOrder = {
        { rating="ITEM_MOD_HASTE_RATING_SHORT",
            cap="Fixed", userdata={ 411, 1231, 2050, 2870,
                547, 1641, 2733,
                165, 493, 821, 1149, 1477, 1804,
                235, 704, 1172, 1641, 2109, 2577 }},
        { rating="ITEM_MOD_MASTERY_RATING_SHORT", cap="MaximumPossible" },
    }

    model.useSpellHit = true

    return model
end

function Reforgenator:DiscModel()
    local model = ReforgeModel:new()
    model.readOnly = true
    model.statRank = Invert {
        "ITEM_MOD_SPIRIT_SHORT",
        "ITEM_MOD_HASTE_RATING_SHORT",
        "ITEM_MOD_MASTERY_RATING_SHORT",
        "ITEM_MOD_CRIT_RATING_SHORT",
        "ITEM_MOD_EXPERTISE_RATING_SHORT",
        "ITEM_MOD_DODGE_RATING_SHORT",
        "ITEM_MOD_PARRY_RATING_SHORT",
        "ITEM_MOD_HIT_RATING_SHORT",
    }

    model.reforgeOrder = {
        { rating="ITEM_MOD_HASTE_RATING_SHORT", cap="Fixed", userdata=831 },
        { rating="ITEM_MOD_MASTERY_RATING_SHORT", cap="MaximumPossible" },
    }

    model.useSpellHit = true

    return model
end

function Reforgenator:HolyModel()
    local model = ReforgeModel:new()
    model.readOnly = true
    model.statRank = Invert {
        "ITEM_MOD_SPIRIT_SHORT",
        "ITEM_MOD_MASTERY_RATING_SHORT",
        "ITEM_MOD_HASTE_RATING_SHORT",
        "ITEM_MOD_CRIT_RATING_SHORT",
        "ITEM_MOD_EXPERTISE_RATING_SHORT",
        "ITEM_MOD_DODGE_RATING_SHORT",
        "ITEM_MOD_PARRY_RATING_SHORT",
        "ITEM_MOD_HIT_RATING_SHORT",
    }

    model.reforgeOrder = {
        { rating="ITEM_MOD_MASTERY_RATING_SHORT", cap="MaximumPossible" },
    }

    model.useSpellHit = true

    return model
end

function Reforgenator:RestoModel()
    local model = ReforgeModel:new()
    model.readOnly = true
    model.statRank = Invert {
        "ITEM_MOD_SPIRIT_SHORT",
        "ITEM_MOD_HASTE_RATING_SHORT",
        "ITEM_MOD_CRIT_RATING_SHORT",
        "ITEM_MOD_MASTERY_RATING_SHORT",
        "ITEM_MOD_EXPERTISE_RATING_SHORT",
        "ITEM_MOD_DODGE_RATING_SHORT",
        "ITEM_MOD_PARRY_RATING_SHORT",
        "ITEM_MOD_HIT_RATING_SHORT",
    }

    model.reforgeOrder = {
        { rating="ITEM_MOD_HASTE_RATING_SHORT", cap="1SecGCD" },
    }

    model.useSpellHit = true

    return model
end

function Reforgenator:HolyPallyModel()
    local model = ReforgeModel:new()
    model.readOnly = true
    model.statRank = Invert {
        "ITEM_MOD_SPIRIT_SHORT",
        "ITEM_MOD_HASTE_RATING_SHORT",
        "ITEM_MOD_MASTERY_RATING_SHORT",
        "ITEM_MOD_CRIT_RATING_SHORT",
        "ITEM_MOD_EXPERTISE_RATING_SHORT",
        "ITEM_MOD_DODGE_RATING_SHORT",
        "ITEM_MOD_PARRY_RATING_SHORT",
        "ITEM_MOD_HIT_RATING_SHORT",
    }

    model.reforgeOrder = {
        { rating="ITEM_MOD_HASTE_RATING_SHORT", cap="1SecGCD" },
        { rating="ITEM_MOD_MASTERY_RATING_SHORT", cap="MaximumPossible" },
    }

    model.useSpellHit = true

    return model
end

function Reforgenator:LoadDefaultModels()
    self:LoadModel(self:TankModel(), 'built-in: DK, blood', 'DEATHKNIGHT/1', 'DEATHKNIGHT')
    self:LoadModel(self:TwoHandFrostDKModel(), 'built-in: DK, 2H frost', '2HFrost', 'DEATHKNIGHT')
    self:LoadModel(self:DWFrostDKModel(), 'built-in: DK, DW frost', 'DWFrost', 'DEATHKNIGHT')
    self:LoadModel(self:UnholyDKModel(), 'built-in: DK, unholy', 'DEATHKNIGHT/3', 'DEATHKNIGHT')

    self:LoadModel(self:BoomkinModel(), 'built-in: Druid, boomkin', 'DRUID/1', 'DRUID')
    self:LoadModel(self:CatModel(), 'built-in: Druid, feral cat', nil, 'DRUID')
    self:LoadModel(self:TankModel(), 'built-in: Druid, feral bear', 'DRUID/2', 'DRUID')
    self:LoadModel(self:TreeModel(), 'built-in: Druid, restoration', 'DRUID/3', 'DRUID')

    self:LoadModel(self:HunterModel(), 'built-in: Hunter, BM', 'HUNTER/1', 'HUNTER')
    self:LoadModel(self:HunterModel(), 'built-in: Hunter, MM', 'HUNTER/2', 'HUNTER')
    self:LoadModel(self:HunterModel(), 'built-in: Hunter, SV', 'HUNTER/3', 'HUNTER')

    self:LoadModel(self:ArcaneMageModel(), 'built-in: Mage, arcane', 'MAGE/1', 'MAGE')
    self:LoadModel(self:FireMageModel(), 'built-in: Mage, fire', 'MAGE/2', 'MAGE')
    self:LoadModel(self:FrostMageModel(), 'built-in: Mage, frost', 'MAGE/3', 'MAGE')

    self:LoadModel(self:HolyPallyModel(), 'built-in: Paladin, holy', 'PALADIN/1', 'PALADIN')
    self:LoadModel(self:TankModel(), 'built-in: Paladin, protection', 'PALADIN/2', 'PALADIN')
    self:LoadModel(self:RetPallyModel(), 'built-in: Paladin, retribution', 'PALADIN/3', 'PALADIN')

    self:LoadModel(self:DiscModel(), 'built-in: Priest, discipline', 'PRIEST/1', 'PRIEST')
    self:LoadModel(self:HolyModel(), 'built-in: Priest, holy', 'PRIEST/2', 'PRIEST')
    self:LoadModel(self:ShadowPriestModel(), 'built-in: Priest, shadow', 'PRIEST/3', 'PRIEST')

    self:LoadModel(self:RogueModel(), "built-in: Rogue, assassination", 'ROGUE/1', 'ROGUE')
    self:LoadModel(self:RogueModel(), "built-in: Rogue, combat", 'ROGUE/2', 'ROGUE')
    self:LoadModel(self:RogueModel(), "built-in: Rogue, subtlely", 'ROGUE/3', 'ROGUE')

    self:LoadModel(self:ElementalModel(), 'built-in: Shaman, elemental', 'SHAMAN/1', 'SHAMAN')
    self:LoadModel(self:EnhancementModel(), 'built-in: Shaman, enhancement', 'SHAMAN/2', 'SHAMAN')
    self:LoadModel(self:RestoModel(), 'built-in: Shaman, restoration', 'SHAMAN/3', 'SHAMAN')

    self:LoadModel(self:AffWarlockModel(), 'built-in: Warlock, affliction', 'WARLOCK/1', 'WARLOCK')
    self:LoadModel(self:DemoWarlockModel(), 'built-in: Warlock, demonology', 'WARLOCK/2', 'WARLOCK')
    self:LoadModel(self:DestroWarlockModel(), 'built-in: Warlock, destruction', 'WARLOCK/3', 'WARLOCK')

    self:LoadModel(self:ArmsModel(), 'built-in: Warrior, arms', 'WARRIOR/1', 'WARRIOR')
    self:LoadModel(self:FuryModel(), 'built-in: Warrior, fury', 'WARRIOR/2', 'WARRIOR')
    self:LoadModel(self:TankModel(), 'built-in: Warrior, protection', 'WARRIOR/3', 'WARRIOR')
end

function Reforgenator:LoadModel(model, modelName, ak, class)
    local m = Reforgenator.db.global.models
    if not m then
        m = {}
    end

    if not modelName then
        modelName = model.name
    end
    m[modelName] = model
    m[modelName].PerCharacterOptions = {}

    if ak then
        m[modelName].ak = ak
    end

    if class then
        m[modelName].class = class
    end

    Reforgenator.db.global.models = m
end


function Reforgenator:GetPlayerReforgeModel(playerModel)
    local db = Reforgenator.db

    local key = self:GetPlayerKey()
    for k,v in pairs(db.global.models) do
        if v.PerCharacterOptions[key] then
            self:Debug("using previously-selected model "..v.name)
            return v
        end
    end

    local ak
    ak = playerModel.className .. "/" .. to_string(playerModel.primaryTab)
    if playerModel.className == "DEATHKNIGHT" and playerModel.primaryTab == 2 then
        if playerModel.mainHandWeaponType:sub(1,10) == "Two-handed" then
            ak = '2HFrost'
        else
            ak = 'DWFrost'
        end
    end

    if not ak then
        self:MessageBox("Your class/spec isn't supported yet.")
        return nil
    end

    self:Debug("### searching for ak="..ak)
    for k,v in pairs(Reforgenator.db.global.models) do
        self:Debug("### model["..tostring(k).."].ak="..(v.ak or "nil"))
        if v.ak == ak then
            v.PerCharacterOptions[key] = true
            return v
        end
    end

    self:MessageBox("Your default model has been deleted. Please restore the database on the options panel")
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
    self:Debug("playerModel="..to_string(playerModel))

    local model = self:GetPlayerReforgeModel(playerModel)
    if not model then
        return
    end
    for k,v in ipairs(model.reforgeOrder) do
        if not STAT_CAPS[v.cap] then
            self:MessageBox("model has invalid stat cap")
        end
    end

    --
    -- Get the character's current ratings
    local c = Reforgenator.constants
    local playerStats = {
        ["ITEM_MOD_HIT_RATING_SHORT"] = GetCombatRating(c.COMBAT_RATINGS.CR_HIT_MELEE),
        ["ITEM_MOD_EXPERTISE_RATING_SHORT"] = GetCombatRating(c.COMBAT_RATINGS.CR_EXPERTISE),
        ["ITEM_MOD_MASTERY_RATING_SHORT"] = GetCombatRating(c.COMBAT_RATINGS.CR_MASTERY),
        ["ITEM_MOD_DODGE_RATING_SHORT"] = GetCombatRating(c.COMBAT_RATINGS.CR_DODGE),
        ["ITEM_MOD_PARRY_RATING_SHORT"] = GetCombatRating(c.COMBAT_RATINGS.CR_PARRY),
        ["ITEM_MOD_CRIT_RATING_SHORT"] = GetCombatRating(c.COMBAT_RATINGS.CR_CRIT_MELEE),
        ["ITEM_MOD_HASTE_RATING_SHORT"] = GetCombatRating(c.COMBAT_RATINGS.CR_HASTE_MELEE),
        ["ITEM_MOD_SPIRIT_SHORT"] = 0,
    }

    if model.useSpellHit then
        playerStats.ITEM_MOD_HIT_RATING_SHORT = GetCombatRating(c.COMBAT_RATINGS.CR_HIT_SPELL)
        playerStats.ITEM_MOD_CRIT_RATING_SHORT = GetCombatRating(c.COMBAT_RATINGS.CR_CRIT_SPELL)
        playerStats.ITEM_MOD_HASTE_RATING_SHORT = GetCombatRating(c.COMBAT_RATINGS.CR_HASTE_SPELL)
    end

    self:Debug("playerStats="..to_string(playerStats))


    -- Get the current state of the equipment
    soln = SolutionContext:new()
    for k,v in ipairs(Reforgenator.constants.INVENTORY_SLOTS) do
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
                if Reforgenator.constants.ITEM_STATS[k] then
                    entry[k] = v
                end
            end

            soln.items[#soln.items + 1] = entry
        end
    end
    self:Dump("current", soln)


    for _, entry in ipairs(model.reforgeOrder) do
        self:Debug("### entry.cap="..entry.cap)
        local f = STAT_CAPS[entry.cap]
        soln = self:OptimizeSolution(entry.rating, playerStats[entry.rating], f(playerModel, entry.userdata), model.statRank, soln)
    end

    -- Populate the window with the things to change
    if #soln.changes == 0 then
        self:MessageBox("Reforgenator has no suggestions for your gear")
    else
        for k,v in ipairs(soln.changes) do
            self:Debug("changed: " .. to_string(v))
        end
    end

    self.changes = soln.changes
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
    self:Debug("### desiredValue="..to_string(desiredValue))

    soln = SolutionContext:new()

    for k,v in pairs(ancestor.excessRating) do
        soln.excessRating[k] = v
    end
    for k,v in ipairs(ancestor.changes) do
        soln.changes[#soln.changes + 1] = v
    end

    -- already over cap?
    local overCap = nil
    if type(desiredValue) == "table" then
        local vec = self:deepCopy(desiredValue)
        table.sort(vec, function(a,b) return a > b end)
        if currentValue > vec[1] then
            overCap = true
        end
    else
        if currentValue > desiredValue then
            overCap = true
        end
    end
    if overCap then
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

    -- "desiredValue" might be a list of break points instead of a single
    -- value. Reforge to get as far up the list as possible, but any
    -- past a break point that we can avoid reforging is a win
    if type(desiredValue) == "table" then
        vec = self:deepCopy(desiredValue)
        table.sort(vec, function(a,b) return a > b end)
        self:Debug("### vec="..to_string(vec))
        val = currentValue
        for k,v in ipairs(unforged) do
            val = val + v.delta
        end
        self:Debug("### max reforged ="..val)

        while vec[1] and vec[1] > val do
            self:Debug("### is it bigger than " .. vec[1] .. "?")
            table.remove(vec, 1)
        end

        if not vec[1] then
            self:Debug("### can't reach first breakpoint ... go for max")
            vec[1] = val
        end
        self:Debug("### breakpoint ="..vec[1])

        for n = #unforged, 1, -1 do
            local v = unforged[n]
            self:Debug("### can we lose " .. v.delta .. "?")
            if val - v.delta < vec[1] then
                break
            end
            self:Debug("### backing out another reforge")
            val = val - v.delta
        end

        self:Debug("### pretend cap is now "..val)
        desiredValue = val
    end

    val = currentValue
    newList = {}
    for k,v in ipairs(unforged) do
        self:Debug("### val="..val..", delta="..v.delta..", desiredValue="..desiredValue)
        if val + v.delta <= desiredValue then
            val = val + v.delta
            v.item = self:ReforgeItem(v, rating, soln.excessRating)
            soln.changes[#soln.changes + 1] = v.item
            soln.items[#soln.items + 1] = v.item
        else
            newList[#newList + 1] = v
        end
    end
    unforged = newList

    if #unforged > 0 then
        local v = unforged[#unforged]
        local under = math.abs(desiredValue - val)
        local over = math.abs(desiredValue - val + v.delta)
        self:Debug("### under="..under)
        self:Debug("### over="..over)
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


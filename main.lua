local addOnName = ...
GetAddOnMetadata = C_AddOns.GetAddOnMetadata
local addOnVersion = GetAddOnMetadata(addOnName, "Version") or "0.0.1"

local clientVersionString = GetBuildInfo()
local clientBuildMajor = string.byte(clientVersionString, 1)
-- load only on classic/tbc/wotlk/cata/mop
if (clientBuildMajor < 49 or clientBuildMajor > 53) then -- or string.byte(clientVersionString, 2) ~= 46
    return
end
assert(LibStub, "TacoTip requires LibStub")
assert(LibStub:GetLibrary("LibClassicInspector", true), "TacoTip requires LibClassicInspector")
assert(LibStub:GetLibrary("LibDetours-1.0", true), "TacoTip requires LibDetours-1.0")
--assert(LibStub:GetLibrary("LibClassicGearScore", true), "TacoTip requires LibClassicGearScore")

--_G[addOnName] = {}

local CI = LibStub("LibClassicInspector")
local Detours = LibStub("LibDetours-1.0")
local GearScore = TT_GS
local L = TACOTIP_LOCALE
local TT = _G[addOnName]

local GetItemInfo = (C_Item and C_Item.GetItemInfo) and C_Item.GetItemInfo or GetItemInfo
local IsEquippableItem = C_Item.IsEquippableItem;

-- local isPawnLoaded = PawnClassicLastUpdatedVersion and PawnClassicLastUpdatedVersion >= 2.0538
local isPawnLoaded = PawnClassicLastUpdatedVersion ~= nil

local HORDE_ICON = "|TInterface\\TargetingFrame\\UI-PVP-HORDE:16:16:-2:0:64:64:0:38:0:38|t"
local ALLIANCE_ICON = "|TInterface\\TargetingFrame\\UI-PVP-ALLIANCE:16:16:-2:0:64:64:0:38:0:38|t"
local PVP_FLAG_ICON = "|TInterface\\GossipFrame\\BattleMasterGossipIcon:0|t"
local ACHIEVEMENT_ICON = "|TInterface\\AchievementFrame\\UI-Achievement-TinyShield:18:18:0:0:20:20:0:12.5:0:12.5|t"

local POWERBAR_UPDATE_RATE = 0.2

local NewTicker = C_Timer.NewTicker
local CAfter = C_Timer.After

local playerClass = select(2, UnitClass("player"))

local FORMAT_ILVL = "%.1f"

-- ============================================================
-- Item Slot Overlays (Quality Border, Item Level, Durability)
-- ============================================================

local EQUIP_SLOT_NAMES = {
    "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot",
    "WristSlot", "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot",
    "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot",
    "MainHandSlot", "SecondaryHandSlot"
}

local EQUIP_SLOT_IDS = {
    HeadSlot = 1, NeckSlot = 2, ShoulderSlot = 3, BackSlot = 15,
    ChestSlot = 5, WristSlot = 9, HandsSlot = 10, WaistSlot = 6,
    LegsSlot = 7, FeetSlot = 8, Finger0Slot = 11, Finger1Slot = 12,
    Trinket0Slot = 13, Trinket1Slot = 14, MainHandSlot = 16,
    SecondaryHandSlot = 17
}

if not CI:IsMop() then
    tinsert(EQUIP_SLOT_NAMES, "RangedSlot")
    EQUIP_SLOT_IDS.RangedSlot = 18
end

local QUALITY_GLOW_ALPHA = 0.75

local function IsOverlayableItem(itemLink)
    if not itemLink or not IsEquippableItem(itemLink) then return false end
    local _, _, _, _, _, _, _, _, itemEquipLoc = GetItemInfo(itemLink)
    return itemEquipLoc ~= "INVTYPE_SHIRT" and itemEquipLoc ~= "INVTYPE_TABARD"
end

local function GetQualityColor(quality)
    local c = GearScore.Rarity[quality]
    if c then
        return c.Red, c.Green, c.Blue
    end
    return 1, 1, 1
end

-- Quality Border

local function EnsureQualityBorder(frame)
    if not frame or frame._qualityBorder then return end
    local border = frame:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    border:SetBlendMode("ADD")
    border:SetVertexColor(1, 1, 1, 0)
    border:SetPoint("CENTER")
    local normTex = frame.GetName and _G[frame:GetName() .. "NormalTexture"]
    if normTex then
        local w, h = normTex:GetSize()
        border:SetSize(w, h)
    else
        border:SetSize(frame:GetWidth() * 1.4, frame:GetHeight() * 1.4)
    end
    frame._qualityBorder = border
end

local function SetQualityBorder(frame, itemLink, quality)
    EnsureQualityBorder(frame)
    if not frame._qualityBorder then return end
    if not TacoTipConfig.show_quality or not itemLink then
        frame._qualityBorder:SetVertexColor(1, 1, 1, 0)
        return
    end
    if quality then
        local r, g, b = GetQualityColor(quality)
        local alpha = QUALITY_GLOW_ALPHA
        if r == 1 and g == 1 and b == 1 then
            alpha = alpha - 0.2
        end
        frame._qualityBorder:SetVertexColor(r, g, b, alpha)
    else
        frame._qualityBorder:SetVertexColor(1, 1, 1, 0)
    end
end

-- Item Level Text

local function EnsureItemLevelText(frame)
    if not frame or frame._itemLevelText then return end
    local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOP", frame, "TOP", 0, -3)
    fs:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    fs:SetText("")
    frame._itemLevelText = fs
end

local function SetItemLevel(frame, itemLink, quality, unit, slotId, bagID)
    EnsureItemLevelText(frame)
    if not frame._itemLevelText then return end
    if not TacoTipConfig.show_item_level or not itemLink then
        frame._itemLevelText:SetText("")
        frame._itemLevelText:Hide()
        return
    end
    local _, _, _, ilvl = GetItemInfo(itemLink)
    if unit and slotId then
        local currentIlvl = GearScore:GetCurrentItemLevel(unit, slotId, nil)
        if currentIlvl then ilvl = currentIlvl end
    end
    if bagID and slotId then
        local currentIlvl = GearScore:GetCurrentItemLevel(nil, slotId, bagID)
        if currentIlvl then ilvl = currentIlvl end
    end
    if ilvl then
        local r, g, b = GetQualityColor(quality or 1)
        frame._itemLevelText:SetText(ilvl)
        frame._itemLevelText:SetTextColor(r, g, b)
        frame._itemLevelText:Show()
    else
        frame._itemLevelText:SetText("")
        frame._itemLevelText:Hide()
    end
end

-- Durability Text

local function EnsureDurabilityText(frame)
    if not frame or frame._durabilityText then return end
    local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("BOTTOM", frame, "BOTTOM", 0, 3)
    fs:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    fs:SetText("")
    frame._durabilityText = fs
end

local function SetDurability(frame, current, max)
    EnsureDurabilityText(frame)
    if not frame._durabilityText then return end
    if not TacoTipConfig.show_durability or not current or not max or max <= 0 then
        frame._durabilityText:SetText("")
        frame._durabilityText:Hide()
        return
    end
    local percent = math.floor((current / max) * 100)
    if percent < 100 then
        if percent > 50 then
            frame._durabilityText:SetTextColor(0.1, 1.0, 0.1)
        elseif percent > 30 then
            frame._durabilityText:SetTextColor(1.0, 1.0, 0.1)
        else
            frame._durabilityText:SetTextColor(1.0, 0.1, 0.1)
        end
        frame._durabilityText:SetText(percent .. "%")
        frame._durabilityText:Show()
    else
        frame._durabilityText:SetText("")
        frame._durabilityText:Hide()
    end
end

-- ============================================================
-- Player Tooltip (OnTooltipSetUnit)
-- ============================================================

function TacoTip_GSCallback(guid)
    local _, ttUnit = GameTooltip:GetUnit()
    if (ttUnit and UnitGUID(ttUnit) == guid) then
        GameTooltip:SetUnit(ttUnit)
    end
end

GameTooltip:HookScript("OnTooltipSetUnit", function(self)
    local name, unit = self:GetUnit()
    if (not unit) then
        return
    end

    if (TacoTipDragButton and TacoTipDragButton:IsShown()) then
        if (not UnitIsUnit(unit, "player")) then
            TacoTipDragButton:ShowExample()
            return
        end
    end

    local guid = UnitGUID(unit)

    local wide_style = (TacoTipConfig.tip_style == 1 or ((TacoTipConfig.tip_style == 2 or TacoTipConfig.tip_style == 4) and IsModifierKeyDown()))
    local mini_style = (not wide_style and (TacoTipConfig.tip_style == 4 or TacoTipConfig.tip_style == 5))

    local text = {}
    local linesToAdd = {}

    local numLines = GameTooltip:NumLines()

    for i = 1, numLines do
        text[i] = _G["GameTooltipTextLeft" .. i]:GetText()
    end
    if (not text[1] or text[1] == "") then return end
    if (not text[2] or text[2] == "") then return end

    -- Target
    if (TacoTipConfig.show_target and UnitIsConnected(unit) and not UnitIsUnit(unit, "player")) then
        local unitTarget = unit .. "target"
        local targetName = UnitName(unitTarget)

        if (targetName) then
            if (UnitIsUnit(unitTarget, unit)) then
                if (wide_style) then
                    tinsert(linesToAdd,
                        { L["Target"] .. ":", L["Self"], NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b,
                            HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b })
                else
                    tinsert(linesToAdd, { L["Target"] .. ": |cFFFFFFFF" .. L["Self"] .. "|r" })
                end
            elseif (UnitIsUnit(unitTarget, "player")) then
                if (wide_style) then
                    tinsert(linesToAdd,
                        { L["Target"] .. ":", L["You"], NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1, 1, 0 })
                else
                    tinsert(linesToAdd, { L["Target"] .. ": |cFFFFFF00" .. L["You"] .. "|r" })
                end
            elseif (UnitIsPlayer(unitTarget)) then
                local classc
                if (TacoTipConfig.color_class) then
                    local _, targetClass = UnitClass(unitTarget)
                    if (targetClass) then
                        classc = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[targetClass]
                    end
                end
                if (classc) then
                    if (wide_style) then
                        tinsert(linesToAdd,
                            { L["Target"] .. ":", string.format("|cFF%02x%02x%02x%s|r (%s)", classc.r * 255, classc.g *
                                255, classc.b * 255, targetName, L["Player"]), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g,
                                NORMAL_FONT_COLOR.b, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR
                                .b })
                    else
                        tinsert(linesToAdd,
                            { string.format("%s: |cFF%02x%02x%02x%s|cFFFFFFFF (%s)|r", L["Target"], classc.r * 255,
                                classc.g * 255, classc.b * 255, targetName, L["Player"]) })
                    end
                else
                    if (wide_style) then
                        tinsert(linesToAdd,
                            { L["Target"] .. ":", targetName .. " (" .. L["Player"] .. ")", NORMAL_FONT_COLOR.r,
                                NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g,
                                HIGHLIGHT_FONT_COLOR.b })
                    else
                        tinsert(linesToAdd,
                            { L["Target"] .. ": |cFFFFFFFF" .. targetName .. " (" .. L["Player"] .. ")|r" })
                    end
                end
            elseif (UnitIsUnit(unitTarget, "pet") or UnitIsOtherPlayersPet(unitTarget)) then
                if (wide_style) then
                    tinsert(linesToAdd,
                        { L["Target"] .. ":", targetName .. " (" .. L["Pet"] .. ")", NORMAL_FONT_COLOR.r,
                            NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g,
                            HIGHLIGHT_FONT_COLOR.b })
                else
                    tinsert(linesToAdd, { L["Target"] .. ": |cFFFFFFFF" .. targetName .. " (" .. L["Pet"] .. ")|r" })
                end
            else
                if (wide_style) then
                    tinsert(linesToAdd,
                        { L["Target"] .. ":", targetName, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b,
                            HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b })
                else
                    tinsert(linesToAdd, { L["Target"] .. ": |cFFFFFFFF" .. targetName .. "|r" })
                end
            end
        else
            local inSameMap = true
            if (IsInGroup() and ((IsInRaid() and UnitInRaid(unit)) or UnitInParty(unit))) then
                if (C_Map.GetBestMapForUnit(unit) ~= C_Map.GetBestMapForUnit("player")) then
                    inSameMap = false
                end
            end
            if (inSameMap) then
                if (wide_style) then
                    tinsert(linesToAdd,
                        { L["Target"] .. ":", L["None"], NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b,
                            GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b })
                else
                    tinsert(linesToAdd, { L["Target"] .. ": |cFF808080" .. L["None"] .. "|r" })
                end
            end
        end
    end

    if (UnitIsPlayer(unit)) then
        local localizedClass, class = UnitClass(unit)

        if (not TacoTipConfig.show_titles and string.find(text[1], name)) then
            text[1] = name
        end
        if (TacoTipConfig.color_class) then
            if (localizedClass and class) then
                local classc = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
                if (classc) then
                    text[1] = string.format("|cFF%02x%02x%02x%s|r", classc.r * 255, classc.g * 255, classc.b * 255,
                        text[1])
                    for i = 2, 3 do
                        if (text[i]) then
                            text[i] = string.gsub(text[i], localizedClass,
                                string.format("|cFF%02x%02x%02x%s|r", classc.r * 255, classc.g * 255, classc.b * 255,
                                    localizedClass), 1)
                        end
                    end
                end
            end
        end
        local guildName, guildRankName = GetGuildInfo(unit);
        if (guildName and guildRankName) then
            if (TacoTipConfig.show_guild_name) then
                if (TacoTipConfig.show_guild_rank) then
                    if (TacoTipConfig.guild_rank_alt_style) then
                        text[2] = string.gsub(text[2], guildName,
                            string.format("|cFF40FB40<%s> (%s)|r", guildName, guildRankName), 1)
                    else
                        text[2] = string.gsub(text[2], guildName,
                            string.format("|cFF40FB40" .. L["FORMAT_GUILD_RANK_1"] .. "|r", guildRankName, guildName), 1)
                    end
                else
                    text[2] = string.gsub(text[2], guildName, string.format("|cFF40FB40<%s>|r", guildName), 1)
                end
            else
                text[2] = string.gsub(text[2], guildName, "", 1)
            end
        end
        if (TacoTipConfig.show_team) then
            text[1] = text[1] .. " " .. (UnitFactionGroup(unit) == "Horde" and HORDE_ICON or ALLIANCE_ICON)
        end

        if (not TacoTipConfig.hide_in_combat or not InCombatLockdown()) then
            if (TacoTipConfig.show_talents) then
                local x1, x2, x3, x4, x5, x6 = 0, 0, 0, 0, 0, 0
                local y1, y2, y3, y4, y5, y6 = 0, 0, 0, 0, 0, 0
                local spec1 = CI:GetSpecialization(guid, 1)
                if (spec1) then
                    if CI:IsMop() and spec1 == -1 then spec1 = 1 end
                    if not CI:IsMop() then
                        x1, x2, x3 = CI:GetTalentPoints(guid, 1)
                    else
                        x1, x2, x3, x4, x5, x6 = CI:GetTalentPoints(guid, 1)
                    end
                end
                local spec2 = CI:GetSpecialization(guid, 2)
                if (spec2) then
                    if CI:IsMop() and spec2 == -1 then spec2 = 1 end
                    if not CI:IsMop() then
                        y1, y2, y3 = CI:GetTalentPoints(guid, 2)
                    else
                        y1, y2, y3, y4, y5, y6 = CI:GetTalentPoints(guid, 2)
                    end
                end

                local specName1 = spec1 and CI:GetSpecializationName(class, spec1, true) or ""
                local specName2 = spec2 and CI:GetSpecializationName(class, spec2, true) or ""
                if (specName1 == nil or specName1 == "") then specName1 = localizedClass or "" end
                if (specName2 == nil or specName2 == "") then specName2 = localizedClass or "" end

                if (not UnitIsUnit(unit, "player")) then
                    specName1 = ""
                    specName2 = ""
                end

                local active = CI:GetActiveTalentGroup(guid)
                if (not active or active == 0) then
                    if (spec1) then active = 1
                    elseif (spec2) then active = 2 end
                end

                if (active == 2) then
                    if (spec2) then
                        if (wide_style) then
                            local talents = string.format("%s [%d/%d/%d]", specName2, y1, y2, y3)
                            if CI:IsMop() then
                                talents = string.format("%s [%d/%d/%d/%d/%d/%d]", specName2, y1, y2, y3, y4, y5, y6)
                            end
                            tinsert(linesToAdd,
                                { L["Talents"] .. ":", talents, NORMAL_FONT_COLOR.r,
                                    NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, HIGHLIGHT_FONT_COLOR.r,
                                    HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b })
                        else
                            local talents = string.format("%s:|cFFFFFFFF %s [%d/%d/%d]|r", L["Talents"],
                                specName2, y1, y2, y3)
                            if CI:IsMop() then
                                talents = string.format("%s:|cFFFFFFFF %s [%d/%d/%d/%d/%d/%d]|r", L["Talents"],
                                    specName2, y1, y2, y3, y4, y5, y6)
                            end
                            tinsert(linesToAdd, { talents })
                        end
                    end
                    if (spec1) then
                        if (wide_style) then
                            local talents = string.format("%s [%d/%d/%d]", specName1, x1, x2, x3)
                            if CI:IsMop() then
                                talents = string.format("%s [%d/%d/%d/%d/%d/%d]", specName1, x1, x2, x3, x4, x5, x6)
                            end
                            tinsert(linesToAdd,
                                { (spec2 and " " or L["Talents"] .. ":"), talents, NORMAL_FONT_COLOR.r,
                                    NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g,
                                    GRAY_FONT_COLOR.b })
                        else
                            local talents
                            if (spec2) then
                                talents = string.format("|cFF808080%s [%d/%d/%d]|r", specName1, x1, x2, x3)
                                if CI:IsMop() then
                                    talents = string.format("|cFF808080%s [%d/%d/%d/%d/%d/%d]|r",
                                        specName1, x1, x2, x3, x4, x5, x6)
                                end
                            else
                                talents = string.format("%s:|cFF808080 %s [%d/%d/%d]|r", L["Talents"],
                                    specName1, x1, x2, x3)
                                if CI:IsMop() then
                                    talents = string.format("%s:|cFF808080 %s [%d/%d/%d/%d/%d/%d]|r", L["Talents"],
                                        specName1, x1, x2, x3, x4, x5, x6)
                                end
                            end
                            tinsert(linesToAdd, { talents })
                        end
                    end
                elseif (active == 1) then
                    if (spec1) then
                        if (wide_style) then
                            local talents = string.format("%s [%d/%d/%d]", specName1, x1, x2, x3)
                            if CI:IsMop() then
                                talents = string.format("%s [%d/%d/%d/%d/%d/%d]", specName1, x1, x2, x3, x4, x5, x6)
                            end
                            tinsert(linesToAdd,
                                { L["Talents"] .. ":", talents, NORMAL_FONT_COLOR.r,
                                    NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, HIGHLIGHT_FONT_COLOR.r,
                                    HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b })
                        else
                            local talents = string.format("%s:|cFFFFFFFF %s [%d/%d/%d]|r", L["Talents"],
                                specName1, x1, x2, x3)
                            if CI:IsMop() then
                                talents = string.format("%s:|cFFFFFFFF %s [%d/%d/%d/%d/%d/%d]|r", L["Talents"],
                                    specName1, x1, x2, x3, x4, x5, x6)
                            end
                            tinsert(linesToAdd, { talents })
                        end
                    end
                    if (spec2) then
                        if (wide_style) then
                            local talents = string.format("%s [%d/%d/%d]", specName2, y1, y2, y3)
                            if CI:IsMop() then
                                talents = string.format("%s [%d/%d/%d/%d/%d/%d]", specName2, y1, y2, y3, y4, y5, y6)
                            end
                            tinsert(linesToAdd,
                                { (spec1 and " " or L["Talents"] .. ":"), talents, NORMAL_FONT_COLOR.r,
                                    NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g,
                                    GRAY_FONT_COLOR.b })
                        else
                            local talents
                            if (spec1) then
                                talents = string.format("|cFF808080%s [%d/%d/%d]|r", specName2, y1, y2, y3)
                                if CI:IsMop() then
                                    talents = string.format("|cFF808080%s [%d/%d/%d/%d/%d/%d]|r",
                                        specName2, y1, y2, y3, y4, y5, y6)
                                end
                            else
                                talents = string.format("%s:|cFF808080 %s [%d/%d/%d]|r", L["Talents"],
                                    specName2, y1, y2, y3)
                                if CI:IsMop() then
                                    talents = string.format("%s:|cFF808080 %s [%d/%d/%d/%d/%d/%d]|r", L["Talents"],
                                        specName2, y1, y2, y3, y4, y5, y6)
                                end
                            end
                            tinsert(linesToAdd, { talents })
                        end
                    end
                end
            end
            local miniText = ""
            if (TacoTipConfig.show_gs_player) then
                local gearscore, avg_ilvl = GearScore:GetScore(guid, true, unit)
                local avg_ilevel_dec = string.format(FORMAT_ILVL, avg_ilvl)
                if (gearscore > 0) then
                    local r, g, b, quality = GearScore:GetQuality(gearscore)
                    if (wide_style) then
                        if TacoTipConfig.gearscore_ilevel_style then
                            if (r == b and r == g) then
                                tinsert(linesToAdd,
                                    { "|cFFFFFFFFGearScore:|r " .. gearscore, "|cFFFFFFFF(iLvl:|r " ..
                                    avg_ilevel_dec .. "|cFFFFFFFF)|r", r, g, b, r, g, b })
                            else
                                tinsert(linesToAdd,
                                    { "GearScore: " .. gearscore, "(iLvl: " .. avg_ilevel_dec .. ")", r, g, b, r, g, b })
                            end
                        elseif TacoTipConfig.gearscore_style then
                            if (r == b and r == g) then
                                tinsert(linesToAdd,
                                    { "|cFFFFFFFFGearScore:|r " .. gearscore .. "|cFFFFFFFF|r", "", r, g, b, r, g, b })
                            else
                                tinsert(linesToAdd, { "GearScore: " .. gearscore, "", r, g, b, r, g, b })
                            end
                        elseif TacoTipConfig.ilevel_style then
                            if (r == b and r == g) then
                                tinsert(linesToAdd,
                                    { "|cFFFFFFFFiLvl:|r " .. avg_ilevel_dec .. "|cFFFFFFFF|r", "", r, g, b, r, g, b })
                            else
                                tinsert(linesToAdd, { "iLvl: " .. avg_ilevel_dec, "", r, g, b, r, g, b })
                            end
                        end
                    elseif (mini_style) then
                        if TacoTipConfig.gearscore_ilevel_style then
                            if (r == b and r == g) then
                                tinsert(linesToAdd,
                                    { "|cFFFFFFFFGS:|r " ..
                                    gearscore .. " |cFFFFFFFFL:|r " .. avg_ilevel_dec .. "|cFFFFFFFF|r", r, g, b })
                            else
                                tinsert(linesToAdd, { "GS: " .. gearscore .. " L: " .. avg_ilevel_dec, r, g, b })
                            end
                        elseif TacoTipConfig.gearscore_style then
                            if (r == b and r == g) then
                                tinsert(linesToAdd, { "|cFFFFFFFFGS:|r " .. gearscore .. "|cFFFFFFFF|r", r, g, b })
                            else
                                tinsert(linesToAdd, { "GS: " .. gearscore, r, g, b })
                            end
                        elseif TacoTipConfig.ilevel_style then
                            if (r == b and r == g) then
                                tinsert(linesToAdd, { "|cFFFFFFFFL:|r " .. avg_ilevel_dec .. "|cFFFFFFFF|r", r, g, b })
                            else
                                tinsert(linesToAdd, { "L: " .. avg_ilevel_dec, r, g, b })
                            end
                        end
                    else
                        if TacoTipConfig.gearscore_ilevel_style then
                            if (r == b and r == g) then
                                tinsert(linesToAdd,
                                    { "|cFFFFFFFFGearScore:|r " .. gearscore .. " (iLvl:|r " .. avg_ilevel_dec .. ")", r,
                                        g, b })
                            else
                                tinsert(linesToAdd, { "GearScore: " .. gearscore .. " (iLvl: " .. avg_ilevel_dec .. ")",
                                    r, g, b })
                            end
                        elseif TacoTipConfig.gearscore_style then
                            if (r == b and r == g) then
                                tinsert(linesToAdd, { "|cFFFFFFFFGearScore:|r " .. gearscore, r, g, b })
                            else
                                tinsert(linesToAdd, { "GearScore: " .. gearscore, r, g, b })
                            end
                        elseif TacoTipConfig.ilevel_style then
                            if (r == b and r == g) then
                                tinsert(linesToAdd, { "|cFFFFFFFFiLvl:|r " .. avg_ilevel_dec, r, g, b })
                            else
                                tinsert(linesToAdd, { "iLvl: " .. avg_ilevel_dec, r, g, b })
                            end
                        end
                    end
                end
            end
            if (isPawnLoaded and TacoTipConfig.show_pawn_player) then
                local pawnScore, specName, specColor = TT_PAWN:GetScore(guid, not TacoTipConfig.show_gs_player)
                if (not UnitIsUnit(unit, "player")) then specName = "" end
                if (pawnScore > 0) then
                    if (wide_style) then
                        local rightText = specName ~= "" and string.format("%s(%s)|r", specColor, specName) or ""
                        tinsert(linesToAdd,
                            { string.format("Pawn: %s%.2f|r", specColor, pawnScore), rightText, 1, 1, 1, 1, 1, 1 })
                    elseif (mini_style) then
                        miniText = miniText .. string.format("P: %s%.1f|r", specColor, pawnScore)
                    else
                        if (specName ~= "") then
                            tinsert(linesToAdd,
                                { string.format("Pawn: %s%.2f (%s)|r", specColor, pawnScore, specName), 1, 1, 1 })
                        else
                            tinsert(linesToAdd,
                                { string.format("Pawn: %s%.2f|r", specColor, pawnScore), 1, 1, 1 })
                        end
                    end
                end
            end
            if (miniText ~= "") then
                tinsert(linesToAdd, { miniText, 1, 1, 1 })
            end
            if ((CI:IsWotlk() or CI:IsCata() or CI:IsMop()) and TacoTipConfig.show_achievement_points) then
                local achi_pts = CI:GetTotalAchievementPoints(guid)
                if (achi_pts) then
                    if (wide_style) then
                        tinsert(linesToAdd, { ACHIEVEMENT_ICON .. " " .. achi_pts, " ", 1, 1, 1, 1, 1, 1 })
                    else
                        tinsert(linesToAdd, { ACHIEVEMENT_ICON .. " " .. achi_pts, 1, 1, 1 })
                    end
                end
            end
        end
    end

    if (TacoTipConfig.show_pvp_icon and UnitIsPVP(unit)) then
        text[1] = text[1] .. " " .. PVP_FLAG_ICON
        for i = 2, numLines do
            if (text[i]) then
                text[i] = string.gsub(text[i], "PvP", "", 1)
            end
        end
    end

    local n = 0
    for i = 1, numLines do
        if (text[i] and text[i] ~= "") then
            n = n + 1
            _G["GameTooltipTextLeft" .. n]:SetText(text[i])
        end
    end
    if (wide_style) then
        local anchor = "GameTooltipTextLeft" .. n
        while (n < numLines) do
            n = n + 1
            _G["GameTooltipTextLeft" .. n]:SetText()
            _G["GameTooltipTextRight" .. n]:SetText()
            _G["GameTooltipTextLeft" .. n]:Hide()
            _G["GameTooltipTextRight" .. n]:Hide()
        end
        for _, v in ipairs(linesToAdd) do
            self:AddDoubleLine(unpack(v))
        end
        if (_G["GameTooltipTextLeft" .. (n + 1)]) then
            _G["GameTooltipTextLeft" .. (n + 1)]:SetPoint("TOP", _G[anchor], "BOTTOM", 0, -2)
        end
    else
        for _, v in ipairs(linesToAdd) do
            if (n < numLines) then
                n = n + 1
                local txt, r, g, b = unpack(v)
                _G["GameTooltipTextLeft" .. n]:SetTextColor(r or NORMAL_FONT_COLOR.r, g or NORMAL_FONT_COLOR.g,
                    b or NORMAL_FONT_COLOR.b)
                _G["GameTooltipTextLeft" .. n]:SetText(txt)
            else
                self:AddLine(unpack(v))
            end
        end
        while (n < numLines) do
            n = n + 1
            _G["GameTooltipTextLeft" .. n]:SetText()
            _G["GameTooltipTextRight" .. n]:SetText()
            _G["GameTooltipTextLeft" .. n]:Hide()
            _G["GameTooltipTextRight" .. n]:Hide()
        end
    end

    if (not TacoTipConfig.show_hp_bar and GameTooltipStatusBar and GameTooltipStatusBar:IsShown()) then
        GameTooltipStatusBar:Hide()
    end

    if (TacoTipConfig.show_power_bar) then
        if (not TacoTipPowerBar) then
            TacoTipPowerBar = CreateFrame("StatusBar", "TacoTipPowerBar", GameTooltip)
            TacoTipPowerBar:SetSize(0, 8)
            TacoTipPowerBar:SetPoint("TOPLEFT", GameTooltip, "BOTTOMLEFT", 2, -9)
            TacoTipPowerBar:SetPoint("TOPRIGHT", GameTooltip, "BOTTOMRIGHT", -2, -9)
            TacoTipPowerBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
            TacoTipPowerBar:SetStatusBarColor(0, 0, 1)
            function TacoTipPowerBar:Update(u)
                if (TacoTipConfig.show_power_bar) then
                    local unit = u or select(2, GameTooltip:GetUnit())
                    if (unit) then
                        local _, power = UnitPowerType(unit)
                        local color = power and PowerBarColor[power] or {}
                        self:SetStatusBarColor(color.r or 0, color.g or 0, color.b or 1);
                        self:SetMinMaxValues(0, UnitPowerMax(unit))
                        self:SetValue(UnitPower(unit))
                    end
                end
            end

            TacoTipPowerBar:SetScript("OnEvent", function(self, event, unit)
                local _, ttUnit = GameTooltip:GetUnit()
                if (unit and ttUnit and UnitIsUnit(unit, ttUnit)) then
                    self:Update(unit)
                end
            end)
            TacoTipPowerBar:RegisterEvent("UNIT_POWER_UPDATE")
            TacoTipPowerBar:RegisterEvent("UNIT_MAXPOWER")
            TacoTipPowerBar:RegisterEvent("UNIT_DISPLAYPOWER")
            TacoTipPowerBar:RegisterEvent("UNIT_POWER_BAR_SHOW")
            TacoTipPowerBar:RegisterEvent("UNIT_POWER_BAR_HIDE")
            TacoTipPowerBar.updateTicker = NewTicker(POWERBAR_UPDATE_RATE, function()
                TacoTipPowerBar:Update()
            end)
        end
        if (UnitPowerMax(unit) > 0) then
            if (TacoTipConfig.show_hp_bar) then
                TacoTipPowerBar:SetPoint("TOPLEFT", GameTooltip, "BOTTOMLEFT", 2, -9)
                TacoTipPowerBar:SetPoint("TOPRIGHT", GameTooltip, "BOTTOMRIGHT", -2, -9)
            else
                TacoTipPowerBar:SetPoint("TOPLEFT", GameTooltip, "BOTTOMLEFT", 2, -1)
                TacoTipPowerBar:SetPoint("TOPRIGHT", GameTooltip, "BOTTOMRIGHT", -2, -1)
            end
            TacoTipPowerBar:Update()
            TacoTipPowerBar:Show()
        else
            TacoTipPowerBar:Hide()
        end
    elseif (TacoTipPowerBar) then
        TacoTipPowerBar:Hide()
    end
end)

-- ============================================================
-- GearScore on Item Tooltips
-- ============================================================

local function itemToolTipHook(self)
    local _, itemLink = self:GetItem()
    if not itemLink or not IsEquippableItem(itemLink) then return end
    if TacoTipConfig.hide_in_combat and InCombatLockdown() then return end

    local wide_style = (TacoTipConfig.tip_style == 1 or ((TacoTipConfig.tip_style == 2 or TacoTipConfig.tip_style == 4) and IsModifierKeyDown()))
    local mini_style = (not wide_style and (TacoTipConfig.tip_style == 4 or TacoTipConfig.tip_style == 5))

    local ilvlAfterUpgrades = GearScore:ScanTooltipForItemLevel(self)

    local ilvl
    if TacoTipConfig.show_item_level then
        ilvl = ilvlAfterUpgrades or select(4, GetItemInfo(itemLink))
        if ilvl and ilvl <= 1 then ilvl = nil end
    end

    local gs, gs_r, gs_g, gs_b
    if TacoTipConfig.show_gs_items then
        local score, _, r, g, b = GearScore:GetItemScore(itemLink, ilvlAfterUpgrades)
        if score and score > 1 then
            gs, gs_r, gs_g, gs_b = score, r, g, b
        end
    end

    if gs and ilvl then
        if wide_style then
            self:AddDoubleLine("GearScore: " .. gs, "(iLvl: " .. ilvl .. ")", gs_r, gs_g, gs_b, gs_r, gs_g, gs_b)
        elseif mini_style then
            self:AddLine("GS: " .. gs .. " L: " .. ilvl, gs_r, gs_g, gs_b)
        else
            self:AddLine("GearScore: " .. gs .. " (iLvl: " .. ilvl .. ")", gs_r, gs_g, gs_b)
        end
    elseif gs then
        if wide_style then
            self:AddDoubleLine("GearScore:", gs, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, gs_r, gs_g, gs_b)
        elseif mini_style then
            self:AddLine("GS: " .. gs, gs_r, gs_g, gs_b)
        else
            self:AddLine("GearScore: " .. gs, gs_r, gs_g, gs_b)
        end
    elseif ilvl then
        if wide_style then
            self:AddDoubleLine(L["Item Level"] .. ":", ilvl, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
        elseif mini_style then
            self:AddLine("L: " .. ilvl, 1, 1, 1)
        else
            self:AddLine(L["Item Level"] .. " " .. ilvl, 1, 1, 1)
        end
    end

    if gs then
        if TacoTipConfig.show_gs_items_hs or IsModifierKeyDown() or playerClass == "HUNTER" or
                (InspectFrame and InspectFrame:IsShown() and InspectFrame.unit and select(2, UnitClass(InspectFrame.unit)) == "HUNTER") then
            local hs, _, hr, hg, hb = GearScore:GetItemHunterScore(itemLink)
            if gs ~= hs and not CI:IsMop() then
                if wide_style then
                    self:AddDoubleLine("HunterScore:", hs, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, hr, hg, hb)
                elseif mini_style then
                    self:AddLine("HS: " .. hs, hr, hg, hb)
                else
                    self:AddLine("HunterScore: " .. hs, hr, hg, hb)
                end
            end
        end
    end

    if (isPawnLoaded and TacoTipConfig.show_pawn_player) then
        local _, pClass = UnitClass("player")
        local pSpec = CI:GetSpecialization(UnitGUID("player"))
        if (pSpec and pClass) then
            if CI:IsMop() and pSpec == -1 then
                pSpec = 1
            end
            local scaleName = "\"Classic\":" .. pClass .. pSpec
            local pawnScore = TT_PAWN:GetItemScore(itemLink, pClass, pSpec)
            if (pawnScore > 0) then
                local ok, specColor = pcall(PawnGetScaleColor, scaleName, true)
                specColor = (ok and specColor) or "|cffffffff"
                local specName = CI:GetSpecializationName(pClass, pSpec, true)
                if (wide_style) then
                    self:AddDoubleLine(string.format("Pawn: %s%.2f|r", specColor, pawnScore),
                        string.format("%s(%s)|r", specColor, specName), 1, 1, 1, 1, 1, 1)
                elseif (mini_style) then
                    self:AddLine(string.format("P: %s%.1f|r", specColor, pawnScore), 1, 1, 1)
                else
                    self:AddLine(string.format("Pawn: %s%.2f (%s)|r", specColor, pawnScore, specName), 1, 1, 1)
                end
            end
        end
    end
end

GameTooltip:HookScript("OnTooltipSetItem", itemToolTipHook)
ShoppingTooltip1:HookScript("OnTooltipSetItem", itemToolTipHook)
ShoppingTooltip2:HookScript("OnTooltipSetItem", itemToolTipHook)
ItemRefTooltip:HookScript("OnTooltipSetItem", itemToolTipHook)

-- Update functions

local function UpdateEquipSlots(unit, framePrefix)
    for _, slotName in ipairs(EQUIP_SLOT_NAMES) do
        local frame = _G[framePrefix .. slotName]
        if frame then
            local slotId = EQUIP_SLOT_IDS[slotName]
            local itemLink = GetInventoryItemLink(unit, slotId)
            local quality = itemLink and select(3, GetItemInfo(itemLink))
            SetQualityBorder(frame, itemLink, quality)
            SetItemLevel(frame, itemLink, quality, unit, slotId, nil)
            if unit == "player" then
                local current, max = GetInventoryItemDurability(slotId)
                SetDurability(frame, current, max)
            else
                SetDurability(frame, nil, nil)
            end
        end
    end
end

local function UpdateBagSlots()
    for i = 1, NUM_CONTAINER_FRAMES do
        local container = _G["ContainerFrame" .. i]
        if container then
            local bagID = container:GetID()
            if IsBagOpen(bagID) then
                local numSlots = C_Container.GetContainerNumSlots(bagID)
                for slot = 1, numSlots do
                    local frame = _G["ContainerFrame" .. i .. "Item" .. (numSlots - slot + 1)]
                    if frame then
                        local itemLink = C_Container.GetContainerItemLink(bagID, slot)
                        if IsOverlayableItem(itemLink) then
                            local quality = select(3, GetItemInfo(itemLink))
                            SetQualityBorder(frame, itemLink, quality)
                            SetItemLevel(frame, itemLink, quality, nil, slot, bagID)
                            local current, max = C_Container.GetContainerItemDurability(bagID, slot)
                            SetDurability(frame, current, max)
                        else
                            SetQualityBorder(frame, nil, nil)
                            SetItemLevel(frame, nil, nil, nil, nil, nil)
                            SetDurability(frame, nil, nil)
                        end
                    end
                end
            end
        end
    end
end

local function UpdateBankSlots()
    for i = 1, NUM_BANKGENERIC_SLOTS do
        local frame = _G["BankFrameItem" .. i]
        if frame then
            local itemLink = C_Container.GetContainerItemLink(-1, i)
            if IsOverlayableItem(itemLink) then
                local quality = select(3, GetItemInfo(itemLink))
                SetQualityBorder(frame, itemLink, quality)
                SetItemLevel(frame, itemLink, quality, nil, i, -1)
                local current, max = C_Container.GetContainerItemDurability(-1, i)
                SetDurability(frame, current, max)
            else
                SetQualityBorder(frame, nil, nil)
                SetItemLevel(frame, nil, nil, nil, nil, nil)
                SetDurability(frame, nil, nil)
            end
        end
    end
end

-- ============================================================
-- GearScore & Average iLvl on Character / Inspect Frames
-- ============================================================

local function InitCharacterGS()
    CharacterModelScene:CreateFontString("PersonalGearScore")
    PersonalGearScore:SetFont(L["CHARACTER_FRAME_GS_VALUE_FONT"], L["CHARACTER_FRAME_GS_VALUE_FONT_SIZE"])
    PersonalGearScore:SetText("0")
    PersonalGearScore.RefreshPosition = function()
        PersonalGearScore:ClearAllPoints()
        PersonalGearScore:SetPoint("BOTTOMLEFT", PaperDollFrame, "BOTTOMLEFT",
            L["CHARACTER_FRAME_GS_VALUE_XPOS"] + (TacoTipConfig.character_gs_offset_x or 0),
            L["CHARACTER_FRAME_GS_VALUE_YPOS"] + (TacoTipConfig.character_gs_offset_y or 0))
    end
    PersonalGearScore:RefreshPosition()

    CharacterModelScene:CreateFontString("PersonalGearScoreText")
    PersonalGearScoreText:SetFont(L["CHARACTER_FRAME_GS_TITLE_FONT"], L["CHARACTER_FRAME_GS_TITLE_FONT_SIZE"])
    PersonalGearScoreText:SetText("GearScore")
    PersonalGearScoreText.RefreshPosition = function()
        PersonalGearScoreText:ClearAllPoints()
        PersonalGearScoreText:SetPoint("BOTTOMLEFT", PaperDollFrame, "BOTTOMLEFT",
            L["CHARACTER_FRAME_GS_TITLE_XPOS"] + (TacoTipConfig.character_gs_offset_x or 0),
            L["CHARACTER_FRAME_GS_TITLE_YPOS"] + (TacoTipConfig.character_gs_offset_y or 0))
    end
    PersonalGearScoreText:RefreshPosition()

    CharacterModelScene:CreateFontString("PersonalAvgItemLvl")
    PersonalAvgItemLvl:SetFont(L["CHARACTER_FRAME_ILVL_VALUE_FONT"], L["CHARACTER_FRAME_ILVL_VALUE_FONT_SIZE"])
    PersonalAvgItemLvl:SetText("0")
    PersonalAvgItemLvl.RefreshPosition = function()
        PersonalAvgItemLvl:ClearAllPoints()
        PersonalAvgItemLvl:SetPoint("BOTTOMRIGHT", PaperDollFrame, "BOTTOMLEFT",
            L["CHARACTER_FRAME_ILVL_VALUE_XPOS"] + (TacoTipConfig.character_ilvl_offset_x or 0),
            L["CHARACTER_FRAME_ILVL_VALUE_YPOS"] + (TacoTipConfig.character_ilvl_offset_y or 0))
    end
    PersonalAvgItemLvl:RefreshPosition()

    CharacterModelScene:CreateFontString("PersonalAvgItemLvlText")
    PersonalAvgItemLvlText:SetFont(L["CHARACTER_FRAME_ILVL_TITLE_FONT"], L["CHARACTER_FRAME_ILVL_TITLE_FONT_SIZE"])
    PersonalAvgItemLvlText:SetText("iLvl")
    PersonalAvgItemLvlText.RefreshPosition = function()
        PersonalAvgItemLvlText:ClearAllPoints()
        PersonalAvgItemLvlText:SetPoint("BOTTOMRIGHT", PaperDollFrame, "BOTTOMLEFT",
            L["CHARACTER_FRAME_ILVL_TITLE_XPOS"] + (TacoTipConfig.character_ilvl_offset_x or 0),
            L["CHARACTER_FRAME_ILVL_TITLE_YPOS"] + (TacoTipConfig.character_ilvl_offset_y or 0))
    end
    PersonalAvgItemLvlText:RefreshPosition()
end

local function InitInspectGS()
    InspectModelFrame:CreateFontString("InspectGearScore")
    InspectGearScore:SetFont(L["INSPECT_FRAME_GS_VALUE_FONT"], L["INSPECT_FRAME_GS_VALUE_FONT_SIZE"])
    InspectGearScore:SetText("0")
    InspectGearScore.RefreshPosition = function()
        InspectGearScore:ClearAllPoints()
        InspectGearScore:SetPoint("BOTTOMLEFT", InspectPaperDollFrame, "BOTTOMLEFT",
            L["INSPECT_FRAME_GS_VALUE_XPOS"] + (TacoTipConfig.inspect_gs_offset_x or 0),
            L["INSPECT_FRAME_GS_VALUE_YPOS"] + (TacoTipConfig.inspect_gs_offset_y or 0))
    end
    InspectGearScore:RefreshPosition()

    InspectModelFrame:CreateFontString("InspectGearScoreText")
    InspectGearScoreText:SetFont(L["INSPECT_FRAME_GS_TITLE_FONT"], L["INSPECT_FRAME_GS_TITLE_FONT_SIZE"])
    InspectGearScoreText:SetText("GearScore")
    InspectGearScoreText.RefreshPosition = function()
        InspectGearScoreText:ClearAllPoints()
        InspectGearScoreText:SetPoint("BOTTOMLEFT", InspectPaperDollFrame, "BOTTOMLEFT",
            L["INSPECT_FRAME_GS_TITLE_XPOS"] + (TacoTipConfig.inspect_gs_offset_x or 0),
            L["INSPECT_FRAME_GS_TITLE_YPOS"] + (TacoTipConfig.inspect_gs_offset_y or 0))
    end
    InspectGearScoreText:RefreshPosition()

    InspectModelFrame:CreateFontString("InspectAvgItemLvl")
    InspectAvgItemLvl:SetFont(L["INSPECT_FRAME_ILVL_VALUE_FONT"], L["INSPECT_FRAME_ILVL_VALUE_FONT_SIZE"])
    InspectAvgItemLvl:SetText("0")
    InspectAvgItemLvl.RefreshPosition = function()
        InspectAvgItemLvl:ClearAllPoints()
        InspectAvgItemLvl:SetPoint("BOTTOMRIGHT", InspectPaperDollFrame, "BOTTOMLEFT",
            L["INSPECT_FRAME_ILVL_VALUE_XPOS"] + (TacoTipConfig.inspect_ilvl_offset_x or 0),
            L["INSPECT_FRAME_ILVL_VALUE_YPOS"] + (TacoTipConfig.inspect_ilvl_offset_y or 0))
    end
    InspectAvgItemLvl:RefreshPosition()

    InspectModelFrame:CreateFontString("InspectAvgItemLvlText")
    InspectAvgItemLvlText:SetFont(L["INSPECT_FRAME_ILVL_TITLE_FONT"], L["INSPECT_FRAME_ILVL_TITLE_FONT_SIZE"])
    InspectAvgItemLvlText:SetText("iLvl")
    InspectAvgItemLvlText.RefreshPosition = function()
        InspectAvgItemLvlText:ClearAllPoints()
        InspectAvgItemLvlText:SetPoint("BOTTOMRIGHT", InspectPaperDollFrame, "BOTTOMLEFT",
            L["INSPECT_FRAME_ILVL_TITLE_XPOS"] + (TacoTipConfig.inspect_ilvl_offset_x or 0),
            L["INSPECT_FRAME_ILVL_TITLE_YPOS"] + (TacoTipConfig.inspect_ilvl_offset_y or 0))
    end
    InspectAvgItemLvlText:RefreshPosition()

    InspectFrame:HookScript("OnHide", function()
        InspectGearScore:Hide()
        InspectGearScoreText:Hide()
        InspectAvgItemLvl:Hide()
        InspectAvgItemLvlText:Hide()
    end)
end

function TT:RefreshCharacterFrame()
    if not PersonalGearScore then
        if not CharacterModelScene or not PaperDollFrame then return end
        InitCharacterGS()
    end
    local gs, avgIlvl, r, g, b = 0, 0, 0, 0, 0
    if (TacoTipConfig.show_gs_character or TacoTipConfig.show_avg_ilvl) and (not TacoTipConfig.hide_in_combat or not InCombatLockdown()) then
        gs, avgIlvl = GearScore:GetScore("player")
        r, g, b = GearScore:GetQuality(gs)
    end
    if TacoTipConfig.show_gs_character and (not TacoTipConfig.hide_in_combat or not InCombatLockdown()) then
        PersonalGearScore:SetText(gs)
        PersonalGearScore:SetTextColor(r, g, b, 1)
        PersonalGearScore:Show()
        PersonalGearScoreText:Show()
    else
        PersonalGearScore:Hide()
        PersonalGearScoreText:Hide()
    end
    if TacoTipConfig.show_avg_ilvl and (not TacoTipConfig.hide_in_combat or not InCombatLockdown()) then
        PersonalAvgItemLvl:SetText(string.format(FORMAT_ILVL, avgIlvl))
        PersonalAvgItemLvl:SetTextColor(r, g, b, 1)
        PersonalAvgItemLvl:Show()
        PersonalAvgItemLvlText:Show()
    else
        PersonalAvgItemLvl:Hide()
        PersonalAvgItemLvlText:Hide()
    end
    UpdateEquipSlots("player", "Character")
end

function TT:RefreshInspectFrame()
    if TacoTipConfig.hide_in_combat and InCombatLockdown() then return end
    if not InspectGearScore then
        if not InspectModelFrame or not InspectPaperDollFrame then return end
        InitInspectGS()
    end
    local gs, avgIlvl, r, g, b = 0, 0, 0, 0, 0
    if (TacoTipConfig.show_gs_character or TacoTipConfig.show_avg_ilvl) and InspectFrame and InspectFrame.unit then
        gs, avgIlvl = GearScore:GetScore(InspectFrame.unit, false, InspectFrame.unit)
        r, g, b = GearScore:GetQuality(gs)
    end
    if TacoTipConfig.show_gs_character and InspectFrame and InspectFrame.unit then
        InspectGearScore:SetText(gs)
        InspectGearScore:SetTextColor(r, g, b, 1)
        InspectGearScore:Show()
        InspectGearScoreText:Show()
    else
        InspectGearScore:Hide()
        InspectGearScoreText:Hide()
    end
    if TacoTipConfig.show_avg_ilvl and InspectFrame and InspectFrame.unit then
        InspectAvgItemLvl:SetText(string.format(FORMAT_ILVL, avgIlvl))
        InspectAvgItemLvl:SetTextColor(r, g, b, 1)
        InspectAvgItemLvl:Show()
        InspectAvgItemLvlText:Show()
    else
        InspectAvgItemLvl:Hide()
        InspectAvgItemLvlText:Hide()
    end
    if InspectFrame and InspectFrame.unit then
        UpdateEquipSlots(InspectFrame.unit, "Inspect")
    end
end

-- Hooks

local bagButtonsHooked = false
local function HookBagButtons()
    if bagButtonsHooked then return end
    bagButtonsHooked = true
    for i = 1, NUM_CONTAINER_FRAMES do
        local cf = _G["ContainerFrame" .. i]
        if cf then
            cf:HookScript("OnShow", function()
                CAfter(0, UpdateBagSlots)
            end)
        end
    end
end

local bankButtonsHooked = false
local function HookBankButtons()
    if bankButtonsHooked then return end
    if not BankSlotsFrame then return end
    bankButtonsHooked = true
    for i = 1, NUM_BANKBAGSLOTS do
        local bagSlot = BankSlotsFrame["Bag" .. i]
        if bagSlot then
            bagSlot:HookScript("OnClick", function()
                CAfter(0, UpdateBagSlots)
            end)
        end
    end
end

local characterHooked = false
local function HookCharacterFrame()
    if characterHooked or not PaperDollFrame then return end
    characterHooked = true
    PaperDollFrame:HookScript("OnShow", function()
        TT:RefreshCharacterFrame()
    end)
end

local inspectHooked = false
local function HookInspectFrame()
    if inspectHooked or not InspectPaperDollFrame then return end
    inspectHooked = true
    InspectPaperDollFrame:HookScript("OnShow", function()
        TT:RefreshInspectFrame()
    end)
end

-- Event frame

local qcFrame = CreateFrame("Frame")
TT.frame = qcFrame

local function RefreshTooltipUnit()
    local _, ttUnit = GameTooltip:GetUnit()
    if (ttUnit) then
        GameTooltip:SetUnit(ttUnit)
    end
end

qcFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        HookBagButtons()
        HookCharacterFrame()
        UpdateBagSlots()
    elseif event == "BAG_OPEN" or event == "BAG_UPDATE" then
        UpdateBagSlots()
    elseif event == "BANKFRAME_OPENED" or event == "PLAYERBANKSLOTS_CHANGED" then
        HookBankButtons()
        UpdateBankSlots()
        UpdateBagSlots()
    elseif event == "UNIT_INVENTORY_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
        if PaperDollFrame and PaperDollFrame:IsShown() then
            TT:RefreshCharacterFrame()
        end
        UpdateBagSlots()
    elseif event == "UPDATE_INVENTORY_DURABILITY" then
        if PaperDollFrame and PaperDollFrame:IsShown() then
            TT:RefreshCharacterFrame()
        end
        UpdateBagSlots()
    elseif event == "UNIT_TARGET" then
        RefreshTooltipUnit()
    elseif event == "MODIFIER_STATE_CHANGED" then
        RefreshTooltipUnit()
    end
end)

qcFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
qcFrame:RegisterEvent("BAG_OPEN")
qcFrame:RegisterEvent("BAG_UPDATE")
qcFrame:RegisterEvent("BANKFRAME_OPENED")
qcFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
qcFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
qcFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
qcFrame:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
qcFrame:RegisterEvent("UNIT_TARGET")
qcFrame:RegisterEvent("MODIFIER_STATE_CHANGED")

CI.RegisterCallback(addOnName .. "_QualityColors", "INVENTORY_READY", function(_, guid)
    HookInspectFrame()
    if InspectFrame and InspectFrame:IsShown() then
        TT:RefreshInspectFrame()
    end
    local _, ttUnit = GameTooltip:GetUnit()
    if (ttUnit and UnitGUID(ttUnit) == guid) then
        GameTooltip:SetUnit(ttUnit)
    end
end)

CI.RegisterCallback(addOnName .. "_TalentsReady", "TALENTS_READY", function(_, guid)
    local _, ttUnit = GameTooltip:GetUnit()
    if (ttUnit and UnitGUID(ttUnit) == guid) then
        GameTooltip:SetUnit(ttUnit)
    end
end)

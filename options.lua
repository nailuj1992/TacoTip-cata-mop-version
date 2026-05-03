local addOnName = ...
GetAddOnMetadata = C_AddOns.GetAddOnMetadata
local addOnVersion = GetAddOnMetadata(addOnName, "Version") or "0.0.1"
local addOnTitle = GetAddOnMetadata(addOnName, "Title") or addOnName

local clientVersionString = GetBuildInfo()
local majorVersion = tonumber(string.match(clientVersionString, "^(%d+)%.?%d*"))
-- load only on classic/tbc/wotlk/cata/mop
if (majorVersion < 1 or majorVersion > 5) then
    return
end

assert(LibStub, "TacoTip requires LibStub")
assert(LibStub:GetLibrary("LibClassicInspector", true), "TacoTip requires LibClassicInspector")
assert(LibStub:GetLibrary("LibDetours-1.0", true), "TacoTip requires LibDetours-1.0")

local Detours = LibStub("LibDetours-1.0")
local CI = LibStub("LibClassicInspector")

local SettingsLib = LibStub and LibStub("LibEQOLSettingsMode-1.0", true)
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

_G[addOnName] = {}
local isPawnLoaded = PawnClassicLastUpdatedVersion ~= nil

local GearScore = TT_GS
local L = TACOTIP_LOCALE
local TT = _G[addOnName]

local HORDE_ICON = "|TInterface\\TargetingFrame\\UI-PVP-HORDE:16:16:-2:0:64:64:0:38:0:38|t"
local ALLIANCE_ICON = "|TInterface\\TargetingFrame\\UI-PVP-ALLIANCE:16:16:-2:0:64:64:0:38:0:38|t"
local PVP_FLAG_ICON = "|TInterface\\GossipFrame\\BattleMasterGossipIcon:0|t"

local SupportedExpansions = {
    [5] = "Mists of Pandaria",
}

local TacoTipBaseConfig = {
    color_class = true,
    show_titles = true,
    show_guild_name = true,
    show_guild_rank = true,
    show_talents = true,
    show_gs_player = true,
    gearscore_style = false,
    ilevel_style = false,
    gearscore_ilevel_style = true,
    show_gs_character = true,
    show_gs_items = true,
    show_gs_items_hs = false,
    show_avg_ilvl = true,
    show_quality = true,
    show_durability = true,
    hide_in_combat = false,
    show_item_level = true,
    tip_style = 2,
    show_target = true,
    show_pawn_player = isPawnLoaded,
    show_team = true,
    show_pvp_icon = true,
    guild_rank_alt_style = true,
    show_hp_bar = true,
    show_power_bar = false,
    instant_fade = false,
    anchor_mouse = false,
    anchor_mouse_world = true,
    anchor_mouse_spells = false,
    inspect_gs_offset_x = 0,
    inspect_gs_offset_y = 0,
    inspect_ilvl_offset_x = 0,
    inspect_ilvl_offset_y = 0,
    character_gs_offset_x = 0,
    character_gs_offset_y = 0,
    character_ilvl_offset_x = 0,
    character_ilvl_offset_y = 0,
    unlock_info_position = false,
    show_achievement_points = false,
    --conf_version = addOnVersion,
    --custom_pos = nil,
    --custom_anchor = nil,
}

function TT:GetDefaults()
    local defaults = {}
    for k, v in pairs(TacoTipBaseConfig) do
        defaults[k] = v
    end
    return defaults
end

local function InitConfig()
    TacoTipConfig = TacoTipConfig or {}
    for key, defaultValue in pairs(TacoTipBaseConfig) do
        if TacoTipConfig[key] == nil then
            TacoTipConfig[key] = defaultValue
        end
    end
    return TacoTipConfig
end

TacoTipConfig = InitConfig()

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event, isInitialLogin, isReloadingUi)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        local function copyDefaults(src, dst)
            if type(src) ~= "table" then return {} end
            if not type(dst) then dst = {} end
            for k, v in pairs(src) do
                if type(v) == "table" then
                    dst[k] = copyDefaults(v, dst[k])
                elseif type(v) ~= type(dst[k]) then
                    dst[k] = v
                end
            end
            return dst
        end
        TacoTipConfig = copyDefaults(TacoTipBaseConfig, TacoTipConfig)
    end
end)

local function resetCfg()
    if (TacoTipDragButton) then
        TacoTipDragButton:_Disable()
    end
    if (TacoTipConfig and TacoTipConfig.instant_fade) then
        TT.frame:UnregisterEvent("UPDATE_MOUSEOVER_UNIT")
        Detours:DetourUnhook(TT, GameTooltip, "FadeOut")
    end
    TacoTipConfig = TT:GetDefaults()
    if (PersonalGearScore) then
        PersonalGearScore:RefreshPosition()
    end
    if (PersonalGearScoreText) then
        PersonalGearScoreText:RefreshPosition()
    end
    if (PersonalAvgItemLvl) then
        PersonalAvgItemLvl:RefreshPosition()
    end
    if (PersonalAvgItemLvlText) then
        PersonalAvgItemLvlText:RefreshPosition()
    end
    if (InspectGearScore) then
        InspectGearScore:RefreshPosition()
    end
    if (InspectGearScoreText) then
        InspectGearScoreText:RefreshPosition()
    end
    if (InspectAvgItemLvl) then
        InspectAvgItemLvl:RefreshPosition()
    end
    if (InspectAvgItemLvlText) then
        InspectAvgItemLvlText:RefreshPosition()
    end
    if (TT.RefreshCharacterFrame and PaperDollFrame and PaperDollFrame:IsShown()) then
        TT:RefreshCharacterFrame()
    end
    if (TT.RefreshInspectFrame and InspectFrame and InspectFrame:IsShown()) then
        TT:RefreshInspectFrame()
    end
    --SetCVar("showItemLevel", "1")
end

local function Register()
    local category, layout = Settings.RegisterVerticalLayoutCategory(addOnTitle)
    Settings.TACOTIP_CATEGORY_ID = category:GetID()

    --------------------------------------------------------------------------------
    -- HEADER SECTION
    --------------------------------------------------------------------------------
    local name = "Version " .. addOnVersion
    if SupportedExpansions[majorVersion] then
        name = name .. " for " .. SupportedExpansions[majorVersion]
    end
    SettingsLib:CreateHeader(category, {
        name = name,
    })
    SettingsLib:CreateText(category, {
        name = L["TEXT_OPT_DESC"],
    })

    --------------------------------------------------------------------------------
    -- EXAMPLE TOOLTIP PREVIEW
    --------------------------------------------------------------------------------
    local exampleTooltip = CreateFrame("GameTooltip", "TacoTipOptExampleTooltip", UIParent, "GameTooltipTemplate")
    local exampleTooltipHealthBar = CreateFrame("StatusBar", "TacoTipOptExampleTooltipStatusBar", exampleTooltip)
    exampleTooltipHealthBar:SetSize(0, 8)
    exampleTooltipHealthBar:SetPoint("TOPLEFT", exampleTooltip, "BOTTOMLEFT", 2, -1)
    exampleTooltipHealthBar:SetPoint("TOPRIGHT", exampleTooltip, "BOTTOMRIGHT", -2, -1)
    exampleTooltipHealthBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
    exampleTooltipHealthBar:SetStatusBarColor(0, 1, 0)
    local exampleTooltipPowerBar = CreateFrame("StatusBar", "TacoTipOptExampleTooltipPowerBar", exampleTooltip)
    exampleTooltipPowerBar:SetSize(0, 8)
    exampleTooltipPowerBar:SetPoint("TOPLEFT", exampleTooltip, "BOTTOMLEFT", 2, -9)
    exampleTooltipPowerBar:SetPoint("TOPRIGHT", exampleTooltip, "BOTTOMRIGHT", -2, -9)
    exampleTooltipPowerBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
    exampleTooltipPowerBar:SetStatusBarColor(1, 1, 0)

    local function showExampleTooltip()
        exampleTooltip:SetOwner(SettingsPanel, "ANCHOR_NONE")
        exampleTooltip:ClearAllPoints()
        exampleTooltip:SetPoint("TOPRIGHT", SettingsPanel, "TOPRIGHT", -20, -120)
        local classc = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)["ROGUE"]
        local name_r = TacoTipConfig.color_class and classc and classc.r or 0
        local name_g = TacoTipConfig.color_class and classc and classc.g or 0.6
        local name_b = TacoTipConfig.color_class and classc and classc.b or 0.1
        local title = TacoTipConfig.show_titles and L[" the Kingslayer"] or ""
        exampleTooltip:AddLine(string.format("|cFF%02x%02x%02xKebabstorm%s %s%s|r", name_r * 255, name_g * 255,
            name_b * 255, title, (TacoTipConfig.show_team and (HORDE_ICON .. " ") or ""),
            (TacoTipConfig.show_pvp_icon and PVP_FLAG_ICON or "")))
        if (TacoTipConfig.show_guild_name) then
            if (TacoTipConfig.show_guild_rank) then
                if (TacoTipConfig.guild_rank_alt_style) then
                    exampleTooltip:AddLine("|cFF40FB40<Drunken Wrath> (Officer)|r")
                else
                    exampleTooltip:AddLine(string.format("|cFF40FB40" .. L["FORMAT_GUILD_RANK_1"] .. "|r",
                        "Officer", "Drunken Wrath"))
                end
            else
                exampleTooltip:AddLine("|cFF40FB40<Drunken Wrath>|r")
            end
        end
        local level = 85
        if CI:IsMop() then
            level = 90
        end
        if (TacoTipConfig.color_class) then
            exampleTooltip:AddLine(
                string.format("%s %s %s |cFF%02x%02x%02x%s|r (%s)", L["Level"], level, L["Undead"], name_r * 255,
                    name_g * 255, name_b * 255, LOCALIZED_CLASS_NAMES_MALE["ROGUE"], L["Player"]), 1, 1, 1)
        else
            exampleTooltip:AddLine(
                string.format("%s %s %s %s (%s)", L["Level"], level, L["Undead"], LOCALIZED_CLASS_NAMES_MALE["ROGUE"],
                    L["Player"]), 1, 1, 1)
        end
        if (not TacoTipConfig.show_pvp_icon) then
            exampleTooltip:AddLine("PvP", 1, 1, 1)
        end
        local wide_style = (TacoTipConfig.tip_style == 1 or ((TacoTipConfig.tip_style == 2 or TacoTipConfig.tip_style == 4) and IsModifierKeyDown()))
        local mini_style = (not wide_style and (TacoTipConfig.tip_style == 4 or TacoTipConfig.tip_style == 5))
        if (TacoTipConfig.show_target) then
            if (wide_style) then
                exampleTooltip:AddDoubleLine(L["Target"] .. ":", L["None"], NORMAL_FONT_COLOR.r,
                    NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
            else
                exampleTooltip:AddLine(L["Target"] .. ": |cFF808080" .. L["None"] .. "|r")
            end
        end
        if (TacoTipConfig.show_talents) then
            if (wide_style) then
                local talents = CI:GetSpecializationName("ROGUE", 1, true) .. " [31/2/8]"
                if CI:IsMop() then
                    talents = CI:GetSpecializationName("ROGUE", 1, true) .. " [2/3/1/3/2/2]"
                end
                exampleTooltip:AddDoubleLine(L["Talents"] .. ":", talents, NORMAL_FONT_COLOR.r,
                    NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g,
                    HIGHLIGHT_FONT_COLOR.b)
                exampleTooltip:AddDoubleLine(" ", CI:GetSpecializationName("ROGUE", 2, true) .. " [7/31/3]",
                    NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, GRAY_FONT_COLOR.r,
                    GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
            else
                local talents = CI:GetSpecializationName("ROGUE", 1, true) .. " [31/2/8]"
                if CI:IsMop() then
                    talents = CI:GetSpecializationName("ROGUE", 1, true) .. " [2/3/1/3/2/2]"
                end
                exampleTooltip:AddLine(L["Talents"] .. ":|cFFFFFFFF " .. talents)
            end
        end
        local miniText = ""
        if (TacoTipConfig.show_gs_player) then
            local gs, ilevel = 10405, 388
            if CI:IsMop() then
                gs = 13579
                ilevel = 497
            end
            local gs_r, gs_b, gs_g = GearScore:GetQuality(gs)
            if (wide_style) then
                if TacoTipConfig.gearscore_ilevel_style then
                    exampleTooltip:AddDoubleLine("GearScore: " .. gs, "(iLvl: " .. ilevel .. ")", gs_r, gs_b,
                        gs_g, gs_r, gs_b, gs_g)
                elseif TacoTipConfig.gearscore_style then
                    exampleTooltip:AddLine("GearScore: " .. gs, gs_r, gs_b, gs_g)
                elseif TacoTipConfig.ilevel_style then
                    exampleTooltip:AddLine("iLvl: " .. ilevel, gs_r, gs_b, gs_g)
                end
            elseif (mini_style) then
                if TacoTipConfig.gearscore_ilevel_style then
                    exampleTooltip:AddLine("GS: " .. gs .. " L: " .. ilevel, gs_r, gs_b, gs_g)
                elseif TacoTipConfig.gearscore_style then
                    exampleTooltip:AddLine("GS: " .. gs, gs_r, gs_b, gs_g)
                elseif TacoTipConfig.ilevel_style then
                    exampleTooltip:AddLine("L: " .. ilevel, gs_r, gs_b, gs_g)
                end
            else
                if TacoTipConfig.gearscore_ilevel_style then
                    exampleTooltip:AddLine("GearScore: " .. gs .. " (iLvl: " .. ilevel .. ")", gs_r, gs_b, gs_g)
                elseif TacoTipConfig.gearscore_style then
                    exampleTooltip:AddLine("GearScore: " .. gs, gs_r, gs_b, gs_g)
                elseif TacoTipConfig.ilevel_style then
                    exampleTooltip:AddLine("iLvl: " .. ilevel, gs_r, gs_b, gs_g)
                end
            end
        end
        if (isPawnLoaded and TacoTipConfig.show_pawn_player) then
            local specColor = PawnGetScaleColor("\"Classic\":ROGUE1", true) or "|cffffffff"
            if (wide_style) then
                exampleTooltip:AddDoubleLine(string.format("Pawn: %s1234.56|r", specColor),
                    string.format("%s(%s)|r", specColor, CI:GetSpecializationName("ROGUE", 1, true)), 1, 1, 1, 1, 1, 1)
            elseif (mini_style) then
                miniText = miniText .. string.format("P: %s1234.5|r", specColor)
            else
                exampleTooltip:AddLine(
                    string.format("Pawn: %s1234.56 (%s)|r", specColor, CI:GetSpecializationName("ROGUE", 1, true)), 1, 1,
                    1)
            end
        end
        if (miniText ~= "") then
            exampleTooltip:AddLine(miniText, 1, 1, 1)
        end
        exampleTooltip:Show()
        if (TacoTipConfig.show_hp_bar) then
            exampleTooltipHealthBar:Show()
            exampleTooltipPowerBar:SetPoint("TOPLEFT", exampleTooltip, "BOTTOMLEFT", 2, -9)
            exampleTooltipPowerBar:SetPoint("TOPRIGHT", exampleTooltip, "BOTTOMRIGHT", -2, -9)
        else
            exampleTooltipHealthBar:Hide()
            exampleTooltipPowerBar:SetPoint("TOPLEFT", exampleTooltip, "BOTTOMLEFT", 2, -1)
            exampleTooltipPowerBar:SetPoint("TOPRIGHT", exampleTooltip, "BOTTOMRIGHT", -2, -1)
        end
        if (TacoTipConfig.show_power_bar) then
            exampleTooltipPowerBar:Show()
        else
            exampleTooltipPowerBar:Hide()
        end
    end

    exampleTooltip:SetScript("OnEvent", function() showExampleTooltip() end)

    Settings.RegisterAddOnCategory(category)

    hooksecurefunc(SettingsPanel, "DisplayCategory", function(self, showingCategory)
        if showingCategory:GetID() == Settings.TACOTIP_CATEGORY_ID then
            showExampleTooltip()
            exampleTooltip:RegisterEvent("MODIFIER_STATE_CHANGED")
        else
            exampleTooltip:UnregisterEvent("MODIFIER_STATE_CHANGED")
            exampleTooltip:Hide()
        end
    end)

    SettingsPanel:HookScript("OnHide", function()
        exampleTooltip:UnregisterEvent("MODIFIER_STATE_CHANGED")
        exampleTooltip:Hide()
    end)

    --------------------------------------------------------------------------------
    -- UNIT TOOLTIPS SECTION
    --------------------------------------------------------------------------------
    local unitSection = SettingsLib:CreateExpandableSection(category, {
        name = L["Unit Tooltips"],
        expanded = false,
        colorizeTitle = false,
    })

    SettingsLib:CreateCheckbox(category, {
        prefix = "TT_",
        key = "color_class",
        name = L["Class Color"],
        default = TacoTipBaseConfig.color_class,
        get = function() return TacoTipConfig.color_class end,
        set = function(v)
            TacoTipConfig.color_class = v; showExampleTooltip()
        end,
        desc = L["Color class names in tooltips"],
        parentSection = unitSection,
    })

    SettingsLib:CreateCheckbox(category, {
        prefix = "TT_",
        key = "show_titles",
        name = L["Title"],
        default = TacoTipBaseConfig.show_titles,
        get = function() return TacoTipConfig.show_titles end,
        set = function(v)
            TacoTipConfig.show_titles = v; showExampleTooltip()
        end,
        desc = L["Show player's title in tooltips"],
        parentSection = unitSection,
    })

    local guildNamesInit, guildNamesSetting = SettingsLib:CreateCheckbox(category, {
        prefix = "TT_",
        key = "show_guild_name",
        name = L["Guild Name"],
        default = TacoTipBaseConfig.show_guild_name,
        get = function() return TacoTipConfig.show_guild_name end,
        set = function(v)
            TacoTipConfig.show_guild_name = v
            Settings.NotifyUpdate("TT_show_guild_rank")
            showExampleTooltip()
        end,
        desc = L["Show guild name in tooltips"],
        parentSection = unitSection,
    })

    local guildRankInit, guildRanksSetting = SettingsLib:CreateCheckbox(category, {
        prefix = "TT_",
        key = "show_guild_rank",
        name = L["Guild Rank"],
        default = TacoTipBaseConfig.show_guild_rank,
        get = function() return TacoTipConfig.show_guild_rank end,
        set = function(v)
            TacoTipConfig.show_guild_rank = v; showExampleTooltip()
        end,
        desc = L["Show guild rank in tooltips"],
        parentSection = unitSection,
        parent = guildNamesInit,
        parentCheck = function() return guildNamesSetting:GetValue() end,
    })

    local guildRankStyleInit = SettingsLib:CreateDropdown(category, {
        prefix = "TT_",
        key = "guild_rank_alt_style_str",
        name = L["Style"],
        varType = Settings.VarType.String,
        default = "style1",
        get = function() return TacoTipConfig.guild_rank_alt_style and "style2" or "style1" end,
        set = function(v)
            TacoTipConfig.guild_rank_alt_style = (v == "style2"); showExampleTooltip()
        end,
        desc = "Format of guild rank display",
        values = {
            ["style1"] = string.format(L["FORMAT_GUILD_RANK_1"], L["Rank"], L["Guild"]),
            ["style2"] = string.format("<%s> (%s)", L["Guild"], L["Rank"]),
        },
        parentSection = unitSection,
        parent = guildRankInit,
        parentCheck = function() return guildNamesSetting:GetValue() and guildRanksSetting:GetValue() end,
    })

    SettingsLib:CreateCheckbox(category, {
        prefix = "TT_",
        key = "show_talents",
        name = L["Talents"],
        default = TacoTipBaseConfig.show_talents,
        get = function() return TacoTipConfig.show_talents end,
        set = function(v)
            TacoTipConfig.show_talents = v; showExampleTooltip()
        end,
        desc = L["Show talents and specialization in tooltips"],
        parentSection = unitSection,
    })

    SettingsLib:CreateCheckbox(category, {
        prefix = "TT_",
        key = "show_target",
        name = L["Target"],
        default = TacoTipBaseConfig.show_target,
        get = function() return TacoTipConfig.show_target end,
        set = function(v)
            TacoTipConfig.show_target = v; showExampleTooltip()
        end,
        desc = L["Show unit's target in tooltips"],
        parentSection = unitSection,
    })

    SettingsLib:CreateCheckbox(category, {
        prefix = "TT_",
        key = "show_team",
        name = L["Faction Icon"],
        default = TacoTipBaseConfig.show_team,
        get = function() return TacoTipConfig.show_team end,
        set = function(v)
            TacoTipConfig.show_team = v; showExampleTooltip()
        end,
        desc = L["Show player's faction icon (Horde/Alliance) in tooltips"],
        parentSection = unitSection,
    })

    SettingsLib:CreateCheckbox(category, {
        prefix = "TT_",
        key = "show_pvp_icon",
        name = L["PVP Icon"],
        default = TacoTipBaseConfig.show_pvp_icon,
        get = function() return TacoTipConfig.show_pvp_icon end,
        set = function(v)
            TacoTipConfig.show_pvp_icon = v; showExampleTooltip()
        end,
        desc = L["Show player's pvp flag status as icon instead of text"],
        parentSection = unitSection,
    })

    SettingsLib:CreateCheckbox(category, {
        prefix = "TT_",
        key = "show_hp_bar",
        name = L["Health Bar"],
        default = TacoTipBaseConfig.show_hp_bar,
        get = function() return TacoTipConfig.show_hp_bar end,
        set = function(v)
            TacoTipConfig.show_hp_bar = v; showExampleTooltip()
        end,
        desc = L["Show unit's health bar under tooltip"],
        parentSection = unitSection,
    })

    SettingsLib:CreateCheckbox(category, {
        prefix = "TT_",
        key = "show_power_bar",
        name = L["Power Bar"],
        default = TacoTipBaseConfig.show_power_bar,
        get = function() return TacoTipConfig.show_power_bar end,
        set = function(v)
            TacoTipConfig.show_power_bar = v; showExampleTooltip()
        end,
        desc = L["Show unit's power bar under tooltip"],
        parentSection = unitSection,
    })

    local gsPlayerInit, gsPlayerSetting = SettingsLib:CreateCheckbox(category, {
        prefix = "TT_",
        key = "show_gs_player",
        name = "GearScore",
        default = TacoTipBaseConfig.show_gs_player,
        get = function() return TacoTipConfig.show_gs_player end,
        set = function(v)
            TacoTipConfig.show_gs_player = v; showExampleTooltip()
        end,
        desc = L["Show player's GearScore in tooltips"],
        parentSection = unitSection,
    })

    SettingsLib:CreateDropdown(category, {
        prefix = "TT_",
        key = "gearscore_display_style",
        name = L["Style"],
        varType = Settings.VarType.String,
        default = "gs_ilevel",
        get = function()
            if TacoTipConfig.gearscore_style then
                return "gs_only"
            elseif TacoTipConfig.ilevel_style then
                return "ilevel_only"
            else
                return "gs_ilevel"
            end
        end,
        set = function(v)
            TacoTipConfig.gearscore_style = (v == "gs_only")
            TacoTipConfig.ilevel_style = (v == "ilevel_only")
            TacoTipConfig.gearscore_ilevel_style = (v == "gs_ilevel")
            showExampleTooltip()
        end,
        desc = "Display format for GearScore",
        values = { ["gs_ilevel"] = "GearScore + iLvl", ["gs_only"] = "GearScore only", ["ilevel_only"] = "iLvl only" },
        parentSection = unitSection,
        parent = gsPlayerInit,
        parentCheck = function() return gsPlayerSetting:GetValue() end,
    })

    local pawnLabel = isPawnLoaded and "PawnScore" or ("PawnScore (" .. L["requires Pawn"] .. ")")
    SettingsLib:CreateCheckbox(category, {
        prefix = "TT_",
        key = "show_pawn_player",
        name = pawnLabel,
        default = TacoTipBaseConfig.show_pawn_player,
        get = function() return TacoTipConfig.show_pawn_player end,
        set = function(v)
            TacoTipConfig.show_pawn_player = v; showExampleTooltip()
        end,
        desc = L["Show player's PawnScore in tooltips (may affect performance)"],
        parentSection = unitSection,
        isEnabled = isPawnLoaded,
    })

    --------------------------------------------------------------------------------
    -- CHARACTER FRAME SECTION
    --------------------------------------------------------------------------------
    local characterSection = SettingsLib:CreateExpandableSection(category, {
        name = L["Character Frame"],
        expanded = false,
        colorizeTitle = false,
    })

    SettingsLib:CreateCheckbox(category, {
        prefix = "TT_",
        key = "show_gs_character",
        name = "GearScore",
        default = TacoTipBaseConfig.show_gs_character,
        get = function() return TacoTipConfig.show_gs_character end,
        set = function(v)
            TacoTipConfig.show_gs_character = v
            if PaperDollFrame and PaperDollFrame:IsShown() then TT:RefreshCharacterFrame() end
            if InspectFrame and InspectFrame:IsShown() then TT:RefreshInspectFrame() end
        end,
        desc = L["Show GearScore in character frame"],
        parentSection = characterSection,
    })

    SettingsLib:CreateCheckbox(category, {
        prefix = "TT_",
        key = "show_avg_ilvl",
        name = L["Average iLvl"],
        default = TacoTipBaseConfig.show_avg_ilvl,
        get = function() return TacoTipConfig.show_avg_ilvl end,
        set = function(v)
            TacoTipConfig.show_avg_ilvl = v
            if PaperDollFrame and PaperDollFrame:IsShown() then TT:RefreshCharacterFrame() end
            if InspectFrame and InspectFrame:IsShown() then TT:RefreshInspectFrame() end
        end,
        desc = L["Show Average Item Level in character frame"],
        parentSection = characterSection,
    })

    SettingsLib:CreateCheckbox(category, {
        prefix = "TT_",
        key = "lock_info_position",
        name = L["Lock Position"],
        default = not TacoTipBaseConfig.unlock_info_position,
        get = function() return not TacoTipConfig.unlock_info_position end,
        set = function(v)
            TacoTipConfig.unlock_info_position = not v
            if PaperDollFrame and PaperDollFrame:IsShown() then TT:RefreshCharacterFrame() end
            if InspectFrame and InspectFrame:IsShown() then TT:RefreshInspectFrame() end
        end,
        desc = L["Lock GearScore and Average Item Level positions in character frame"],
        parentSection = characterSection,
        isEnabled = function() return TacoTipConfig.show_gs_character or TacoTipConfig.show_avg_ilvl end,
    })

    --------------------------------------------------------------------------------
    -- EXTRA SECTION
    --------------------------------------------------------------------------------
    local extraSection = SettingsLib:CreateExpandableSection(category, {
        name = L["Extra"],
        expanded = false,
        colorizeTitle = false,
    })

    local showItemLevelInit, showItemLevelSetting = SettingsLib:CreateCheckbox(category, {
        prefix = "TT_",
        key = "show_item_level",
        name = L["Show Item Level"],
        default = TacoTipBaseConfig.show_item_level,
        get = function() return TacoTipConfig.show_item_level end,
        set = function(v) TacoTipConfig.show_item_level = v end,
        desc = L["Display item level in the tooltip for certain items."],
        parentSection = extraSection,
    })

    SettingsLib:CreateCheckbox(category, {
        prefix = "TT_",
        key = "show_gs_items",
        name = L["Show Item GearScore"],
        default = TacoTipBaseConfig.show_gs_items,
        get = function() return TacoTipConfig.show_gs_items end,
        set = function(v) TacoTipConfig.show_gs_items = v end,
        desc = L["Show GearScore in item tooltips"],
        parentSection = extraSection,
    })

    if CI:IsMop() then
        SettingsLib:CreateCheckbox(category, {
            prefix = "TT_",
            key = "show_quality",
            name = L["Show Quality Color"],
            default = TacoTipBaseConfig.show_quality,
            get = function() return TacoTipConfig.show_quality end,
            set = function(v) TacoTipConfig.show_quality = v end,
            desc = L["Display quality colors in the item icon for certain items."],
            parentSection = extraSection,
            parent = showItemLevelInit,
            parentCheck = function() return showItemLevelSetting:GetValue() end,
        })

        SettingsLib:CreateCheckbox(category, {
            prefix = "TT_",
            key = "show_durability",
            name = L["Show Durability"],
            default = TacoTipBaseConfig.show_durability,
            get = function() return TacoTipConfig.show_durability end,
            set = function(v) TacoTipConfig.show_durability = v end,
            desc = L["Display durability in the item icon for certain items."],
            parentSection = extraSection,
            parent = showItemLevelInit,
            parentCheck = function() return showItemLevelSetting:GetValue() end,
        })
    end

    SettingsLib:CreateCheckbox(category, {
        prefix = "TT_",
        key = "uber_tips",
        name = L["Enhanced Tooltips"],
        default = GetCVar("UberTooltips") == "1",
        get = function() return GetCVar("UberTooltips") == "1" end,
        set = function(v) SetCVar("UberTooltips", v and "1" or "0") end,
        desc = L["TEXT_OPT_UBERTIPS"],
        parentSection = extraSection,
    })

    SettingsLib:CreateCheckbox(category, {
        prefix = "TT_",
        key = "hide_in_combat",
        name = L["Disable In Combat"],
        default = TacoTipBaseConfig.hide_in_combat,
        get = function() return TacoTipConfig.hide_in_combat end,
        set = function(v) TacoTipConfig.hide_in_combat = v end,
        desc = L["Disable gearscore & talents in combat"],
        parentSection = extraSection,
    })

    SettingsLib:CreateCheckbox(category, {
        prefix = "TT_",
        key = "show_achievement_points",
        name = L["Show Achievement Points"],
        default = TacoTipBaseConfig.show_achievement_points,
        get = function() return TacoTipConfig.show_achievement_points end,
        set = function(v) TacoTipConfig.show_achievement_points = v end,
        desc = L["Show total achievement points in tooltips"],
        parentSection = extraSection,
    })

    SettingsLib:CreateCheckbox(category, {
        prefix = "TT_",
        key = "instant_fade",
        name = L["Instant Fade"],
        default = TacoTipBaseConfig.instant_fade,
        get = function() return TacoTipConfig.instant_fade end,
        set = function(v)
            TacoTipConfig.instant_fade = v
            if v then
                TT.frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
                Detours:DetourHook(TT, GameTooltip, "FadeOut", function(self) self:Hide() end)
            else
                TT.frame:UnregisterEvent("UPDATE_MOUSEOVER_UNIT")
                Detours:DetourUnhook(TT, GameTooltip, "FadeOut")
            end
        end,
        desc = L["Fade out unit tooltips instantly"],
        parentSection = extraSection,
    })

    SettingsLib:CreateCheckbox(category, {
        prefix = "TT_",
        key = "anchor_mouse_spells",
        name = L["Anchor Spells to Mouse"],
        default = TacoTipBaseConfig.anchor_mouse_spells,
        get = function() return TacoTipConfig.anchor_mouse_spells end,
        set = function(v) TacoTipConfig.anchor_mouse_spells = v end,
        desc = L["Anchor spell tooltips to mouse cursor"],
        parentSection = extraSection,
    })

    SettingsLib:CreateCheckbox(category, {
        prefix = "TT_",
        key = "chat_class_colors",
        name = L["Chat Class Colors"],
        default = GetCVar("chatClassColorOverride") == "0",
        get = function() return GetCVar("chatClassColorOverride") == "0" end,
        set = function(v) SetCVar("chatClassColorOverride", v and "0" or "1") end,
        desc = L["Color names by class in chat windows"],
        parentSection = extraSection,
    })

    SettingsLib:CreateCheckboxButton(category, {
        prefix = "TT_",
        key = "custom_pos_enable",
        name = L["Custom Tooltip Position"],
        default = false,
        get = function() return TacoTipConfig.custom_pos ~= nil end,
        set = function(v)
            if v then
                TacoTipConfig.anchor_mouse = false
                TacoTip_CustomPosEnable(false)
            else
                if TacoTipDragButton then TacoTipDragButton:_Disable() end
                TacoTipConfig.custom_pos = nil
                TacoTipConfig.custom_anchor = nil
            end
        end,
        desc = L["Set a custom position for tooltips"],
        buttonText = L["Mover"],
        buttonClick = function() TacoTip_CustomPosEnable(true) end,
        clickRequiresSet = true,
        parentSection = extraSection,
    })

    local anchorMouseInit, anchorMouseSetting = SettingsLib:CreateCheckbox(category, {
        prefix = "TT_",
        key = "anchor_mouse",
        name = L["Anchor to Mouse"],
        default = TacoTipBaseConfig.anchor_mouse,
        get = function() return TacoTipConfig.anchor_mouse end,
        set = function(v)
            TacoTipConfig.anchor_mouse = v
            if v then
                if TacoTipDragButton then TacoTipDragButton:_Disable() end
                TacoTipConfig.custom_pos = nil
                TacoTipConfig.custom_anchor = nil
            end
        end,
        desc = L["Anchor tooltips to mouse cursor"],
        parentSection = extraSection,
    })

    SettingsLib:CreateCheckbox(category, {
        prefix = "TT_",
        key = "anchor_mouse_world",
        name = L["Only in WorldFrame"],
        default = TacoTipBaseConfig.anchor_mouse_world,
        get = function() return TacoTipConfig.anchor_mouse_world end,
        set = function(v) TacoTipConfig.anchor_mouse_world = v end,
        desc = L["Anchor to mouse only in WorldFrame\nSkips raid / party frames"],
        parentSection = extraSection,
        parent = anchorMouseInit,
        parentCheck = function() return anchorMouseSetting:GetValue() end,
    })

    --------------------------------------------------------------------------------
    -- TOOLTIP STYLE SECTION
    --------------------------------------------------------------------------------
    local styleSection = SettingsLib:CreateExpandableSection(category, {
        name = L["Tooltip Style"],
        expanded = false,
        colorizeTitle = false,
    })

    SettingsLib:CreateDropdown(category, {
        prefix = "TT_",
        key = "tip_style",
        name = L["Tooltip Style"],
        varType = Settings.VarType.Number,
        default = TacoTipBaseConfig.tip_style,
        get = function() return TacoTipConfig.tip_style end,
        set = function(v)
            TacoTipConfig.tip_style = v; showExampleTooltip()
        end,
        desc = "Choose the display style for tooltips",
        values = {
            [1] = L["FULL"],
            [2] = L["COMPACT/FULL"],
            [3] = L["COMPACT"],
            [4] = L["MINI/FULL"],
            [5] = L["MINI"],
        },
        parentSection = styleSection,
    })

    SettingsLib:CreateText(category,
        { name = L["FULL"] .. ": " .. L["Wide, Dual Spec, GearScore, Average iLvl"], parentSection = styleSection })
    SettingsLib:CreateText(category,
        { name = L["COMPACT"] .. ": " .. L["Narrow, Active Spec, GearScore"], parentSection = styleSection })
    SettingsLib:CreateText(category,
        { name = L["MINI"] .. ": " .. L["Narrow, Active Spec, GearScore, Average iLvl"], parentSection = styleSection })

    --------------------------------------------------------------------------------
    -- RESET BUTTON
    --------------------------------------------------------------------------------
    SettingsLib:CreateButton(category, {
        text = L["Reset configuration"],
        click = function()
            resetCfg()
            showExampleTooltip()
        end,
    })
end

SettingsRegistrar:AddRegistrant(Register)

-- for addon compartment (in .toc)
function OpenTacoTipSettings()
    Settings.OpenToCategory(Settings.TACOTIP_CATEGORY_ID)
end

SLASH_TACOTIP1 = "/tacotip";
SLASH_TACOTIP2 = "/tooltip";
SLASH_TACOTIP3 = "/tip";
SLASH_TACOTIP4 = "/tt";
SLASH_TACOTIP5 = "/gs";
SLASH_TACOTIP6 = "/gearscore";
function SlashCmdList.TACOTIP(msg)
    local cmd = strlower(msg)
    if (cmd == "custom") then
        TacoTip_CustomPosEnable(true)
    elseif (cmd == "default") then
        if (not TacoTipConfig.custom_pos) then
            print("|cff59f0dcTacoTip:|r " .. L["Custom tooltip position disabled."])
        end
        if (TacoTipDragButton) then
            TacoTipDragButton:_Disable()
        end
        TacoTipConfig.custom_pos = nil
        TacoTipConfig.custom_anchor = nil
    elseif (cmd == "reset") then
        resetCfg()
        if (TacoTipOptions and TacoTipOptions:IsShown()) then
            TacoTipOptions:Refresh()
        end
        print("|cff59f0dcTacoTip:|r " .. L["Configuration has been reset to default."])
    elseif (cmd == "save") then
        if (TacoTipDragButton and TacoTipDragButton:IsShown()) then
            TacoTipDragButton:_Save()
        end
    elseif (strfind(cmd, "anchor")) then
        if (strfind(cmd, "topleft")) then
            TacoTipConfig.custom_anchor = "TOPLEFT"
            print("|cff59f0dcTacoTip:|r " .. L["Custom position anchor set"] .. ": 'TOPLEFT'")
        elseif (strfind(cmd, "topright")) then
            TacoTipConfig.custom_anchor = "TOPRIGHT"
            print("|cff59f0dcTacoTip:|r " .. L["Custom position anchor set"] .. ": 'TOPRIGHT'")
        elseif (strfind(cmd, "bottomleft")) then
            TacoTipConfig.custom_anchor = "BOTTOMLEFT"
            print("|cff59f0dcTacoTip:|r " .. L["Custom position anchor set"] .. ": 'BOTTOMLEFT'")
        elseif (strfind(cmd, "bottomright")) then
            TacoTipConfig.custom_anchor = "BOTTOMRIGHT"
            print("|cff59f0dcTacoTip:|r " .. L["Custom position anchor set"] .. ": 'BOTTOMRIGHT'")
        elseif (strfind(cmd, "center")) then
            TacoTipConfig.custom_anchor = "CENTER"
            print("|cff59f0dcTacoTip:|r " .. L["Custom position anchor set"] .. ": 'CENTER'")
        else
            print("|cff59f0dcTacoTip:|r " .. L["TEXT_HELP_ANCHOR"])
        end
    else
        OpenTacoTipSettings()
    end
end

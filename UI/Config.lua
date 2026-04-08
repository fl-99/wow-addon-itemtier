-- ItemTier: /itemtier slash command and settings panel

ItemTier = ItemTier or {}
ItemTier.Config = {}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function Print(msg)
    print("|cff00aaff[ItemTier]|r " .. tostring(msg))
end

local function PrintHelp()
    Print("Commands:")
    Print("  /itemtier                  – show this help")
    Print("  /itemtier enable           – enable the addon")
    Print("  /itemtier disable          – disable the addon")
    Print("  /itemtier mode short|abbrev|full  – set display mode")
    Print("  /itemtier colors on|off    – toggle color-coded labels")
    Print("  /itemtier debug on|off     – toggle debug output")
    Print("  /itemtier cache clear      – clear the item-tier cache")
    Print("  /itemtier cache size       – show cache entry count")
    Print("  /itemtier status           – show current settings")
end

local function PrintStatus()
    local db = ItemTier.DB
    if not db then Print("Not yet initialised."); return end
    Print("Status:")
    Print("  Enabled    : " .. tostring(db.enabled))
    Print("  Mode       : " .. tostring(db.displayMode))
    Print("  Colors     : " .. tostring(db.useColors))
    Print("  Debug      : " .. tostring(db.debug))
    Print("  Cache size : " .. tostring(ItemTier.Cache.Size()))
end

-- ---------------------------------------------------------------------------
-- Slash command handler
-- ---------------------------------------------------------------------------
local function HandleSlash(input)
    local db = ItemTier.DB
    if not db then Print("Not yet initialised."); return end

    local args = {}
    for word in input:gmatch("%S+") do args[#args + 1] = word:lower() end

    local cmd = args[1]

    if not cmd or cmd == "" or cmd == "help" then
        PrintHelp()

    elseif cmd == "enable" then
        db.enabled = true
        Print("Enabled.")

    elseif cmd == "disable" then
        db.enabled = false
        Print("Disabled.")

    elseif cmd == "mode" then
        local mode = args[2]
        if mode == "short" or mode == "abbrev" or mode == "full" then
            db.displayMode = mode
            ItemTier.Cache.Clear()
            Print("Display mode set to: " .. mode)
        else
            Print("Valid modes: short | abbrev | full")
        end

    elseif cmd == "colors" then
        local arg = args[2]
        if arg == "on" then
            db.useColors = true
            ItemTier.Cache.Clear()
            Print("Colors enabled.")
        elseif arg == "off" then
            db.useColors = false
            ItemTier.Cache.Clear()
            Print("Colors disabled.")
        else
            Print("Usage: /itemtier colors on|off")
        end

    elseif cmd == "debug" then
        local arg = args[2]
        if arg == "on" then
            db.debug = true
            Print("Debug output enabled.")
        elseif arg == "off" then
            db.debug = false
            Print("Debug output disabled.")
        else
            Print("Usage: /itemtier debug on|off")
        end

    elseif cmd == "cache" then
        local sub = args[2]
        if sub == "clear" then
            ItemTier.Cache.Clear()
            Print("Cache cleared.")
        elseif sub == "size" then
            Print("Cache entries: " .. tostring(ItemTier.Cache.Size()))
        else
            Print("Usage: /itemtier cache clear|size")
        end

    elseif cmd == "status" then
        PrintStatus()

    else
        PrintHelp()
    end

    -- Request a Baganator refresh so changes take effect immediately.
    if Baganator and Baganator.API and Baganator.API.RequestItemButtonsRefresh then
        Baganator.API.RequestItemButtonsRefresh()
    end
end

-- ---------------------------------------------------------------------------
-- Register slash command
-- ---------------------------------------------------------------------------
SLASH_ITEMTIER1 = "/itemtier"
SlashCmdList["ITEMTIER"] = HandleSlash

-- ---------------------------------------------------------------------------
-- Vanilla Options → AddOns settings panel
-- Built with the modern Settings API (available in WoW 10.0+).
-- Call this after SavedVariables have been loaded (i.e. from ItemTier.Init).
-- ---------------------------------------------------------------------------
function ItemTier.Config.BuildSettingsPanel()
    if not Settings then return end

    local category = Settings.RegisterVerticalLayoutCategory("ItemTier")

    -- Helper: register a proxy setting backed by ItemTier.DB
    local function ProxySetting(key, varType, name, default, getter, setter)
        return Settings.RegisterProxySetting(
            category, key, varType, name, default, getter, setter
        )
    end

    -- Enabled / disabled toggle
    local enabledSetting = ProxySetting(
        "ITEMTIER_ENABLED", Settings.VarType.Boolean,
        "Enable ItemTier",
        ItemTier.Constants.DefaultConfig.enabled,
        function() return ItemTier.DB.enabled end,
        function(val) ItemTier.DB.enabled = val end
    )
    Settings.CreateCheckBox(category, enabledSetting,
        "Show upgrade track / tier labels on bag item icons.")

    -- Color-coded labels toggle
    local colorsSetting = ProxySetting(
        "ITEMTIER_USE_COLORS", Settings.VarType.Boolean,
        "Color-coded Labels",
        ItemTier.Constants.DefaultConfig.useColors,
        function() return ItemTier.DB.useColors end,
        function(val)
            ItemTier.DB.useColors = val
            ItemTier.Cache.Clear()
        end
    )
    Settings.CreateCheckBox(category, colorsSetting,
        "Tint each label with the color associated with its upgrade track.")

    -- Display mode dropdown
    local modeSetting = ProxySetting(
        "ITEMTIER_DISPLAY_MODE", Settings.VarType.String,
        "Display Mode",
        ItemTier.Constants.DefaultConfig.displayMode,
        function() return ItemTier.DB.displayMode end,
        function(val)
            ItemTier.DB.displayMode = val
            ItemTier.Cache.Clear()
        end
    )
    local function GetModeOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add("short",  "Short  (E / A / V \226\128\166)")
        container:Add("abbrev", "Abbreviated  (Expl / Adv / Vet \226\128\166)")
        container:Add("full",   "Full  (Explorer / Adventurer \226\128\166)")
        return container:GetData()
    end
    Settings.CreateDropdown(category, modeSetting, GetModeOptions,
        "Choose how the upgrade track is displayed on bag icons.")

    -- Label scale slider (0.5× – 2.0×)
    local fontSizeSetting = ProxySetting(
        "ITEMTIER_FONT_SIZE", Settings.VarType.Number,
        "Label Scale",
        ItemTier.Constants.DefaultConfig.fontSize,
        function() return ItemTier.DB.fontSize end,
        function(val) ItemTier.DB.fontSize = val end
    )
    local sliderOptions = Settings.CreateSliderOptions(0.5, 2.0, 0.1)
    Settings.CreateSlider(category, fontSizeSetting, sliderOptions,
        "Font size multiplier for upgrade track labels (1.0 = default).")

    -- Debug output toggle
    local debugSetting = ProxySetting(
        "ITEMTIER_DEBUG", Settings.VarType.Boolean,
        "Debug Output",
        ItemTier.Constants.DefaultConfig.debug,
        function() return ItemTier.DB.debug end,
        function(val) ItemTier.DB.debug = val end
    )
    Settings.CreateCheckBox(category, debugSetting,
        "Print verbose debug messages to the chat frame.")

    Settings.RegisterAddOnCategory(category)
end

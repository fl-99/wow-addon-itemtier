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

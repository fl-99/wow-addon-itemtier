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
    Print("  /itemtier                  – open options (or show help)")
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

local function RequestBagWidgetRefresh()
    local baganator = rawget(_G, "Baganator")
    if baganator and baganator.API and baganator.API.RequestItemButtonsRefresh then
        baganator.API.RequestItemButtonsRefresh()
    end

    if ItemTier.BlizzardBags and ItemTier.BlizzardBags.RefreshAll then
        ItemTier.BlizzardBags.RefreshAll()
    end
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

    if not cmd or cmd == "" then
        if ItemTier.Config.CategoryID then
            Settings.OpenToCategory(ItemTier.Config.CategoryID)
        else
            PrintHelp()
        end

    elseif cmd == "help" then
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
    RequestBagWidgetRefresh()
end

-- ---------------------------------------------------------------------------
-- Register slash command
-- ---------------------------------------------------------------------------
SLASH_ITEMTIER1 = "/itemtier"
SlashCmdList["ITEMTIER"] = HandleSlash

-- ---------------------------------------------------------------------------
-- Vanilla Options → AddOns settings panel
-- Uses canvas-layout registration (RegisterCanvasLayoutCategory) so that the
-- category is registered immediately and widgets are built manually inside the
-- frame – the same reliable pattern used by well-known retail addons.
-- Call this after SavedVariables have been loaded (i.e. from ItemTier.Init).
-- ---------------------------------------------------------------------------
function ItemTier.Config.BuildSettingsPanel()
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end

    local panel = CreateFrame("Frame")
    panel.OnCommit  = function() end
    panel.OnDefault = function() end
    panel.OnRefresh = function() end

    local category, layout = Settings.RegisterCanvasLayoutCategory(panel, "ItemTier")
    layout:AddAnchorPoint("TOPLEFT",     10, -10)
    layout:AddAnchorPoint("BOTTOMRIGHT", -10, 10)
    panel:Hide()

    -- Register immediately so the category appears even if widget setup fails.
    Settings.RegisterAddOnCategory(category)
    ItemTier.Config.CategoryID = category:GetID()

    -- ── layout helper ───────────────────────────────────────────────────────
    local lastCtrl = nil
    local function Place(frame, extraY)
        if lastCtrl then
            frame:SetPoint("TOPLEFT", lastCtrl, "BOTTOMLEFT", 0, extraY or -6)
        else
            frame:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, extraY or -6)
        end
        lastCtrl = frame
    end

    -- ── checkbox helper ─────────────────────────────────────────────────────
    local function AddCheckbox(label, tip, getter, setter)
        local cb = CreateFrame("CheckButton", nil, panel,
                               "InterfaceOptionsCheckButtonTemplate")
        cb.Text:SetText(label)
        cb.tooltipText        = label
        cb.tooltipRequirement = tip
        cb:SetScript("OnShow",  function(self) self:SetChecked(getter()) end)
        cb:SetScript("OnClick", function(self)
            setter(self:GetChecked())
            RequestBagWidgetRefresh()
        end)
        Place(cb)
    end

    -- ── controls ────────────────────────────────────────────────────────────
    AddCheckbox("Enable ItemTier",
        "Show upgrade track labels on bag item icons.",
        function() return ItemTier.DB and ItemTier.DB.enabled end,
        function(v) if ItemTier.DB then ItemTier.DB.enabled = v end end)

    AddCheckbox("Color-coded Labels",
        "Tint each label with the color of its upgrade track.",
        function() return ItemTier.DB and ItemTier.DB.useColors end,
        function(v)
            if ItemTier.DB then
                ItemTier.DB.useColors = v
                ItemTier.Cache.Clear()
            end
        end)

    AddCheckbox("Debug Output",
        "Print verbose debug messages to the chat frame.",
        function() return ItemTier.DB and ItemTier.DB.debug end,
        function(v) if ItemTier.DB then ItemTier.DB.debug = v end end)

    -- Display mode label
    local modeLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    modeLabel:SetText("Display Mode")
    Place(modeLabel, -12)

    -- Display mode dropdown
    local modeDD = CreateFrame("Frame", "ItemTierConfigModeDropdown",
                               panel, "UIDropDownMenuTemplate")
    modeDD:SetPoint("TOPLEFT", modeLabel, "BOTTOMLEFT", -15, -2)
    UIDropDownMenu_SetWidth(modeDD, 220)

    local modeChoices = {
        { value = "short",  text = "Short  (E / V / C ...)" },
        { value = "abbrev", text = "Abbreviated  (Expl / Vet / Chmp ...)" },
        { value = "full",   text = "Full  (Explorer / Veteran / Champion ...)" },
    }

    panel:HookScript("OnShow", function()
        UIDropDownMenu_Initialize(modeDD, function()
            for _, m in ipairs(modeChoices) do
                local info = UIDropDownMenu_CreateInfo()
                info.text  = m.text
                info.value = m.value
                info.func  = function(self)
                    if ItemTier.DB then
                        ItemTier.DB.displayMode = self.value
                        ItemTier.Cache.Clear()
                    end
                    UIDropDownMenu_SetSelectedValue(modeDD, self.value)
                    RequestBagWidgetRefresh()
                end
                UIDropDownMenu_AddButton(info)
            end
            UIDropDownMenu_SetSelectedValue(modeDD,
                (ItemTier.DB and ItemTier.DB.displayMode)
                or ItemTier.Constants.DefaultConfig.displayMode)
        end)
    end)
end

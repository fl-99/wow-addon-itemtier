-- ItemTier: Baganator icon-corner widget integration
--
-- Registers a corner widget with Baganator:
--   "itemtier_track" – compact text badge (default: bottom-right, priority 2)
--
-- The widgets appear in Baganator → Icon Settings / Icon Corners so the user
-- can assign them to any corner they prefer.
--
-- Registration is deferred until Baganator is fully loaded via ADDON_LOADED.

ItemTier = ItemTier or {}

-- ---------------------------------------------------------------------------
-- onInit – called once per item button to create the overlay frame/widget.
-- Returns a FontString. Setting .sizeFont = true lets Baganator provide its
-- configured base size; ItemTier's font-size multiplier is applied on refresh.
-- ---------------------------------------------------------------------------
local function OnInit(itemButton)
    local text = itemButton:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    text.sizeFont = true
    return text
end

local function IsAddonEnabled()
    local db = ItemTier.DB
    return db and db.enabled
end

local function GetFontScale()
    local db = ItemTier.DB
    if not db or not db.fontSize then return 1 end
    return db.fontSize
end

local function ApplyCornerDisplay(cornerText, track)
    local display = ItemTier.Scanner.GetDisplayData(track)
    if not display then return false end
    cornerText:SetText(display.text)
    cornerText:SetTextColor(display.r, display.g, display.b)
    cornerText:SetScale(GetFontScale())
    return true
end

-- ---------------------------------------------------------------------------
-- onUpdate – called on every item-button refresh.
-- Must return:
--   true  → show the widget
--   false → hide the widget
--   nil   → data not available yet (Baganator will retry)
-- ---------------------------------------------------------------------------
local function OnUpdate(cornerText, details)
    if not IsAddonEnabled() then
        return false
    end

    local track = ItemTier.Scanner.Resolve(details)
    if track == nil then
        -- Item data not yet available; let Baganator retry next frame.
        return nil
    end
    if not track then
        -- Confirmed: no upgrade track on this item.
        return false
    end

    return ApplyCornerDisplay(cornerText, track)
end

-- ---------------------------------------------------------------------------
-- Register with Baganator once it has finished loading.
-- ---------------------------------------------------------------------------
local function RegisterWithBaganator()
    local baganator = rawget(_G, "Baganator")
    if not (baganator and baganator.API and baganator.API.RegisterCornerWidget) then
        return
    end

    baganator.API.RegisterCornerWidget(
        "ItemTier: Track",   -- label shown in Baganator's icon-corner config
        "itemtier_track",    -- unique internal ID
        OnUpdate,
        OnInit,
        { corner = "bottom_right", priority = 2 }  -- default position
    )
end

-- Listen for ADDON_LOADED so we register at the right moment regardless of
-- load order.
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, addonName)
    if addonName == "Baganator" then
        RegisterWithBaganator()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- With OptionalDeps: Baganator, Baganator always loads before ItemTier when it
-- is installed, so ADDON_LOADED for "Baganator" has already fired by the time
-- this file runs.
local checkLoaded = C_AddOns and C_AddOns.IsAddOnLoaded
if checkLoaded and checkLoaded("Baganator") then
    RegisterWithBaganator()
    loader:UnregisterEvent("ADDON_LOADED")
end

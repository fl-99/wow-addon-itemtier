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
-- Returns a FontString.  Setting .sizeFont = true lets Baganator honour the
-- user-configured font-size setting automatically.
-- ---------------------------------------------------------------------------
local function OnInit(itemButton)
    local text = itemButton:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    text.sizeFont = true
    return text
end

-- ---------------------------------------------------------------------------
-- onUpdate – called on every item-button refresh.
-- Must return:
--   true  → show the widget
--   false → hide the widget
--   nil   → data not available yet (Baganator will retry)
-- ---------------------------------------------------------------------------
local function OnUpdate(cornerText, details)
    if not ItemTier.DB or not ItemTier.DB.enabled then
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

    local display = ItemTier.Scanner.GetDisplayData(track)
    if not display then return false end

    cornerText:SetText(display.text)
    cornerText:SetTextColor(display.r, display.g, display.b)
    return true
end

-- ---------------------------------------------------------------------------
-- Register with Baganator once it has finished loading.
-- ---------------------------------------------------------------------------
local function RegisterWithBaganator()
    if not (Baganator and Baganator.API and Baganator.API.RegisterCornerWidget) then
        return
    end

    Baganator.API.RegisterCornerWidget(
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
-- this file runs.  The global IsAddOnLoaded was moved to C_AddOns.IsAddOnLoaded
-- in 10.0, so we check both for forward- and backward-compatibility.
local checkLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
if checkLoaded and checkLoaded("Baganator") then
    RegisterWithBaganator()
    loader:UnregisterEvent("ADDON_LOADED")
end

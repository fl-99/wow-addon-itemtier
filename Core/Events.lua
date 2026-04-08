-- ItemTier: Event registration and cache invalidation

ItemTier = ItemTier or {}
ItemTier.Events = {}

local eventFrame = CreateFrame("Frame")

-- ---------------------------------------------------------------------------
-- BAG_UPDATE* family – invalidate cache so fresh items are re-scanned.
-- We only wipe the cache rather than individual slots because we don't track
-- which item link lives in which slot; the next Baganator onUpdate call
-- will re-resolve as needed.
-- ---------------------------------------------------------------------------
local function OnBagUpdate()
    ItemTier.Cache.Clear()
    -- Ask Baganator to refresh its item buttons if it's loaded.
    if Baganator and Baganator.API and Baganator.API.RequestItemButtonsRefresh then
        Baganator.API.RequestItemButtonsRefresh({
            Baganator.Constants
            and Baganator.Constants.RefreshReason
            and Baganator.Constants.RefreshReason.ItemWidgets
            or "ItemWidgets"
        })
    end
end

-- PLAYER_ENTERING_WORLD fires on login, reload, and zone changes.
-- Clear cache so item locations remain valid.
local function OnEnteringWorld()
    ItemTier.Cache.Clear()
end

eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        OnEnteringWorld()
    else
        OnBagUpdate()
    end
end)

-- ItemTier: Event registration and cache invalidation

ItemTier = ItemTier or {}
ItemTier.Events = {}

local eventFrame = CreateFrame("Frame")

local function ResolveBaganatorRefreshReason(baganator)
    local refreshReason = "ItemWidgets"
    local constants = baganator.Constants
    if not constants then return refreshReason end
    local reasons = constants.RefreshReason
    if not reasons then return refreshReason end
    if not reasons.ItemWidgets then return refreshReason end
    return reasons.ItemWidgets
end

local function RequestBaganatorRefresh()
    local baganator = rawget(_G, "Baganator")
    if not baganator then return end

    local api = baganator.API
    if not api then return end
    if not api.RequestItemButtonsRefresh then return end

    local refreshReason = ResolveBaganatorRefreshReason(baganator)
    api.RequestItemButtonsRefresh({ refreshReason })
end

local function RequestBlizzardBagRefresh()
    local blizzardBags = ItemTier.BlizzardBags
    if blizzardBags and blizzardBags.RefreshAll then
        blizzardBags.RefreshAll()
    end
end

-- ---------------------------------------------------------------------------
-- BAG_UPDATE* family – invalidate cache so fresh items are re-scanned.
-- We only wipe the cache rather than individual slots because we don't track
-- which item link lives in which slot; the next Baganator onUpdate call
-- will re-resolve as needed.
-- ---------------------------------------------------------------------------
local function OnBagUpdate()
    ItemTier.Cache.Clear()
    RequestBaganatorRefresh()
    RequestBlizzardBagRefresh()
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

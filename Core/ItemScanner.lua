-- ItemTier: Item analysis – resolves upgrade track / difficulty tier
--
-- Detection methods, in priority order:
--   1. C_ItemUpgrade.GetItemUpgradeInfo()   – most accurate for upgradeable gear
--   2. Tooltip text scan                    – authoritative when available
--   3. Bonus ID table lookup                – fallback when tooltip data unavailable

ItemTier = ItemTier or {}
ItemTier.Scanner = {}

local BonusIDToTrack = ItemTier.Constants.BonusIDToTrack
local TrackNames     = ItemTier.Constants.TrackNames

-- ---------------------------------------------------------------------------
-- Helpers: item-link parsing
-- ---------------------------------------------------------------------------

-- Extract the raw bonus-ID section from an item link.
-- Format: item:id:enc:gem1:gem2:gem3:gem4:suf:uid:lvl:spec:upgradeType
--              :diffID:numBonusIDs:bonusID1:bonusID2:…
local function GetBonusIDs(itemLink)
    if not itemLink then return nil end
    -- Strip colour codes / hyperlink wrappers so strsplit works cleanly.
    local plain = itemLink:match("item:[0-9:%-]+")
    if not plain then return nil end

    local parts = { strsplit(":", plain) }
    -- parts[1]  = "item"
    -- parts[14] = number of bonus IDs
    -- parts[15+] = individual bonus IDs
    local numBonus = tonumber(parts[14])
    if not numBonus or numBonus == 0 then return nil end

    local ids = {}
    for i = 1, numBonus do
        local id = tonumber(parts[14 + i])
        if id then ids[#ids + 1] = id end
    end
    return ids
end

-- ---------------------------------------------------------------------------
-- Method 1: C_ItemUpgrade API
-- Returns the track name string, or nil if unavailable.
-- ---------------------------------------------------------------------------
local function DetectViaUpgradeAPI(itemLocation)
    if not (C_ItemUpgrade and itemLocation) then return nil end
    if not C_ItemUpgrade.GetItemUpgradeInfo then return nil end
    if not C_Item.DoesItemExist(itemLocation) then return nil end

    local ok, info = pcall(C_ItemUpgrade.GetItemUpgradeInfo, itemLocation)
    if not ok or not info then return nil end

    -- The upgradeInfo table is an array of upgrade step entries.
    -- Each entry may carry a `bandTitle` (TWW naming) or `trackDescription`.
    if type(info.upgradeInfo) == "table" then
        for _, entry in ipairs(info.upgradeInfo) do
            local name = entry.bandTitle or entry.trackDescription or entry.trackName
            if name and name ~= "" then
                -- Clean up locale-suffixed strings like "Champion Track"
                for _, knownTrack in ipairs(TrackNames) do
                    if name:find(knownTrack, 1, true) then
                        return knownTrack
                    end
                end
                return name  -- Return raw if no known track matched
            end
        end
    end
    -- Some API versions return a top-level bandTitle
    local topName = info.bandTitle or info.trackName
    if topName and topName ~= "" then
        for _, knownTrack in ipairs(TrackNames) do
            if topName:find(knownTrack, 1, true) then
                return knownTrack
            end
        end
        return topName
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Method 3: Bonus ID table lookup
-- Returns the track name string, or nil.
-- ---------------------------------------------------------------------------
local function DetectViaBonusIDs(itemLink)
    local ids = GetBonusIDs(itemLink)
    if not ids then return nil end
    for _, id in ipairs(ids) do
        local track = BonusIDToTrack[id]
        if track then return track end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Method 2: Tooltip text scan
-- Returns the track name string, or nil.
-- ---------------------------------------------------------------------------
local function DetectViaTooltip(tooltipInfo)
    if not tooltipInfo then return nil end

    -- Pass 1: look for the explicit "Upgrade Level: <Track> …" tooltip line.
    -- This is the authoritative source (Champions show "Champion", not "Mythic").
    for _, row in ipairs(tooltipInfo.lines or {}) do
        local text = row.leftText
        if text then
            local candidate = text:match("%a[%a ]+[Ll]evel:%s*(%a+)")
            if candidate then
                if ItemTier.Constants.TrackInfo[candidate] then return candidate end
                local lower = candidate:lower()
                for _, knownTrack in ipairs(TrackNames) do
                    if lower == knownTrack:lower() then return knownTrack end
                end
            end
        end
    end

    -- Pass 2: whole-word scan – %f[%a]/%f[%A] prevents "Myth" matching "Mythic".
    for _, row in ipairs(tooltipInfo.lines or {}) do
        local text = row.leftText
        if text then
            for _, knownTrack in ipairs(TrackNames) do
                if text:find("%f[%a]" .. knownTrack .. "%f[%A]") then
                    return knownTrack
                end
            end
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Public: resolve the upgrade track for an item.
--
-- `details`  – the Baganator item-details table
--              (fields: itemLink, itemLocation, tooltipInfo, tooltipGetter)
--
-- Returns the track name string (e.g. "Champion"), or nil if unresolved,
-- or false if the item is confirmed to have no upgrade track.
-- ---------------------------------------------------------------------------
function ItemTier.Scanner.Resolve(details)
    if not details or not details.itemLink then return nil end
    local itemLink = details.itemLink

    -- Check cache first.
    -- Cache.Get returns false (confirmed no track), a track string, or nil (not cached).
    local cached = ItemTier.Cache.Get(itemLink)
    if cached ~= nil then
        return cached  -- false or track string – caller handles both
    end

    -- Only equipment-class items can carry upgrade tracks.
    -- If classID is nil the item data hasn't loaded yet; fall through and let
    -- the detection methods return nil (Baganator will retry next frame).
    local classID = select(6, C_Item.GetItemInfoInstant(itemLink))
    local isEquipment = (classID == Enum.ItemClass.Armor
                      or classID == Enum.ItemClass.Weapon
                      or classID == Enum.ItemClass.Profession)
    if classID and not isEquipment then
        ItemTier.Cache.Set(itemLink, false)
        return false
    end

    -- Method 1: upgrade API (requires item to be physically present in bags).
    local track = DetectViaUpgradeAPI(details.itemLocation)

    -- Method 2: tooltip scan – most reliable text source.
    -- Called eagerly via tooltipGetter() so that stale bonus IDs cannot
    -- override what the game itself reports (e.g. "Champion 1/6").
    if not track then
        local tipInfo = details.tooltipInfo
        if not tipInfo and details.tooltipGetter then
            tipInfo = details.tooltipGetter()
        end
        if tipInfo then
            track = DetectViaTooltip(tipInfo)
        end
    end

    -- Method 3: bonus ID table – fast fallback when tooltip data is not yet
    -- available (item not yet cached by the client).
    if not track then
        track = DetectViaBonusIDs(itemLink)
    end

    -- Cache the result (nil → false so we don't re-scan on every frame).
    ItemTier.Cache.Set(itemLink, track or false)

    if ItemTier.DB and ItemTier.DB.debug and track then
        print("|cff00ff00[ItemTier]|r", itemLink, "→", track)
    end

    return track
end

-- ---------------------------------------------------------------------------
-- Public: build the display label for a given track name.
-- Returns { text, r, g, b } or nil.
-- ---------------------------------------------------------------------------
function ItemTier.Scanner.GetDisplayData(track)
    if not track then return nil end
    local info = ItemTier.Constants.TrackInfo[track]
    if not info then
        -- Unknown track – show first letter
        return { text = track:sub(1,1), r = 1, g = 1, b = 1 }
    end

    local cfg = ItemTier.DB or ItemTier.Constants.DefaultConfig
    local mode = cfg.displayMode or "short"

    local text
    if mode == "full" then
        text = track
    elseif mode == "abbrev" then
        text = info.abbrev
    else  -- "short" (default)
        text = info.short
    end

    local r, g, b = 1, 1, 1
    if cfg.useColors and info.color then
        r, g, b = info.color[1], info.color[2], info.color[3]
    end

    return { text = text, r = r, g = g, b = b }
end

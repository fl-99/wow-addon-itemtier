-- ItemTier: Item-link keyed tier cache

ItemTier = ItemTier or {}
ItemTier.Cache = {}

-- Internal storage: itemLink -> { track = "Champion", timestamp = GetTime() }
local cache = {}

-- Entries older than this many seconds are considered stale.
local CACHE_TTL = 300  -- 5 minutes

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

-- Retrieve a cached entry for the given item link.
-- Returns the track string, or nil if no valid entry exists.
function ItemTier.Cache.Get(itemLink)
    local entry = cache[itemLink]
    if not entry then return nil end
    if (GetTime() - entry.timestamp) > CACHE_TTL then
        cache[itemLink] = nil
        return nil
    end
    return entry.track
end

-- Store a resolved track name for the given item link.
-- Pass nil or false to cache a "no track" result (prevents repeated scanning).
function ItemTier.Cache.Set(itemLink, track)
    cache[itemLink] = { track = track or false, timestamp = GetTime() }
end

-- Invalidate a single entry.
function ItemTier.Cache.Invalidate(itemLink)
    cache[itemLink] = nil
end

-- Wipe the entire cache (call on PLAYER_ENTERING_WORLD or major patch loads).
function ItemTier.Cache.Clear()
    wipe(cache)
end

-- Return the number of cached entries (for /itemtier debug).
function ItemTier.Cache.Size()
    local n = 0
    for _ in pairs(cache) do n = n + 1 end
    return n
end

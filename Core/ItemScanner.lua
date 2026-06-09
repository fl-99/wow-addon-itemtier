-- ItemTier: Item analysis – resolves upgrade track / difficulty tier

ItemTier = ItemTier or {}
ItemTier.Scanner = {}

local BonusIDToTrack = ItemTier.Constants.BonusIDToTrack
local TrackNames = ItemTier.Constants.TrackNames

local function MatchKnownTrack(name)
    if not name or name == "" then return nil end
    for _, knownTrack in ipairs(TrackNames) do
        if name:find(knownTrack, 1, true) then
            return knownTrack
        end
    end
    return name
end

local function FirstPresentValue(source, keys)
    for _, key in ipairs(keys) do
        local value = source[key]
        if value and value ~= "" then
            return value
        end
    end
    return nil
end

local function GetBonusIDs(itemLink)
    if not itemLink then return nil end
    local plain = itemLink:match("item:[0-9:%-]+")
    if not plain then return nil end

    local parts = { strsplit(":", plain) }
    local numBonus = tonumber(parts[14])
    if not numBonus then return nil end
    if numBonus == 0 then return nil end

    local function CollectNumericBonusIDs()
        local ids = {}
        for i = 1, numBonus do
            local id = tonumber(parts[14 + i])
            if id then
                ids[#ids + 1] = id
            end
        end
        return ids
    end

    return CollectNumericBonusIDs()
end

local function HasUpgradeAPI()
    if not C_ItemUpgrade then return false end
    if not C_ItemUpgrade.GetItemUpgradeInfo then return false end
    return true
end

local function IsItemAtLocation(itemLocation)
    if not C_Item then return false end
    local doesItemExist = C_Item.DoesItemExist
    if not doesItemExist then return false end
    return doesItemExist(itemLocation)
end

local function GetTrackFromUpgradeEntries(entries)
    if type(entries) ~= "table" then return nil end
    for _, entry in ipairs(entries) do
        local name = FirstPresentValue(entry, { "bandTitle", "trackDescription", "trackName" })
        local track = MatchKnownTrack(name)
        if track then return track end
    end
    return nil
end

local function CanUseUpgradeDetection(itemLocation)
    if not itemLocation then return false end
    if not HasUpgradeAPI() then return false end
    if not IsItemAtLocation(itemLocation) then return false end
    return true
end

local function DetectViaUpgradeAPI(itemLocation)
    if not CanUseUpgradeDetection(itemLocation) then return nil end

    local ok, info = pcall(C_ItemUpgrade.GetItemUpgradeInfo, itemLocation)
    if not ok then return nil end
    if not info then return nil end

    local entryTrack = GetTrackFromUpgradeEntries(info.upgradeInfo)
    if entryTrack then return entryTrack end

    local topName = FirstPresentValue(info, { "bandTitle", "trackName" })
    return MatchKnownTrack(topName)
end

local function DetectViaBonusIDs(itemLink)
    local ids = GetBonusIDs(itemLink)
    if not ids then return nil end
    for _, id in ipairs(ids) do
        local track = BonusIDToTrack[id]
        if track then return track end
    end
    return nil
end

local function NormalizeTooltipCandidate(candidate)
    if not candidate then return nil end
    if ItemTier.Constants.TrackInfo[candidate] then return candidate end
    local lower = candidate:lower()
    for _, knownTrack in ipairs(TrackNames) do
        if lower == knownTrack:lower() then
            return knownTrack
        end
    end
    return nil
end

local function DetectTooltipLevelLine(lines)
    for _, row in ipairs(lines) do
        local text = row.leftText
        if text then
            local candidate = text:match("%a[%a ]+[Ll]evel:%s*(%a+)")
            local normalized = NormalizeTooltipCandidate(candidate)
            if normalized then return normalized end
        end
    end
    return nil
end

local function DetectTooltipWordMatch(lines)
    for _, row in ipairs(lines) do
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

local function DetectViaTooltip(tooltipInfo)
    if not tooltipInfo then return nil end
    local lines = tooltipInfo.lines
    if not lines then lines = {} end

    local fromLevel = DetectTooltipLevelLine(lines)
    if fromLevel then return fromLevel end
    return DetectTooltipWordMatch(lines)
end

local function IsEquipmentClass(classID)
    if classID == Enum.ItemClass.Armor then return true end
    if classID == Enum.ItemClass.Weapon then return true end
    if classID == Enum.ItemClass.Profession then return true end
    return false
end

local function GetTooltipInfo(details)
    if details.tooltipInfo then return details.tooltipInfo end
    local tooltipGetter = details.tooltipGetter
    if not tooltipGetter then return nil end
    return tooltipGetter()
end

local function GetItemLink(details)
    if not details then return nil end
    return details.itemLink
end

local function DetectTrack(details, itemLink)
    local track = DetectViaUpgradeAPI(details.itemLocation)
    if track then return track end

    local tooltipInfo = GetTooltipInfo(details)
    if tooltipInfo then
        track = DetectViaTooltip(tooltipInfo)
    end
    if track then return track end

    return DetectViaBonusIDs(itemLink)
end

local function CacheTrack(itemLink, track)
    if track then
        ItemTier.Cache.Set(itemLink, track)
        return
    end
    ItemTier.Cache.Set(itemLink, false)
end

local function DebugTrack(itemLink, track)
    local db = ItemTier.DB
    if not db then return end
    if not db.debug then return end
    if not track then return end
    print("|cff00ff00[ItemTier]|r", itemLink, "→", track)
end

local function GetDisplayConfig()
    local cfg = ItemTier.DB
    if cfg then return cfg end
    return ItemTier.Constants.DefaultConfig
end

local function ResolveDisplayModeText(track, info, mode)
    if mode == "full" then return track end
    if mode == "abbrev" then return info.abbrev end
    return info.short
end

local function ResolveDisplayColor(cfg, info)
    if not cfg.useColors then return 1, 1, 1 end
    local color = info.color
    if not color then return 1, 1, 1 end
    return color[1], color[2], color[3]
end

function ItemTier.Scanner.Resolve(details)
    local itemLink = GetItemLink(details)
    if not itemLink then return nil end

    local cached = ItemTier.Cache.Get(itemLink)
    if cached ~= nil then return cached end

    local classID = select(6, C_Item.GetItemInfoInstant(itemLink))
    if classID then
        if not IsEquipmentClass(classID) then
            ItemTier.Cache.Set(itemLink, false)
            return false
        end
    end

    local track = DetectTrack(details, itemLink)
    CacheTrack(itemLink, track)
    DebugTrack(itemLink, track)
    return track
end

function ItemTier.Scanner.GetDisplayData(track)
    if not track then return nil end

    local info = ItemTier.Constants.TrackInfo[track]
    if not info then
        return { text = track:sub(1, 1), r = 1, g = 1, b = 1 }
    end

    local cfg = GetDisplayConfig()
    local mode = cfg.displayMode
    if not mode then mode = "short" end

    local text = ResolveDisplayModeText(track, info, mode)
    local r, g, b = ResolveDisplayColor(cfg, info)
    return { text = text, r = r, g = g, b = b }
end

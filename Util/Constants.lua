-- ItemTier: Constants and tier data tables

ItemTier = ItemTier or {}
ItemTier.Constants = {}

-- ---------------------------------------------------------------------------
-- Upgrade-track definitions
-- Each entry maps a bonus ID to tier metadata used for display.
--
-- TODO: Verify / extend these bonus IDs against live TWW patch 12.0.1.
--       Bonus IDs for upcoming seasons will need additions here.
--       Reference: https://www.wowhead.com/item-bonus-ids
--
-- TWW Season 1 upgrade-track bonus IDs (11.0.2 – present)
-- ---------------------------------------------------------------------------
ItemTier.Constants.BonusIDToTrack = {
    -- Explorer track
    [10320] = "Explorer", [10321] = "Explorer", [10322] = "Explorer",
    [10323] = "Explorer", [10324] = "Explorer", [10325] = "Explorer",
    -- Adventurer track
    [10326] = "Adventurer", [10327] = "Adventurer", [10328] = "Adventurer",
    [10329] = "Adventurer", [10330] = "Adventurer", [10331] = "Adventurer",
    -- Veteran track
    [10332] = "Veteran", [10333] = "Veteran", [10334] = "Veteran",
    [10335] = "Veteran", [10336] = "Veteran", [10337] = "Veteran",
    -- Champion track
    [10338] = "Champion", [10339] = "Champion", [10340] = "Champion",
    [10341] = "Champion", [10342] = "Champion", [10343] = "Champion",
    -- Hero track
    [10344] = "Hero", [10345] = "Hero", [10346] = "Hero",
    [10347] = "Hero", [10348] = "Hero", [10349] = "Hero",
    -- Myth track
    [10350] = "Myth", [10351] = "Myth", [10352] = "Myth",
    [10353] = "Myth", [10354] = "Myth", [10355] = "Myth",
    -- Dragonflight Season 3/4 bonus IDs kept for cached items
    [10222] = "Explorer",   [10225] = "Explorer",   [10228] = "Explorer",
    [10223] = "Adventurer", [10226] = "Adventurer", [10229] = "Adventurer",
    [10224] = "Veteran",    [10227] = "Veteran",    [10230] = "Veteran",
    [10246] = "Champion",   [10249] = "Champion",   [10252] = "Champion",
    [10247] = "Hero",       [10250] = "Hero",       [10253] = "Hero",
    [10248] = "Myth",       [10251] = "Myth",       [10254] = "Myth",
}

-- ---------------------------------------------------------------------------
-- Per-track display metadata
-- ---------------------------------------------------------------------------
ItemTier.Constants.TrackInfo = {
    Explorer   = { short = "E",  abbrev = "Expl", color = {0.60, 0.60, 0.60} },
    Adventurer = { short = "A",  abbrev = "Adv",  color = {0.12, 0.78, 0.12} },
    Veteran    = { short = "V",  abbrev = "Vet",  color = {0.00, 0.44, 0.87} },
    Champion   = { short = "C",  abbrev = "Chmp", color = {0.64, 0.21, 0.93} },
    Hero       = { short = "H",  abbrev = "Hero", color = {0.88, 0.38, 0.00} },
    Myth       = { short = "M",  abbrev = "Myth", color = {0.88, 0.78, 0.35} },
    -- PvP tracks
    PvP        = { short = "P",  abbrev = "PvP",  color = {0.88, 0.10, 0.10} },
    Aspirant   = { short = "As", abbrev = "Asp",  color = {0.80, 0.10, 0.10} },
    Combatant  = { short = "Co", abbrev = "Comb", color = {0.85, 0.10, 0.10} },
    Challenger = { short = "Ch", abbrev = "Chal", color = {0.90, 0.10, 0.10} },
    Rival      = { short = "Ri", abbrev = "Rivl", color = {0.95, 0.10, 0.10} },
    Duelist    = { short = "Du", abbrev = "Duel", color = {1.00, 0.20, 0.20} },
    Gladiator  = { short = "Gl", abbrev = "Glad", color = {1.00, 0.40, 0.40} },
}

-- Ordered list for fallback substring search (longest first to avoid false matches)
ItemTier.Constants.TrackNames = {
    "Gladiator", "Combatant", "Challenger", "Aspirant",
    "Adventurer", "Champion", "Veteran", "Explorer",
    "Duelist", "Rival", "Hero", "Myth", "PvP",
}

-- ---------------------------------------------------------------------------
-- Display mode identifiers
-- ---------------------------------------------------------------------------
ItemTier.Constants.DisplayMode = {
    SHORT  = "short",   -- single letter  : M
    ABBREV = "abbrev",  -- abbreviated     : Myth
    FULL   = "full",    -- full word       : Myth  (same as abbrev for most)
}

-- ---------------------------------------------------------------------------
-- Default saved-variable config
-- ---------------------------------------------------------------------------
ItemTier.Constants.DefaultConfig = {
    enabled         = true,
    displayMode     = "short",   -- "short" | "abbrev" | "full"
    useColors       = true,
    fontSize        = 1.0,       -- multiplier applied to the font string scale
    debug           = false,
}

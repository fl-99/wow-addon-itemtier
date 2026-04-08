# ItemTier

A World of Warcraft addon (**Retail 12.0.1 / The War Within**) that displays a compact upgrade-track or difficulty-tier badge on bag item buttons via a **Baganator icon-corner widget**.

---

## Features

- Registers a **Baganator icon-corner widget** ("ItemTier: Track") selectable in  
  *Baganator → Icon Settings / Icon Corners*.
- Detects the item upgrade track (Explorer → Myth) and PvP tracks, using multiple  
  detection strategies in priority order:
  1. `C_ItemUpgrade.GetItemUpgradeInfo()` — most accurate for live bag items
  2. Bonus-ID lookup table — fast, works from the item link alone
  3. Tooltip text scan — last resort, lazy and cached
- Three display modes: **short** (`M`), **abbrev** (`Myth`), **full** (`Myth`)
- Color-coded labels per track.
- Lightweight: item links are cached; cache is cleared on `BAG_UPDATE`.
- Fails gracefully when Baganator is not installed.

---

## Installation

1. Copy the `ItemTier` folder into  
   `World of Warcraft/_retail_/Interface/AddOns/`
2. Enable **ItemTier** in the WoW AddOns list.
3. Open Baganator, go to **Icon Settings → Icon Corners**, and assign  
   *ItemTier: Track* to your preferred corner.

---

## Slash Commands

```
/itemtier                     Show help
/itemtier enable|disable      Toggle the addon on or off
/itemtier mode short|abbrev|full  Change display mode
/itemtier colors on|off       Toggle color-coded labels
/itemtier debug on|off        Print resolved tracks to chat
/itemtier cache clear         Wipe the item-tier cache
/itemtier cache size          Show current cache entry count
/itemtier status              Print current settings
```

---

## Project Structure

```
ItemTier/
├── ItemTier.toc               TOC for Retail 12.0.1
├── ItemTier.lua               Main entry point / ADDON_LOADED bootstrap
├── Util/
│   └── Constants.lua          Tier names, colors, abbreviations, bonus-ID table
├── Core/
│   ├── Init.lua               Namespace setup, SavedVariables defaults
│   ├── Events.lua             BAG_UPDATE / PLAYER_ENTERING_WORLD wiring
│   ├── ItemScanner.lua        Upgrade-track resolution (all three methods)
│   └── Cache.lua              Item-link keyed result cache (TTL 5 min)
├── Integrations/
│   └── Baganator.lua          RegisterCornerWidget call + onInit / onUpdate
└── UI/
    └── Config.lua             /itemtier slash-command handler
```

---

## Baganator Integration

ItemTier uses the public **`Baganator.API.RegisterCornerWidget`** API.  
The widget is registered after Baganator's `ADDON_LOADED` event fires,  
so load order does not matter.

The `onUpdate` callback receives Baganator's `details` table for each item button:

| Field | Used for |
|---|---|
| `details.itemLink` | cache key, bonus-ID parsing |
| `details.itemLocation` | `C_ItemUpgrade.GetItemUpgradeInfo()` call |
| `details.tooltipInfo` | tooltip-text fallback (if already fetched) |

---

## API Uncertainty & Known Limitations

### Bonus IDs

Upgrade-track bonus IDs **change each WoW season**.  The table in  
`Util/Constants.lua` ships with best-effort values for **TWW Season 1**  
(patch 11.0.2 – 12.0.x) and previously confirmed Dragonflight Season 3/4  
IDs for cached items.

> **TODO:** Verify all bonus IDs against live servers for 12.0.1.66838.  
> Update `ItemTier.Constants.BonusIDToTrack` when new seasons launch.

### C_ItemUpgrade

`C_ItemUpgrade.GetItemUpgradeInfo()` returns different struct layouts  
depending on the patch.  The scanner attempts multiple field names  
(`bandTitle`, `trackDescription`, `trackName`) to remain resilient.  Items  
that Blizzard does not mark as upgradeable (crafted legendaries, PvP  
vendor items) will not be detected by this method; bonus-ID or tooltip  
scanning acts as the fallback.

### Difficulty / Source tier

Raid difficulty (Normal / Heroic / Mythic / LFR) and Mythic+ level detection  
are **not yet implemented**.  The `instanceDifficultyID` field in the item link  
and M+ keystone bonus IDs are the intended data sources for a future  
"ItemTier: Difficulty" widget.

---

## Configuration (Saved Variables)

All settings live in the `ItemTierDB` SavedVariables table:

| Key | Type | Default | Description |
|---|---|---|---|
| `enabled` | boolean | `true` | Master on/off switch |
| `displayMode` | string | `"short"` | `"short"` \| `"abbrev"` \| `"full"` |
| `useColors` | boolean | `true` | Color-code the badge text |
| `fontSize` | number | `1.0` | Font scale multiplier (Baganator controls actual size) |
| `debug` | boolean | `false` | Print resolved tracks to chat |

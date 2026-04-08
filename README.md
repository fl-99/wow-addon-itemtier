# ItemTier

A World of Warcraft addon (**Retail 12.0.1**) that displays a compact **upgrade-track** badge on bag item buttons via a **Baganator icon-corner widget**.

---

## Features

- Registers a **Baganator icon-corner widget** ("ItemTier: Track") selectable in  
  *Baganator → Icon Settings / Icon Corners*.
- Adds a **vanilla Options → AddOns** panel for in-game configuration.
- Detects the item upgrade track (Explorer → Myth) and PvP tracks, using multiple  
  detection strategies in priority order:
  1. `C_ItemUpgrade.GetItemUpgradeInfo()` — most accurate for live bag items
  2. Tooltip text scan (`Upgrade Level: ...`) — authoritative fallback
  3. Bonus-ID lookup table — fast fallback when tooltip data is unavailable
- Three display modes: **short** (`V`), **abbrev** (`Vet`), **full** (`Veteran`)
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
/itemtier                     Open ItemTier options (or show help if unavailable)
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
  └── Config.lua             /itemtier slash commands + AddOns settings panel
```

---

## Baganator Integration

ItemTier uses the public **`Baganator.API.RegisterCornerWidget`** API.  
The widget is registered either on Baganator's `ADDON_LOADED` event or
immediately if Baganator is already loaded (including `C_AddOns.IsAddOnLoaded`
compat handling).

The `onUpdate` callback receives Baganator's `details` table for each item button:

| Field | Used for |
|---|---|
| `details.itemLink` | cache key, bonus-ID parsing |
| `details.itemLocation` | `C_ItemUpgrade.GetItemUpgradeInfo()` call |
| `details.tooltipInfo` / `details.tooltipGetter` | tooltip fallback (`Upgrade Level: ...`) |

---

## API Uncertainty & Known Limitations

### Bonus IDs

Upgrade-track bonus IDs **change each WoW season**.  The table in  
`Util/Constants.lua` ships with best-effort values for **TWW Season 1**  
(patch 11.0.2 – 12.0.x) and previously confirmed Dragonflight Season 3/4  
IDs for cached items.

> **TODO:** Verify all bonus IDs against live servers for 12.0.1.66838.  
> Update `ItemTier.Constants.BonusIDToTrack` when new seasons launch.

### C_ItemUpgrade and Tooltip Fallback

`C_ItemUpgrade.GetItemUpgradeInfo()` returns different struct layouts  
depending on the patch.  The scanner attempts multiple field names  
(`bandTitle`, `trackDescription`, `trackName`) to remain resilient.  Items  
that Blizzard does not mark as upgradeable (crafted legendaries, PvP  
vendor items) will not be detected by this method; tooltip scanning and
bonus-ID lookup act as fallbacks.

### Difficulty / Source tier

Raid difficulty (Normal / Heroic / Mythic / LFR) and Mythic+ level detection  
are **not yet implemented**.  The `instanceDifficultyID` field in the item link  
and M+ keystone bonus IDs are the intended data sources for a future  
"ItemTier: Difficulty" widget.

---

## In-Game Options

ItemTier registers a category under **Options → AddOns → ItemTier**.

Available toggles/options:

- Enable ItemTier
- Color-coded Labels
- Debug Output
- Display Mode (short / abbrev / full)

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

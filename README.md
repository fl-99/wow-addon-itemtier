# ItemTier

A World of Warcraft addon that displays compact **upgrade-track** badges (Hero, Myth, etc.) on item icons.

---

## Features

- Shows upgrade-track badges on **Blizzard default bags** (including separate bag windows).
- Shows upgrade-track badges on the **character panel** equipped slots.
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
- Works standalone; Baganator integration is optional.

---

## Installation

### Recommended way

Use Curseforge! You can find the project here: https://www.curseforge.com/wow/addons/itemtier.

### Manual way

1. Copy the `ItemTier` folder into  
   `World of Warcraft/_retail_/Interface/AddOns/`
2. Enable **ItemTier** in the WoW AddOns list.
3. Optional (Baganator): Open **Icon Settings → Icon Corners** and assign  
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

Upgrade-track bonus IDs **change each WoW season**. The table in  
`Util/Constants.lua` includes best-effort mappings for current supported data,
plus previously confirmed Dragonflight IDs for cached items.

Action item:
- Re-validate `ItemTier.Constants.BonusIDToTrack` at each seasonal reset and
  update mappings when Blizzard introduces new track bonus IDs.

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

Action item:
- Add an optional second widget for source/difficulty once mapping coverage is
  validated for raid and Mythic+ loot sources.

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

---

## Local Development

For local development, you can create a zip with the same top-level addon
folder layout used for CurseForge releases (`ItemTier/...`).

Run from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\package-addon.ps1
```

Output:

- Zip file in `dist/` (default name: `ItemTier-<version>.zip`)
- `@project-version@` in `ItemTier.toc` is replaced in the packaged copy
  with a local version string (`git describe --tags --always --dirty`, or
  `local-dev` fallback)

Useful options:

```powershell
# Custom output folder and zip name
powershell -ExecutionPolicy Bypass -File .\scripts\package-addon.ps1 -OutputDir release -ZipName ItemTier-dev.zip

# Force-clean output folder before packaging
powershell -ExecutionPolicy Bypass -File .\scripts\package-addon.ps1 -CleanOutput

# Override version token replacement value
powershell -ExecutionPolicy Bypass -File .\scripts\package-addon.ps1 -ProjectVersion 12.0.5-dev
```


---

## Releasing to CurseForge

CurseForge publishing is handled by GitHub Actions in `.github/workflows/release.yml`.
The pipeline is triggered when you push a tag that matches:

`release-*`

Example release flow:

```powershell
# 1) Create a release tag
git --no-pager tag release-<YEAR>.<NUMBER>

# 2) Push the tag to GitHub (this triggers the CurseForge pipeline)
git --no-pager push origin release-<YEAR>.<NUMBER>
```

Then check the workflow run in GitHub Actions (**CurseForge Release**).

Prerequisite: repository secret `CF_API_KEY` must be configured for publishing.

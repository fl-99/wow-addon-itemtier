-- ItemTier: Addon namespace and saved-variable initialisation

ItemTier = ItemTier or {}

-- Filled on ADDON_LOADED once SavedVariables are available.
ItemTier.DB = nil

-- Merge in any missing keys from `defaults` into `target` (shallow).
local function ApplyDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if target[k] == nil then
            target[k] = v
        end
    end
end

-- Called by ItemTier.lua when ADDON_LOADED fires for "ItemTier".
function ItemTier.Init()
    -- ItemTierDB is the SavedVariables table declared in the .toc.
    if type(ItemTierDB) ~= "table" then ItemTierDB = {} end
    ApplyDefaults(ItemTierDB, ItemTier.Constants.DefaultConfig)
    ItemTier.DB = ItemTierDB

    -- Build the vanilla Options → AddOns settings panel now that
    -- SavedVariables are available and all files have been loaded.
    ItemTier.Config.BuildSettingsPanel()
end

-- ItemTier: Blizzard default bag integration
--
-- Adds a compact track badge to default Blizzard bag item buttons so the addon
-- works without Baganator.

ItemTier = ItemTier or {}
ItemTier.BlizzardBags = ItemTier.BlizzardBags or {}

-- All known Blizzard container frame global names in TWW/Dragonflight.
-- ContainerFrameCombinedBags is the combined backpack; ContainerFrame1-6 are
-- individual bag windows; ContainerFrame6 is typically the reagent bag.
local CONTAINER_FRAME_NAMES = {
    "ContainerFrameCombinedBags",
    "ContainerFrame1",
    "ContainerFrame2",
    "ContainerFrame3",
    "ContainerFrame4",
    "ContainerFrame5",
    "ContainerFrame6",
}

-- Track which frames have already had UpdateItems hooked to avoid duplicates.
-- Keys are stable string identifiers only (no frame object keys).
local hookedFrames = {}
local mixinHooksInstalled = false

local BAG_ID_FIELDS = { "bagID", "BagID", "bag", "container" }
local SLOT_FIELDS = { "slotIndex", "slot", "Slot", "slotID", "containerSlotID" }
local LEGACY_ITEM_BUTTON_PATTERNS = {
    "^ContainerFrame%d+Item%d+$",
    "^ContainerFrameCombinedBagsItem%d+$",
    "^ContainerFrameReagentBagItem%d+$",
    "^ContainerFrameCombinedBagsItemButton%d+$",
    "^ContainerFrame%d+ItemButton%d+$",
}

local function GetMethodValue(obj, methodName)
    if not obj then return nil end
    local method = obj[methodName]
    if type(method) ~= "function" then return nil end
    return method(obj)
end

local function GetFirstFieldValue(obj, fields)
    if not obj then return nil end
    for _, field in ipairs(fields) do
        local value = obj[field]
        if value ~= nil then
            return value
        end
    end
    return nil
end

local function ResolveBagIDFromObject(obj)
    local bagID = GetMethodValue(obj, "GetBagID")
    if bagID ~= nil then return bagID end
    return GetFirstFieldValue(obj, BAG_ID_FIELDS)
end

local function ResolveSlotFromButton(button)
    local slot = GetMethodValue(button, "GetID")
    if slot ~= nil then return slot end
    slot = GetMethodValue(button, "GetSlotIndex")
    if slot ~= nil then return slot end
    return GetFirstFieldValue(button, SLOT_FIELDS)
end

local function ResolveBagIDFromParentChain(button)
    local current = nil
    if button then
        if button.GetParent then
            current = button:GetParent()
        end
    end
    for _ = 1, 2 do
        if not current then break end
        local bagID = ResolveBagIDFromObject(current)
        if bagID ~= nil then return bagID end
        if current.GetParent then
            current = current:GetParent()
        else
            current = nil
        end
    end
    return nil
end

local function GetFontScale()
    local db = ItemTier.DB
    if not db then return 1 end
    if not db.fontSize then return 1 end
    return db.fontSize
end

local function GetItemLocationFromButton(button)
    local itemLocation = GetMethodValue(button, "GetItemLocation")
    if itemLocation then return itemLocation end
    return button.itemLocation
end

local function ResolveBagSlotFromItemLocation(button)
    local itemLocation = GetItemLocationFromButton(button)
    if not itemLocation then return nil, nil end
    if not itemLocation.GetBagAndSlot then return nil, nil end

    local isBagAndSlot = true
    if itemLocation.IsBagAndSlot then
        isBagAndSlot = itemLocation:IsBagAndSlot()
    end
    if not isBagAndSlot then return nil, nil end

    local bagID, slot = itemLocation:GetBagAndSlot()
    if type(bagID) ~= "number" or type(slot) ~= "number" then
        return nil, nil
    end
    return bagID, slot
end

local function EnsureOverlay(button)
    if not button or button.ItemTierTrackText then return end

    -- Match character panel badge proportions.
    local text = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    text:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    text:SetJustifyH("RIGHT")
    text:SetScale(GetFontScale())

    button.ItemTierTrackText = text
end

local function HideOverlay(button)
    if button and button.ItemTierTrackText then
        button.ItemTierTrackText:SetText("")
        button.ItemTierTrackText:Hide()
    end
end

local function ResolveBagSlot(button)
    if not button then return nil, nil end

    local itemLocationBag, itemLocationSlot = ResolveBagSlotFromItemLocation(button)
    if itemLocationBag then
        if itemLocationSlot then
            return itemLocationBag, itemLocationSlot
        end
    end

    local bagID = ResolveBagIDFromObject(button)
    if bagID == nil then
        bagID = ResolveBagIDFromParentChain(button)
    end
    local slot = ResolveSlotFromButton(button)

    if type(bagID) ~= "number" or type(slot) ~= "number" then
        return nil, nil
    end
    return bagID, slot
end

local function BuildDetails(bagID, slot)
    if not C_Container then return nil end
    if not C_Container.GetContainerItemLink then return nil end

    local itemLink = C_Container.GetContainerItemLink(bagID, slot)
    if not itemLink then return nil end

    local details = {
        itemLink = itemLink,
    }

    local createFromBagAndSlot = nil
    if ItemLocation then
        createFromBagAndSlot = ItemLocation.CreateFromBagAndSlot
    end
    if createFromBagAndSlot then
        details.itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slot)
    end

    local getBagItem = nil
    if C_TooltipInfo then
        getBagItem = C_TooltipInfo.GetBagItem
    end
    if getBagItem then
        details.tooltipGetter = function()
            return getBagItem(bagID, slot)
        end
    end

    return details
end

local function IsValidItemLocation(itemLocation)
    if not itemLocation then return false end
    if not itemLocation.GetBagAndSlot then return false end

    local bagID, slot = itemLocation:GetBagAndSlot()
    if type(bagID) ~= "number" or type(slot) ~= "number" then return false end

    -- Verify there is actually an item at this bag+slot.
    local getContainerItemLink = nil
    if C_Container then
        getContainerItemLink = C_Container.GetContainerItemLink
    end
    if getContainerItemLink then
        return getContainerItemLink(bagID, slot) ~= nil
    end

    return true
end

local function ResolveItemLocation(button)
    if not button then return nil end

    local itemLocation = GetItemLocationFromButton(button)
    if not itemLocation then return nil end

    if itemLocation.IsBagAndSlot then
        if not itemLocation:IsBagAndSlot() then
            return nil
        end
    end

    if not IsValidItemLocation(itemLocation) then
        return nil
    end

    return itemLocation
end

local function BuildDetailsFromItemLocation(itemLocation)
    if not itemLocation then return nil end
    if not C_Item then return nil end
    if not C_Item.GetItemLink then return nil end

    local itemLink
    local ok = pcall(function()
        itemLink = C_Item.GetItemLink(itemLocation)
    end)

    if not ok then return nil end
    if not itemLink then return nil end

    local details = {
        itemLink = itemLink,
        itemLocation = itemLocation,
    }

    local getBagItem = nil
    if C_TooltipInfo then
        getBagItem = C_TooltipInfo.GetBagItem
    end
    if getBagItem then
        if itemLocation.GetBagAndSlot then
            local bagID, slot = itemLocation:GetBagAndSlot()
            if type(bagID) == "number" then
                if type(slot) == "number" then
                    details.tooltipGetter = function()
                        return getBagItem(bagID, slot)
                    end
                    return details
                end
            end
        end
    end

    local getHyperlink = nil
    if C_TooltipInfo then
        getHyperlink = C_TooltipInfo.GetHyperlink
    end
    if getHyperlink then
        details.tooltipGetter = function()
            return getHyperlink(itemLink)
        end
    end

    return details
end

local function IsAddonEnabled()
    local db = ItemTier.DB
    return db and db.enabled
end

local function ResolveDetailsForButton(button)
    local itemLocation = ResolveItemLocation(button)
    if itemLocation then
        local byLocation = BuildDetailsFromItemLocation(itemLocation)
        if byLocation then return byLocation end
    end

    local bagID, slot = ResolveBagSlot(button)
    if bagID then
        if slot then
            return BuildDetails(bagID, slot)
        end
    end
    return nil
end

local function UpdateButton(button)
    if not button then return end

    EnsureOverlay(button)

    if not IsAddonEnabled() then
        HideOverlay(button)
        return
    end

    local details = ResolveDetailsForButton(button)
    if not details then
        HideOverlay(button)
        return
    end

    local track = ItemTier.Scanner.Resolve(details)
    if not track then
        HideOverlay(button)
        return
    end

    local display = ItemTier.Scanner.GetDisplayData(track)
    if not display then
        HideOverlay(button)
        return
    end

    button.ItemTierTrackText:SetText(display.text)
    button.ItemTierTrackText:SetTextColor(display.r, display.g, display.b)
    button.ItemTierTrackText:SetScale(GetFontScale())
    button.ItemTierTrackText:Show()
end

local function RefreshContainerFrame(frame)
    if not frame or not frame.EnumerateValidItems then
        return
    end

    for itemButton in frame:EnumerateValidItems() do
        UpdateButton(itemButton)
    end
end

local function IsLegacyContainerButton(name, frame)
    for _, pattern in ipairs(LEGACY_ITEM_BUTTON_PATTERNS) do
        if name:match(pattern) then
            return true
        end
    end
    if frame.GetBagID and name:match("^ContainerFrame") then
        return true
    end
    return false
end

local function IsButtonFrame(frame)
    if not frame then return false end
    if not frame.GetObjectType then return false end
    return frame:GetObjectType() == "Button"
end

function ItemTier.BlizzardBags.RefreshAll()
    for _, frameName in ipairs(CONTAINER_FRAME_NAMES) do
        RefreshContainerFrame(_G[frameName])
    end

    if ContainerFrameUtil_EnumerateContainerFrames then
        for containerFrame in ContainerFrameUtil_EnumerateContainerFrames() do
            RefreshContainerFrame(containerFrame)
        end
    end

    for name, frame in pairs(_G) do
        if type(name) == "string" then
            if IsButtonFrame(frame) then
                if IsLegacyContainerButton(name, frame) then
                    UpdateButton(frame)
                end
            end
        end
    end
end

local function HookContainerFrameUpdateItems()
    local function HookSingleFrame(frame, frameKey)
        if not frame then return end
        if hookedFrames[frameKey] then return end
        if not frame.UpdateItems then return end

        local capturedFrame = frame
        hooksecurefunc(frame, "UpdateItems", function()
            RefreshContainerFrame(capturedFrame)
        end)

        hookedFrames[frameKey] = true
    end

    for _, frameName in ipairs(CONTAINER_FRAME_NAMES) do
        HookSingleFrame(_G[frameName], frameName)
    end

    if ContainerFrameUtil_EnumerateContainerFrames then
        for containerFrame in ContainerFrameUtil_EnumerateContainerFrames() do
            local frameKey = tostring(containerFrame)
            if containerFrame.GetName then
                local frameName = containerFrame:GetName()
                if frameName and frameName ~= "" then
                    frameKey = frameName
                end
            end
            HookSingleFrame(containerFrame, frameKey)
        end
    end
end

local function HookMixinMethod(target, methodName, callback)
    if not target then return false end
    if not target[methodName] then return false end
    hooksecurefunc(target, methodName, callback)
    return true
end

local function HookContainerButtonMixin()
    local hookedAny = false
    if not ContainerFrameItemButtonMixin then return hookedAny end

    for _, method in ipairs({ "UpdateItemDetails", "Update" }) do
        if HookMixinMethod(ContainerFrameItemButtonMixin, method, UpdateButton) then
            hookedAny = true
        end
    end

    return hookedAny
end

local function HookSetBagMethods()
    local hookedAny = false
    if not ContainerFrameItemButtonMixin then return hookedAny end
    for _, method in ipairs({ "SetBagID", "SetBagAndSlot" }) do
        if HookMixinMethod(ContainerFrameItemButtonMixin, method, function(button)
            UpdateButton(button)
        end) then
            hookedAny = true
        end
    end
    return hookedAny
end

local function HookItemButtonMixinSetItem()
    if not ItemButtonMixin then return false end
    return HookMixinMethod(ItemButtonMixin, "SetItem", UpdateButton)
end

local function HookLegacyButtonUpdate()
    local buttonUpdateFn = rawget(_G, "ContainerFrameItemButton_Update")
    if type(buttonUpdateFn) ~= "function" then return false end
    hooksecurefunc("ContainerFrameItemButton_Update", UpdateButton)
    return true
end

local function TryMixinHooks()
    if mixinHooksInstalled then return end

    local anyHooked = HookContainerButtonMixin()
    if HookSetBagMethods() then
        anyHooked = true
    end

    if HookItemButtonMixinSetItem() then
        anyHooked = true
    end
    if HookLegacyButtonUpdate() then
        anyHooked = true
    end

    if anyHooked then
        mixinHooksInstalled = true
    end
end

local function SetupHooks()
    if ItemTier.BlizzardBags.HooksInstalled then return end

    TryMixinHooks()
    HookContainerFrameUpdateItems()

    for _, fnName in ipairs({ "ToggleBag", "ToggleBackpack", "OpenAllBags" }) do
        if type(rawget(_G, fnName)) == "function" then
            hooksecurefunc(fnName, function()
                ItemTier.BlizzardBags.RefreshAll()
            end)
        end
    end

    ItemTier.BlizzardBags.HooksInstalled = true
    ItemTier.BlizzardBags.RefreshAll()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("BAG_UPDATE_DELAYED")
loader:RegisterEvent("BAG_UPDATE")
loader:RegisterEvent("BAG_NEW_ITEMS_UPDATED")
loader:RegisterEvent("ITEM_LOCK_CHANGED")
loader:RegisterEvent("INVENTORY_SEARCH_UPDATE")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" then
        if addonName == "ItemTier" then
            SetupHooks()
        elseif addonName == "Blizzard_Bags" then
            -- Retry mixin hooks now that Blizzard_Bags is fully loaded.
            TryMixinHooks()
            HookContainerFrameUpdateItems()
            ItemTier.BlizzardBags.RefreshAll()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Re-attempt hooks in case frames weren't ready at ADDON_LOADED.
        TryMixinHooks()
        HookContainerFrameUpdateItems()
        ItemTier.BlizzardBags.RefreshAll()
    else
        -- BAG_UPDATE, BAG_UPDATE_DELAYED, BAG_NEW_ITEMS_UPDATED,
        -- ITEM_LOCK_CHANGED, INVENTORY_SEARCH_UPDATE
        ItemTier.BlizzardBags.RefreshAll()
    end
end)

-- Attempt immediate setup if container system is already available.
if ContainerFrame1 or ContainerFrameCombinedBags or _G["ContainerFrame1"] then
    SetupHooks()
end

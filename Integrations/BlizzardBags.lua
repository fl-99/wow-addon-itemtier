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

local function EnsureOverlay(button)
    if not button or button.ItemTierTrackText then return end

    -- Match character panel badge proportions.
    local text = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    text:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    text:SetJustifyH("RIGHT")
    text:SetScale(ItemTier.DB and ItemTier.DB.fontSize or 1)

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

    -- Modern bag buttons usually carry itemLocation; prefer it when it is a
    -- real bag+slot location.
    local itemLocation = (button.GetItemLocation and button:GetItemLocation())
        or button.itemLocation
    if itemLocation and itemLocation.GetBagAndSlot then
        local isBagAndSlot = true
        if itemLocation.IsBagAndSlot then
            isBagAndSlot = itemLocation:IsBagAndSlot()
        end
        if isBagAndSlot then
            local bagID, slot = itemLocation:GetBagAndSlot()
            if type(bagID) == "number" and type(slot) == "number" then
                return bagID, slot
            end
        end
    end

    local bagID = (button.GetBagID and button:GetBagID())
        or button.bagID
        or button.BagID
        or button.bag
        or button.container
    local slot = (button.GetID and button:GetID())
        or (button.GetSlotIndex and button:GetSlotIndex())
        or button.slotIndex
        or button.slot
        or button.Slot
        or button.slotID
        or button.containerSlotID

    if (not bagID) and button.GetParent then
        local parent = button:GetParent()
        if parent then
            bagID = (parent.GetBagID and parent:GetBagID())
                or parent.bagID
                or parent.BagID
                or parent.bag
                or parent.container
        end

        if (not bagID) and parent and parent.GetParent then
            local grandParent = parent:GetParent()
            if grandParent then
                bagID = (grandParent.GetBagID and grandParent:GetBagID())
                    or grandParent.bagID
                    or grandParent.BagID
                    or grandParent.bag
                    or grandParent.container
            end
        end
    end

    if type(bagID) ~= "number" or type(slot) ~= "number" then
        return nil, nil
    end
    return bagID, slot
end

local function BuildDetails(bagID, slot)
    if not (C_Container and C_Container.GetContainerItemLink) then return nil end

    local itemLink = C_Container.GetContainerItemLink(bagID, slot)
    if not itemLink then return nil end

    local details = {
        itemLink = itemLink,
    }

    if ItemLocation and ItemLocation.CreateFromBagAndSlot then
        details.itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slot)
    end

    if C_TooltipInfo and C_TooltipInfo.GetBagItem then
        details.tooltipGetter = function()
            return C_TooltipInfo.GetBagItem(bagID, slot)
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
    if C_Container and C_Container.GetContainerItemLink then
        local itemLink = C_Container.GetContainerItemLink(bagID, slot)
        if not itemLink then
            return false
        end
    end

    return true
end

local function ResolveItemLocation(button)
    if not button then return nil end

    local itemLocation = (button.GetItemLocation and button:GetItemLocation())
        or button.itemLocation
    if not itemLocation then return nil end

    if itemLocation.IsBagAndSlot and not itemLocation:IsBagAndSlot() then
        return nil
    end

    if not IsValidItemLocation(itemLocation) then
        return nil
    end

    return itemLocation
end

local function BuildDetailsFromItemLocation(itemLocation)
    if not itemLocation then return nil end
    if not (C_Item and C_Item.GetItemLink) then return nil end

    local itemLink
    local ok = pcall(function()
        itemLink = C_Item.GetItemLink(itemLocation)
    end)

    if not ok or not itemLink then
        return nil
    end

    local details = {
        itemLink = itemLink,
        itemLocation = itemLocation,
    }

    if C_TooltipInfo and C_TooltipInfo.GetBagItem and itemLocation.GetBagAndSlot then
        local bagID, slot = itemLocation:GetBagAndSlot()
        if type(bagID) == "number" and type(slot) == "number" then
            details.tooltipGetter = function()
                return C_TooltipInfo.GetBagItem(bagID, slot)
            end
            return details
        end
    end

    if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        details.tooltipGetter = function()
            return C_TooltipInfo.GetHyperlink(itemLink)
        end
    end

    return details
end

local function UpdateButton(button)
    if not button then return end

    EnsureOverlay(button)

    if not ItemTier.DB or not ItemTier.DB.enabled then
        HideOverlay(button)
        return
    end

    local details

    local itemLocation = ResolveItemLocation(button)
    if itemLocation then
        details = BuildDetailsFromItemLocation(itemLocation)
    end

    if not details then
        local bagID, slot = ResolveBagSlot(button)
        if bagID and slot then
            details = BuildDetails(bagID, slot)
        end
    end

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
    button.ItemTierTrackText:SetScale(ItemTier.DB and ItemTier.DB.fontSize or 1)
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

function ItemTier.BlizzardBags.RefreshAll()
    -- Primary: iterate all known container frames directly by name.
    for _, frameName in ipairs(CONTAINER_FRAME_NAMES) do
        RefreshContainerFrame(_G[frameName])
    end

    -- Secondary: iterate all currently active container frames when available.
    if ContainerFrameUtil_EnumerateContainerFrames then
        for containerFrame in ContainerFrameUtil_EnumerateContainerFrames() do
            RefreshContainerFrame(containerFrame)
        end
    end

    -- Last-resort fallback: scan _G for named item buttons (pre-Dragonflight naming).
    for name, frame in pairs(_G) do
        if type(name) == "string" and frame and frame.GetObjectType
                and frame:GetObjectType() == "Button" then
            if name:match("^ContainerFrame%d+Item%d+$")
                    or name:match("^ContainerFrameCombinedBagsItem%d+$")
                    or name:match("^ContainerFrameReagentBagItem%d+$")
                    or name:match("^ContainerFrameCombinedBagsItemButton%d+$")
                    or name:match("^ContainerFrame%d+ItemButton%d+$")
                    or (name:match("^ContainerFrame") and frame.GetBagID) then
                UpdateButton(frame)
            end
        end
    end
end

local function HookContainerFrameUpdateItems()
    local function HookSingleFrame(frame, frameKey)
        if not frame or hookedFrames[frameKey] or not frame.UpdateItems then
            return
        end

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
            local frameKey = (containerFrame.GetName and containerFrame:GetName())
                or tostring(containerFrame)
            HookSingleFrame(containerFrame, frameKey)
        end
    end
end

local function TryMixinHooks()
    if mixinHooksInstalled then return end

    local anyHooked = false

    if ContainerFrameItemButtonMixin then
        -- TWW uses UpdateItemDetails; older clients used Update.
        for _, method in ipairs({ "UpdateItemDetails", "Update" }) do
            if ContainerFrameItemButtonMixin[method] then
                hooksecurefunc(ContainerFrameItemButtonMixin, method, UpdateButton)
                anyHooked = true
            end
        end

        for _, method in ipairs({ "SetBagID", "SetBagAndSlot" }) do
            if ContainerFrameItemButtonMixin[method] then
                hooksecurefunc(ContainerFrameItemButtonMixin, method, function(button)
                    UpdateButton(button)
                end)
                anyHooked = true
            end
        end
    end

    if ItemButtonMixin and ItemButtonMixin.SetItem then
        hooksecurefunc(ItemButtonMixin, "SetItem", UpdateButton)
        anyHooked = true
    end

    -- Legacy global function hook (pre-Dragonflight).
    local buttonUpdateFn = rawget(_G, "ContainerFrameItemButton_Update")
    if type(buttonUpdateFn) == "function" then
        hooksecurefunc("ContainerFrameItemButton_Update", UpdateButton)
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

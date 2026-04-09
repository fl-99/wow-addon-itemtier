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

-- Track which frames have already had UpdateItems hooked to avoid duplicates
local hookedFrames = {}

local function EnsureOverlay(button)
    if not button or button.ItemTierTrackText then return end

    local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    text:SetJustifyH("RIGHT")

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

    local bagID = (button.GetBagID and button:GetBagID())
        or button.bagID
        or button.BagID
        or button.bag
    local slot = (button.GetID and button:GetID())
        or button.slot
        or button.Slot
        or button.slotID

    if (not bagID) and button:GetParent() then
        local parent = button:GetParent()
        bagID = (parent.GetBagID and parent:GetBagID()) or parent.bagID or parent:GetID()
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

local function UpdateButton(button)
    if not button then return end
    
    EnsureOverlay(button)

    if not ItemTier.DB or not ItemTier.DB.enabled then
        HideOverlay(button)
        return
    end

    local bagID, slot = ResolveBagSlot(button)
    if not bagID or not slot then
        HideOverlay(button)
        return
    end

    local details = BuildDetails(bagID, slot)
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
    if ItemTier.DB and ItemTier.DB.fontSize then
        button.ItemTierTrackText:SetScale(ItemTier.DB.fontSize)
    end
    button.ItemTierTrackText:Show()
end

-- Iterate a specific container frame and update all its item buttons via EnumerateValidItems.
local function RefreshContainerFrame(frame)
    if not frame or not frame.EnumerateValidItems then return false end
    local found = false
    for itemButton in frame:EnumerateValidItems() do
        UpdateButton(itemButton)
        found = true
    end
    return found
end

function ItemTier.BlizzardBags.RefreshAll()
    local foundAny = false

    -- Primary: iterate all known container frames directly by name.
    -- This covers ContainerFrameCombinedBags (combined backpack) and each
    -- individual bag window (ContainerFrame1-6).
    for _, frameName in ipairs(CONTAINER_FRAME_NAMES) do
        local frame = _G[frameName]
        if frame and RefreshContainerFrame(frame) then
            foundAny = true
        end
    end

    -- Secondary legacy fallback for older WoW versions that expose this iterator.
    if not foundAny and ContainerFrameUtil_EnumerateContainerFrames then
        for containerFrame in ContainerFrameUtil_EnumerateContainerFrames() do
            if containerFrame and containerFrame.EnumerateValidItems then
                for itemButton in containerFrame:EnumerateValidItems() do
                    UpdateButton(itemButton)
                    foundAny = true
                end
            end
        end
    end

    -- Last-resort fallback: scan _G for named item buttons (pre-Dragonflight naming).
    if not foundAny then
        for name, frame in pairs(_G) do
            if type(name) == "string" and frame and frame.GetObjectType
                    and frame:GetObjectType() == "Button" then
                if name:match("^ContainerFrame%d+Item%d+$")
                        or name:match("^ContainerFrameCombinedBagsItem%d+$")
                        or name:match("^ContainerFrameReagentBagItem%d+$")
                        or name:match("^ContainerFrameCombinedBagsItemButton%d+$")
                        or name:match("^ContainerFrame%d+ItemButton%d+$") then
                    UpdateButton(frame)
                end
            end
        end
    end
end

-- Hook UpdateItems on any container frames that are available now but not yet hooked.
-- Called at setup time and again on PLAYER_ENTERING_WORLD in case frames weren't
-- available when the addon first loaded.
local function HookContainerFrameUpdateItems()
    for _, frameName in ipairs(CONTAINER_FRAME_NAMES) do
        if not hookedFrames[frameName] then
            local frame = _G[frameName]
            if frame and frame.UpdateItems then
                -- Capture frame reference so the closure is correct even if _G changes.
                local capturedFrame = frame
                hooksecurefunc(frame, "UpdateItems", function()
                    RefreshContainerFrame(capturedFrame)
                end)
                hookedFrames[frameName] = true
            end
        end
    end
end

local function SetupHooks()
    if ItemTier.BlizzardBags.HooksInstalled then return end

    -- Per-button mixin hooks: fire whenever a single item button is refreshed.
    if ContainerFrameItemButtonMixin and ContainerFrameItemButtonMixin.Update then
        hooksecurefunc(ContainerFrameItemButtonMixin, "Update", function(button)
            UpdateButton(button)
        end)
    end

    if ItemButtonMixin and ItemButtonMixin.SetItem then
        hooksecurefunc(ItemButtonMixin, "SetItem", function(button)
            UpdateButton(button)
        end)
    end

    -- Legacy global function hook (pre-Dragonflight).
    local buttonUpdateFn = rawget(_G, "ContainerFrameItemButton_Update")
    if type(buttonUpdateFn) == "function" then
        hooksecurefunc("ContainerFrameItemButton_Update", UpdateButton)
    end

    -- Frame-level UpdateItems hooks (primary mechanism for the combined backpack).
    -- Matches LiteBag's approach: hook ContainerFrameCombinedBags.UpdateItems
    -- and each ContainerFrameN.UpdateItems directly.
    HookContainerFrameUpdateItems()

    -- Hooks on bag open/toggle functions to force a refresh when bags are opened.
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
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" and addonName == "ItemTier" then
        SetupHooks()
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Re-attempt frame-level hooks in case frames weren't ready at ADDON_LOADED.
        HookContainerFrameUpdateItems()
        ItemTier.BlizzardBags.RefreshAll()
    else
        -- BAG_UPDATE, BAG_UPDATE_DELAYED
        ItemTier.BlizzardBags.RefreshAll()
    end
end)

-- Attempt immediate setup if container system is already available.
if ContainerFrame1 or ContainerFrameCombinedBags or _G["ContainerFrame1"] then
    SetupHooks()
end

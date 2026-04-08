-- ItemTier: Blizzard default bag integration
--
-- Adds a compact track badge to default Blizzard bag item buttons so the addon
-- works without Baganator.

ItemTier = ItemTier or {}
ItemTier.BlizzardBags = ItemTier.BlizzardBags or {}

local function EnsureOverlay(button)
    if not button or button.ItemTierTrackText then return end

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
    button.ItemTierTrackText:SetScale(ItemTier.DB and ItemTier.DB.fontSize or 1)
    button.ItemTierTrackText:Show()
end

local function RefreshByNamePattern()
    for name, frame in pairs(_G) do
        if type(name) == "string" and frame and frame.GetObjectType and frame:GetObjectType() == "Button" then
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

local function RefreshViaHierarchy()
    if not UIParent or not UIParent.GetChildren then return end

    local function Visit(frame)
        if not frame or not frame.GetObjectType then return end

        if frame:GetObjectType() == "Button"
            and (frame.GetBagID or frame.bagID or frame.BagID or frame.bag)
            and (frame.GetID or frame.slot or frame.Slot or frame.slotID) then
            UpdateButton(frame)
        end

        if frame.GetChildren then
            for _, child in ipairs({ frame:GetChildren() }) do
                Visit(child)
            end
        end
    end

    Visit(UIParent)
end

local function RefreshViaContainerIterator()
    if not ContainerFrameUtil_EnumerateContainerFrames then return false end

    local didAny = false
    for containerFrame in ContainerFrameUtil_EnumerateContainerFrames() do
        if containerFrame and containerFrame.EnumerateValidItems then
            for itemButton in containerFrame:EnumerateValidItems() do
                UpdateButton(itemButton)
                didAny = true
            end
        end
    end
    return didAny
end

function ItemTier.BlizzardBags.RefreshAll()
    local foundAny = RefreshViaContainerIterator()
    if not foundAny then
        RefreshByNamePattern()
        RefreshViaHierarchy()
    end
end

local function SetupHooks()
    if ItemTier.BlizzardBags.HooksInstalled then return true end

    local hookedAny = false

    local buttonUpdateFn = rawget(_G, "ContainerFrameItemButton_Update")
    if type(buttonUpdateFn) == "function" then
        hooksecurefunc("ContainerFrameItemButton_Update", UpdateButton)
        hookedAny = true
    end

    if ItemButtonMixin and ItemButtonMixin.SetItem then
        hooksecurefunc(ItemButtonMixin, "SetItem", function(button)
            UpdateButton(button)
        end)
        hookedAny = true
    end

    if ContainerFrameItemButtonMixin and ContainerFrameItemButtonMixin.Update then
        hooksecurefunc(ContainerFrameItemButtonMixin, "Update", UpdateButton)
        hookedAny = true
    end

    local containerFrameUpdate = rawget(_G, "ContainerFrame_Update")
    if type(containerFrameUpdate) == "function" then
        hooksecurefunc("ContainerFrame_Update", function(frame)
            if frame and frame.EnumerateValidItems then
                for itemButton in frame:EnumerateValidItems() do
                    UpdateButton(itemButton)
                end
            else
                ItemTier.BlizzardBags.RefreshAll()
            end
        end)
        hookedAny = true
    end

    local openBackpack = rawget(_G, "OpenBackpack")
    if type(openBackpack) == "function" then
        hooksecurefunc("OpenBackpack", function()
            ItemTier.BlizzardBags.RefreshAll()
        end)
        hookedAny = true
    end

    local openAllBags = rawget(_G, "OpenAllBags")
    if type(openAllBags) == "function" then
        hooksecurefunc("OpenAllBags", function()
            ItemTier.BlizzardBags.RefreshAll()
        end)
        hookedAny = true
    end

    local toggleBackpack = rawget(_G, "ToggleBackpack")
    if type(toggleBackpack) == "function" then
        hooksecurefunc("ToggleBackpack", function()
            ItemTier.BlizzardBags.RefreshAll()
        end)
        hookedAny = true
    end

    local toggleBag = rawget(_G, "ToggleBag")
    if type(toggleBag) == "function" then
        hooksecurefunc("ToggleBag", function()
            ItemTier.BlizzardBags.RefreshAll()
        end)
        hookedAny = true
    end

    if hookedAny then
        ItemTier.BlizzardBags.HooksInstalled = true
    end

    ItemTier.BlizzardBags.RefreshAll()
    return hookedAny
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("BAG_UPDATE_DELAYED")
loader:RegisterEvent("BAG_OPEN")
loader:RegisterEvent("BAG_CLOSED")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" and addonName ~= "Blizzard_ContainerUI" then
        return
    end

    if not ItemTier.BlizzardBags.HooksInstalled then
        SetupHooks()
    end

    ItemTier.BlizzardBags.RefreshAll()
end)

local checkLoaded = C_AddOns and C_AddOns.IsAddOnLoaded
if checkLoaded and checkLoaded("Blizzard_ContainerUI") then
    SetupHooks()
    ItemTier.BlizzardBags.RefreshAll()
else
    -- Try once on load even if Blizzard_ContainerUI reports nil on some clients.
    SetupHooks()
end

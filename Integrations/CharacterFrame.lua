-- ItemTier: Character frame (paper doll) integration
--
-- Adds a compact track badge to equipped item buttons in the character window.

ItemTier = ItemTier or {}

local SLOT_BUTTON_NAMES = {
    "CharacterHeadSlot",
    "CharacterNeckSlot",
    "CharacterShoulderSlot",
    "CharacterBackSlot",
    "CharacterChestSlot",
    "CharacterShirtSlot",
    "CharacterTabardSlot",
    "CharacterWristSlot",
    "CharacterHandsSlot",
    "CharacterWaistSlot",
    "CharacterLegsSlot",
    "CharacterFeetSlot",
    "CharacterFinger0Slot",
    "CharacterFinger1Slot",
    "CharacterTrinket0Slot",
    "CharacterTrinket1Slot",
    "CharacterMainHandSlot",
    "CharacterSecondaryHandSlot",
}

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

local function BuildDetails(unit, slotID)
    local itemLink = GetInventoryItemLink(unit, slotID)
    if not itemLink then return nil end

    local details = {
        itemLink = itemLink,
    }

    if unit == "player" and ItemLocation and ItemLocation.CreateFromEquipmentSlot then
        details.itemLocation = ItemLocation:CreateFromEquipmentSlot(slotID)
    end

    if C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
        details.tooltipGetter = function()
            return C_TooltipInfo.GetInventoryItem(unit, slotID)
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

    local slotID = button:GetID()
    if not slotID then
        HideOverlay(button)
        return
    end

    local details = BuildDetails("player", slotID)
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

local function RefreshAll()
    for _, buttonName in ipairs(SLOT_BUTTON_NAMES) do
        local button = _G[buttonName]
        if button then
            UpdateButton(button)
        end
    end
end

local function SetupHooks()
    if not PaperDollItemSlotButton_Update then return false end
    if ItemTier.CharacterFrameHooksInstalled then return true end

    hooksecurefunc("PaperDollItemSlotButton_Update", UpdateButton)
    ItemTier.CharacterFrameHooksInstalled = true
    RefreshAll()
    return true
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
loader:RegisterEvent("UNIT_INVENTORY_CHANGED")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "Blizzard_CharacterUI" then
        SetupHooks()
        return
    end

    if event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" then
        return
    end

    if not ItemTier.CharacterFrameHooksInstalled then
        SetupHooks()
    end
    RefreshAll()
end)

local checkLoaded = C_AddOns and C_AddOns.IsAddOnLoaded
if checkLoaded and checkLoaded("Blizzard_CharacterUI") then
    SetupHooks()
    RefreshAll()
end
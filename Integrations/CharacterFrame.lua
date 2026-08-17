-- ItemTier: Character frame (paper doll) integration
--
-- Adds a compact track badge to equipped item buttons in the character window.

ItemTier = ItemTier or {}
ItemTier.CharacterFrame = ItemTier.CharacterFrame or {}

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

local function CreateItemLocationForSlot(slotID)
    if not ItemLocation then return nil end
    if not ItemLocation.CreateFromEquipmentSlot then return nil end
    return ItemLocation:CreateFromEquipmentSlot(slotID)
end

local function BuildInventoryTooltipGetter(unit, slotID)
    local tooltipInfo = C_TooltipInfo
    if not tooltipInfo then return nil end
    local getInventoryItem = tooltipInfo.GetInventoryItem
    if not getInventoryItem then return nil end
    return function()
        return getInventoryItem(unit, slotID)
    end
end

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

    local details = { itemLink = itemLink }

    if unit == "player" then
        details.itemLocation = CreateItemLocationForSlot(slotID)
    end

    details.tooltipGetter = BuildInventoryTooltipGetter(unit, slotID)

    return details
end

local function IsAddonEnabled()
    local db = ItemTier.DB
    return db and db.enabled
end

local function ResolveDisplayForSlot(slotID)
    if not slotID then return nil end
    local details = BuildDetails("player", slotID)
    if not details then return nil end
    local track = ItemTier.Scanner.Resolve(details)
    if not track then return nil end
    return ItemTier.Scanner.GetDisplayData(track)
end

local function GetFontScale()
    local db = ItemTier.DB
    if not db then return 1 end
    if not db.fontSize then return 1 end
    return db.fontSize
end

local function UpdateButton(button)
    if not button then return end
    EnsureOverlay(button)

    if not IsAddonEnabled() then
        HideOverlay(button)
        return
    end

    local slotID = button:GetID()
    local display = ResolveDisplayForSlot(slotID)
    if not display then
        HideOverlay(button)
        return
    end

    button.ItemTierTrackText:SetText(display.text)
    button.ItemTierTrackText:SetTextColor(display.r, display.g, display.b)
    button.ItemTierTrackText:SetScale(GetFontScale())
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

ItemTier.CharacterFrame.RefreshAll = RefreshAll

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

local function HandleInventoryRefresh()
    if not ItemTier.CharacterFrameHooksInstalled then
        SetupHooks()
    end
    RefreshAll()
end

loader:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "Blizzard_CharacterUI" then
            SetupHooks()
        end
        return
    end

    if event == "UNIT_INVENTORY_CHANGED" then
        if arg1 ~= "player" then
            return
        end
    end

    HandleInventoryRefresh()
end)

local checkLoaded = C_AddOns and C_AddOns.IsAddOnLoaded
if checkLoaded and checkLoaded("Blizzard_CharacterUI") then
    SetupHooks()
    RefreshAll()
end

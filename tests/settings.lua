test("ItemTier initializes font-size configuration", function()
    assertNotNil(ItemTier)
    assertNotNil(ItemTier.DB)
    assertNotNil(ItemTier.Constants)
    assertAlmostEquals(1.0, ItemTier.Constants.DefaultConfig.fontSize)
    assertNotNil(ItemTier.DB.fontSize)
end)

test("item text size slider is registered", function()
    local slider = _G.ItemTierConfigFontSizeSlider
    assertNotNil(slider)

    local minValue, maxValue = slider:GetMinMaxValues()
    assertAlmostEquals(0.5, minValue)
    assertAlmostEquals(2.0, maxValue)
    assertAlmostEquals(0.1, slider:GetValueStep())
    assertAlmostEquals(ItemTier.DB.fontSize, slider:GetValue())
    assertContains(slider.Text:GetText(), "Item Text Size")
end)

test("item text size slider updates the saved setting and refreshes overlays", function()
    local slider = _G.ItemTierConfigFontSizeSlider
    assertNotNil(slider)

    local originalFontSize = ItemTier.DB.fontSize
    local oldBagRefresh = ItemTier.BlizzardBags.RefreshAll
    local oldCharacterRefresh = ItemTier.CharacterFrame.RefreshAll
    local bagRefreshes = 0
    local characterRefreshes = 0

    ItemTier.BlizzardBags.RefreshAll = function()
        bagRefreshes = bagRefreshes + 1
    end
    ItemTier.CharacterFrame.RefreshAll = function()
        characterRefreshes = characterRefreshes + 1
    end

    slider:SetValue(1.5)

    assertAlmostEquals(1.5, ItemTier.DB.fontSize)
    assertEquals(1, bagRefreshes)
    assertEquals(1, characterRefreshes)

    ItemTier.BlizzardBags.RefreshAll = oldBagRefresh
    ItemTier.CharacterFrame.RefreshAll = oldCharacterRefresh
    slider:SetValue(originalFontSize)
end)

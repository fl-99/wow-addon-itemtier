-- ItemTier: Main entry point

local addonName = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, _, loadedAddon)
    if loadedAddon ~= addonName then return end
    ItemTier.Init()
    self:UnregisterEvent("ADDON_LOADED")
end)

-- Bootstrap: once saved variables are loaded, start the addon on the real game layer.
local addonName, ns = ...

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, loadedName)
  if loadedName ~= addonName then return end
  self:UnregisterEvent("ADDON_LOADED")
  ShamanTrackerDB = ShamanTrackerDB or {}
  ns.addon = ns.Addon.Start(ns.CreateRealGame(), ShamanTrackerDB)
end)

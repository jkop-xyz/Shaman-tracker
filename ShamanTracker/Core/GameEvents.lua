-- The events the game layer reports to the rest of the addon.
-- Both the real game layer and the fake one accept only these names.
local _, ns = ...

ns.GameEvents = {
  combatStarted = true,
  combatEnded = true,
}

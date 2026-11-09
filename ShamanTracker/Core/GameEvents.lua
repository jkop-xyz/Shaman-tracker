-- The events the game layer reports to the rest of the addon.
-- Both the real game layer and the fake one accept only these names.
local _, ns = ...

ns.GameEvents = {
  combatStarted = true,
  combatEnded = true,
  -- The main-hand weapon or its enchants changed.
  weaponChanged = true,
  -- The player learned or lost spells.
  spellsChanged = true,
  -- The player died, released, or came back to life.
  lifeChanged = true,
  -- Once a second, so time-based states stay current.
  tick = true,
}

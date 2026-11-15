-- Buff Trackers: Maelstrom Weapon stacks and Lightning Shield charges.
--
-- Addons can't read auras in combat on Forever, so the game draws these
-- buffs itself (ADR-0002): the addon only says which spell IDs to show and
-- at how many stacks to glow. While the buff is down, the tracker shows the
-- spell's icon dimmed, if the player knows the spell.
local _, ns = ...

local BuffTrackers = {}
ns.BuffTrackers = BuffTrackers

BuffTrackers.SPECS = {
  {
    key = "maelstromTracker",
    name = "MaelstromTracker",
    label = "Maelstrom Weapon Tracker",
    spellName = "Maelstrom Weapon",
    -- The buff's ID on Forever (seen in-game, issue #23).
    spellIDs = { 408505 },
    glowAt = 5,
    defaultLayout = { point = "CENTER", relativePoint = "CENTER", x = -50, y = -150 },
  },
  {
    key = "shieldTracker",
    name = "ShieldTracker",
    label = "Lightning Shield Tracker",
    spellName = "Lightning Shield",
    -- Every rank (Classic IDs; rank 1, 324, seen in-game).
    spellIDs = { 324, 325, 905, 945, 8134, 10431, 10432 },
    defaultLayout = { point = "CENTER", relativePoint = "CENTER", x = 50, y = -150 },
  },
}

-- Returns the trackers' Feature frame controllers, for /st lock and unlock.
function BuffTrackers.Start(game, gate, db, settingsCategory)
  local frames = {}
  for _, spec in ipairs(BuffTrackers.SPECS) do
    local tracker = game:CreateBuffTracker(spec.name, {
      label = spec.label,
      spellIDs = spec.spellIDs,
      glowAt = spec.glowAt,
    })
    local frame = ns.FeatureFrame.Attach(game, gate, db, settingsCategory, {
      key = spec.key,
      label = spec.label,
      frame = tracker,
      protected = true,
      defaultLayout = spec.defaultLayout,
    })

    local function showPlaceholder()
      local known = game:IsSpellNameKnown(spec.spellName)
      tracker:SetPlaceholder(known and game:GetSpellIcon(spec.spellName) or nil)
    end
    game:On("spellsChanged", showPlaceholder)

    frame.apply()
    showPlaceholder()
    -- The game's aura slot can only be created out of combat.
    gate:Run("buffTracker:" .. spec.key, function() tracker:Activate() end)
    table.insert(frames, frame)
  end
  return frames
end

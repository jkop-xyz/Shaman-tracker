-- Fake game layer for tests: same methods as ShamanTracker/Game/RealGame.lua,
-- plus helpers to set game state and fire events.
local FakeGame = {}
FakeGame.__index = FakeGame

function FakeGame.new(ns, options)
  options = options or {}
  return setmetatable({
    ns = ns,
    class = options.class or "SHAMAN",
    inCombat = false,
    handlers = {},
    printed = {},
    slashCommand = nil,
    settingsCategories = {},
    openedSettings = {},
    -- Game state tests set directly:
    dead = false,
    knownSpells = {},       -- [spellID] = true
    mainHandIcon = nil,     -- fileID of the equipped main-hand weapon, nil if none
    mainHandEnchants = {},  -- list of { hasEnchant, enchantType, timeLeft (ms), iconID }
    -- What's on screen, by name:
    icons = {},
  }, FakeGame)
end

-- A fake icon records what it shows, for tests to check.
local FakeIcon = {}
FakeIcon.__index = FakeIcon

function FakeIcon:SetTexture(fileID) self.texture = fileID end
function FakeIcon:SetTint(r, g, b) self.tint = { r, g, b } end
function FakeIcon:Show() self.shown = true end
function FakeIcon:Hide() self.shown = false end

-- Game layer methods --------------------------------------------------------

function FakeGame:On(name, handler)
  assert(self.ns.GameEvents[name], "unknown game event: " .. tostring(name))
  self.handlers[name] = self.handlers[name] or {}
  table.insert(self.handlers[name], handler)
end

function FakeGame:GetPlayerClass()
  return self.class
end

function FakeGame:IsInCombat()
  return self.inCombat
end

function FakeGame:Print(message)
  table.insert(self.printed, message)
end

function FakeGame:RegisterSlashCommand(aliases, handler)
  self.slashCommand = { aliases = aliases, handler = handler }
end

function FakeGame:CreateSettingsCategory(name)
  local category = { name = name }
  table.insert(self.settingsCategories, category)
  return category
end

function FakeGame:OpenSettings(category)
  table.insert(self.openedSettings, category)
end

function FakeGame:IsPlayerDead()
  return self.dead
end

function FakeGame:IsSpellKnown(spellID)
  return self.knownSpells[spellID] == true
end

function FakeGame:GetMainHandWeaponIcon()
  return self.mainHandIcon
end

function FakeGame:GetMainHandEnchants()
  return self.mainHandEnchants
end

function FakeGame:CreateIcon(name)
  assert(not self.icons[name], "icon created twice: " .. name)
  local icon = setmetatable({ name = name, shown = false, clickable = false }, FakeIcon)
  self.icons[name] = icon
  return icon
end

-- Test helpers ----------------------------------------------------------------

function FakeGame:Fire(name, ...)
  assert(self.ns.GameEvents[name], "unknown game event: " .. tostring(name))
  if name == "combatStarted" then self.inCombat = true end
  if name == "combatEnded" then self.inCombat = false end
  for _, handler in ipairs(self.handlers[name] or {}) do
    handler(...)
  end
end

-- Runs a slash command the way the player would type it, e.g. "/st settings".
function FakeGame:Type(line)
  local alias, rest = line:match("^(%S+)%s*(.-)$")
  assert(self.slashCommand, "no slash command registered")
  local known = false
  for _, registered in ipairs(self.slashCommand.aliases) do
    if registered == alias then known = true end
  end
  assert(known, "unknown slash command: " .. alias)
  self.slashCommand.handler(rest)
end

return FakeGame

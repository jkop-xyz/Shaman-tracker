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
    knownTotems = {},       -- [totem slot] = list of { name, icon }
    spellIcons = {},        -- [spell name] = fileID, for spells not in knownTotems
    -- What's on screen, by name:
    icons = {},
    totemBars = {},
    openMenu = nil,         -- { owner, items } of the last menu shown
    -- What the player did:
    casts = {},             -- spell names cast from addon buttons
  }, FakeGame)
end

-- A fake secure totem button. Like the game, it refuses spell changes in combat.
local FakeTotemButton = {}
FakeTotemButton.__index = FakeTotemButton

function FakeTotemButton:SetSpell(spellName)
  assert(not self.game.inCombat, "blocked: secure button changed in combat")
  self.spell = spellName
end
function FakeTotemButton:SetIcon(fileID) self.icon = fileID end
function FakeTotemButton:SetPendingMarker(shown) self.pendingMarker = shown end
function FakeTotemButton:OnRightClick(handler) self.rightClickHandler = handler end

-- Test helpers: click the button the way the player would.
function FakeTotemButton:LeftClick()
  if self.spell then table.insert(self.game.casts, self.spell) end
end
function FakeTotemButton:RightClick()
  if self.rightClickHandler then self.rightClickHandler() end
end

local FakeTotemBar = {}
FakeTotemBar.__index = FakeTotemBar

function FakeTotemBar:CreateButton(elementKey)
  local button = setmetatable({ game = self.game, element = elementKey }, FakeTotemButton)
  self.buttons[elementKey] = button
  table.insert(self.order, elementKey)
  return button
end

-- A fake icon records what it shows, for tests to check.
local FakeIcon = {}
FakeIcon.__index = FakeIcon

function FakeIcon:SetTexture(fileID) self.texture = fileID end
function FakeIcon:SetTint(r, g, b) self.tint = { r, g, b } end
function FakeIcon:SetText(text) self.text = text end
function FakeIcon:SetPulsing(pulsing) self.pulsing = pulsing end
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

-- slider = { id, label, tooltip, min, max, step, default, get = fn, set = fn }
function FakeGame:AddSlider(category, slider)
  table.insert(category.settings, slider)
end

function FakeGame:CreateSettingsCategory(name)
  local category = { name = name, settings = {} }
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

function FakeGame:GetKnownTotems(slot)
  return self.knownTotems[slot] or {}
end

function FakeGame:GetSpellIcon(spellName)
  return self.spellIcons[spellName]
end

function FakeGame:CreateTotemBar(name)
  assert(not self.totemBars[name], "totem bar created twice: " .. name)
  local bar = setmetatable({ game = self, name = name, buttons = {}, order = {} }, FakeTotemBar)
  self.totemBars[name] = bar
  return bar
end

-- items: list of { title = text } | { divider = true } | { text, checked, onSelect }
function FakeGame:ShowMenu(owner, items)
  self.openMenu = { owner = owner, items = items }
end

function FakeGame:FindMenuItem(text)
  assert(self.openMenu, "no menu open")
  for _, item in ipairs(self.openMenu.items) do
    if item.text == text then return item end
  end
  error("no menu item " .. text)
end

-- Picks a menu item the way the player would; the menu closes.
function FakeGame:ChooseMenuItem(text)
  local item = self:FindMenuItem(text)
  self.openMenu = nil
  item.onSelect()
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

function FakeGame:FindSetting(id)
  for _, category in ipairs(self.settingsCategories) do
    for _, setting in ipairs(category.settings) do
      if setting.id == id then return setting end
    end
  end
  error("no setting with id " .. id)
end

-- Changes a setting the way the player would in the settings panel.
function FakeGame:ChangeSetting(id, value)
  self:FindSetting(id).set(value)
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

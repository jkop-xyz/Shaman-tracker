-- Fake game layer for tests: same methods as ShamanTracker/Game/RealGame.lua,
-- plus helpers to set game state and fire events.
local FakeGame = {}
FakeGame.__index = FakeGame

-- A stand-in for a value the game keeps secret in combat. Like the real thing,
-- it can be handed to widgets, but comparing it, doing arithmetic with it,
-- indexing it or turning it into text raises an error.
function FakeGame.Secret(label)
  local secret = newproxy(true)
  local mt = getmetatable(secret)
  local function refuse() error("secret value used: " .. label, 2) end
  mt.__index = refuse
  mt.__lt = refuse
  mt.__le = refuse
  mt.__add = refuse
  mt.__sub = refuse
  mt.__mul = refuse
  mt.__div = refuse
  mt.__concat = refuse
  mt.__len = refuse
  mt.__tostring = refuse
  return secret
end

-- Feature frame methods shared by the fake icon and the fake Totem Bar. A
-- protected frame (one holding secure buttons) refuses changes in combat.
local FeatureFrameMethods = {}

local function refuseInCombat(frame, what)
  if frame.protected then
    assert(not frame.game.inCombat, "blocked: " .. what .. " in combat")
  end
end

function FeatureFrameMethods:SetLayout(layout)
  refuseInCombat(self, "frame moved or scaled")
  self.layout = { point = layout.point, relativePoint = layout.relativePoint,
    x = layout.x, y = layout.y, scale = layout.scale }
end
function FeatureFrameMethods:SetEnabled(enabled)
  refuseInCombat(self, "frame shown or hidden")
  self.enabled = enabled
end
function FeatureFrameMethods:SetUnlocked(unlocked) self.unlocked = unlocked end
function FeatureFrameMethods:OnMoved(handler) self.movedHandler = handler end
-- Test helper: drags the frame the way the player would.
function FeatureFrameMethods:DragTo(point, relativePoint, x, y)
  assert(self.unlocked, "frame is locked")
  -- Like a real frame, it moves itself; then the game layer reports where to.
  self.layout = { point = point, relativePoint = relativePoint, x = x, y = y,
    scale = self.layout and self.layout.scale }
  self.movedHandler(point, relativePoint, x, y)
end

local function addFeatureFrameMethods(class)
  for name, fn in pairs(FeatureFrameMethods) do class[name] = fn end
end

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
    macros = {},            -- [macro name] = body
    macroIsCharacter = {},  -- [macro name] = true for character (not account) macros
    freeCharacterMacroSlots = 18,
    macroWrites = 0,
    macroBodySuffix = "", -- the game may store bodies with trailing whitespace
    knownTotems = {},       -- [totem slot] = list of { name, icon }
    activeTotems = {},      -- [totem slot] = { icon, duration } (possibly FakeGame.Secret values)
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
function FakeTotemButton:ShowActiveTotem(totem) self.activeTotem = totem end
function FakeTotemButton:HideActiveTotem() self.activeTotem = nil end
function FakeTotemButton:OnRightClick(handler) self.rightClickHandler = handler end

-- Test helpers: click the button the way the player would.
function FakeTotemButton:LeftClick()
  if self.spell then table.insert(self.game.casts, self.spell) end
end
function FakeTotemButton:RightClick()
  if self.rightClickHandler then self.rightClickHandler() end
end

-- The Totem Bar's control for switching Totem Set.
local FakeSetButton = {}
FakeSetButton.__index = FakeSetButton

function FakeSetButton:SetText(text) self.text = text end
function FakeSetButton:SetPendingMarker(shown) self.pendingMarker = shown end
function FakeSetButton:OnClick(handler) self.clickHandler = handler end
function FakeSetButton:Click() self.clickHandler() end

local FakeTotemBar = {}
FakeTotemBar.__index = FakeTotemBar
addFeatureFrameMethods(FakeTotemBar)

function FakeTotemBar:SetVertical(vertical)
  refuseInCombat(self, "Totem Bar re-laid out")
  self.vertical = vertical
end

function FakeTotemBar:CreateSetButton()
  self.setButton = setmetatable({}, FakeSetButton)
  return self.setButton
end

function FakeTotemBar:CreateButton(elementKey, elementName)
  local button = setmetatable({ game = self.game, element = elementKey, elementName = elementName },
    FakeTotemButton)
  self.buttons[elementKey] = button
  table.insert(self.order, elementKey)
  return button
end

-- A fake icon records what it shows, for tests to check.
local FakeIcon = {}
FakeIcon.__index = FakeIcon
addFeatureFrameMethods(FakeIcon)

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

-- checkbox = { id, label, tooltip, default, get = fn, set = fn }
function FakeGame:AddCheckbox(category, checkbox)
  table.insert(category.settings, checkbox)
end

function FakeGame:AddHeader(category, text)
  category.headers = category.headers or {}
  table.insert(category.headers, text)
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

function FakeGame:GetMacroBody(name)
  return self.macros[name]
end

-- Creates (as a character macro) or rewrites a macro. Like the game, refuses
-- in combat. Returns false if a new macro doesn't fit.
function FakeGame:SetMacro(name, body)
  assert(not self.inCombat, "blocked: macro changed in combat")
  if self.macros[name] == nil then
    if self.freeCharacterMacroSlots <= 0 then return false end
    self.freeCharacterMacroSlots = self.freeCharacterMacroSlots - 1
    self.macroIsCharacter[name] = true
  end
  self.macros[name] = body .. self.macroBodySuffix
  self.macroWrites = self.macroWrites + 1
  self:Fire("macrosChanged")
  return true
end

function FakeGame:GetActiveTotem(slot)
  return self.activeTotems[slot]
end

function FakeGame:GetKnownTotems(slot)
  return self.knownTotems[slot] or {}
end

function FakeGame:GetSpellIcon(spellName)
  return self.spellIcons[spellName]
end

function FakeGame:CreateTotemBar(name)
  assert(not self.totemBars[name], "totem bar created twice: " .. name)
  local bar = setmetatable({ game = self, name = name, buttons = {}, order = {}, protected = true },
    FakeTotemBar)
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
  assert(not item.disabled, "menu item is disabled: " .. text)
  self.openMenu = nil
  item.onSelect()
end

-- prompt = { title, default, onAccept = fn(text) }
function FakeGame:PromptText(prompt)
  self.openPrompt = prompt
end

-- confirmation = { text, onAccept = fn() }
function FakeGame:Confirm(confirmation)
  self.openConfirmation = confirmation
end

-- Types into the open prompt and accepts it.
function FakeGame:AnswerPrompt(text)
  local prompt = assert(self.openPrompt, "no prompt open")
  self.openPrompt = nil
  prompt.onAccept(text)
end

function FakeGame:AnswerConfirmation(accept)
  local confirmation = assert(self.openConfirmation, "no confirmation open")
  self.openConfirmation = nil
  if accept then confirmation.onAccept() end
end

function FakeGame:CreateIcon(name)
  assert(not self.icons[name], "icon created twice: " .. name)
  local icon = setmetatable({ game = self, name = name, shown = false, clickable = false }, FakeIcon)
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

function FakeGame:DeleteMacroByPlayer(name)
  assert(self.macros[name], "no macro " .. name)
  self.macros[name] = nil
  self.macroIsCharacter[name] = nil
  self.freeCharacterMacroSlots = self.freeCharacterMacroSlots + 1
  self:Fire("macrosChanged")
end

function FakeGame:EditMacroByPlayer(name, body)
  assert(self.macros[name], "no macro " .. name)
  self.macros[name] = body
  self:Fire("macrosChanged")
end

function FakeGame:MacroNamesStartingWith(prefix)
  local names = {}
  for name in pairs(self.macros) do
    if name:sub(1, #prefix) == prefix then table.insert(names, name) end
  end
  table.sort(names)
  return names
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

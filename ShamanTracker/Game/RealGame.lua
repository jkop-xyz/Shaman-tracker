-- The real game layer: the only place in Shaman-tracker that calls the WoW API.
-- The tests use a fake with the same methods (spec/support/fake_game.lua).
local _, ns = ...

local MAIN_HAND_SLOT = 16
local TICK_SECONDS = 1

-- Each game event, and the WoW events behind it. Entries with a unit are unit events.
local WOW_EVENTS = {
  combatStarted = { { "PLAYER_REGEN_DISABLED" } },
  combatEnded = { { "PLAYER_REGEN_ENABLED" } },
  weaponChanged = {
    { "WEAPON_ENCHANT_CHANGED" },
    { "PLAYER_EQUIPMENT_CHANGED" },
    { "UNIT_INVENTORY_CHANGED", "player" },
  },
  spellsChanged = { { "SPELLS_CHANGED" }, { "LEARNED_SPELL_IN_SKILL_LINE" } },
  lifeChanged = { { "PLAYER_DEAD" }, { "PLAYER_ALIVE" }, { "PLAYER_UNGHOST" } },
}

local ICON_SIZE = 40

function ns.CreateRealGame()
  local frame = CreateFrame("Frame")
  local handlers = {}      -- [game event] = { handler, ... }
  local namesByWowEvent = {} -- [WoW event] = { game event, ... }
  local ticker

  local function dispatch(name)
    for _, handler in ipairs(handlers[name] or {}) do
      handler()
    end
  end

  frame:SetScript("OnEvent", function(_, wowEvent)
    for _, name in ipairs(namesByWowEvent[wowEvent] or {}) do
      dispatch(name)
    end
  end)

  local function listen(name)
    if name == "tick" then
      ticker = C_Timer.NewTicker(TICK_SECONDS, function() dispatch("tick") end)
      return
    end
    for _, spec in ipairs(WOW_EVENTS[name]) do
      local wowEvent, unit = spec[1], spec[2]
      if not namesByWowEvent[wowEvent] then
        namesByWowEvent[wowEvent] = {}
        if unit then
          frame:RegisterUnitEvent(wowEvent, unit)
        else
          frame:RegisterEvent(wowEvent)
        end
      end
      table.insert(namesByWowEvent[wowEvent], name)
    end
  end

  local game = {}

  function game:On(name, handler)
    assert(ns.GameEvents[name], "unknown game event: " .. tostring(name))
    if not handlers[name] then
      handlers[name] = {}
      listen(name)
    end
    table.insert(handlers[name], handler)
  end

  function game:GetPlayerClass()
    local _, classFile = UnitClass("player")
    return classFile
  end

  function game:IsInCombat()
    return InCombatLockdown() and true or false
  end

  function game:IsPlayerDead()
    return UnitIsDeadOrGhost("player") and true or false
  end

  function game:IsSpellKnown(spellID)
    return C_SpellBook.IsSpellKnown(spellID) and true or false
  end

  function game:GetMainHandWeaponIcon()
    return GetInventoryItemTexture("player", MAIN_HAND_SLOT)
  end

  function game:GetMainHandEnchants()
    local enchants = {}
    for _, info in ipairs(C_Item.GetWeaponEnchantInfo(Enum.WeaponSlot.MainHand) or {}) do
      table.insert(enchants, {
        hasEnchant = info.hasEnchant,
        enchantType = info.enchantType,
        timeLeft = info.timeLeft,
        iconID = info.enchantIconID,
      })
    end
    return enchants
  end

  function game:Print(message)
    print("|cff0070deShaman-tracker|r: " .. message)
  end

  function game:RegisterSlashCommand(aliases, handler)
    for i, alias in ipairs(aliases) do
      _G["SLASH_SHAMANTRACKER" .. i] = alias
    end
    SlashCmdList.SHAMANTRACKER = handler
  end

  function game:CreateSettingsCategory(name)
    local category = Settings.RegisterVerticalLayoutCategory(name)
    Settings.RegisterAddOnCategory(category)
    return category
  end

  function game:OpenSettings(category)
    Settings.OpenToCategory(category:GetID())
  end

  -- slider = { id, label, tooltip, min, max, step, default, get = fn, set = fn }
  function game:AddSlider(category, slider)
    local variable = "ShamanTracker_" .. slider.id
    local setting
    if Settings.RegisterProxySetting then
      setting = Settings.RegisterProxySetting(category, variable, Settings.VarType.Number,
        slider.label, slider.default, slider.get, slider.set)
    else
      local store = { value = slider.get() }
      setting = Settings.RegisterAddOnSetting(category, variable, "value", store,
        Settings.VarType.Number, slider.label, slider.default)
      Settings.SetOnValueChangedCallback(variable, function(_, _, value) slider.set(value) end)
    end
    local options = Settings.CreateSliderOptions(slider.min, slider.max, slider.step)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    Settings.CreateSlider(category, setting, options, slider.tooltip)
  end

  -- A display-only icon. Clicks pass through it.
  function game:CreateIcon(name)
    local iconFrame = CreateFrame("Frame", "ShamanTracker" .. name, UIParent)
    iconFrame:SetSize(ICON_SIZE, ICON_SIZE)
    iconFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
    iconFrame:EnableMouse(false)
    iconFrame:Hide()
    local texture = iconFrame:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints()
    local text = iconFrame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    text:SetPoint("TOP", iconFrame, "BOTTOM", 0, -2)

    local pulse = iconFrame:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.35)
    fade:SetDuration(0.6)

    local icon = { clickable = false }
    function icon:SetTexture(fileID) texture:SetTexture(fileID) end
    function icon:SetTint(r, g, b) texture:SetVertexColor(r, g, b) end
    function icon:SetText(value) text:SetText(value) end
    function icon:SetPulsing(pulsing)
      if pulsing and not pulse:IsPlaying() then
        pulse:Play()
      elseif not pulsing and pulse:IsPlaying() then
        pulse:Stop()
        iconFrame:SetAlpha(1)
      end
    end
    function icon:Show() iconFrame:Show() end
    function icon:Hide() iconFrame:Hide() end
    return icon
  end

  return game
end

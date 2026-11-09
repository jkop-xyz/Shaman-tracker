-- The real game layer: the only place in Shaman-tracker that calls the WoW API.
-- The tests use a fake with the same methods (spec/support/fake_game.lua).
local _, ns = ...

local MAIN_HAND_SLOT = 16
local TICK_SECONDS = 1
-- Character macros come after the account macros (index 121 on, Phase 0).
local ACCOUNT_MACRO_SLOTS = 120
-- With #showtooltip, the macro shows the spell's own icon.
local MACRO_ICON = "INV_MISC_QUESTIONMARK"

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
  macrosChanged = { { "UPDATE_MACROS" } },
  totemsChanged = { { "PLAYER_TOTEM_UPDATE" } },
}

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

  -- Character macros only. Scanning their slots (not GetMacroIndexByName)
  -- means an account macro with the same name is never touched.
  local function characterMacroIndex(name)
    local _, numCharacter = GetNumMacros()
    for index = ACCOUNT_MACRO_SLOTS + 1, ACCOUNT_MACRO_SLOTS + numCharacter do
      if GetMacroInfo(index) == name then return index end
    end
    return nil
  end

  function game:GetMacroBody(name)
    local index = characterMacroIndex(name)
    if not index then return nil end
    local _, _, body = GetMacroInfo(index)
    return body
  end

  function game:SetMacro(name, body)
    local index = characterMacroIndex(name)
    if index then
      EditMacro(index, nil, nil, body)
      return true
    end
    local ok, newIndex = pcall(CreateMacro, name, MACRO_ICON, body, true)
    return ok and type(newIndex) == "number" and newIndex > 0
  end

  -- nil if the slot is empty. In combat the values are secret: they may only
  -- be handed to widgets. GetTotemDuration returns nil (not secret) for an
  -- empty slot; the `haveTotem` flag isn't reliable (Phase 0, issue #9).
  function game:GetActiveTotem(slot)
    local duration = GetTotemDuration(slot)
    if duration == nil then return nil end
    local _, _, _, _, icon = GetTotemInfo(slot)
    return { icon = icon, duration = duration }
  end

  function game:GetKnownTotems(slot)
    local totems = {}
    for _, spellID in ipairs({ GetMultiCastTotemSpells(slot) }) do
      table.insert(totems, { name = C_Spell.GetSpellName(spellID), icon = C_Spell.GetSpellTexture(spellID) })
    end
    return totems
  end

  function game:GetSpellIcon(spellName)
    return C_Spell.GetSpellTexture(spellName)
  end

  -- On-screen widgets live in Game/Widgets.lua.
  function game:CreateIcon(name) return ns.Widgets.CreateIcon(name) end
  function game:CreateTotemBar(name) return ns.Widgets.CreateTotemBar(name) end
  function game:ShowMenu(owner, items) ns.Widgets.ShowMenu(owner, items) end
  function game:PromptText(prompt) ns.Widgets.PromptText(prompt) end
  function game:Confirm(confirmation) ns.Widgets.Confirm(confirmation) end

  return game
end

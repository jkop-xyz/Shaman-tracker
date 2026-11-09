-- The real game layer: the only place in Shaman-tracker that calls the WoW API.
-- The tests use a fake with the same methods (spec/support/fake_game.lua).
local _, ns = ...

local WOW_EVENTS = {
  combatStarted = "PLAYER_REGEN_DISABLED",
  combatEnded = "PLAYER_REGEN_ENABLED",
}

function ns.CreateRealGame()
  local frame = CreateFrame("Frame")
  local handlers = {}

  frame:SetScript("OnEvent", function(_, wowEvent, ...)
    for _, handler in ipairs(handlers[wowEvent] or {}) do
      handler(...)
    end
  end)

  local game = {}

  function game:On(name, handler)
    assert(ns.GameEvents[name], "unknown game event: " .. tostring(name))
    local wowEvent = WOW_EVENTS[name]
    if not handlers[wowEvent] then
      handlers[wowEvent] = {}
      frame:RegisterEvent(wowEvent)
    end
    table.insert(handlers[wowEvent], handler)
  end

  function game:GetPlayerClass()
    local _, classFile = UnitClass("player")
    return classFile
  end

  function game:IsInCombat()
    return InCombatLockdown() and true or false
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

  return game
end

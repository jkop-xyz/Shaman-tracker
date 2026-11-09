-- Starts Shaman-tracker on top of a game layer.
local _, ns = ...

local Addon = {}
ns.Addon = Addon

local SCHEMA_VERSION = 1
local SETTINGS_NAME = "Shaman-tracker"
local SLASH_ALIASES = { "/st", "/shamantracker" }

local USAGE = {
  "Commands:",
  "/st settings - open the settings panel",
}

-- Returns the running addon. On a non-Shaman character it stays inactive:
-- no slash command, no settings, nothing on screen.
function Addon.Start(game, db)
  local addon = { active = false, game = game, db = db }
  if game:GetPlayerClass() ~= "SHAMAN" then
    return addon
  end

  addon.active = true
  db.schemaVersion = db.schemaVersion or SCHEMA_VERSION
  addon.settingsCategory = game:CreateSettingsCategory(SETTINGS_NAME)
  game:RegisterSlashCommand(SLASH_ALIASES, function(msg)
    Addon.HandleSlash(addon, msg)
  end)
  addon.imbueReminder = ns.ImbueReminder.Start(game, db, addon.settingsCategory)
  addon.gate = ns.CombatGate.New(game)
  addon.totemBar = ns.TotemBar.Start(game, db, addon.gate)
  addon.totemMacros = ns.TotemMacros.Start(game, addon.gate, db.totemSets)
  addon.totemBar.onApplied = addon.totemMacros.sync
  return addon
end

function Addon.HandleSlash(addon, msg)
  local command = ((msg or ""):match("^%s*(%S*)") or ""):lower()
  if command == "settings" then
    addon.game:OpenSettings(addon.settingsCategory)
    return
  end
  for _, line in ipairs(USAGE) do
    addon.game:Print(line)
  end
end

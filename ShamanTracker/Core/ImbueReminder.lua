-- Imbue Reminder: shows an icon when the main-hand weapon's Imbue is Missing
-- or Expiring.
local _, ns = ...

local ImbueReminder = {}
ns.ImbueReminder = ImbueReminder

-- Weapon-enchant entries of this type are Shaman Imbues; stones and oils are
-- type 2 (confirmed in-game in Phase 0, issue #9).
local IMBUE_ENCHANT_TYPE = 3

-- Rank 1 of each Imbue spell. Every rank stays in the spellbook, so knowing
-- rank 1 means the Imbue is known.
local IMBUE_SPELLS = {
  8017, -- Rockbiter Weapon
  8024, -- Flametongue Weapon
  8033, -- Frostbrand Weapon
  8232, -- Windfury Weapon
}

local THRESHOLD_SETTING = {
  id = "imbueExpiringThreshold",
  label = "Imbue Expiring warning (minutes)",
  tooltip = "Show the Imbue Reminder when the Imbue has less time left than this.",
  min = 1,
  max = 60,
  step = 1,
  default = 5,
}

ImbueReminder.MISSING_TINT = { 1, 0.3, 0.3 }
ImbueReminder.NO_TINT = { 1, 1, 1 }

local function knowsAnyImbue(game)
  for _, spellID in ipairs(IMBUE_SPELLS) do
    if game:IsSpellKnown(spellID) then return true end
  end
  return false
end

local function findImbue(enchants)
  for _, enchant in ipairs(enchants) do
    if enchant.hasEnchant and enchant.enchantType == IMBUE_ENCHANT_TYPE then
      return enchant
    end
  end
  return nil
end

-- "m:ss", rounding up so the text never shows 0:00 while time remains.
function ImbueReminder.FormatTimeLeft(milliseconds)
  local seconds = math.ceil(milliseconds / 1000)
  return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

-- Works out what the reminder should show right now. Returns one of:
--   { kind = "hidden" }
--   { kind = "missing", weaponIcon = <fileID> }
--   { kind = "expiring", imbueIcon = <fileID>, timeLeft = <ms> }
function ImbueReminder.Evaluate(game, thresholdMinutes)
  if game:IsPlayerDead() then return { kind = "hidden" } end
  local weaponIcon = game:GetMainHandWeaponIcon()
  if not weaponIcon then return { kind = "hidden" } end
  if not knowsAnyImbue(game) then return { kind = "hidden" } end

  local imbue = findImbue(game:GetMainHandEnchants())
  if not imbue then
    return { kind = "missing", weaponIcon = weaponIcon }
  end
  if imbue.timeLeft < thresholdMinutes * 60 * 1000 then
    return { kind = "expiring", imbueIcon = imbue.iconID, timeLeft = imbue.timeLeft }
  end
  return { kind = "hidden" }
end

local function render(icon, state)
  if state.kind == "missing" then
    icon:SetTexture(state.weaponIcon)
    icon:SetTint(unpack(ImbueReminder.MISSING_TINT))
    icon:SetText("")
    icon:SetPulsing(false)
    icon:Show()
  elseif state.kind == "expiring" then
    icon:SetTexture(state.imbueIcon)
    icon:SetTint(unpack(ImbueReminder.NO_TINT))
    icon:SetText(ImbueReminder.FormatTimeLeft(state.timeLeft))
    icon:SetPulsing(true)
    icon:Show()
  else
    icon:SetPulsing(false)
    icon:Hide()
  end
end

-- db: the per-character saved data; settingsCategory: where its settings go.
function ImbueReminder.Start(game, db, settingsCategory, gate)
  db.imbueReminder = db.imbueReminder or {}
  local saved = db.imbueReminder
  saved.expiringThresholdMinutes = saved.expiringThresholdMinutes or THRESHOLD_SETTING.default

  local icon = game:CreateIcon("ImbueReminder")
  local frame = ns.FeatureFrame.Attach(game, gate, db, settingsCategory, {
    key = "imbueReminder",
    label = "Imbue Reminder",
    frame = icon,
    defaultLayout = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -150 },
  })
  frame.apply()
  local function update()
    render(icon, ImbueReminder.Evaluate(game, saved.expiringThresholdMinutes))
  end

  local slider = {}
  for key, value in pairs(THRESHOLD_SETTING) do slider[key] = value end
  slider.get = function() return saved.expiringThresholdMinutes end
  slider.set = function(minutes)
    saved.expiringThresholdMinutes = minutes
    update()
  end
  game:AddSlider(settingsCategory, slider)

  for _, event in ipairs({ "weaponChanged", "spellsChanged", "lifeChanged", "tick" }) do
    game:On(event, update)
  end
  update()
  return { icon = icon, update = update, frame = frame }
end

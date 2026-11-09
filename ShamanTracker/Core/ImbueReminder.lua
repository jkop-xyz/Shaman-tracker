-- Imbue Reminder: shows an icon when the main-hand weapon's Imbue is Missing.
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

ImbueReminder.MISSING_TINT = { 1, 0.3, 0.3 }

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

-- Works out what the reminder should show right now.
-- Returns { kind = "hidden" } or { kind = "missing", weaponIcon = <fileID> }.
function ImbueReminder.Evaluate(game)
  if game:IsPlayerDead() then return { kind = "hidden" } end
  local weaponIcon = game:GetMainHandWeaponIcon()
  if not weaponIcon then return { kind = "hidden" } end
  if not knowsAnyImbue(game) then return { kind = "hidden" } end
  if findImbue(game:GetMainHandEnchants()) then return { kind = "hidden" } end
  return { kind = "missing", weaponIcon = weaponIcon }
end

local function render(icon, state)
  if state.kind == "missing" then
    icon:SetTexture(state.weaponIcon)
    icon:SetTint(unpack(ImbueReminder.MISSING_TINT))
    icon:Show()
  else
    icon:Hide()
  end
end

function ImbueReminder.Start(game)
  local icon = game:CreateIcon("ImbueReminder")
  local function update()
    render(icon, ImbueReminder.Evaluate(game))
  end
  for _, event in ipairs({ "weaponChanged", "spellsChanged", "lifeChanged", "tick" }) do
    game:On(event, update)
  end
  update()
  return { icon = icon, update = update }
end

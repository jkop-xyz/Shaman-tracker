-- Totem Bar: one button per Element. Left-click places the Chosen Totem;
-- right-click picks a different one.
local _, ns = ...

local TotemBar = {}
ns.TotemBar = TotemBar

local TotemSets = ns.TotemSets

local function elementByKey(key)
  for _, element in ipairs(ns.Elements) do
    if element.key == key then return element end
  end
end

-- The icon for a totem name: from the known totems, else from the spell itself.
local function totemIcon(game, element, totemName)
  if not totemName then return nil end
  for _, totem in ipairs(game:GetKnownTotems(element.slot)) do
    if totem.name == totemName then return totem.icon end
  end
  return game:GetSpellIcon(totemName)
end

function TotemBar.Start(game, db)
  db.totemSets = TotemSets.Ensure(db.totemSets or {})
  local data = db.totemSets

  local bar = game:CreateTotemBar("TotemBar")
  local buttons = {}
  local controller = { bar = bar, buttons = buttons }

  -- Brings every button in line with the Active Totem Set.
  function controller.refresh()
    for _, element in ipairs(ns.Elements) do
      local chosen = TotemSets.Chosen(data, element.key)
      local button = buttons[element.key]
      button:SetIcon(totemIcon(game, element, chosen))
      button:SetSpell(chosen)
    end
  end

  function controller.choose(elementKey, totemName)
    TotemSets.Choose(data, elementKey, totemName)
    controller.refresh()
  end

  local function openTotemMenu(element)
    local chosen = TotemSets.Chosen(data, element.key)
    local items = { { title = element.name } }
    for _, totem in ipairs(game:GetKnownTotems(element.slot)) do
      table.insert(items, {
        text = totem.name,
        checked = totem.name == chosen,
        onSelect = function() controller.choose(element.key, totem.name) end,
      })
    end
    table.insert(items, {
      text = "None",
      checked = chosen == nil,
      onSelect = function() controller.choose(element.key, nil) end,
    })
    game:ShowMenu(buttons[element.key], items)
  end

  for _, element in ipairs(ns.Elements) do
    local button = bar:CreateButton(element.key)
    button:OnRightClick(function() openTotemMenu(elementByKey(element.key)) end)
    buttons[element.key] = button
  end

  -- Icons can change when the player learns a new rank.
  game:On("spellsChanged", controller.refresh)
  controller.refresh()
  return controller
end

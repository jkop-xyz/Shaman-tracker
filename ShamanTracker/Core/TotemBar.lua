-- Totem Bar: one button per Element. Left-click places the Chosen Totem;
-- right-click picks a different one.
--
-- Changes made in combat become Pending Choices: they go into a pending copy
-- of the Totem Sets, and the buttons keep placing the old totems (the game
-- doesn't allow changing them in combat). When combat ends, the pending copy
-- replaces the saved Totem Sets and everything is applied together.
local _, ns = ...

local TotemBar = {}
ns.TotemBar = TotemBar

local TotemSets = ns.TotemSets

-- The icon for a totem name: from the known totems, else from the spell itself.
local function totemIcon(game, element, totemName)
  if not totemName then return nil end
  for _, totem in ipairs(game:GetKnownTotems(element.slot)) do
    if totem.name == totemName then return totem.icon end
  end
  return game:GetSpellIcon(totemName)
end

function TotemBar.Start(game, db, gate, settingsCategory)
  db.totemSets = TotemSets.Ensure(db.totemSets or {})
  local saved = db.totemSets -- what the buttons place
  local pending = nil        -- in combat: the Totem Sets with Pending Choices applied

  local bar = game:CreateTotemBar("TotemBar")
  local buttons = {}
  local controller = { bar = bar, buttons = buttons }

  local frame = ns.FeatureFrame.Attach(game, gate, db, settingsCategory, {
    key = "totemBar",
    label = "Totem Bar",
    frame = bar,
    protected = true,
    defaultLayout = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -200 },
    applyExtra = function(saved) bar:SetVertical(saved.vertical == true) end,
    onEnabledChanged = function(enabled)
      if controller.onEnabledChanged then controller.onEnabledChanged(enabled) end
    end,
  })
  frame.addCheckbox({
    id = "totemBarVertical",
    label = "Vertical Totem Bar",
    tooltip = "Stack the Totem Bar's buttons top to bottom instead of left to right.",
    default = false,
    get = function() return frame.saved.vertical == true end,
    set = function(vertical)
      frame.saved.vertical = vertical
      frame.apply()
    end,
  })
  controller.frame = frame

  function controller.isEnabled()
    return frame.saved.enabled
  end

  -- The Totem Sets as the player has left them, Pending Choices included.
  local function current()
    return pending or saved
  end

  local setButton

  -- Pending Choice markers, and the set control (which shows the set the
  -- player has picked, pending or not).
  local function showMarkers()
    for _, element in ipairs(ns.Elements) do
      local isPending = pending ~= nil
        and TotemSets.Chosen(pending, element.key) ~= TotemSets.Chosen(saved, element.key)
      buttons[element.key]:SetPendingMarker(isPending)
    end
    setButton:SetText(current().active)
    setButton:SetPendingMarker(pending ~= nil and pending.active ~= saved.active)
  end

  -- Icons are safe to change any time; they show what the button places.
  local function showIcons()
    for _, element in ipairs(ns.Elements) do
      buttons[element.key]:SetIcon(totemIcon(game, element, TotemSets.Chosen(saved, element.key)))
    end
  end

  -- The Active Totem badge. In combat the game keeps totem data secret: it
  -- can't be compared or calculated with, only handed to widgets. So the
  -- badge shows whatever is up, without comparing it to the Chosen Totem.
  local function showActiveTotems()
    for _, element in ipairs(ns.Elements) do
      local totem = game:GetActiveTotem(element.slot)
      if totem then
        buttons[element.key]:ShowActiveTotem(totem)
      else
        buttons[element.key]:HideActiveTotem()
      end
    end
  end

  -- Secure: only through the combat gate.
  local function applySpells()
    for _, element in ipairs(ns.Elements) do
      buttons[element.key]:SetSpell(TotemSets.Chosen(saved, element.key))
    end
  end

  -- Called whenever the Totem Sets change. Out of combat the change is saved
  -- and applied; in combat it stays pending.
  local function changed()
    gate:Run("totemBar", function()
      if pending then
        TotemSets.Replace(saved, pending)
        pending = nil
      end
      showIcons()
      applySpells()
      showMarkers()
      if controller.onApplied then controller.onApplied(saved) end
    end)
    showMarkers()
  end

  -- Runs `edit` on the Totem Sets the player is editing right now.
  function controller.edit(edit)
    if game:IsInCombat() and not pending then
      pending = TotemSets.Copy(saved)
    end
    local result = { edit(current()) }
    changed()
    return unpack(result)
  end

  function controller.choose(elementKey, totemName)
    controller.edit(function(data) TotemSets.Choose(data, elementKey, totemName) end)
  end

  function controller.current()
    return current()
  end

  local function openTotemMenu(element)
    local chosen = TotemSets.Chosen(current(), element.key)
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

  -- Runs a Totem Sets change; tells the player if it was refused.
  local function editSets(edit)
    local ok, reason = controller.edit(edit)
    if not ok and reason then game:Print(reason) end
  end

  local function openSetMenu()
    local data = current()
    local items = { { title = "Totem Sets" } }
    for _, name in ipairs(TotemSets.Names(data)) do
      table.insert(items, {
        text = name,
        checked = name == data.active,
        onSelect = function()
          editSets(function(sets) TotemSets.Switch(sets, name) return true end)
        end,
      })
    end
    table.insert(items, { divider = true })
    table.insert(items, {
      text = "New set...",
      onSelect = function()
        game:PromptText({
          title = "Name for the new Totem Set:",
          default = TotemSets.UnusedName(current()),
          onAccept = function(name)
            editSets(function(sets) return TotemSets.Create(sets, name) end)
          end,
        })
      end,
    })
    local active = data.active
    table.insert(items, {
      text = "Rename \"" .. active .. "\"...",
      onSelect = function()
        game:PromptText({
          title = "New name for the Totem Set \"" .. active .. "\":",
          default = active,
          onAccept = function(name)
            editSets(function(sets) return TotemSets.Rename(sets, active, name) end)
          end,
        })
      end,
    })
    table.insert(items, {
      text = "Delete \"" .. active .. "\"...",
      disabled = #data.sets <= 1,
      onSelect = function()
        game:Confirm({
          text = "Delete the Totem Set \"" .. active .. "\"?",
          onAccept = function()
            editSets(function(sets) return TotemSets.Delete(sets, active) end)
          end,
        })
      end,
    })
    game:ShowMenu(setButton, items)
  end

  setButton = bar:CreateSetButton()
  setButton:OnClick(openSetMenu)

  for _, element in ipairs(ns.Elements) do
    local button = bar:CreateButton(element.key, element.name)
    button:OnRightClick(function() openTotemMenu(element) end)
    buttons[element.key] = button
  end

  -- Icons can change when the player learns a new rank.
  game:On("spellsChanged", showIcons)
  game:On("totemsChanged", showActiveTotems)

  frame.apply()
  showIcons()
  showActiveTotems()
  gate:Run("totemBar", applySpells)
  showMarkers()
  return controller
end

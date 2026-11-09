-- Totem Macros (ADR-0001): the addon owns five character macros and keeps
-- them in step with the Active Totem Set, so the player's own action bars and
-- keybinds always place the current Chosen Totems. Rewrites wait for combat to
-- end; deleted macros are recreated; no other macro is ever touched.
local _, ns = ...

local TotemMacros = {}
ns.TotemMacros = TotemMacros

local TotemSets = ns.TotemSets

local EMPTY_BODY = "#showtooltip"
local DROP_ALL_NAME = "ST All"
-- Restarts the sequence after combat, or after 5 seconds without a press.
local DROP_ALL_RESET = "reset=combat/5"

function TotemMacros.ElementMacroName(element)
  return "ST " .. element.name
end

-- [macro name] = body, for the given Totem Sets data.
function TotemMacros.Bodies(data)
  local bodies = {}
  local sequence = {}
  for _, element in ipairs(ns.Elements) do
    local totem = TotemSets.Chosen(data, element.key)
    if totem then
      bodies[TotemMacros.ElementMacroName(element)] = EMPTY_BODY .. "\n/cast " .. totem
      table.insert(sequence, totem)
    else
      bodies[TotemMacros.ElementMacroName(element)] = EMPTY_BODY
    end
  end
  if #sequence > 0 then
    bodies[DROP_ALL_NAME] = EMPTY_BODY .. "\n/castsequence " .. DROP_ALL_RESET .. " " .. table.concat(sequence, ", ")
  else
    bodies[DROP_ALL_NAME] = EMPTY_BODY
  end
  return bodies
end

local function macroNames()
  local names = {}
  for _, element in ipairs(ns.Elements) do
    table.insert(names, TotemMacros.ElementMacroName(element))
  end
  table.insert(names, DROP_ALL_NAME)
  return names
end

-- The game may store a body with trailing whitespace; comparing exactly
-- would rewrite the macro on every macro update, forever.
local function trimmed(body)
  return body and (body:gsub("%s+$", "")) or nil
end

-- data: the saved Totem Sets (what the buttons place).
function TotemMacros.Start(game, gate, data)
  local warnedFull = false
  local syncing = false

  local function sync()
    if syncing then return end -- our own writes fire macrosChanged
    syncing = true
    local bodies = TotemMacros.Bodies(data)
    local full = false
    for _, name in ipairs(macroNames()) do
      if trimmed(game:GetMacroBody(name)) ~= bodies[name] then
        if not game:SetMacro(name, bodies[name]) then full = true end
      end
    end
    syncing = false
    if full and not warnedFull then
      warnedFull = true
      game:Print("Can't create all Totem Macros: your character macro slots are full. "
        .. "Free some up and they'll be created.")
    elseif not full then
      warnedFull = false
    end
  end

  local function requestSync()
    gate:Run("totemMacros", sync)
  end

  game:On("macrosChanged", requestSync)
  requestSync()
  return { sync = requestSync }
end

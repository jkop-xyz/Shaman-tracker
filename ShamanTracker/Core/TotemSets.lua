-- Totem Sets: the per-character data behind the Totem Bar and Totem Macros.
--
-- Shape (saved per character):
--   { active = "Default", sets = { { name = "Default", totems = { earth = "Stoneskin Totem", ... } }, ... } }
-- A missing Element in `totems` means the Element is empty. Totems are stored
-- by name (all ranks); the game casts the highest rank known.
local _, ns = ...

local TotemSets = {}
ns.TotemSets = TotemSets

TotemSets.DEFAULT_NAME = "Default"

-- Fills in a fresh "Default" set if the data is new or broken. Returns the data.
function TotemSets.Ensure(data)
  data.sets = data.sets or {}
  if #data.sets == 0 then
    table.insert(data.sets, { name = TotemSets.DEFAULT_NAME, totems = {} })
  end
  if not TotemSets.Find(data, data.active) then
    data.active = data.sets[1].name
  end
  return data
end

function TotemSets.Find(data, name)
  for _, set in ipairs(data.sets) do
    if set.name == name then return set end
  end
  return nil
end

function TotemSets.Active(data)
  return TotemSets.Find(data, data.active)
end

-- The Active Totem Set's Chosen Totem for an Element, or nil if empty.
function TotemSets.Chosen(data, elementKey)
  return TotemSets.Active(data).totems[elementKey]
end

-- Sets (or, with nil, clears) a Chosen Totem in the Active Totem Set.
function TotemSets.Choose(data, elementKey, totemName)
  TotemSets.Active(data).totems[elementKey] = totemName
end

function TotemSets.Switch(data, name)
  assert(TotemSets.Find(data, name), "no Totem Set named " .. tostring(name))
  data.active = name
end

function TotemSets.Names(data)
  local names = {}
  for i, set in ipairs(data.sets) do names[i] = set.name end
  return names
end

-- Returns a name not yet used: "Set 2", "Set 3", ...
function TotemSets.UnusedName(data)
  local n = #data.sets + 1
  while TotemSets.Find(data, "Set " .. n) do n = n + 1 end
  return "Set " .. n
end

local function validName(data, name, except)
  if type(name) ~= "string" then return false, "A Totem Set needs a name." end
  name = name:match("^%s*(.-)%s*$")
  if name == "" then return false, "A Totem Set needs a name." end
  local existing = TotemSets.Find(data, name)
  if existing and existing.name ~= except then
    return false, "There is already a Totem Set named \"" .. name .. "\"."
  end
  return true, name
end

-- Creates an empty set and makes it the Active Totem Set.
-- Returns true, or false and a reason.
function TotemSets.Create(data, name)
  local ok, result = validName(data, name)
  if not ok then return false, result end
  table.insert(data.sets, { name = result, totems = {} })
  data.active = result
  return true
end

function TotemSets.Rename(data, oldName, newName)
  local set = TotemSets.Find(data, oldName)
  if not set then return false, "No Totem Set named \"" .. tostring(oldName) .. "\"." end
  local ok, result = validName(data, newName, oldName)
  if not ok then return false, result end
  set.name = result
  if data.active == oldName then data.active = result end
  return true
end

-- Deletes a set. Deleting the Active Totem Set switches to another set first;
-- the last set can't be deleted.
function TotemSets.Delete(data, name)
  if #data.sets <= 1 then return false, "The last Totem Set can't be deleted." end
  for i, set in ipairs(data.sets) do
    if set.name == name then
      table.remove(data.sets, i)
      if data.active == name then
        data.active = data.sets[math.min(i, #data.sets)].name
      end
      return true
    end
  end
  return false, "No Totem Set named \"" .. tostring(name) .. "\"."
end

-- A deep copy, used to hold Pending Choices during combat.
function TotemSets.Copy(data)
  local copy = { active = data.active, sets = {} }
  for i, set in ipairs(data.sets) do
    local totems = {}
    for element, totem in pairs(set.totems) do totems[element] = totem end
    copy.sets[i] = { name = set.name, totems = totems }
  end
  return copy
end

-- Replaces `target`'s contents with `source`'s (keeps the saved-variable table).
function TotemSets.Replace(target, source)
  local copy = TotemSets.Copy(source)
  target.active = copy.active
  target.sets = copy.sets
end

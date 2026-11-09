-- The combat gate: the one place that knows the game refuses some changes in
-- combat (secure button spells, macros, moving the Totem Bar). Such changes go
-- through gate:Run. Out of combat they happen at once; in combat they wait,
-- and the latest change for each key wins. When combat ends, every waiting
-- change runs, in the order its key was first queued.
local _, ns = ...

local CombatGate = {}
ns.CombatGate = CombatGate

function CombatGate.New(game)
  local gate = {}
  local waiting = {} -- [key] = fn
  local order = {}   -- keys, in first-queued order

  function gate:Run(key, fn)
    if not game:IsInCombat() then
      fn()
      return
    end
    if not waiting[key] then table.insert(order, key) end
    waiting[key] = fn
  end

  game:On("combatEnded", function()
    local keys, fns = order, waiting
    order, waiting = {}, {}
    for _, key in ipairs(keys) do
      fns[key]()
    end
  end)

  return gate
end

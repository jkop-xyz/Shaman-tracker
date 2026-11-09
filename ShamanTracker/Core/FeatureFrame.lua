-- Feature frames: each Feature's on-screen frame has its own saved position,
-- size, lock and on/off switch, with settings in the settings panel.
local _, ns = ...

local FeatureFrame = {}
ns.FeatureFrame = FeatureFrame

local SIZE = { min = 50, max = 200, step = 10, default = 100 }

-- spec = {
--   key,            -- saved-data key and setting id prefix, e.g. "totemBar"
--   label,          -- shown in settings, e.g. "Totem Bar"
--   frame,          -- from the game layer (icon or Totem Bar)
--   defaultLayout,  -- { point, relativePoint, x, y }
--   protected,      -- true if the frame holds secure buttons: changes go through the combat gate
--   applyExtra,     -- optional fn(saved), run with every apply
--   onEnabledChanged, -- optional fn(enabled)
-- }
-- Returns a controller: { saved, apply(), setLocked(locked), addCheckbox(checkbox) }.
function FeatureFrame.Attach(game, gate, db, category, spec)
  db.frames = db.frames or {}
  db.frames[spec.key] = db.frames[spec.key] or {}
  local saved = db.frames[spec.key]
  if saved.enabled == nil then saved.enabled = true end
  if saved.locked == nil then saved.locked = true end
  saved.size = saved.size or SIZE.default
  if not saved.point then
    saved.point = spec.defaultLayout.point
    saved.relativePoint = spec.defaultLayout.relativePoint
    saved.x = spec.defaultLayout.x
    saved.y = spec.defaultLayout.y
  end

  local frame = spec.frame
  local controller = { saved = saved }

  local function applyNow()
    frame:SetLayout({
      point = saved.point, relativePoint = saved.relativePoint,
      x = saved.x, y = saved.y, scale = saved.size / 100,
    })
    frame:SetEnabled(saved.enabled)
    frame:SetUnlocked(not saved.locked)
    if spec.applyExtra then spec.applyExtra(saved) end
  end

  function controller.apply()
    if spec.protected then
      gate:Run("frame:" .. spec.key, applyNow)
    else
      applyNow()
    end
  end

  function controller.setLocked(locked)
    saved.locked = locked
    controller.apply()
  end

  function controller.addCheckbox(checkbox)
    game:AddCheckbox(category, checkbox)
  end

  frame:OnMoved(function(point, relativePoint, x, y)
    saved.point, saved.relativePoint, saved.x, saved.y = point, relativePoint, x, y
  end)

  game:AddHeader(category, spec.label)
  game:AddCheckbox(category, {
    id = spec.key .. "Shown",
    label = "Show " .. spec.label,
    tooltip = "Switch the " .. spec.label .. " on or off.",
    default = true,
    get = function() return saved.enabled end,
    set = function(enabled)
      saved.enabled = enabled
      controller.apply()
      if spec.onEnabledChanged then spec.onEnabledChanged(enabled) end
    end,
  })
  game:AddCheckbox(category, {
    id = spec.key .. "Locked",
    label = "Lock " .. spec.label .. " position",
    tooltip = "Unlock to drag the " .. spec.label .. " somewhere else. /st unlock unlocks every Feature.",
    default = true,
    get = function() return saved.locked end,
    set = controller.setLocked,
  })
  game:AddSlider(category, {
    id = spec.key .. "Size",
    label = spec.label .. " size (%)",
    tooltip = "Scale the " .. spec.label .. ".",
    min = SIZE.min,
    max = SIZE.max,
    step = SIZE.step,
    default = SIZE.default,
    get = function() return saved.size end,
    set = function(size)
      saved.size = size
      controller.apply()
    end,
  })

  return controller
end

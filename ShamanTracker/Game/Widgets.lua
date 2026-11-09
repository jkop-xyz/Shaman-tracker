-- On-screen widgets for the real game layer. Like RealGame.lua, this is WoW
-- API code; the fake game layer has a matching fake for each widget.
local _, ns = ...

local Widgets = {}
ns.Widgets = Widgets

local ICON_SIZE = 40
local BUTTON_SIZE = 36
local BUTTON_GAP = 4
local BADGE_SIZE = 16
local EMPTY_COLOR = { 0, 0, 0, 0.5 }

---------------------------------------------------------------------------
-- Imbue Reminder icon: display-only, clicks pass through.
---------------------------------------------------------------------------

function Widgets.CreateIcon(name)
  local frame = CreateFrame("Frame", "ShamanTracker" .. name, UIParent)
  frame:SetSize(ICON_SIZE, ICON_SIZE)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
  frame:EnableMouse(false)
  frame:Hide()
  local texture = frame:CreateTexture(nil, "ARTWORK")
  texture:SetAllPoints()
  local text = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  text:SetPoint("TOP", frame, "BOTTOM", 0, -2)

  local pulse = frame:CreateAnimationGroup()
  pulse:SetLooping("BOUNCE")
  local fade = pulse:CreateAnimation("Alpha")
  fade:SetFromAlpha(1)
  fade:SetToAlpha(0.35)
  fade:SetDuration(0.6)

  local icon = { frame = frame, clickable = false }
  function icon:SetTexture(fileID) texture:SetTexture(fileID) end
  function icon:SetTint(r, g, b) texture:SetVertexColor(r, g, b) end
  function icon:SetText(value) text:SetText(value) end
  function icon:SetPulsing(pulsing)
    if pulsing and not pulse:IsPlaying() then
      pulse:Play()
    elseif not pulsing and pulse:IsPlaying() then
      pulse:Stop()
      frame:SetAlpha(1)
    end
  end
  function icon:Show() frame:Show() end
  function icon:Hide() frame:Hide() end
  return icon
end

---------------------------------------------------------------------------
-- Totem Bar: a row of secure buttons, one per Element.
---------------------------------------------------------------------------

local function createTotemButton(bar, elementKey, index)
  local frame = CreateFrame("Button", "ShamanTrackerTotemButton" .. index, bar.frame,
    "SecureActionButtonTemplate")
  frame:SetSize(BUTTON_SIZE, BUTTON_SIZE)
  frame:RegisterForClicks("AnyUp", "AnyDown")
  -- Only the left button casts; the right button opens the totem menu.
  frame:SetAttribute("type1", "spell")

  local background = frame:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints()
  background:SetColorTexture(unpack(EMPTY_COLOR))
  local icon = frame:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints()
  local highlight = frame:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetAllPoints()
  highlight:SetColorTexture(1, 1, 1, 0.15)

  -- Pending Choice marker: a small gold dot in the top-right corner.
  local marker = frame:CreateTexture(nil, "OVERLAY")
  marker:SetSize(10, 10)
  marker:SetPoint("TOPRIGHT", -1, -1)
  marker:SetColorTexture(1, 0.82, 0, 1)
  marker:Hide()

  -- Active Totem: a cooldown swipe with countdown over the button, and a
  -- small badge with the Active Totem's icon in the bottom-left corner.
  local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
  cooldown:SetAllPoints()
  cooldown:SetDrawEdge(false)
  cooldown:SetHideCountdownNumbers(false)
  local badgeFrame = CreateFrame("Frame", nil, frame)
  badgeFrame:SetFrameLevel(cooldown:GetFrameLevel() + 1)
  badgeFrame:SetSize(BADGE_SIZE, BADGE_SIZE)
  badgeFrame:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -3, -3)
  local badgeBorder = badgeFrame:CreateTexture(nil, "BACKGROUND")
  badgeBorder:SetPoint("TOPLEFT", -1, 1)
  badgeBorder:SetPoint("BOTTOMRIGHT", 1, -1)
  badgeBorder:SetColorTexture(0, 0, 0, 1)
  local badge = badgeFrame:CreateTexture(nil, "ARTWORK")
  badge:SetAllPoints()
  badgeFrame:Hide()

  local button = { frame = frame, element = elementKey }
  local rightClickHandler

  -- totem = { icon, duration } from the game layer; possibly secret values,
  -- so they go straight into the widgets.
  function button:ShowActiveTotem(totem)
    badge:SetTexture(totem.icon)
    badgeFrame:Show()
    cooldown:SetCooldownFromDurationObject(totem.duration)
  end
  function button:HideActiveTotem()
    badgeFrame:Hide()
    cooldown:Clear()
  end

  frame:HookScript("OnClick", function(_, mouseButton, down)
    if mouseButton == "RightButton" and not down and rightClickHandler then
      rightClickHandler()
    end
  end)

  function button:SetSpell(spellName) frame:SetAttribute("spell", spellName) end
  function button:SetIcon(fileID) icon:SetTexture(fileID) end
  function button:SetPendingMarker(shown) marker:SetShown(shown and true or false) end
  function button:OnRightClick(handler) rightClickHandler = handler end
  return button
end

function Widgets.CreateTotemBar(name)
  local frame = CreateFrame("Frame", "ShamanTracker" .. name, UIParent)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
  local bar = { frame = frame, buttons = {} }

  local function layout()
    local count = #bar.buttons
    frame:SetSize(count * BUTTON_SIZE + math.max(count - 1, 0) * BUTTON_GAP, BUTTON_SIZE)
    for i, button in ipairs(bar.buttons) do
      button.frame:ClearAllPoints()
      button.frame:SetPoint("LEFT", frame, "LEFT", (i - 1) * (BUTTON_SIZE + BUTTON_GAP), 0)
    end
  end

  function bar:CreateButton(elementKey)
    local button = createTotemButton(bar, elementKey, #bar.buttons + 1)
    table.insert(bar.buttons, button)
    layout()
    return button
  end

  return bar
end

---------------------------------------------------------------------------
-- Menus. items: list of { title = text } | { divider = true } |
-- { text, checked, onSelect }. Items with `checked` (true or false) are
-- radio items; items without it are plain buttons.
---------------------------------------------------------------------------

function Widgets.ShowMenu(owner, items)
  MenuUtil.CreateContextMenu(owner.frame, function(_, root)
    for _, item in ipairs(items) do
      if item.title then
        root:CreateTitle(item.title)
      elseif item.divider then
        root:CreateDivider()
      elseif item.checked ~= nil then
        root:CreateRadio(item.text, function() return item.checked end, function() item.onSelect() end)
      else
        root:CreateButton(item.text, function() item.onSelect() end)
      end
    end
  end)
end

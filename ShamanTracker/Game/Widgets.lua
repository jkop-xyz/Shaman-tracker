-- On-screen widgets for the real game layer. Like RealGame.lua, this is WoW
-- API code; the fake game layer has a matching fake for each widget.
local _, ns = ...

local Widgets = {}
ns.Widgets = Widgets

local ICON_SIZE = 40
local BUTTON_SIZE = 36
local BUTTON_GAP = 4
local BADGE_SIZE = 16
local SET_BUTTON_HEIGHT = 14
local EMPTY_COLOR = { 0, 0, 0, 0.5 }
local SET_BUTTON_WIDTH = 90
local PLACEHOLDER_ICON = 134400 -- question mark

---------------------------------------------------------------------------
-- Feature frame behaviour shared by the Imbue Reminder icon and the Totem
-- Bar: layout, on/off, and an unlocked mode with a drag handle on top (so
-- dragging never clicks the secure buttons underneath).
---------------------------------------------------------------------------

local function addFeatureFrame(handle, frame, label, updateVisibility)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)

  local dragHandle = CreateFrame("Frame", nil, frame)
  dragHandle:SetAllPoints()
  dragHandle:SetFrameLevel(frame:GetFrameLevel() + 20)
  dragHandle:EnableMouse(true)
  dragHandle:RegisterForDrag("LeftButton")
  local tint = dragHandle:CreateTexture(nil, "OVERLAY")
  tint:SetAllPoints()
  tint:SetColorTexture(0, 0.8, 0.2, 0.35)
  local caption = dragHandle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  caption:SetPoint("BOTTOM", dragHandle, "TOP", 0, 2)
  caption:SetText(label)
  dragHandle:Hide()

  local movedHandler
  dragHandle:SetScript("OnDragStart", function()
    if not InCombatLockdown() then frame:StartMoving() end
  end)
  dragHandle:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    -- Shaman-tracker saves the position itself, not the game's layout cache.
    frame:SetUserPlaced(false)
    local point, _, relativePoint, x, y = frame:GetPoint()
    if movedHandler then movedHandler(point, relativePoint, x, y) end
  end)

  handle.enabled = true
  handle.unlocked = false
  function handle:SetLayout(layout)
    frame:ClearAllPoints()
    frame:SetPoint(layout.point, UIParent, layout.relativePoint, layout.x, layout.y)
    frame:SetScale(layout.scale)
  end
  function handle:SetEnabled(enabled)
    handle.enabled = enabled
    updateVisibility()
  end
  function handle:SetUnlocked(unlocked)
    handle.unlocked = unlocked
    dragHandle:SetShown(unlocked)
    updateVisibility()
  end
  function handle:OnMoved(handler) movedHandler = handler end
end

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
  -- Shown while unlocked with nothing to remind about, so there's something to drag.
  local placeholder = frame:CreateTexture(nil, "ARTWORK")
  placeholder:SetAllPoints()
  placeholder:SetTexture(PLACEHOLDER_ICON)
  placeholder:Hide()
  local text = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  text:SetPoint("TOP", frame, "BOTTOM", 0, -2)

  local pulse = frame:CreateAnimationGroup()
  pulse:SetLooping("BOUNCE")
  local fade = pulse:CreateAnimation("Alpha")
  fade:SetFromAlpha(1)
  fade:SetToAlpha(0.35)
  fade:SetDuration(0.6)

  local icon = { frame = frame, clickable = false }
  local contentShown = false

  local function updateVisibility()
    texture:SetShown(contentShown)
    text:SetShown(contentShown)
    placeholder:SetShown(icon.unlocked and not contentShown)
    frame:SetShown(icon.enabled and (contentShown or icon.unlocked))
  end
  addFeatureFrame(icon, frame, "Imbue Reminder", updateVisibility)

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
  function icon:Show()
    contentShown = true
    updateVisibility()
  end
  function icon:Hide()
    contentShown = false
    updateVisibility()
  end
  return icon
end

---------------------------------------------------------------------------
-- Totem Bar: a row of secure buttons, one per Element.
---------------------------------------------------------------------------

-- Out of combat only: hovering a totem button shows the totem's tooltip.
local RIGHT_CLICK_HINT = "Right-click to choose a different totem."
local tooltipOwners = {}

local function showTotemTooltip(frame, elementName)
  if InCombatLockdown() then return end
  GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
  local spell = frame:GetAttribute("spell")
  local info = spell and C_Spell.GetSpellInfo(spell)
  if info then
    GameTooltip:SetSpellByID(info.spellID)
  else
    GameTooltip:SetText(elementName)
    GameTooltip:AddLine("No totem chosen.", 1, 1, 1)
  end
  GameTooltip:AddLine(RIGHT_CLICK_HINT, 0.5, 0.8, 1)
  GameTooltip:Show()
end

-- A tooltip that's open when combat starts is closed.
local combatWatcher = CreateFrame("Frame")
combatWatcher:RegisterEvent("PLAYER_REGEN_DISABLED")
combatWatcher:SetScript("OnEvent", function()
  if tooltipOwners[GameTooltip:GetOwner()] then GameTooltip:Hide() end
end)

local function createTotemButton(bar, elementKey, elementName, index)
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

  tooltipOwners[frame] = true
  frame:SetScript("OnEnter", function() showTotemTooltip(frame, elementName) end)
  frame:SetScript("OnLeave", function()
    if GameTooltip:GetOwner() == frame then GameTooltip:Hide() end
  end)

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
  local vertical = false

  local function layout()
    local count = #bar.buttons
    local length = count * BUTTON_SIZE + math.max(count - 1, 0) * BUTTON_GAP
    if vertical then
      frame:SetSize(BUTTON_SIZE, length)
    else
      frame:SetSize(length, BUTTON_SIZE)
    end
    for i, button in ipairs(bar.buttons) do
      local offset = (i - 1) * (BUTTON_SIZE + BUTTON_GAP)
      button.frame:ClearAllPoints()
      if vertical then
        button.frame:SetPoint("TOP", frame, "TOP", 0, -offset)
      else
        button.frame:SetPoint("LEFT", frame, "LEFT", offset, 0)
      end
    end
  end

  addFeatureFrame(bar, frame, "Totem Bar", function()
    frame:SetShown(bar.enabled)
  end)

  function bar:SetVertical(isVertical)
    vertical = isVertical
    layout()
  end

  -- The control for switching Totem Set: the set's name, under the bar.
  function bar:CreateSetButton()
    local setFrame = CreateFrame("Button", "ShamanTracker" .. name .. "SetButton", frame)
    setFrame:SetSize(SET_BUTTON_WIDTH, SET_BUTTON_HEIGHT)
    setFrame:SetPoint("TOP", frame, "BOTTOM", 0, -2)
    setFrame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local label = setFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER")
    local highlight = setFrame:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.1)
    local marker = setFrame:CreateTexture(nil, "OVERLAY")
    marker:SetSize(6, 6)
    marker:SetPoint("LEFT", label, "RIGHT", 3, 0)
    marker:SetColorTexture(1, 0.82, 0, 1)
    marker:Hide()

    local setButton = { frame = setFrame }
    function setButton:SetText(text) label:SetText(text) end
    function setButton:SetPendingMarker(shown) marker:SetShown(shown and true or false) end
    function setButton:OnClick(handler) setFrame:SetScript("OnClick", function() handler() end) end
    bar.setButton = setButton
    return setButton
  end

  function bar:CreateButton(elementKey, elementName)
    local button = createTotemButton(bar, elementKey, elementName, #bar.buttons + 1)
    table.insert(bar.buttons, button)
    layout()
    return button
  end

  return bar
end

---------------------------------------------------------------------------
-- Menus. items: list of { title = text } | { divider = true } |
-- { text, checked, disabled, onSelect }. Items with `checked` (true or
-- false) are radio items; items without it are plain buttons.
---------------------------------------------------------------------------

function Widgets.ShowMenu(owner, items)
  MenuUtil.CreateContextMenu(owner.frame, function(_, root)
    for _, item in ipairs(items) do
      if item.title then
        root:CreateTitle(item.title)
      elseif item.divider then
        root:CreateDivider()
      else
        local description
        if item.checked ~= nil then
          description = root:CreateRadio(item.text, function() return item.checked end,
            function() item.onSelect() end)
        else
          description = root:CreateButton(item.text, function() item.onSelect() end)
        end
        if item.disabled then description:SetEnabled(false) end
      end
    end
  end)
end

---------------------------------------------------------------------------
-- Dialogs: a text prompt and a yes/no confirmation.
---------------------------------------------------------------------------

local PROMPT = "SHAMANTRACKER_PROMPT"
local CONFIRM = "SHAMANTRACKER_CONFIRM"

local function acceptPrompt(dialog)
  local text = dialog:GetEditBox():GetText()
  dialog.data.onAccept(text)
end

StaticPopupDialogs[PROMPT] = {
  text = "%s",
  button1 = ACCEPT,
  button2 = CANCEL,
  hasEditBox = true,
  OnShow = function(dialog)
    local editBox = dialog:GetEditBox()
    editBox:SetText(dialog.data.default or "")
    editBox:HighlightText()
  end,
  OnAccept = acceptPrompt,
  EditBoxOnEnterPressed = function(editBox, data)
    data.onAccept(editBox:GetText())
    StaticPopup_Hide(PROMPT)
  end,
  EditBoxOnEscapePressed = function() StaticPopup_Hide(PROMPT) end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
}

StaticPopupDialogs[CONFIRM] = {
  text = "%s",
  button1 = YES,
  button2 = NO,
  OnAccept = function(dialog) dialog.data.onAccept() end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
}

-- prompt = { title, default, onAccept = fn(text) }
function Widgets.PromptText(prompt)
  StaticPopup_Show(PROMPT, prompt.title, nil, prompt)
end

-- confirmation = { text, onAccept = fn() }
function Widgets.Confirm(confirmation)
  StaticPopup_Show(CONFIRM, confirmation.text, nil, confirmation)
end

-- Shaman-tracker Probe: throwaway Phase 0 test addon (issue #2).
-- Prints what the WoW: Forever client allows, so the real addon can be built on facts.
-- Every line is "STP | <section> | <key> | <value>" and is also saved to
-- WTF/Account/<account>/<realm>/<character>/SavedVariables/ShamanTrackerProbe.lua.

local addonName = ...

local MACRO_NAME = "STP Test"
local MAX_RUNS = 20
local MAIN_HAND_SLOT = 16

local log -- lines of the current run, or nil when not inside a run
local macroTestArmed = false
local castButton

---------------------------------------------------------------------------
-- Output
---------------------------------------------------------------------------

local function isSecret(v)
  return issecretvalue ~= nil and issecretvalue(v) or false
end

local function fmt(v)
  if isSecret(v) then return "<secret>" end
  if type(v) == "table" then
    local parts = {}
    for k, val in pairs(v) do
      parts[#parts + 1] = tostring(k) .. "=" .. fmt(val)
    end
    table.sort(parts)
    return "{" .. table.concat(parts, ", ") .. "}"
  end
  return tostring(v)
end

local function out(section, key, ...)
  local values = {}
  for i = 1, select("#", ...) do values[i] = fmt((select(i, ...))) end
  local line = ("STP | %s | %s | %s"):format(section, key, table.concat(values, " "))
  print(line)
  if log then
    log[#log + 1] = line
  elseif ShamanTrackerProbeDB then
    -- Lines outside a run (clicks, casts, totem updates) are kept too.
    local live = ShamanTrackerProbeDB.live or {}
    ShamanTrackerProbeDB.live = live
    live[#live + 1] = date("%H:%M:%S ") .. line
    while #live > 400 do table.remove(live, 1) end
  end
end

local function inCombat()
  return InCombatLockdown() and true or false
end

local function beginRun(label)
  log = {}
  out("run", "label", label)
  out("run", "inCombat", inCombat())
end

local function endRun()
  ShamanTrackerProbeDB.runs = ShamanTrackerProbeDB.runs or {}
  local runs = ShamanTrackerProbeDB.runs
  runs[#runs + 1] = { time = date("%Y-%m-%d %H:%M:%S"), lines = log }
  while #runs > MAX_RUNS do table.remove(runs, 1) end
  log = nil
end

-- Calls fn and logs an error instead of aborting the whole run.
local function try(section, key, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then out(section, key, "ERROR: " .. tostring(err)) end
end

local function getSpellName(spellID)
  if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(spellID) end
  return "?"
end

---------------------------------------------------------------------------
-- Checks
---------------------------------------------------------------------------

local function checkBuild()
  local version, build, buildDate, tocVersion = GetBuildInfo()
  out("build", "version", version, build, buildDate)
  out("build", "interface", tocVersion)
  out("build", "WOW_PROJECT_ID", WOW_PROJECT_ID)
  local _, classFile = UnitClass("player")
  out("build", "class", classFile, "level", UnitLevel("player"))
end

local GLOBALS = {
  "issecretvalue", "GetWeaponEnchantInfo", "UnitBuff", "UnitAura", "GetSpellInfo",
  "GetItemInfo", "IsSpellKnown", "CombatLogGetCurrentEventInfo", "GetTotemInfo",
  "GetTotemTimeLeft", "GetNumTotemSlots", "CreateMacro", "EditMacro", "DeleteMacro",
  "GetMacroIndexByName", "GetMacroBody", "GetNumMacros", "MAX_CHARACTER_MACROS",
  "MAX_ACCOUNT_MACROS", "GetFlyoutInfo", "GetFlyoutSlotInfo", "SetMultiCastSpell",
  "GetMultiCastTotemSpells", "HasMultiCastActionBar",
}

local NAMESPACED = {
  { "C_Item", "GetWeaponEnchantInfo" }, { "C_Item", "GetItemInfo" },
  { "C_Spell", "GetSpellInfo" }, { "C_Spell", "GetSpellName" },
  { "C_SpellBook", "IsSpellKnown" }, { "C_SpellBook", "GetSpellBookItemInfo" },
  { "C_UnitAuras", "GetPlayerAuraBySpellID" }, { "C_UnitAuras", "GetBuffDataByIndex" },
  { "C_Macro", "GetMacroName" }, { "Settings", "RegisterCanvasLayoutCategory" },
  { "Settings", "RegisterVerticalLayoutCategory" }, { "C_Timer", "After" },
}

local function checkApis()
  for _, name in ipairs(GLOBALS) do
    out("api", name, _G[name] ~= nil and "present" or "MISSING")
  end
  for _, pair in ipairs(NAMESPACED) do
    local ns = _G[pair[1]]
    local present = ns ~= nil and ns[pair[2]] ~= nil
    out("api", pair[1] .. "." .. pair[2], present and "present" or "MISSING")
  end
  out("api", "Enum.WeaponSlot", Enum and Enum.WeaponSlot)
end

local function checkMainHand()
  out("weapon", "mainHandItemID", GetInventoryItemID("player", MAIN_HAND_SLOT))
  out("weapon", "mainHandIcon", GetInventoryItemTexture("player", MAIN_HAND_SLOT))

  if C_Item and C_Item.GetWeaponEnchantInfo and Enum and Enum.WeaponSlot then
    for _, slotName in ipairs({ "MainHand", "OffHand" }) do
      try("weapon", "C_Item." .. slotName, function()
        local enchants = C_Item.GetWeaponEnchantInfo(Enum.WeaponSlot[slotName])
        if isSecret(enchants) then
          out("weapon", slotName .. ".enchants", "<secret>")
          return
        end
        out("weapon", slotName .. ".count", #enchants)
        for i, e in ipairs(enchants) do
          -- timeLeft is in milliseconds.
          out("weapon", slotName .. "[" .. i .. "]", e)
        end
      end)
    end
  end

  if GetWeaponEnchantInfo then
    try("weapon", "global", function()
      out("weapon", "global.GetWeaponEnchantInfo", GetWeaponEnchantInfo())
    end)
  end
end

local function checkTotems()
  local numSlots = GetNumTotemSlots and GetNumTotemSlots() or 4
  out("totem", "numSlots", numSlots)
  for slot = 1, numSlots do
    try("totem", "slot" .. slot, function()
      local haveTotem, name, startTime, duration, icon, modRate, spellID = GetTotemInfo(slot)
      out("totem", "slot" .. slot, "have=" .. fmt(haveTotem), "name=" .. fmt(name),
        "start=" .. fmt(startTime), "dur=" .. fmt(duration), "spellID=" .. fmt(spellID),
        "icon=" .. fmt(icon))
    end)
    if GetTotemTimeLeft then
      try("totem", "timeLeft" .. slot, function()
        out("totem", "timeLeft" .. slot, GetTotemTimeLeft(slot))
      end)
    end
    if GetTotemDuration then
      try("totem", "durationObject" .. slot, function()
        local d = GetTotemDuration(slot)
        out("totem", "durationObject" .. slot, "type=" .. type(d), "secret=" .. fmt(isSecret(d)))
      end)
    end
  end
  if GetMultiCastTotemSpells then
    -- The Call of the Elements bar knows which totems belong to which Element.
    for slot = 1, 4 do
      try("multicast", "slot" .. slot, function()
        local spells = { GetMultiCastTotemSpells(slot) }
        local names = {}
        for i, spellID in ipairs(spells) do names[i] = fmt(getSpellName(spellID)) .. "(" .. fmt(spellID) .. ")" end
        out("multicast", "slot" .. slot, table.concat(names, ", "))
      end)
    end
  end
end

local function checkAuras()
  if not (C_UnitAuras and C_UnitAuras.GetBuffDataByIndex) then return end
  try("aura", "buffs", function()
    local count = 0
    for i = 1, 40 do
      local aura = C_UnitAuras.GetBuffDataByIndex("player", i)
      if not aura then break end
      count = i
      if i <= 5 then
        out("aura", "buff" .. i, "name=" .. fmt(aura.name), "spellId=" .. fmt(aura.spellId),
          "expires=" .. fmt(aura.expirationTime))
      end
    end
    out("aura", "buffCount", count)
  end)
end

local INTERESTING = { "Totem", "Weapon", "Shield", "Call of the", "Totemic" }

local function isInteresting(name)
  if type(name) ~= "string" then return false end
  for _, word in ipairs(INTERESTING) do
    if name:find(word, 1, true) then return true end
  end
  return false
end

local function checkSpellbook()
  if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) then
    out("spells", "spellbook", "C_SpellBook MISSING")
    return
  end
  local bank = Enum.SpellBookSpellBank.Player
  for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
    local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(line)
    for slot = lineInfo.itemIndexOffset + 1, lineInfo.itemIndexOffset + lineInfo.numSpellBookItems do
      local item = C_SpellBook.GetSpellBookItemInfo(slot, bank)
      if item and item.itemType == Enum.SpellBookItemType.Flyout and GetFlyoutInfo then
        local flyoutName, _, numSlots = GetFlyoutInfo(item.actionID)
        out("spells", "flyout", flyoutName, "id=" .. fmt(item.actionID))
        for i = 1, numSlots or 0 do
          local spellID, _, isKnown, spellName = GetFlyoutSlotInfo(item.actionID, i)
          out("spells", "  in flyout", spellName, "spellID=" .. fmt(spellID), "known=" .. fmt(isKnown))
        end
      elseif item and not item.isPassive and isInteresting(item.name) then
        out("spells", lineInfo.name, item.name, "spellID=" .. fmt(item.spellID))
      end
    end
  end
end

local function runAll(label)
  beginRun(label)
  try("build", "all", checkBuild)
  try("api", "all", checkApis)
  try("weapon", "all", checkMainHand)
  try("totem", "all", checkTotems)
  try("aura", "all", checkAuras)
  try("spells", "all", checkSpellbook)
  endRun()
end

-- The reads that matter in combat (no spellbook dump, no API list).
local function runCombatReads(label)
  beginRun(label)
  try("weapon", "all", checkMainHand)
  try("totem", "all", checkTotems)
  try("aura", "all", checkAuras)
  endRun()
end

---------------------------------------------------------------------------
-- Macro test: create out of combat, try to edit in combat
---------------------------------------------------------------------------

local function macroBody(version)
  return ("/run print('STP macro body v%d')"):format(version)
end

local function armMacroTest()
  if inCombat() then out("macro", "arm", "leave combat first") return end
  beginRun("macro arm")
  try("macro", "create", function()
    local index = GetMacroIndexByName(MACRO_NAME)
    if index == 0 then
      index = CreateMacro(MACRO_NAME, "INV_MISC_QUESTIONMARK", macroBody(1), true)
    else
      EditMacro(index, nil, nil, macroBody(1))
    end
    out("macro", "index", index, "body", GetMacroBody(index))
    out("macro", "counts", GetNumMacros())
    macroTestArmed = true
    out("macro", "armed", "enter combat: the probe will try to edit the macro 1s later")
  end)
  endRun()
end

local function runMacroCombatEdit()
  macroTestArmed = false
  beginRun("macro edit in combat")
  try("macro", "edit", function()
    local index = GetMacroIndexByName(MACRO_NAME)
    if index == 0 then out("macro", "edit", "test macro missing") return end
    local ok, err = pcall(EditMacro, index, nil, nil, macroBody(2))
    out("macro", "pcall", ok, err)
    local body = GetMacroBody(index) or ""
    out("macro", "result", body:find("v2", 1, true) and "EDITED in combat" or "NOT edited in combat")
  end)
  endRun()
end

local function cleanupMacro()
  if inCombat() then out("macro", "cleanup", "leave combat first") return end
  local index = GetMacroIndexByName(MACRO_NAME)
  if index ~= 0 then DeleteMacro(index) end
  macroTestArmed = false
  out("macro", "cleanup", "done")
end

---------------------------------------------------------------------------
-- Secure cast button
---------------------------------------------------------------------------

local function setButtonSpell(spell)
  local before = castButton:GetAttribute("spell")
  local ok, err = pcall(castButton.SetAttribute, castButton, "spell", spell)
  local after = castButton:GetAttribute("spell")
  out("button", "setSpell", "inCombat=" .. fmt(inCombat()), "pcall=" .. fmt(ok), fmt(err),
    "before=" .. fmt(before), "after=" .. fmt(after),
    after == spell and before ~= spell and "CHANGED" or "unchanged")
  if not inCombat() then
    ShamanTrackerProbeDB.buttonSpell = spell
    local texture = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spell)
    castButton.icon:SetTexture(texture or 134400)
  end
end

local function createCastButton()
  castButton = CreateFrame("Button", "STPCastButton", UIParent, "SecureActionButtonTemplate")
  castButton:SetSize(40, 40)
  castButton:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
  castButton:RegisterForClicks("AnyUp", "AnyDown")
  castButton:SetAttribute("type", "spell")
  castButton.icon = castButton:CreateTexture(nil, "ARTWORK")
  castButton.icon:SetAllPoints()
  castButton.icon:SetTexture(134400)
  castButton:SetMovable(true)
  castButton:RegisterForDrag("LeftButton")
  castButton:SetScript("OnDragStart", function(self)
    if IsShiftKeyDown() and not inCombat() then self:StartMoving() end
  end)
  castButton:SetScript("OnDragStop", castButton.StopMovingOrSizing)
  castButton:HookScript("PostClick", function(_, mouseButton, down)
    out("button", "click", mouseButton, "down=" .. fmt(down), "inCombat=" .. fmt(inCombat()),
      "spell=" .. fmt(castButton:GetAttribute("spell")))
  end)
  if ShamanTrackerProbeDB.buttonSpell then setButtonSpell(ShamanTrackerProbeDB.buttonSpell) end
end

---------------------------------------------------------------------------
-- Display test: can addon frames SHOW totem data the addon can't READ?
-- Four icons (totem slots 1-4) under the test button, each with a cooldown
-- swipe and a time-left text, fed straight from the totem API.
---------------------------------------------------------------------------

local displayIcons = {}

local function createDisplayIcons()
  for slot = 1, 4 do
    local f = CreateFrame("Frame", "STPTotemDisplay" .. slot, UIParent)
    f:SetSize(32, 32)
    f:SetPoint("TOP", castButton, "BOTTOM", (slot - 2.5) * 36, -8)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints()
    f.icon:SetColorTexture(0.2, 0.2, 0.2, 0.8)
    f.cooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.cooldown:SetAllPoints()
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.text:SetPoint("TOP", f, "BOTTOM", 0, -2)
    f.text:SetText(slot)
    displayIcons[slot] = f
  end
end

local function updateDisplayIcon(slot)
  local f = displayIcons[slot]
  if not f then return end
  local results = {}
  local function attempt(label, fn)
    local ok, err = pcall(fn)
    results[#results + 1] = label .. "=" .. (ok and "ok" or ("ERR " .. tostring(err)))
  end
  local _, _, startTime, duration, icon = GetTotemInfo(slot)
  attempt("icon", function() f.icon:SetTexture(icon) end)
  if GetTotemDuration and f.cooldown.SetCooldownFromDurationObject then
    attempt("durationObject", function() f.cooldown:SetCooldownFromDurationObject(GetTotemDuration(slot)) end)
  else
    results[#results + 1] = "durationObject=unavailable"
    attempt("cooldownSet", function() f.cooldown:SetCooldown(startTime, duration) end)
  end
  attempt("text", function() f.text:SetText(GetTotemTimeLeft(slot)) end)
  out("display", "slot" .. slot, "inCombat=" .. fmt(inCombat()), table.concat(results, " "))
  -- Read back what the widgets hold, where the game lets us.
  try("display", "readback" .. slot, function()
    out("display", "readback" .. slot, "texture=" .. fmt(f.icon:GetTexture()),
      "swipeShown=" .. fmt(f.cooldown:IsShown()), "text=" .. fmt(f.text:GetText()))
  end)
end

---------------------------------------------------------------------------
-- Copy window: everything recorded, ready for Ctrl+A / Ctrl+C
---------------------------------------------------------------------------

local copyFrame

local function collectText()
  local lines = {}
  for _, run in ipairs(ShamanTrackerProbeDB.runs or {}) do
    lines[#lines + 1] = "== run " .. run.time
    for _, line in ipairs(run.lines) do lines[#lines + 1] = line end
  end
  lines[#lines + 1] = "== live"
  for _, line in ipairs(ShamanTrackerProbeDB.live or {}) do lines[#lines + 1] = line end
  return table.concat(lines, "\n")
end

local function showCopyFrame()
  if not copyFrame then
    copyFrame = CreateFrame("Frame", "STPCopyFrame", UIParent, "BasicFrameTemplateWithInset")
    copyFrame:SetSize(700, 450)
    copyFrame:SetPoint("CENTER")
    copyFrame:SetFrameStrata("DIALOG")
    copyFrame:SetMovable(true)
    copyFrame:EnableMouse(true)
    copyFrame:RegisterForDrag("LeftButton")
    copyFrame:SetScript("OnDragStart", copyFrame.StartMoving)
    copyFrame:SetScript("OnDragStop", copyFrame.StopMovingOrSizing)

    local title = copyFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -5)
    title:SetText("Shaman-tracker Probe: Ctrl+A then Ctrl+C to copy")

    local scroll = CreateFrame("ScrollFrame", nil, copyFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -30)
    scroll:SetPoint("BOTTOMRIGHT", -32, 12)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(650)
    edit:SetScript("OnEscapePressed", function() copyFrame:Hide() end)
    scroll:SetScrollChild(edit)
    copyFrame.edit = edit
  end
  copyFrame.edit:SetText(collectText())
  copyFrame:Show()
  copyFrame.edit:SetFocus()
  copyFrame.edit:HighlightText()
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local frame = CreateFrame("Frame")

local EVENTS = {
  "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
  "WEAPON_ENCHANT_CHANGED", "UNIT_INVENTORY_CHANGED", "PLAYER_EQUIPMENT_CHANGED",
  "PLAYER_TOTEM_UPDATE", "SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE",
  "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "UPDATE_MACROS",
  "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN",
}

local eventSupport = {}
for _, event in ipairs(EVENTS) do
  eventSupport[event] = pcall(frame.RegisterEvent, frame, event)
end
eventSupport.UNIT_SPELLCAST_SUCCEEDED =
  pcall(frame.RegisterUnitEvent, frame, "UNIT_SPELLCAST_SUCCEEDED", "player")

local function reportEventSupport()
  for event, ok in pairs(eventSupport) do
    out("event", event, ok and "registered" or "UNKNOWN EVENT")
  end
end

-- Events whose firing is worth seeing live; logged outside of runs.
local LIVE = {
  WEAPON_ENCHANT_CHANGED = true, PLAYER_EQUIPMENT_CHANGED = true, PLAYER_DEAD = true,
  PLAYER_ALIVE = true, PLAYER_UNGHOST = true, LEARNED_SPELL_IN_SKILL_LINE = true,
}

frame:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    if ... ~= addonName then return end
    ShamanTrackerProbeDB = ShamanTrackerProbeDB or {}
    createCastButton()
    createDisplayIcons()
  elseif event == "PLAYER_LOGIN" then
    beginRun("events")
    reportEventSupport()
    endRun()
    out("run", "help", "type /stp for commands")
  elseif event == "PLAYER_REGEN_DISABLED" then
    out("combat", "entered")
    C_Timer.After(1, function()
      if macroTestArmed then runMacroCombatEdit() end
      runCombatReads("in combat")
    end)
  elseif event == "PLAYER_REGEN_ENABLED" then
    out("combat", "left")
  elseif event == "PLAYER_TOTEM_UPDATE" then
    -- Placing each totem once reveals which slot (Element) it uses.
    local slot = ...
    try("totem", "update", function()
      local haveTotem, name, _, duration, _, _, spellID = GetTotemInfo(slot)
      out("totem", "update", "slot=" .. fmt(slot), "have=" .. fmt(haveTotem), "name=" .. fmt(name),
        "spellID=" .. fmt(spellID), "dur=" .. fmt(duration), "inCombat=" .. fmt(inCombat()))
    end)
    if type(slot) == "number" then try("display", "update", updateDisplayIcon, slot) end
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    local _, _, spellID = ...
    out("cast", "succeeded", getSpellName(spellID), "spellID=" .. fmt(spellID),
      "inCombat=" .. fmt(inCombat()))
  elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
    local blockedAddon, func = ...
    if blockedAddon == addonName then out("blocked", event, func, "inCombat=" .. fmt(inCombat())) end
  elseif LIVE[event] then
    out("event", event, ...)
  end
end)

---------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------

local HELP = {
  "/stp run - run every check now",
  "/stp combat - run the in-combat reads now",
  "/stp button <spell name or ID> - set what the test button casts (shift-drag to move it)",
  "/stp macro - create the test macro and arm the in-combat edit test",
  "/stp cleanup - delete the test macro",
  "/stp note <text> - record what you see, e.g. /stp note slot2 icon yes swipe yes number no",
  "/stp copy - open a window with everything recorded, to copy out",
  "/stp clear - forget all saved runs",
}

SLASH_SHAMANTRACKERPROBE1 = "/stp"
SlashCmdList.SHAMANTRACKERPROBE = function(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
  if cmd == "run" then
    runAll(inCombat() and "manual (in combat)" or "manual (out of combat)")
  elseif cmd == "combat" then
    runCombatReads(inCombat() and "manual (in combat)" or "manual (out of combat)")
  elseif cmd == "button" and rest ~= "" then
    setButtonSpell(tonumber(rest) or rest)
  elseif cmd == "macro" then
    armMacroTest()
  elseif cmd == "cleanup" then
    cleanupMacro()
  elseif cmd == "copy" then
    showCopyFrame()
  elseif cmd == "note" and rest ~= "" then
    out("note", "user", rest)
  elseif cmd == "clear" then
    ShamanTrackerProbeDB.runs = {}
    ShamanTrackerProbeDB.live = {}
    out("run", "clear", "done")
  else
    for _, line in ipairs(HELP) do print(line) end
  end
end

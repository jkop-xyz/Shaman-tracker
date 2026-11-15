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

---------------------------------------------------------------------------
-- Aura test (round 3): can Maelstrom Weapon and Lightning Shield stacks be
-- read, or at least shown, in combat? And does anything fire at 5 stacks?
---------------------------------------------------------------------------

local TRACKED_AURAS = { "Lightning Shield", "Maelstrom Weapon", "Water Shield" }
-- Classic spell IDs to try even if the name scan finds nothing.
local CANDIDATE_AURA_IDS = { 324, 325, 905, 945, 8134, 10431, 10432, 51530, 53817, 408505 }
-- Maelstrom Weapon and Lightning Shield (rank 1) as seen in round 3.
local DEFAULT_MW_ID, DEFAULT_LS_ID = 408505, 324
local POLL_LINES = 40
local LIGHTNING_BOLT_IDS = { 403, 529, 548, 915, 943, 6041, 10391, 10392, 15207, 15208 }
local STRIP_SIZE = 10
local AURA_LOG_BUDGET = 25

local knownAuraIDs = {}      -- [name] = spellId, learned while readable
local knownInstances = {}    -- [name] = auraInstanceID, learned while readable
local auraStrip = {}         -- icons with stack text, fed only by pass-through
local auraLogBudget = AURA_LOG_BUDGET
local lightningBoltCastTime -- defined with the round 4 poll below

local function trackedName(name)
  if isSecret(name) or type(name) ~= "string" then return nil end
  for _, tracked in ipairs(TRACKED_AURAS) do
    if name == tracked then return tracked end
  end
end

local function createAuraStrip()
  for i = 1, STRIP_SIZE do
    local f = CreateFrame("Frame", "STPAuraStrip" .. i, UIParent)
    f:SetSize(28, 28)
    f:SetPoint("TOP", castButton, "BOTTOM", (i - (STRIP_SIZE + 1) / 2) * 30, -60)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints()
    f.icon:SetColorTexture(0.2, 0.2, 0.2, 0.6)
    f.count = f:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    f.count:SetPoint("BOTTOMRIGHT", -1, 1)
    auraStrip[i] = f
  end
  local label = auraStrip[1]:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  label:SetPoint("RIGHT", auraStrip[1], "LEFT", -4, 0)
  label:SetText("STP buffs:")
end

-- Fills the strip with the player's buffs, using only values passed straight
-- to widgets. Returns a short status for the log.
local function updateAuraStrip()
  local ok, ids = pcall(C_UnitAuras.GetUnitAuraInstanceIDs, "player", "HELPFUL")
  if not ok then return "instanceIDs ERR " .. tostring(ids) end
  if isSecret(ids) then return "instanceIDs <secret>" end
  local status = "instanceIDs=" .. #ids
  for i = 1, STRIP_SIZE do
    local f, id = auraStrip[i], ids[i]
    if id then
      local okData, data = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, "player", id)
      local okIcon = okData and data and pcall(f.icon.SetTexture, f.icon, data.icon)
      local okCount, count = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, "player", id, 1, 99)
      if okCount then pcall(f.count.SetText, f.count, count) end
      if i == 1 then
        status = status .. " first: data=" .. (okData and "ok" or "ERR") .. " icon=" .. fmt(okIcon)
          .. " count=" .. (okCount and fmt(count) or ("ERR " .. tostring(count)))
      end
    else
      f.icon:SetColorTexture(0.2, 0.2, 0.2, 0.6)
      f.count:SetText("")
    end
  end
  return status
end

-- Out of combat, buffs are readable: learn the tracked auras' IDs.
local function scanTrackedAuras()
  for i = 1, 40 do
    local aura = C_UnitAuras.GetBuffDataByIndex("player", i)
    if not aura then break end
    local name = trackedName(aura.name)
    if name then
      knownAuraIDs[name] = aura.spellId
      knownInstances[name] = aura.auraInstanceID
      out("aura", "found", name, "spellId=" .. fmt(aura.spellId), "stacks=" .. fmt(aura.applications),
        "instance=" .. fmt(aura.auraInstanceID), "max=" .. fmt(aura.maxCharges))
    end
  end
end

local function checkAuras(label)
  beginRun("auras " .. label)
  if not inCombat() then try("aura", "scan", scanTrackedAuras) end

  -- 1. Direct lookup by spell ID (works only for non-secret auras).
  local ids, seen = {}, {}
  for _, id in pairs(knownAuraIDs) do if not seen[id] then seen[id] = true table.insert(ids, id) end end
  for _, id in ipairs(CANDIDATE_AURA_IDS) do if not seen[id] then seen[id] = true table.insert(ids, id) end end
  for _, id in ipairs(ids) do
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
    if not ok then
      out("aura", "bySpellID " .. id, "ERR " .. tostring(aura))
    elseif aura then
      out("aura", "bySpellID " .. id, "name=" .. fmt(aura.name), "stacks=" .. fmt(aura.applications),
        "instance=" .. fmt(aura.auraInstanceID))
    end
  end

  -- 2. Display count for instance IDs learned out of combat.
  for name, instance in pairs(knownInstances) do
    local ok, count = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, "player", instance, 1, 99)
    out("aura", "displayCount " .. name, ok and fmt(count) or ("ERR " .. tostring(count)))
    local okData, data = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, "player", instance)
    out("aura", "byInstance " .. name, okData and data and ("stacks=" .. fmt(data.applications)
      .. " spellId=" .. fmt(data.spellId)) or (okData and "gone" or ("ERR " .. tostring(data))))
  end

  out("aura", "cooldownManager", "C_CooldownViewer=" .. fmt(C_CooldownViewer ~= nil),
    "boltCast=" .. lightningBoltCastTime())

  -- 3. The pass-through strip.
  out("aura", "strip", updateAuraStrip())

  -- 4. Proc glow on Lightning Bolt (Maelstrom Weapon at 5 stacks?).
  if C_SpellActivationOverlay then
    for _, id in ipairs(LIGHTNING_BOLT_IDS) do
      local ok, glowing = pcall(C_SpellActivationOverlay.IsSpellOverlayed, id)
      if not ok or glowing then out("aura", "overlayed " .. id, ok and fmt(glowing) or "ERR") end
    end
  end
  endRun()
end

local secretUpdateLogged = false

local function onUnitAura(updateInfo)
  updateAuraStrip()
  if not inCombat() or auraLogBudget <= 0 or not updateInfo then return end
  -- Round 3: in combat the whole updateInfo table is secret.
  if isSecret(updateInfo) then
    if not secretUpdateLogged then
      secretUpdateLogged = true
      out("aura", "unitAura", "updateInfo is secret in combat")
    end
    return
  end
  for _, aura in ipairs(updateInfo.addedAuras or {}) do
    if auraLogBudget <= 0 then break end
    auraLogBudget = auraLogBudget - 1
    out("aura", "added in combat", "name=" .. fmt(aura.name), "spellId=" .. fmt(aura.spellId),
      "stacks=" .. fmt(aura.applications), "instance=" .. fmt(aura.auraInstanceID))
  end
  for _, id in ipairs(updateInfo.updatedAuraInstanceIDs or {}) do
    if auraLogBudget <= 0 then break end
    auraLogBudget = auraLogBudget - 1
    local ok, count = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, "player", id, 1, 99)
    out("aura", "updated in combat", "instance=" .. fmt(id), "count=" .. (ok and fmt(count) or "ERR"))
  end
end

-- Round 4: once a second in combat, try the routes round 3 couldn't reach.
local pollTicker, pollStart, pollLines

local function shortError(err)
  return "ERR " .. tostring(err):gsub("\n.*", ""):sub(1, 70)
end

-- Direct lookup; works only if the game treats the aura as non-secret.
local function describeAuraByID(id)
  local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
  if not ok then return shortError(aura) end
  if aura == nil then return "nil" end
  if isSecret(aura) then return "<secret table>" end
  return "stacks=" .. fmt(aura.applications)
end

-- Maelstrom Weapon may shorten Lightning Bolt's cast time per stack.
function lightningBoltCastTime()
  local ok, info = pcall(C_Spell.GetSpellInfo, "Lightning Bolt")
  if not ok then return shortError(info) end
  if info == nil then return "nil" end
  if isSecret(info) then return "<secret table>" end
  return fmt(info.castTime)
end

local function overlayedBolts()
  if not C_SpellActivationOverlay then return "no API" end
  local lit = {}
  for _, id in ipairs(LIGHTNING_BOLT_IDS) do
    local ok, glowing = pcall(C_SpellActivationOverlay.IsSpellOverlayed, id)
    if not ok then return shortError(glowing) end
    if isSecret(glowing) then return "<secret>" end
    if glowing then table.insert(lit, id) end
  end
  return #lit > 0 and table.concat(lit, ",") or "none"
end

local function pollCombat()
  if pollLines <= 0 then return end
  pollLines = pollLines - 1
  local mw = knownAuraIDs["Maelstrom Weapon"] or DEFAULT_MW_ID
  local ls = knownAuraIDs["Lightning Shield"] or DEFAULT_LS_ID
  out("poll", ("t=%ds"):format(GetTime() - pollStart), "MW=" .. describeAuraByID(mw),
    "LS=" .. describeAuraByID(ls), "boltCast=" .. lightningBoltCastTime(),
    "boltGlow=" .. overlayedBolts())
end

local frame = CreateFrame("Frame")

local EVENTS = {
  "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
  "WEAPON_ENCHANT_CHANGED", "UNIT_INVENTORY_CHANGED", "PLAYER_EQUIPMENT_CHANGED",
  "PLAYER_TOTEM_UPDATE", "SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE",
  "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "UPDATE_MACROS",
  "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN",
  "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",
  "SPELL_ACTIVATION_OVERLAY_SHOW", "SPELL_ACTIVATION_OVERLAY_HIDE",
}

local eventSupport = {}
for _, event in ipairs(EVENTS) do
  eventSupport[event] = pcall(frame.RegisterEvent, frame, event)
end
eventSupport.UNIT_SPELLCAST_SUCCEEDED =
  pcall(frame.RegisterUnitEvent, frame, "UNIT_SPELLCAST_SUCCEEDED", "player")
eventSupport.UNIT_AURA = pcall(frame.RegisterUnitEvent, frame, "UNIT_AURA", "player")

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
    createAuraStrip()
  elseif event == "PLAYER_LOGIN" then
    beginRun("events")
    reportEventSupport()
    endRun()
    out("run", "help", "type /stp for commands")
  elseif event == "PLAYER_REGEN_DISABLED" then
    out("combat", "entered")
    auraLogBudget = AURA_LOG_BUDGET
    secretUpdateLogged = false
    pollStart, pollLines = GetTime(), POLL_LINES
    if pollTicker then pollTicker:Cancel() end
    pollTicker = C_Timer.NewTicker(1, function() try("poll", "tick", pollCombat) end)
    C_Timer.After(1, function()
      if macroTestArmed then runMacroCombatEdit() end
      runCombatReads("in combat")
    end)
    -- Late enough to have built Maelstrom Weapon stacks.
    C_Timer.After(8, function()
      if inCombat() then checkAuras("in combat, 8s") end
    end)
  elseif event == "PLAYER_REGEN_ENABLED" then
    out("combat", "left")
    if pollTicker then pollTicker:Cancel() pollTicker = nil end
    out("poll", "afterCombat", "boltCast=" .. lightningBoltCastTime())
    C_Timer.After(1, function() checkAuras("just after combat") end)
  elseif event == "UNIT_AURA" then
    local _, updateInfo = ...
    try("aura", "unitAura", onUnitAura, updateInfo)
  elseif event:find("^SPELL_ACTIVATION_OVERLAY") then
    local spellID = ...
    out("overlay", event, getSpellName(spellID), "spellID=" .. fmt(spellID), "inCombat=" .. fmt(inCombat()))
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
  "/stp auras - check Lightning Shield and Maelstrom Weapon now",
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
  elseif cmd == "auras" then
    checkAuras(inCombat() and "manual (in combat)" or "manual (out of combat)")
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

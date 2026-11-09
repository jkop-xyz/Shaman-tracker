local AddonLoader = require("addon_loader")
local FakeGame = require("fake_game")

local KNOWN = {
  [1] = { { name = "Searing Totem", icon = 101 }, { name = "Magma Totem", icon = 102 } },
  [2] = { { name = "Stoneskin Totem", icon = 201 } },
  [3] = { { name = "Healing Stream Totem", icon = 301 } },
  [4] = {},
}

local EMPTY_BODY = "#showtooltip"

describe("Totem Macros", function()
  local ns, game, db

  before_each(function()
    ns = AddonLoader.load()
    game = FakeGame.new(ns)
    game.knownTotems = KNOWN
    db = { totemSets = { active = "Default", sets = {
      { name = "Default", totems = { earth = "Stoneskin Totem", fire = "Searing Totem" } },
    } } }
  end)

  local function start()
    ns.Addon.Start(game, db)
    return game.totemBars.TotemBar
  end

  local function pick(bar, elementKey, totemName)
    bar.buttons[elementKey]:RightClick()
    game:ChooseMenuItem(totemName)
  end

  describe("on load", function()
    it("creates one macro per Element casting its Chosen Totem", function()
      start()
      assert.are.equal("#showtooltip\n/cast Stoneskin Totem", game.macros["ST Earth"])
      assert.are.equal("#showtooltip\n/cast Searing Totem", game.macros["ST Fire"])
    end)

    it("leaves an empty Element's macro doing nothing", function()
      start()
      assert.are.equal(EMPTY_BODY, game.macros["ST Water"])
      assert.are.equal(EMPTY_BODY, game.macros["ST Air"])
    end)

    it("creates a Drop-All Macro placing every Chosen Totem in Earth, Fire, Water, Air order", function()
      db.totemSets.sets[1].totems.air = "Grace of Air Totem"
      start()
      assert.are.equal(
        "#showtooltip\n/castsequence reset=combat/5 Stoneskin Totem, Searing Totem, Grace of Air Totem",
        game.macros["ST All"])
    end)

    it("leaves the Drop-All Macro doing nothing when every Element is empty", function()
      db.totemSets.sets[1].totems = {}
      start()
      assert.are.equal(EMPTY_BODY, game.macros["ST All"])
    end)

    it("creates them as character macros", function()
      start()
      assert.is_true(game.macroIsCharacter["ST All"])
    end)

    it("waits until combat ends when loaded mid-fight", function()
      game.inCombat = true
      start()
      assert.is_nil(game.macros["ST Fire"])
      game:Fire("combatEnded")
      assert.are.equal("#showtooltip\n/cast Searing Totem", game.macros["ST Fire"])
    end)
  end)

  describe("when a Chosen Totem changes", function()
    it("rewrites that Element's macro and the Drop-All Macro", function()
      local bar = start()
      pick(bar, "fire", "Magma Totem")
      assert.are.equal("#showtooltip\n/cast Magma Totem", game.macros["ST Fire"])
      assert.are.equal("#showtooltip\n/castsequence reset=combat/5 Stoneskin Totem, Magma Totem",
        game.macros["ST All"])
    end)

    it("waits until combat ends when changed mid-fight", function()
      local bar = start()
      game:Fire("combatStarted")
      pick(bar, "fire", "Magma Totem")
      pick(bar, "water", "Healing Stream Totem")
      assert.are.equal("#showtooltip\n/cast Searing Totem", game.macros["ST Fire"])
      game:Fire("combatEnded")
      assert.are.equal("#showtooltip\n/cast Magma Totem", game.macros["ST Fire"])
      assert.are.equal("#showtooltip\n/cast Healing Stream Totem", game.macros["ST Water"])
      assert.are.equal(
        "#showtooltip\n/castsequence reset=combat/5 Stoneskin Totem, Magma Totem, Healing Stream Totem",
        game.macros["ST All"])
    end)

    it("skips empty Elements in the Drop-All Macro", function()
      local bar = start()
      pick(bar, "earth", "None")
      assert.are.equal("#showtooltip\n/castsequence reset=combat/5 Searing Totem", game.macros["ST All"])
    end)
  end)

  describe("when the player deletes one", function()
    it("recreates it", function()
      start()
      game:DeleteMacroByPlayer("ST Earth")
      assert.are.equal("#showtooltip\n/cast Stoneskin Totem", game.macros["ST Earth"])
    end)

    it("recreates it once combat ends if deleted mid-fight", function()
      start()
      game:Fire("combatStarted")
      game:DeleteMacroByPlayer("ST Earth")
      assert.is_nil(game.macros["ST Earth"])
      game:Fire("combatEnded")
      assert.are.equal("#showtooltip\n/cast Stoneskin Totem", game.macros["ST Earth"])
    end)
  end)

  it("overwrites manual edits to its own macros", function()
    start()
    game:EditMacroByPlayer("ST Fire", "/say hello")
    assert.are.equal("#showtooltip\n/cast Searing Totem", game.macros["ST Fire"])
  end)

  it("doesn't keep rewriting when the game stores bodies with trailing whitespace", function()
    game.macroBodySuffix = "\n"
    start()
    local writes = game.macroWrites
    game:Fire("macrosChanged")
    game:Fire("macrosChanged")
    assert.are.equal(5, writes)
    assert.are.equal(5, game.macroWrites)
  end)

  it("never touches other macros", function()
    game.macros["My Macro"] = "/dance"
    game.macroIsCharacter["My Macro"] = true
    local bar = start()
    pick(bar, "fire", "Magma Totem")
    game:DeleteMacroByPlayer("ST Air")
    assert.are.equal("/dance", game.macros["My Macro"])
  end)

  describe("with full character macro slots", function()
    it("doesn't throw, and warns once in chat", function()
      game.freeCharacterMacroSlots = 2
      local bar = start()
      assert.are.equal(2, #game:MacroNamesStartingWith("ST "))
      assert.are.equal(1, #game.printed)
      assert.truthy(game.printed[1]:find("macro slots are full", 1, true))
      pick(bar, "fire", "Magma Totem")
      assert.are.equal(1, #game.printed)
    end)

    it("creates the rest once slots free up", function()
      game.freeCharacterMacroSlots = 0
      start()
      game.freeCharacterMacroSlots = 10
      game:Fire("macrosChanged")
      assert.are.equal(5, #game:MacroNamesStartingWith("ST "))
    end)
  end)

  it("doesn't create macros on a non-Shaman character", function()
    game.class = "ROGUE"
    start()
    assert.are.same({}, game:MacroNamesStartingWith("ST "))
  end)
end)

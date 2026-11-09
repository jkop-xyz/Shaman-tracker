local AddonLoader = require("addon_loader")
local FakeGame = require("fake_game")

local KNOWN = {
  [1] = { { name = "Searing Totem", icon = 101 }, { name = "Magma Totem", icon = 102 } },
  [2] = { { name = "Stoneskin Totem", icon = 201 } },
  [3] = {},
  [4] = {},
}

describe("Totem Sets", function()
  local ns, game, db, bar

  -- Two sets: Default (Searing) is active, AoE has Magma + Stoneskin.
  before_each(function()
    ns = AddonLoader.load()
    game = FakeGame.new(ns)
    game.knownTotems = KNOWN
    db = { totemSets = { active = "Default", sets = {
      { name = "Default", totems = { fire = "Searing Totem" } },
      { name = "AoE", totems = { fire = "Magma Totem", earth = "Stoneskin Totem" } },
    } } }
    ns.Addon.Start(game, db)
    bar = game.totemBars.TotemBar
  end)

  local function openSetMenu()
    bar.setButton:Click()
  end

  local function switchTo(name)
    openSetMenu()
    game:ChooseMenuItem(name)
  end

  describe("the set control on the bar", function()
    it("shows the Active Totem Set", function()
      assert.are.equal("Default", bar.setButton.text)
    end)

    it("lists every set, marking the active one, plus New, Rename and Delete", function()
      openSetMenu()
      assert.is_true(game:FindMenuItem("Default").checked)
      assert.is_false(game:FindMenuItem("AoE").checked)
      assert.truthy(game:FindMenuItem("New set..."))
      assert.truthy(game:FindMenuItem("Rename \"Default\"..."))
      assert.truthy(game:FindMenuItem("Delete \"Default\"..."))
    end)
  end)

  describe("switching out of combat", function()
    it("updates the buttons, the control and the saved data", function()
      switchTo("AoE")
      assert.are.equal("Magma Totem", bar.buttons.fire.spell)
      assert.are.equal("Stoneskin Totem", bar.buttons.earth.spell)
      assert.are.equal("AoE", bar.setButton.text)
      assert.are.equal("AoE", db.totemSets.active)
    end)

    it("rewrites all five macros", function()
      switchTo("AoE")
      assert.are.equal("#showtooltip\n/cast Magma Totem", game.macros["ST Fire"])
      assert.are.equal("#showtooltip\n/cast Stoneskin Totem", game.macros["ST Earth"])
      assert.are.equal("#showtooltip\n/castsequence reset=combat/5 Stoneskin Totem, Magma Totem",
        game.macros["ST All"])
    end)

    it("lets later picks edit the newly active set", function()
      switchTo("AoE")
      bar.buttons.fire:RightClick()
      game:ChooseMenuItem("Searing Totem")
      assert.are.equal("Searing Totem", db.totemSets.sets[2].totems.fire)
      assert.are.equal("Searing Totem", db.totemSets.sets[1].totems.fire)
    end)
  end)

  describe("switching in combat", function()
    before_each(function()
      game:Fire("combatStarted")
    end)

    it("is pending: the buttons and macros keep the old set until combat ends", function()
      switchTo("AoE")
      assert.are.equal("Searing Totem", bar.buttons.fire.spell)
      assert.are.equal("#showtooltip\n/cast Searing Totem", game.macros["ST Fire"])
      assert.are.equal("Default", db.totemSets.active)
    end)

    it("shows the pending set on the control, with a marker", function()
      switchTo("AoE")
      assert.are.equal("AoE", bar.setButton.text)
      assert.is_true(bar.setButton.pendingMarker)
      assert.is_true(bar.buttons.fire.pendingMarker)
      assert.is_true(bar.buttons.earth.pendingMarker)
    end)

    it("applies the latest switch when combat ends", function()
      switchTo("AoE")
      switchTo("Default")
      switchTo("AoE")
      game:Fire("combatEnded")
      assert.are.equal("AoE", db.totemSets.active)
      assert.are.equal("Magma Totem", bar.buttons.fire.spell)
      assert.are.equal("#showtooltip\n/cast Magma Totem", game.macros["ST Fire"])
      assert.is_false(bar.setButton.pendingMarker)
      assert.is_false(bar.buttons.fire.pendingMarker)
    end)

    it("applies edits made to the pending set along with the switch", function()
      switchTo("AoE")
      bar.buttons.earth:RightClick()
      game:ChooseMenuItem("None")
      game:Fire("combatEnded")
      assert.are.equal("AoE", db.totemSets.active)
      assert.is_nil(db.totemSets.sets[2].totems.earth)
      assert.is_nil(bar.buttons.earth.spell)
    end)

    it("clears the marker when switching back before combat ends", function()
      switchTo("AoE")
      switchTo("Default")
      assert.is_false(bar.setButton.pendingMarker)
    end)
  end)

  describe("creating a set", function()
    it("prompts for a name and makes the new, empty set active", function()
      openSetMenu()
      game:ChooseMenuItem("New set...")
      assert.are.equal("Set 3", game.openPrompt.default)
      game:AnswerPrompt("Raid")
      assert.are.equal("Raid", db.totemSets.active)
      assert.are.equal("Raid", db.totemSets.sets[3].name)
      assert.are.same({}, db.totemSets.sets[3].totems)
      assert.is_nil(bar.buttons.fire.spell)
      assert.are.equal("Raid", bar.setButton.text)
    end)

    it("refuses a duplicate or empty name, saying why", function()
      openSetMenu()
      game:ChooseMenuItem("New set...")
      game:AnswerPrompt("AoE")
      assert.are.equal(2, #db.totemSets.sets)
      assert.truthy(game.printed[#game.printed]:find("already", 1, true))
      openSetMenu()
      game:ChooseMenuItem("New set...")
      game:AnswerPrompt("   ")
      assert.are.equal(2, #db.totemSets.sets)
    end)
  end)

  describe("renaming a set", function()
    it("renames the Active Totem Set", function()
      openSetMenu()
      game:ChooseMenuItem("Rename \"Default\"...")
      assert.are.equal("Default", game.openPrompt.default)
      game:AnswerPrompt("Solo")
      assert.are.equal("Solo", db.totemSets.sets[1].name)
      assert.are.equal("Solo", db.totemSets.active)
      assert.are.equal("Solo", bar.setButton.text)
    end)

    it("refuses a name another set already has", function()
      openSetMenu()
      game:ChooseMenuItem("Rename \"Default\"...")
      game:AnswerPrompt("AoE")
      assert.are.equal("Default", db.totemSets.sets[1].name)
    end)
  end)

  describe("deleting a set", function()
    it("asks first, and does nothing if the player cancels", function()
      openSetMenu()
      game:ChooseMenuItem("Delete \"Default\"...")
      assert.truthy(game.openConfirmation.text:find("Default", 1, true))
      game:AnswerConfirmation(false)
      assert.are.equal(2, #db.totemSets.sets)
    end)

    it("switches to another set when the Active Totem Set is deleted", function()
      openSetMenu()
      game:ChooseMenuItem("Delete \"Default\"...")
      game:AnswerConfirmation(true)
      assert.are.equal(1, #db.totemSets.sets)
      assert.are.equal("AoE", db.totemSets.active)
      assert.are.equal("Magma Totem", bar.buttons.fire.spell)
      assert.are.equal("#showtooltip\n/cast Magma Totem", game.macros["ST Fire"])
    end)

    it("can't delete the last set", function()
      openSetMenu()
      game:ChooseMenuItem("Delete \"Default\"...")
      game:AnswerConfirmation(true)
      openSetMenu()
      assert.is_true(game:FindMenuItem("Delete \"AoE\"...").disabled)
    end)
  end)

  it("keeps sets per character across reloads", function()
    switchTo("AoE")
    local reloaded = FakeGame.new(ns)
    reloaded.knownTotems = KNOWN
    ns.Addon.Start(reloaded, db)
    assert.are.equal("AoE", reloaded.totemBars.TotemBar.setButton.text)
    assert.are.equal("Magma Totem", reloaded.totemBars.TotemBar.buttons.fire.spell)
  end)
end)

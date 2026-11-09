local AddonLoader = require("addon_loader")
local FakeGame = require("fake_game")

describe("Shaman-tracker start-up", function()
  local ns

  before_each(function()
    ns = AddonLoader.load()
  end)

  local function start(class, db)
    local game = FakeGame.new(ns, { class = class })
    local addon = ns.Addon.Start(game, db or {})
    return addon, game
  end

  describe("on a non-Shaman character", function()
    it("stays inactive", function()
      local addon, game = start("WARRIOR")
      assert.is_false(addon.active)
      assert.is_nil(game.slashCommand)
      assert.are.same({}, game.settingsCategories)
    end)

    it("leaves saved data untouched", function()
      local db = {}
      start("MAGE", db)
      assert.are.same({}, db)
    end)
  end)

  describe("on a Shaman", function()
    it("is active", function()
      local addon = start("SHAMAN")
      assert.is_true(addon.active)
    end)

    it("adds a Shaman-tracker category to the game's settings", function()
      local _, game = start("SHAMAN")
      assert.are.equal(1, #game.settingsCategories)
      assert.are.equal("Shaman-tracker", game.settingsCategories[1].name)
    end)

    it("prints usage for /st", function()
      local _, game = start("SHAMAN")
      game:Type("/st")
      assert.are.equal("Commands:", game.printed[1])
      assert.truthy(game.printed[2]:find("/st settings", 1, true))
    end)

    it("also answers to /shamantracker", function()
      local _, game = start("SHAMAN")
      game:Type("/shamantracker")
      assert.are.equal("Commands:", game.printed[1])
    end)

    it("opens its settings with /st settings", function()
      local _, game = start("SHAMAN")
      game:Type("/st settings")
      assert.are.same({ game.settingsCategories[1] }, game.openedSettings)
      assert.are.same({}, game.printed)
    end)

    it("keeps existing saved data", function()
      local db = { schemaVersion = 1, something = "kept" }
      start("SHAMAN", db)
      assert.are.equal("kept", db.something)
    end)
  end)
end)

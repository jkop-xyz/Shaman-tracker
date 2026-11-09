local AddonLoader = require("addon_loader")
local FakeGame = require("fake_game")

-- Slot numbers are the game's totem slots: 1 Fire, 2 Earth, 3 Water, 4 Air.
local KNOWN = {
  [1] = { { name = "Searing Totem", icon = 101 }, { name = "Magma Totem", icon = 102 } },
  [2] = { { name = "Stoneskin Totem", icon = 201 }, { name = "Strength of Earth Totem", icon = 202 } },
  [3] = { { name = "Healing Stream Totem", icon = 301 } },
  [4] = {},
}

describe("Totem Bar", function()
  local ns, game, db

  before_each(function()
    ns = AddonLoader.load()
    game = FakeGame.new(ns)
    game.knownTotems = KNOWN
    db = {}
  end)

  local function start()
    ns.Addon.Start(game, db)
    return game.totemBars.TotemBar
  end

  local function menuTexts()
    local texts = {}
    for _, item in ipairs(game.openMenu.items) do
      table.insert(texts, item.title or item.text or "---")
    end
    return texts
  end

  describe("on first load", function()
    it("seeds a Default Totem Set as the Active Totem Set", function()
      start()
      assert.are.equal("Default", db.totemSets.active)
      assert.are.equal(1, #db.totemSets.sets)
      assert.are.equal("Default", db.totemSets.sets[1].name)
    end)

    it("shows one empty button per Element, in the order Earth, Fire, Water, Air", function()
      local bar = start()
      assert.are.same({ "earth", "fire", "water", "air" }, bar.order)
      for _, key in ipairs(bar.order) do
        assert.is_nil(bar.buttons[key].spell)
        assert.is_nil(bar.buttons[key].icon)
      end
    end)

    it("does nothing when an empty button is clicked", function()
      local bar = start()
      bar.buttons.fire:LeftClick()
      assert.are.same({}, game.casts)
    end)
  end)

  describe("choosing a totem", function()
    it("lists the totems the player knows for that Element, plus None", function()
      local bar = start()
      bar.buttons.fire:RightClick()
      assert.are.equal(bar.buttons.fire, game.openMenu.owner)
      assert.are.same({ "Fire", "Searing Totem", "Magma Totem", "None" }, menuTexts())
    end)

    it("makes the picked totem the Chosen Totem, shown and placed by the button", function()
      local bar = start()
      bar.buttons.fire:RightClick()
      game:ChooseMenuItem("Magma Totem")
      assert.are.equal("Magma Totem", bar.buttons.fire.spell)
      assert.are.equal(102, bar.buttons.fire.icon)
      bar.buttons.fire:LeftClick()
      assert.are.same({ "Magma Totem" }, game.casts)
    end)

    it("edits the Active Totem Set", function()
      local bar = start()
      bar.buttons.earth:RightClick()
      game:ChooseMenuItem("Stoneskin Totem")
      assert.are.equal("Stoneskin Totem", db.totemSets.sets[1].totems.earth)
    end)

    it("marks the current Chosen Totem in the list", function()
      local bar = start()
      bar.buttons.fire:RightClick()
      game:ChooseMenuItem("Searing Totem")
      bar.buttons.fire:RightClick()
      assert.is_true(game:FindMenuItem("Searing Totem").checked)
      assert.is_false(game:FindMenuItem("Magma Totem").checked)
      assert.is_false(game:FindMenuItem("None").checked)
    end)

    it("clears the Element with None", function()
      local bar = start()
      bar.buttons.fire:RightClick()
      game:ChooseMenuItem("Searing Totem")
      bar.buttons.fire:RightClick()
      game:ChooseMenuItem("None")
      assert.is_nil(bar.buttons.fire.spell)
      assert.is_nil(bar.buttons.fire.icon)
      assert.is_nil(db.totemSets.sets[1].totems.fire)
    end)

    it("shows the new totem when the player learns one", function()
      local bar = start()
      game.knownTotems = { [1] = KNOWN[1], [2] = KNOWN[2], [3] = KNOWN[3],
        [4] = { { name = "Grace of Air Totem", icon = 401 } } }
      game:Fire("spellsChanged")
      bar.buttons.air:RightClick()
      assert.are.same({ "Air", "Grace of Air Totem", "None" }, menuTexts())
    end)
  end)

  describe("after a reload", function()
    it("restores the Chosen Totems", function()
      db = { totemSets = { active = "Default", sets = {
        { name = "Default", totems = { earth = "Strength of Earth Totem", water = "Healing Stream Totem" } },
      } } }
      local bar = start()
      assert.are.equal("Strength of Earth Totem", bar.buttons.earth.spell)
      assert.are.equal(202, bar.buttons.earth.icon)
      assert.are.equal("Healing Stream Totem", bar.buttons.water.spell)
      assert.is_nil(bar.buttons.fire.spell)
    end)

    it("still shows a Chosen Totem the player no longer knows", function()
      game.spellIcons["Windfury Totem"] = 499
      db = { totemSets = { active = "Default", sets = {
        { name = "Default", totems = { air = "Windfury Totem" } },
      } } }
      local bar = start()
      assert.are.equal("Windfury Totem", bar.buttons.air.spell)
      assert.are.equal(499, bar.buttons.air.icon)
    end)
  end)

  it("isn't created on a non-Shaman character", function()
    game.class = "PRIEST"
    ns.Addon.Start(game, db)
    assert.is_nil(game.totemBars.TotemBar)
  end)
end)

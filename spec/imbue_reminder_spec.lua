local AddonLoader = require("addon_loader")
local FakeGame = require("fake_game")

local ROCKBITER_RANK_1 = 8017
local WEAPON_ICON = 135576
local STONE = { hasEnchant = true, enchantType = 2, timeLeft = 1800000, iconID = 135249 }
local IMBUE = { hasEnchant = true, enchantType = 3, timeLeft = 3600000, iconID = 136086 }
local EMPTY = { hasEnchant = false, enchantType = 0, timeLeft = 0, iconID = 0 }

describe("Imbue Reminder", function()
  local ns, game

  -- A Shaman who knows Rockbiter, wielding a weapon with nothing on it.
  before_each(function()
    ns = AddonLoader.load()
    game = FakeGame.new(ns)
    game.knownSpells[ROCKBITER_RANK_1] = true
    game.mainHandIcon = WEAPON_ICON
    game.mainHandEnchants = {}
  end)

  local function start()
    ns.Addon.Start(game, {})
    return game.icons.ImbueReminder
  end

  local function assertMissing(icon)
    assert.is_true(icon.shown)
    assert.are.equal(WEAPON_ICON, icon.texture)
    assert.are.same(ns.ImbueReminder.MISSING_TINT, icon.tint)
  end

  it("shows the weapon's icon tinted red when the main hand has no enchant", function()
    assertMissing(start())
  end)

  it("counts a stone or oil alone as Missing", function()
    game.mainHandEnchants = { STONE }
    assertMissing(start())
  end)

  it("ignores empty enchant entries", function()
    game.mainHandEnchants = { EMPTY, STONE }
    assertMissing(start())
  end)

  it("hides when the main hand has a Shaman Imbue", function()
    game.mainHandEnchants = { IMBUE }
    assert.is_false(start().shown)
  end)

  it("hides when the main hand has a stone and an Imbue, in either order", function()
    game.mainHandEnchants = { STONE, IMBUE }
    assert.is_false(start().shown)
    game.mainHandEnchants = { IMBUE, STONE }
    game:Fire("weaponChanged")
    assert.is_false(game.icons.ImbueReminder.shown)
  end)

  it("hides when no main-hand weapon is equipped", function()
    game.mainHandIcon = nil
    assert.is_false(start().shown)
  end)

  it("hides when the player knows no Imbue spell", function()
    game.knownSpells = {}
    assert.is_false(start().shown)
  end)

  it("hides while the player is dead", function()
    game.dead = true
    assert.is_false(start().shown)
  end)

  describe("updates when the game changes", function()
    it("an Imbue is applied", function()
      local icon = start()
      game.mainHandEnchants = { IMBUE }
      game:Fire("weaponChanged")
      assert.is_false(icon.shown)
    end)

    it("an Imbue falls off", function()
      game.mainHandEnchants = { IMBUE }
      local icon = start()
      game.mainHandEnchants = {}
      game:Fire("tick")
      assertMissing(icon)
    end)

    it("the weapon is swapped", function()
      local icon = start()
      game.mainHandIcon = 135000
      game:Fire("weaponChanged")
      assert.are.equal(135000, icon.texture)
    end)

    it("the player dies and is resurrected", function()
      local icon = start()
      game.dead = true
      game:Fire("lifeChanged")
      assert.is_false(icon.shown)
      game.dead = false
      game:Fire("lifeChanged")
      assertMissing(icon)
    end)

    it("the player learns a first Imbue", function()
      game.knownSpells = {}
      local icon = start()
      game.knownSpells[ROCKBITER_RANK_1] = true
      game:Fire("spellsChanged")
      assertMissing(icon)
    end)
  end)

  it("is display-only", function()
    assert.is_false(start().clickable)
  end)

  it("isn't created on a non-Shaman character", function()
    game.class = "WARRIOR"
    ns.Addon.Start(game, {})
    assert.is_nil(game.icons.ImbueReminder)
  end)
end)

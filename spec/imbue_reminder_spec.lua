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

  local function start(db)
    ns.Addon.Start(game, db or {})
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

  describe("Expiring", function()
    local MINUTE = 60 * 1000

    local function imbueWith(timeLeft)
      return { hasEnchant = true, enchantType = 3, timeLeft = timeLeft, iconID = 136086 }
    end

    local function assertExpiring(icon, text)
      assert.is_true(icon.shown)
      assert.are.equal(136086, icon.texture)
      assert.are.same(ns.ImbueReminder.NO_TINT, icon.tint)
      assert.is_true(icon.pulsing)
      assert.are.equal(text, icon.text)
    end

    it("shows the Imbue's icon, pulsing, with time left, below the 5-minute default", function()
      game.mainHandEnchants = { imbueWith(4 * MINUTE) }
      assertExpiring(start(), "4:00")
    end)

    it("hides at exactly the threshold", function()
      game.mainHandEnchants = { imbueWith(5 * MINUTE) }
      assert.is_false(start().shown)
    end)

    it("shows one millisecond below the threshold", function()
      game.mainHandEnchants = { imbueWith(5 * MINUTE - 1) }
      assertExpiring(start(), "5:00")
    end)

    it("counts down", function()
      game.mainHandEnchants = { imbueWith(4 * MINUTE) }
      local icon = start()
      game.mainHandEnchants = { imbueWith(65 * 1000) }
      game:Fire("tick")
      assertExpiring(icon, "1:05")
      game.mainHandEnchants = { imbueWith(9 * 1000 + 1) }
      game:Fire("tick")
      assertExpiring(icon, "0:10")
    end)

    it("switches to Missing when the Imbue falls off", function()
      game.mainHandEnchants = { imbueWith(2000) }
      local icon = start()
      game.mainHandEnchants = {}
      game:Fire("tick")
      assertMissing(icon)
      assert.is_false(icon.pulsing)
      assert.are.equal("", icon.text)
    end)

    it("stops pulsing when the Imbue is reapplied", function()
      game.mainHandEnchants = { imbueWith(MINUTE) }
      local icon = start()
      game.mainHandEnchants = { imbueWith(60 * MINUTE) }
      game:Fire("weaponChanged")
      assert.is_false(icon.shown)
      assert.is_false(icon.pulsing)
    end)

    describe("threshold setting", function()
      it("is in the settings panel, from 1 to 60 minutes, defaulting to 5", function()
        start()
        local slider = game:FindSetting("imbueExpiringThreshold")
        assert.are.equal(1, slider.min)
        assert.are.equal(60, slider.max)
        assert.are.equal(5, slider.default)
        assert.are.equal(5, slider.get())
      end)

      it("changes when Expiring starts, and is saved per character", function()
        local db = {}
        game.mainHandEnchants = { imbueWith(8 * MINUTE) }
        ns.Addon.Start(game, db)
        local icon = game.icons.ImbueReminder
        assert.is_false(icon.shown)

        game:ChangeSetting("imbueExpiringThreshold", 10)
        assertExpiring(icon, "8:00")
        assert.are.equal(10, db.imbueReminder.expiringThresholdMinutes)
      end)

      it("loads a saved threshold", function()
        game.mainHandEnchants = { imbueWith(8 * MINUTE) }
        ns.Addon.Start(game, { imbueReminder = { expiringThresholdMinutes = 10 } })
        assertExpiring(game.icons.ImbueReminder, "8:00")
      end)
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

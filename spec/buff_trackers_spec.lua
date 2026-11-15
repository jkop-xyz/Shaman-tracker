local AddonLoader = require("addon_loader")
local FakeGame = require("fake_game")

local LIGHTNING_SHIELD_RANKS = { 324, 325, 905, 945, 8134, 10431, 10432 }

describe("Buff Trackers", function()
  local ns, game, db

  before_each(function()
    ns = AddonLoader.load()
    game = FakeGame.new(ns)
    game.knownSpellNames = { ["Lightning Shield"] = true, ["Maelstrom Weapon"] = true }
    game.spellIcons = { ["Lightning Shield"] = 136051, ["Maelstrom Weapon"] = 136048 }
    db = {}
  end)

  local function start()
    ns.Addon.Start(game, db)
    return game.buffTrackers.MaelstromTracker, game.buffTrackers.ShieldTracker
  end

  describe("what the game is asked to draw", function()
    it("tracks Maelstrom Weapon by its Forever spell ID, glowing at 5 stacks", function()
      local maelstrom = start()
      assert.are.same({ 408505 }, maelstrom.spec.spellIDs)
      assert.are.equal(5, maelstrom.spec.glowAt)
    end)

    it("tracks every Lightning Shield rank, without a glow", function()
      local _, shield = select(1, start())
      assert.are.same(LIGHTNING_SHIELD_RANKS, shield.spec.spellIDs)
      assert.is_nil(shield.spec.glowAt)
    end)

    it("hands the trackers to the game right away out of combat", function()
      local maelstrom, shield = start()
      assert.is_true(maelstrom.active)
      assert.is_true(shield.active)
    end)

    it("waits until combat ends when loaded mid-fight", function()
      game.inCombat = true
      local maelstrom = start()
      assert.is_falsy(maelstrom.active)
      game:Fire("combatEnded")
      assert.is_true(maelstrom.active)
    end)
  end)

  describe("while the buff is down", function()
    it("shows the spell's icon, dimmed, when the player knows it", function()
      local maelstrom, shield = start()
      assert.are.equal(136048, maelstrom.placeholder)
      assert.are.equal(136051, shield.placeholder)
    end)

    it("shows nothing for a spell the player doesn't know yet", function()
      game.knownSpellNames["Maelstrom Weapon"] = nil
      local maelstrom = start()
      assert.is_nil(maelstrom.placeholder)
    end)

    it("shows the icon once the player learns the spell", function()
      game.knownSpellNames["Maelstrom Weapon"] = nil
      local maelstrom = start()
      game.knownSpellNames["Maelstrom Weapon"] = true
      game:Fire("spellsChanged")
      assert.are.equal(136048, maelstrom.placeholder)
    end)
  end)

  describe("as Features", function()
    it("each gets show, lock and size settings", function()
      start()
      for _, id in ipairs({ "maelstromTrackerShown", "maelstromTrackerLocked", "maelstromTrackerSize",
        "shieldTrackerShown", "shieldTrackerLocked", "shieldTrackerSize" }) do
        assert.truthy(game:FindSetting(id))
      end
    end)

    it("sit in their own places, clear of the Imbue Reminder and the Totem Bar", function()
      local maelstrom, shield = start()
      local imbue, bar = game.icons.ImbueReminder, game.totemBars.TotemBar
      local seen = {}
      for _, frame in ipairs({ maelstrom, shield, imbue, bar }) do
        local spot = frame.layout.x .. "," .. frame.layout.y
        assert.is_nil(seen[spot])
        seen[spot] = true
      end
    end)

    it("move and resize on their own, and remember it", function()
      local maelstrom, shield = start()
      game:ChangeSetting("maelstromTrackerLocked", false)
      maelstrom:DragTo("TOP", "TOP", 30, -40)
      game:ChangeSetting("shieldTrackerSize", 150)
      assert.are.equal(1, maelstrom.layout.scale)
      assert.are.equal(1.5, shield.layout.scale)

      local reloaded = FakeGame.new(ns)
      ns.Addon.Start(reloaded, db)
      assert.are.equal(30, reloaded.buffTrackers.MaelstromTracker.layout.x)
      assert.are.equal(1.5, reloaded.buffTrackers.ShieldTracker.layout.scale)
    end)

    it("follow /st unlock and /st lock", function()
      local maelstrom, shield = start()
      game:Type("/st unlock")
      assert.is_true(maelstrom.unlocked)
      assert.is_true(shield.unlocked)
      game:Type("/st lock")
      assert.is_false(maelstrom.unlocked)
    end)

    it("can be switched off one at a time", function()
      local maelstrom, shield = start()
      game:ChangeSetting("maelstromTrackerShown", false)
      assert.is_false(maelstrom.enabled)
      assert.is_true(shield.enabled)
    end)

    it("hold their frame changes until combat ends", function()
      local maelstrom = start()
      game:Fire("combatStarted")
      game:ChangeSetting("maelstromTrackerSize", 120)
      assert.are.equal(1, maelstrom.layout.scale)
      game:Fire("combatEnded")
      assert.are.equal(1.2, maelstrom.layout.scale)
    end)
  end)

  it("aren't created on a non-Shaman character", function()
    game.class = "HUNTER"
    ns.Addon.Start(game, db)
    assert.are.same({}, game.buffTrackers)
  end)
end)

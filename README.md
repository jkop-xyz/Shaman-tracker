# Shaman-tracker

A World of Warcraft: Forever addon for Shamans. It has two Features: an **Imbue Reminder** and a **Totem Bar**. The spec is in issue #1, the domain language is in [GLOSSARY.md](GLOSSARY.md), and decisions are in [docs/adr/](docs/adr/).

## Install

Copy the `ShamanTracker` folder into your WoW: Forever `Interface/AddOns/` folder. On a Shaman, type `/st` for commands. On other classes the addon stays inactive.

## Development

### Layout

- `ShamanTracker/Core/`: the game logic. It talks to the game **only** through the game layer object it's given, never through WoW globals. The tests load these files.
- `ShamanTracker/Game/RealGame.lua`: the real game layer, and the only code that calls the WoW API.
- `ShamanTracker/Init.lua`: the bootstrap. Once saved variables have loaded, it starts the addon on the real game layer.
- `spec/`: the tests. `spec/support/fake_game.lua` is the fake game layer; it has the same methods as the real one, plus helpers to set game state and fire events. `spec/support/addon_loader.lua` loads the `Core/` files in `.toc` order.

Any new game-layer method or event goes in **both** `RealGame.lua` and `fake_game.lua`. Events are also listed in `Core/GameEvents.lua`.

### Tests

The tests use [busted](https://lunarmodules.github.io/busted/) on Lua 5.1, WoW's Lua version. On Arch, install it with `pacman -S lua51-busted`.

```
make test
```

Tests only check what a player would see, through the fake game layer: what's shown, the macro text, saved data. They don't cover how the code works internally. The views and the real game layer are checked in-game.

### Phase 0 test addon

`probe/ShamanTrackerProbe` is the throwaway in-game test addon used to confirm API facts. Its findings are in issue #9.

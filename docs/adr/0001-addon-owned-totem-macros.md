# Addon-owned Totem Macros, rewritten outside combat

Besides its own Totem Bar buttons, the addon creates and fully owns character macros: one Totem Macro per Element plus a Drop-All Macro. Whenever the Chosen Totems change, it rewrites them so the player's own action bars and keybinds always place the current Totem Set. Macros can't be edited during combat, so changes made in combat are held as Pending Choices and applied to buttons and macros together when combat ends. The addon overwrites any manual edits to its macros and recreates them if they are deleted.

## Considered Options

- **Totem Bar buttons only** (like Totem Caddy): simpler, but forces the player to use the addon's buttons and keybinds instead of their usual action bars.
- **Player-written macros with placeholders** (e.g. `#earth#` filled in by the addon): more flexible, but broken placeholders and renamed macros become failure cases to handle. Players who want custom behaviour can call an addon macro from their own macro instead.

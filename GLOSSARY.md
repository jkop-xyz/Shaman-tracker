# Shaman-tracker

A World of Warcraft: Forever addon that helps a Shaman, of any spec, keep their class mechanics up: weapon imbues and totems.

## Language

### Features

**Feature**:
One self-contained part of the addon that can be switched on or off on its own, and has its own settings and its own on-screen position and size. v1 has two: the Imbue Reminder and the Totem Bar.
_Avoid_: Module, plugin, tracker

**Imbue Reminder**:
The Feature that alerts the player when the main-hand weapon's Imbue is Missing or Expiring.
_Avoid_: Weapon enchant reminder, buff reminder

**Totem Bar**:
The Feature that offers one button per Element, both to place a totem and to show the totem currently placed for that Element.
_Avoid_: Totem frame, multicast bar

### Imbues

**Imbue**:
A temporary Shaman weapon enchantment (Rockbiter, Flametongue, Frostbrand or Windfury) on the main-hand weapon. Every Imbue is equally valid; the addon never judges which one is correct. Sharpening stones and oils are not Imbues and are ignored entirely.
_Avoid_: Weapon buff, enchant

**Missing**:
The main-hand weapon has no Imbue.
_Avoid_: Absent, none

**Expiring**:
The main-hand weapon has an Imbue with less than a configured amount of time left.
_Avoid_: Low, about to fall off

### Totems

**Element**:
One of the four totem categories (Earth, Fire, Water, Air). The player can have at most one totem per Element placed at a time.
_Avoid_: School, slot type

**Chosen Totem**:
The totem the Totem Bar's button for an Element places when clicked. A totem means all of its ranks; it is always placed at the highest rank the player knows.
_Avoid_: Selected totem, assigned totem, totem rank

**Active Totem**:
The totem actually placed in the world for an Element right now, if any. It may differ from the Chosen Totem.
_Avoid_: Current totem, live totem

**Pending Choice**:
A change made during combat, either a Chosen Totem or a switch of Active Totem Set, that has not taken effect yet. It takes effect when combat ends, and the latest change wins.
_Avoid_: Queued totem, deferred change

**Totem Set**:
A named, per-character group of at most one Chosen Totem per Element; an Element may be left empty. The player switches between sets manually.
_Avoid_: Preset, loadout, profile

**Active Totem Set**:
The one Totem Set currently in effect. Its contents are the Chosen Totems, so editing a Chosen Totem edits this set.
_Avoid_: Current set, selected set

### Macros

**Totem Macro**:
A character macro, owned by the addon, that places one Element's Chosen Totem. The addon rewrites it whenever that Chosen Totem changes and recreates it if deleted.
_Avoid_: Element macro, keybind

**Drop-All Macro**:
A character macro, owned by the addon, that places every Chosen Totem of the Active Totem Set, one per press, skipping empty Elements.
_Avoid_: Set macro, sequence macro

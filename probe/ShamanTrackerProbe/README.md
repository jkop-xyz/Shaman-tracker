# Shaman-tracker Probe

A throwaway test addon for Phase 0 (issues #2 and #9). It is **not** part of Shaman-tracker. It answers the questions the design rests on by printing what the WoW: Forever client actually allows. Every line looks like `STP | <section> | <key> | <value>` and is also saved to a file, so you don't have to copy anything out of chat.

## Install

1. Copy the `ShamanTrackerProbe` folder into your WoW: Forever install's `Interface/AddOns/` folder. The beta used `World of Warcraft/_classic_beta_/Interface/AddOns/`; use whichever folder your Forever client loads addons from. The folder name must stay `ShamanTrackerProbe`.
2. Log in on a **Shaman**. Level 20 or higher is best: you'll have several Imbues and totems, plus Call of the Elements.
3. If the addon list says the addon is **out of date**, tick "Load out of date AddOns". The `## Interface: 16001` line is a guess, and the probe prints the real number. Then go to step 1 of the checks.

## Checks

Do them in this order. Each step prints to chat.

1. **Out of combat, full run:** apply an Imbue to your weapon, place totems of two or three Elements, then type `/stp run`.
2. **Every totem's Element:** place each totem you know once, one at a time. Each placement prints a `totem | update | slot=N` line, which tells us which slot (Element) each totem spell uses.
3. **Stones and oils (if you have one):** put a sharpening stone or weightstone on your weapon on top of an Imbue, then type `/stp combat`. This shows whether both enchants appear.
4. **Casting from an addon button:** type `/stp button Searing Totem`, or any totem you know. A button with its icon appears above the centre of the screen; shift-drag to move it.
   - Click it **out of combat**: does the totem drop?
   - Enter combat with a training dummy or a mob, then click it again: does it drop?
   - While still in combat, type `/stp button Stoneskin Totem`, or another totem. The line should say `unchanged` or `CHANGED`.
5. **Macro editing in combat:** out of combat, type `/stp macro`, then enter combat. One second later the probe tries to edit its test macro and prints `EDITED in combat` or `NOT edited in combat`. If the game shows an "addon blocked" message, that's expected; it's part of the result. Afterwards type `/stp cleanup` out of combat to delete the test macro.
6. **Reads in combat:** every time you enter combat, the probe automatically prints the weapon, totem and buff reads one second later. Have an Imbue and some totems up when you pull.
7. **Imbue enchant IDs:** apply each of the four Imbues once (Rockbiter, Flametongue, Frostbrand, Windfury) and type `/stp combat` after each. The `enchantID=` value is what we need.

## Round 2 (follow-up)

The first round answered most questions. This round covers what's left: totem data, button casting, and which Element uses which slot. Every line, including clicks and totem updates, is now recorded, so you never need to copy from chat. Type `/stp clear` first so only this round is recorded.

1. **Out of combat:** place one totem of each Element you know, one at a time. Below the test button are four small squares labelled 1–4, one per totem slot. Record what each square shows with `/stp note`, for example:
   `/stp note out of combat: slot1 icon yes swipe yes number yes, slot2 nothing`
2. Type `/stp run` with those totems still up.
3. **In combat:** with a training dummy or a mob, place totems again, one per Element. Record what the squares show the same way:
   `/stp note in combat: slot1 icon yes swipe no number no`
4. **Button casting:** type `/stp button Searing Totem` out of combat, and click the test button. Then enter combat and click it again. While in combat, type `/stp button Stoneskin Totem`. Record whether the totems dropped, for example `/stp note button: out of combat dropped, in combat dropped`.
5. Type `/stp copy`. A window opens with everything already selected; press Ctrl+C and paste it on issue #9, or here.

## What to paste back on issue #9

**Easiest:** type `/stp copy`, press Ctrl+C, and paste. The window holds the last 20 runs plus every line printed outside a run: clicks, totem updates, casts, blocked actions and your notes. Alternatively, `/reload` and paste the contents of:

```
WTF/Account/<ACCOUNT>/<Realm>/<Character>/SavedVariables/ShamanTrackerProbe.lua
```

The answers being looked for:

- [ ] The Interface number (`build | interface`)
- [ ] The enchant ID of each of the four Imbues
- [ ] Whether a stone or oil shows up next to an Imbue, or replaces it
- [ ] Which slot number each totem uses (`totem | update | slot=N`)
- [ ] Whether the addon button cast a totem out of combat, and in combat
- [ ] Whether changing the button's spell in combat said `CHANGED` or `unchanged`
- [ ] The macro result: `EDITED in combat` or `NOT edited in combat`, and whether a `blocked` line appeared
- [ ] Whether the in-combat reads showed real values or `<secret>` / errors (weapon, totems, buffs)
- [ ] Any `api | ... | MISSING` lines, and any `ERROR:` lines

## Commands

| Command | Does |
|---|---|
| `/stp run` | every check now |
| `/stp combat` | just the weapon, totem and buff reads |
| `/stp button <spell name or ID>` | sets what the test button casts |
| `/stp macro` | creates the test macro and arms the in-combat edit test |
| `/stp cleanup` | deletes the test macro |
| `/stp note <text>` | records what you see on screen |
| `/stp copy` | opens a window with everything recorded, ready to copy |
| `/stp clear` | forgets saved runs and recorded lines |

## Removing it

Delete the `ShamanTrackerProbe` folder from `Interface/AddOns/` once #9 is done. Type `/stp cleanup` first if the test macro still exists.

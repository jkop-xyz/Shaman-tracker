# Buff Trackers are drawn by the game, not the addon

On Forever, addons can't read auras in combat: every aura API errors with "Auras cannot be accessed when secret while tainted", and `UNIT_AURA` payloads are secret (test addon rounds 3 and 4, issue #23). So the Maelstrom Weapon and Lightning Shield trackers hand each buff to one of Blizzard's own aura buttons: a slot in a `CustomAuraContainerTemplate` `AuraContainer`, filtered by spell ID. The game fills in the icon, the stack count and the time left, and keeps them current in combat. The addon never reads them. The glow at 5 Maelstrom Weapon stacks uses Musca Auras' stack gate. The game sets an invisible application bar's fill to the stack count, and a clipping frame running from the end of stack 4 to the fill's right edge only gains width at 5 stacks, revealing a constantly animating glow. Showing the glow on a bar the game hides below 5 stacks (`minApplications`) was tried first in 1.1.1 and drew nothing in-game. The time-left text is the button's `SetDurationText`, filled in by the game. This is the approach used by Aura Ledger's "drawn by the game" mode and by Musca Auras on Forever.

## Consequences

- **No decisions on stacks:** the addon can't make any decision based on stack counts (sounds, macros, colour changes beyond what the game draws), because it never sees the number.
- **Slots are created only out of combat**, and they can't be freed. Changing which spells a tracker follows means a new slot, so a `/reload` is needed to change it cleanly.
- **The button is drawn by the game:** the addon styles it only once, when the button is set up (`initializeFrame`).

## Considered Options

- **Reading auras in combat:** blocked by the client.
- **Counting stacks from the combat log:** the combat log is unavailable to addons on Forever.
- **Inferring stacks from the player's own casts** (like ChronoForge): Maelstrom Weapon stacks come from melee procs, and Lightning Shield charges are used up by incoming hits, neither of which an addon can see.

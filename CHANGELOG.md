# Changelog

## 1.1.0 (2026-10-23)

- A list of players to always treat as healers for each bracket (2v2, 3v3, Solo Queue), next to the one for every bracket. The bracket is read from the arena match you are in.
- An About tab in the options: how to get help (GitHub issues, Warperia, Discord) and the other addons by Skom, with what is installed. ArenaLFG is marked as Warmane only.
- `/shcc` opens the addon's own settings window; the Interface > AddOns page has a button for it (the long settings did not scroll there).
- MIT licence.

## 1.0.0 (2026-10-21)

First release.

- Alerts you the moment your healer is crowd controlled: a large icon of the effect, a countdown that turns from yellow to red, and a sound. Works in arenas by default (option: arenas and battlegrounds, or everywhere to test).
- Healer detection in the order !!!ClassicAPI uses: the role the game assigned, then the class (classes that cannot heal are skipped), then the teammate's talents (LibGroupTalents-1.0). You can also list names that are always healers.
- 152 crowd control spells (stuns, fears, incapacitates, silences, horror, sleep ...), the list of SkomsPlateBuffs checked against the 3.3.5a client data. Disarms and roots are optional.
- Border colour by the type of the effect (magic blue, curse purple, disease green, poison dark green, physical red).
- Big countdown drawn with textures, because this client never draws text bigger than about 20 px: inside the icon or under it, size up to 120. The colour goes from yellow to red as the share of the duration left drops (fully red at 25%), and can be switched off.
- OmniCC never draws on this icon, so there is never a second timer.
- Title, spell name, icon size, movable icon (`/shcc unlock`), a sound from LibSharedMedia and an optional party chat message.
- `/shcc` opens the options, `/shcc test` shows a 30 second sample.

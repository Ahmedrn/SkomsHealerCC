# SkomsHealerCC 0.3.2 (WoW 3.3.5a)

A big icon, a countdown and a sound when an enemy crowd control lands on **your healer**, with the border coloured by the type of the effect.

- **Where:** arenas by default (option: arena + battlegrounds, or everywhere to test).
- **Which healer:** the same order the raid frames of !!!ClassicAPI (Tsoukie) use: the role the game assigned (group finder), then the class (hunters, rogues, mages, warlocks, warriors and death knights cannot heal), then the teammate's talents (LibGroupTalents-1.0, which WeakAuras and DBM already load). Until the talents are known, priests, druids, paladins and shamans count as healers. You can also list names that are always healers.
- **Which crowd control:** stuns, fears, incapacitates, silences, horror, sleep and similar (152 spells). Disarms and roots are optional. The list is the one of SkomsPlateBuffs, checked against the 3.3.5a client data.
- **Look:** icon size, title ("HEALER CC"), timer, spell name, border colour by effect type (magic blue, curse purple, disease green, poison dark green, physical red). Movable.
- **Timer:** our own countdown, inside the icon (or under it), with a size slider up to 120. If OmniCC is installed it is told to stay away from this icon, so you never get two timers; "Let OmniCC draw the timer instead" hands it over, with a size multiplier. This client never draws text bigger than 20 pt, so bigger text is drawn at 20 and scaled.
- **Alert:** a sound (any LibSharedMedia sound) and, optionally, a party chat message.
- Commands: `/shcc` options, `/shcc test`, `/shcc unlock`, `/shcc lock`, `/shcc omnicc` (what OmniCC does with the icon), `/shcc fonttest`, `/shcc info` (what the icon is drawing).

## Install
Put the `SkomsHealerCC` folder in `Interface\AddOns`.

## Credits and inspirations
- The WeakAura **"Healer cc (colored borders)"** by **Elsyn** (retail): the idea, the layout and the border colours.
- The role detection order follows **!!!ClassicAPI** (Tsoukie).
- **LibGroupTalents-1.0** (Zek) for healer detection, **LibSharedMedia-3.0**, **Ace3**.
- Crowd control list from SkomsPlateBuffs (itself started from the BigDebuffs list by Jordon and Tsoukie).

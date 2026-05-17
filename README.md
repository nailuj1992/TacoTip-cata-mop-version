# TacoTip

**Better player tooltips for World of Warcraft: Mists of Pandaria Classic Phase 5**

*A stable build is also maintained for Cataclysm Classic and MoP Classic Phase 4.*

TacoTip enriches the default unit and item tooltips with information that matters in group play — GearScore, item level, talents, guild data, target, and more — while staying lightweight: no FPS drops, no slowdowns, no Lua errors.

Every feature is configurable. You decide exactly what gets shown.

---

## Features

### Unit Tooltips
- Class-colored names
- Player titles
- Guild name and rank
- Talents and active specialization (with Dual-Spec support on WotLK clients and further)
- GearScore
- Average item level
- Pawn score *(requires the [Pawn](https://www.curseforge.com/wow/addons/pawn) addon)*
- Current target of the unit
- Faction icon (Horde / Alliance)
- PvP flag icon
- Health and power bars under the tooltip

<img width="248" height="129" alt="Screenshot 2026-05-06 190145" src="https://github.com/user-attachments/assets/f3cb77c5-da2c-4a0f-8c61-f077f95caa7e" />

### Item Tooltips
- Item GearScore
- Item level

<img width="267" height="290" alt="Screenshot 2026-05-16 160907" src="https://github.com/user-attachments/assets/34f63747-eab1-4736-954f-91a318aacf18" />

### Character Frame
- GearScore
- Average item level
- Repositionable indicators (lockable)

<img width="292" height="397" alt="Screenshot 2026-05-06 190418" src="https://github.com/user-attachments/assets/7e950494-8614-4738-97a6-33977aea9f67" />

### Equipped Items Overlay
- Quality color border on item slots
- Item level shown directly on the icon
- Durability shown directly on the icon

<img width="155" height="254" alt="Screenshot 2026-05-06 190633" src="https://github.com/user-attachments/assets/489d19c1-f9c4-4321-8272-25d7018fff32" />

### Extras
- Class-colored chat names
- Custom tooltip position / mouse anchor
- Instant tooltip fade
- Disable enhancements during combat
- Configurable tooltip style (Full / Compact / Mini)

---

## Installation

1. Download the latest release from the [CurseForge page](https://www.curseforge.com/wow/addons/tacotip-for-mop).
2. Extract the `TacoTip` folder into your WoW install:
   - MoP Classic: `World of Warcraft\_classic_\Interface\AddOns\`
3. Restart the game (or `/reload`).

### "Addon out of date" error

Press `ESC` → **AddOns** → enable **Load out of date AddOns**.

<img width="551" height="106" alt="Screenshot 2026-05-16 160200 - Copy" src="https://github.com/user-attachments/assets/62aa558c-fc1b-425c-90d8-763a18f53be4" />

---

## Configuration

Open the options panel from:

- **Esc → Options → AddOns → TacoTip**, or
- the chat command `/tacotip`

<img width="1024" height="621" alt="Screenshot 2026-05-06 190208" src="https://github.com/user-attachments/assets/f9d9b6a4-9245-4119-9db8-e6fab567b6f9" />

The panel is grouped into clear sections (Unit Tooltips, Character Frame, Item Tooltips, Enhanced Tooltips, Extra) and includes a live preview tooltip plus a **Reset** button to restore defaults.

<img width="550" height="516" alt="Screenshot 2026-05-06 190230" src="https://github.com/user-attachments/assets/7353a3bc-7f34-4c0e-a19b-a7d199a07506" />

<img width="563" height="512" alt="Screenshot 2026-05-06 190242" src="https://github.com/user-attachments/assets/e51b19c9-8dec-4625-a06e-627550be4aae" />

<img width="574" height="514" alt="Screenshot 2026-05-06 190251" src="https://github.com/user-attachments/assets/6015536a-94b4-4358-91dd-a1b26071402a" />

<img width="566" height="511" alt="Screenshot 2026-05-06 190259" src="https://github.com/user-attachments/assets/396371f0-e4f8-4680-af09-c8c017ad343f" />

---

## Compatibility

| Client                                            | Interface | Status                  |
|---------------------------------------------------|-----------|-------------------------|
| **MoP Classic — Phase 5 (Siege of Orgrimmar)**    | `50504`   | **Active development**  |
| MoP Classic — up to Phase 4                       | `50500`   | Stable branch           |
| Cataclysm Classic                                 | `40402`   | Stable branch           |
| WotLK / TBC / Classic Era                         | —         | Supported by kebabstorm |

**Optional dependencies:** `Pawn` (for Pawn score in tooltips), `LibSharedMedia-3.0`.

**Embedded libraries:** `LibStub`, `CallbackHandler-1.0`, `LibDetours-1.0`, `LibClassicInspector`, `LibClassicGearScore`, `LibEQOLSettingsMode-1.0`.

---

## For Addon Developers

[**LibClassicInspector**](./Libs/LibClassicInspector) — the inspection library that powers TacoTip — is publicly released and reusable. Current version: **19** (2025-01-24).

It exposes a single API for inspecting other players across every Classic-era client:

- Inventory, item links and item IDs (slots 1–19 on Classic/TBC/WotLK/Cata, 1–17 on MoP)
- Talents, talent points and active spec, including dual / multi-spec on WotLK+ and the 4-tab MoP Druid layout
- Achievements and statistics (WotLK+)
- Glyphs (WotLK+)
- Client-version helpers (`IsClassic` / `IsTBC` / `IsWotlk` / `IsCata` / `IsMop`)
- Inspection queue is handled automatically — callbacks fire when data is ready

Full reference: [`API.txt`](./Libs/LibClassicInspector/API.txt) — header lists supported clients and client-specific quirks (DEATHKNIGHT requires WotLK+, MONK is MoP-only, MoP removes the Ranged inventory slot, etc.).

---

## Changelog

See [`CHANGELOG.md`](./CHANGELOG.md) for the full release history. Latest: **0.5.7**.

---

## Feedback

Bug reports, suggestions, and translation help are all welcome — open an issue or PR on the repository.

---

## Credits

- **Original author:** [@anzz1](https://github.com/anzz1) (`kebabstorm`)
- **Cataclysm port:** Zik
- **Cataclysm compile / debug & current MoP port:** [@Nailuj1992](https://github.com/Nailuj1992)

### Contributors
- [@Kisanen](https://github.com/Kisanen) — development & testing help
- [@Oshiri](https://github.com/Oshiri) — development & testing help
- [@nullKomplex](https://github.com/nullKomplex) — bugfix
- [@ForestJ316](https://github.com/ForestJ316) — bugfix

### Translators

Credit is based on the `Translators:` header in each `Locale/<locale>.lua` file and the git history of that file. Translations marked *(machine-assisted)* were drafted by the MoP port maintainer and are looking for native-speaker review.

| Locale  | Translator(s) |
|---------|---------------|
| 🇺🇸 enUS / enGB | [@anzz1](https://github.com/anzz1) (`kebabstorm`) — source locale |
| 🇩🇪 deDE | [@shakimas](https://github.com/shakimas) (Shaktor, LakeshireEU) |
| 🇪🇸 esES | [@Yorkylizado](https://github.com/Yorkylizado) |
| 🇲🇽 esMX | [@Yorkylizado](https://github.com/Yorkylizado) (esES base), [@Nailuj1992](https://github.com/Nailuj1992) |
| 🇫🇷 frFR | [@Nailuj1992](https://github.com/Nailuj1992) *(machine-assisted — native-speaker review welcome)* |
| 🇮🇹 itIT | [@Nailuj1992](https://github.com/Nailuj1992) *(machine-assisted — native-speaker review welcome)* |
| 🇰🇷 koKR | [@wagerssi](https://github.com/wagerssi) (와우하는아저씨) |
| 🇧🇷 ptBR | [@Nailuj1992](https://github.com/Nailuj1992) *(machine-assisted — native-speaker review welcome)* |
| 🇷🇺 ruRU | [@Iowerth](https://github.com/Iowerth) |
| 🇨🇳 zhCN | 云是红河岸 五区 碧空之歌 |
| 🇹🇼 zhTW | [@Nailuj1992](https://github.com/Nailuj1992) *(machine-assisted — native-speaker review welcome)* |

If you'd like to improve or review a translation, edit the matching `Locale/<locale>.lua` file and open a PR.

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

### Item Tooltips
- Item GearScore
- Item level

### Character Frame
- GearScore
- Average item level
- Repositionable indicators (lockable)

### Equipped Items Overlay
- Quality color border on item slots
- Item level shown directly on the icon
- Durability shown directly on the icon

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

![out-of-date-addon-menu](https://user-images.githubusercontent.com/13628128/199223990-17896046-3407-472d-be70-b78fc42ae905.jpg)

---

## Configuration

Open the options panel from:

- **Esc → Options → AddOns → TacoTip**, or
- the chat command `/tacotip`

![TacoTip options](https://github.com/user-attachments/assets/333a19c6-f2ac-49bc-8401-254e8ca71b9f)

The panel is grouped into clear sections (Unit Tooltips, Character Frame, Item Tooltips, Enhanced Tooltips, Extra) and includes a live preview tooltip plus a **Reset** button to restore defaults.

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

See [`CHANGELOG.md`](./CHANGELOG.md) for the full release history. Latest: **0.5.7-beta**.

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

# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to a custom incremental versioning scheme.

## [0.5.7-beta]

### Changed
- Reworked the addon options UI: settings are now grouped into clearer sections, making them easier to find and navigate.
- Reorganized example tooltips inside the options panel so the preview better reflects the current configuration.
- Moved specialization (spec) display strings into their corresponding locale files instead of being hardcoded.

### Added
- Localized strings for new options and sections across all supported locales (deDE, enUS, esES, esMX, frFR, itIT, koKR, ptBR, ruRU, zhCN, zhTW).
- A "Reset" button for restoring default option values.

### Fixed
- Pawn integration no longer throws `ScaleName must be the name of an existing scale` on characters that have not yet chosen a specialization. The Pawn lookup is now skipped when no valid spec is available or when the matching Pawn scale is not loaded.

### Removed
- `IsMoP` conditional gates around the example tooltip and around the item quality/durability features, so these now work consistently regardless of the client version.
- Bundled `CallbackHandler-1.0` and `LibStub` standalone copies (now resolved via embeds).

## [0.5.64]

### Changed
- Bumped the addon version to support the last phase of MoP Classic (Siege of Orgrimmar).

### Fixed
- Gearscore now refreshes immediately after an item upgrade, instead of keeping the previous value cached.

## [0.5.63]

### Fixed
- Item level was being displayed incorrectly for hunter ranged weapons (bows, crossbows, guns), the same class of bug previously fixed in 0.5.61 for 2H weapons.

## [0.5.62]

### Fixed
- Restored the instant tooltip fade behavior and the custom tooltip movement options, which had stopped working in a prior change.

## [0.5.61]

### Fixed
- Fixed item level being displayed incorrectly when wearing a 2H weapon.

## [0.5.6]

### Changed
- Reorganized the gearscore scanning code so it runs faster and produces more reliable results.

# Changelog – Reagent Skill Tips

Author: Boomsticky
Game: World of Warcraft: Forever (interface 16001)
Requires: LibProfessionDB (with Ace3 and VersionCheck-1.0)

## 1.3.7 – 2026-11-13
- "Only my own professions" is now at the top of the profession list in the settings, with a thin line below it. The All and None buttons are above the list.
- When "Only my own professions" is on, all your own professions are shown, and the profession checkboxes and the All and None buttons are greyed out. Your choices in the list are kept and used again when you turn it off.

## 1.3.6 – 2026-11-13
- Recipes your character knows get a green check, and recipes it does not know get a red cross. This works in your own professions after you have opened each profession window once. Turn it off with "Mark known recipes" in the settings or with `/rst known`.
- Corrected yellow and green skill levels. In Forever the green level is always halfway between yellow and grey. For example, Heavy Silk Bandage is now 180 / 180 / 210 / 240 (yellow from the start), and Silk Bandage is 150 / 150 / 180 / 210.
- `/rst status` shows how many known recipes are saved and which professions have been checked.

## 1.3.5 – 2026-11-13
- The addon list and the addon compartment menu use the new icon instead of Linen Cloth. Restart WoW completely to see it in the addon list.
- Bolt of Silk Cloth uses the confirmed Forever skill levels: 100 / 110 / 115 / 120.

## 1.3.4 – 2026-11-13
- Author set to Boomsticky.
- Added this changelog.

## 1.3.3 – 2026-11-13
- New minimap icon (map with a magnifying glass), cut out as a round icon.
- The minimap button uses Blizzard's gold ring and dark background again, so it looks like other minimap buttons.
- Restart WoW completely after installing, so the game finds the new image file. `/reload` is not enough.

## 1.3.2 – 2026-11-13
- The minimap button uses a custom icon (`Media\MinimapIcon.tga`) instead of Linen Cloth.

## 1.3.1 – 2026-11-13
- Some recipes only have a placeholder orange level in LibProfessionDB. For these, the yellow level is now shown as `?` and is not used for colours, because the library calculated it from the placeholder.
- A skill requirement borrowed from Vanilla is ignored when it is at or above the recipe's grey level in Forever (for example Bolt of Silk Cloth).
- `/rst status` shows how many recipes have placeholder levels and how many requirements were ignored.

## 1.3.0 – 2026-11-13
- Settings are saved per character. Each character starts with the default settings. Settings from earlier versions are not carried over.
- The settings window has two columns: professions on the left, tooltip options on the right.
- New options in the window: show info in tooltips, only my own professions, show reagent counts (x2), hide grey recipes, compact view, hide skill numbers, and recipes without Shift (1–30).
- New commands: `/rst grey`, `/rst compact` and `/rst numbers`. `/rst lines` is limited to 1–30.
- The help text now also lists `/rst rebuild` and `/rst debug`.

## 1.2.0 – 2026-11-13
- Save and Cancel buttons in the settings. Changes are only saved when you click Save.
- Button to show or hide the minimap icon.
- The settings are also available under Options → AddOns.
- New command: `/rst options`.

## 1.1.0 – 2026-11-13
- Minimap button that can be dragged around the minimap.
- Settings window with a checkbox for each profession, plus All and None.
- Professions you turn off are hidden in tooltips.
- Support for the addon compartment menu.
- New commands: `/rst config` and `/rst minimap`.

## 1.0.1 – 2026-11-13
- `/rst` is registered first, so the command always responds.
- Tooltip hooks are protected, and errors are shown in `/rst status`.
- Chat message at login.

## 1.0.0 – 2026-11-13
- First version: reagent tooltips with professions, icons, recipes, skill levels and colours based on your character's skill.
- Recipe data from LibProfessionDB. Hold Shift to see all recipes.
- Commands for status and troubleshooting.

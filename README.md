# Reagent Skill Tips

A World of Warcraft: Forever addon that shows in the item tooltip what a crafting reagent is used for: which professions, which recipes and at which skill levels. The recipes are coloured for your character's current skill, so you can see at a glance whether a material is useful for levelling a profession.

Author: Boomsticky · Game: WoW: Forever (interface 16001) · License: MIT

## Example

Tooltip for Silk Cloth on a character with First Aid 185 and Tailoring 105:

```
Reagent for: [icons]
[icon] First Aid                          185
    ✓ Heavy Silk Bandage x2      180  180  210  240
[icon] Tailoring                          105
    ✗ Bolt of Silk Cloth x4      100  110  115  120
```

The four numbers are the skill levels where the recipe turns **orange, yellow, green and grey**. The recipe name is coloured for your skill: red when it is too low, then orange, yellow, green and grey. ✓ means your character knows the recipe, ✗ that it does not.

## Features

- **Every recipe in the game**, not only the ones your character knows. The recipe data comes from LibProfessionDB, which reads Forever's own game files.
- **Profession icons** for every profession that uses the item.
- **Known recipes are marked** with a green check, unknown ones with a red cross. Open each profession window once so the addon can see your recipes.
- Your own professions are listed first. `x2` shows when a recipe uses more than one of the item.
- **Hold Shift** to see all recipes. Without Shift, the list starts at the first recipe that is not grey for you.
- Works in normal item tooltips and in chat links.

## Installation

**CurseForge app:** install Reagent Skill Tips. LibProfessionDB is installed automatically.

**Manually:**
1. Install LibProfessionDB from CurseForge (the Forever version). It also brings Ace3 and VersionCheck-1.0.
2. Download `ReagentSkillTips-x.y.z.zip` from [Releases](../../releases) and unzip it so the path becomes
   `World of Warcraft\_forever_\Interface\AddOns\ReagentSkillTips\ReagentSkillTips.toc`
3. Restart WoW completely.

## Settings

Click the minimap button, or open **Esc → Options → AddOns → Reagent Skill Tips**.

- Turn each profession on or off in the tooltips.
- Show info in tooltips, only my own professions, reagent counts (x2), hide grey recipes, compact view (only icons until you hold Shift), hide skill numbers and mark known recipes.
- Choose how many recipes are shown without Shift (1–30).
- Show or hide the minimap button.

Changes are saved when you click **Save**. Settings are saved per character.

## Commands

| Command | What it does |
|---|---|
| `/rst` | List all commands |
| `/rst config` | Open the settings window |
| `/rst options` | Open the settings under Options → AddOns |
| `/rst item <itemID or link>` | Print the info for an item in chat |
| `/rst known` | Turn the check/cross marks on or off |
| `/rst status` | Check the recipe data, your skills and known recipes |
| `/rst debug` | Show error messages in chat |

## About the skill levels

The skill levels come from LibProfessionDB and are corrected for Forever. In Forever the green level is always halfway between yellow and grey, and the addon uses that to fix the yellow and green levels.

- `*` after the first number: the skill requirement is borrowed from Vanilla and not yet confirmed for Forever.
- `?`: the skill requirement is not known for Forever yet.

Levels that have been checked in the game are kept in the `CONFIRMED` table at the top of `ReagentSkillTips.lua`.

## Contributing

Found a recipe with wrong skill levels? Open an [issue](../../issues) with the recipe name and the levels your trainer or profession window shows, or send a pull request that adds the recipe to `CONFIRMED`.

## License

MIT. See [LICENSE](LICENSE).

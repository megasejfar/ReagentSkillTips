-- Reagent Skill Tips - items used in event quests (WoW: Forever)
--
-- Hand-maintained list. Darkmoon Faire: the Classic quests where you turn in
-- items for Darkmoon Faire Prize Tickets, plus the four deck quests. Required
-- items and counts were taken from the Wowhead Classic quest pages
-- (https://www.wowhead.com/classic/quest=<quest ID>), checked 2026-11-23.
-- WoW: Forever may differ from Classic, so check new entries in the game.
--
-- To add an event: add it to ns.events, then add its items below.
--   ns.events[key] = { name = English name, iconItem = item ID whose icon is shown }
--   [itemID] = { { e = event key, q = quest ID, t = English quest name, n = count }, ... }

local _, ns = ...

ns.events = {
    DMF = { name = "Darkmoon Faire", iconItem = 19182 },   -- Darkmoon Faire Prize Ticket
}

ns.eventReagents = {
    -- Darkmoon Faire: gathered items
    [5134]  = { { e = "DMF", q = 7899, t = "Small Furry Paws", n = 5 } },           -- Small Furry Paw
    [11407] = { { e = "DMF", q = 7900, t = "Torn Bear Pelts", n = 5 } },            -- Torn Bear Pelt
    [4582]  = { { e = "DMF", q = 7901, t = "Soft Bushy Tails", n = 5 } },           -- Soft Bushy Tail
    [5117]  = { { e = "DMF", q = 7902, t = "Vibrant Plumes", n = 5 } },             -- Vibrant Plume
    [11404] = { { e = "DMF", q = 7903, t = "Evil Bat Eyes", n = 10 },               -- Evil Bat Eye
                { e = "DMF", q = 7943, t = "More Bat Eyes", n = 10 } },
    [19933] = { { e = "DMF", q = 8222, t = "Glowing Scorpid Blood", n = 10 },       -- Glowing Scorpid Blood
                { e = "DMF", q = 8223, t = "More Glowing Scorpid Blood", n = 10 } },

    -- Darkmoon Faire: crafted items
    [2309]  = { { e = "DMF", q = 7881, t = "Carnival Boots", n = 3 } },             -- Embossed Leather Boots
    [2314]  = { { e = "DMF", q = 7882, t = "Carnival Jerkins", n = 3 } },           -- Toughened Leather Armor
    [5739]  = { { e = "DMF", q = 7883, t = "The World's Largest Gnome!", n = 3 } }, -- Barbaric Harness
    [8185]  = { { e = "DMF", q = 7884, t = "Crocolisk Boy and the Bearded Murloc", n = 1 } }, -- Turtle Scale Leggings
    [15564] = { { e = "DMF", q = 7885, t = "Armor Kits", n = 8 },                   -- Rugged Armor Kit
                { e = "DMF", q = 7941, t = "More Armor Kits", n = 8 } },
    [3240]  = { { e = "DMF", q = 7889, t = "Coarse Weightstone", n = 10 } },        -- Coarse Weightstone
    [3486]  = { { e = "DMF", q = 7890, t = "Heavy Grinding Stone", n = 7 } },       -- Heavy Grinding Stone
    [3835]  = { { e = "DMF", q = 7891, t = "Green Iron Bracers", n = 3 } },         -- Green Iron Bracers
    [7945]  = { { e = "DMF", q = 7892, t = "Big Black Mace", n = 1 } },             -- Big Black Mace
    [12644] = { { e = "DMF", q = 7893, t = "Rituals of Strength", n = 8 },          -- Dense Grinding Stone
                { e = "DMF", q = 7939, t = "More Dense Grinding Stones", n = 8 } },
    [4363]  = { { e = "DMF", q = 7894, t = "Copper Modulator", n = 5 } },           -- Copper Modulator
    [4375]  = { { e = "DMF", q = 7895, t = "Whirring Bronze Gizmo", n = 7 } },      -- Whirring Bronze Gizmo
    [9313]  = { { e = "DMF", q = 7896, t = "Green Fireworks", n = 36 } },           -- Green Firework
    [11590] = { { e = "DMF", q = 7897, t = "Mechanical Repair Kits", n = 6 } },     -- Mechanical Repair Kit
    [15994] = { { e = "DMF", q = 7898, t = "Thorium Widget", n = 6 },               -- Thorium Widget
                { e = "DMF", q = 7942, t = "More Thorium Widgets", n = 6 } },

    -- Darkmoon Faire: decks
    [19228] = { { e = "DMF", q = 7907, t = "Darkmoon Beast Deck", n = 1 } },        -- Beasts Deck
    [19277] = { { e = "DMF", q = 7927, t = "Darkmoon Portals Deck", n = 1 } },      -- Portals Deck
    [19257] = { { e = "DMF", q = 7928, t = "Darkmoon Warlords Deck", n = 1 } },     -- Warlords Deck
    [19267] = { { e = "DMF", q = 7929, t = "Darkmoon Elementals Deck", n = 1 } },   -- Elementals Deck
}

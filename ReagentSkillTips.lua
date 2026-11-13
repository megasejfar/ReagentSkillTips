--[[
    Reagent Skill Tips  (WoW: Forever)
    Author: Boomsticky

    Viser i item-tooltippen for et reagens:
      * hvilke professions det bruges i (med ikoner)
      * hvilke opskrifter det bruges i
      * opskrifternes skill-grænser (orange / gul / grøn / grå)
      * opskriftsnavnet farvet efter din karakters skill
        (rød = for lav skill, orange, gul, grøn, grå)

    Opskriftsdata kommer fra LibProfessionDB-1.0, som har alle Forevers
    opskrifter læst fra spillets egne filer.
]]

local ADDON_NAME = ...

local VERSION = "1.3.7"
local LIB_MAJOR = "LibProfessionDB-1.0"
local PREFIX = "|cff33ff99Reagent Skill Tips:|r "

-- Slash-kommandoen registreres først, så /rst svarer selv hvis
-- resten af filen skulle fejle under indlæsning.
local SlashHandler
local loadErrors = {}
SLASH_REAGENTSKILLTIPS1 = "/rst"
SLASH_REAGENTSKILLTIPS2 = "/reagentskilltips"
SlashCmdList.REAGENTSKILLTIPS = function(msg)
    if SlashHandler then
        SlashHandler(msg)
    else
        print(PREFIX .. "the addon did not finish loading. Turn on Lua errors with /console scriptErrors 1 and /reload.")
    end
end

local DEFAULTS = {
    enabled          = true,  -- vis info i tooltip
    showUnlearned    = true,  -- vis også professions karakteren ikke har
    maxPerProfession = 6,     -- antal opskrifter pr. profession uden Shift
    showCounts       = true,  -- vis antal (x2) hvis en opskrift bruger flere
    hideGrey         = false, -- skjul grå opskrifter i egne professions (uden Shift)
    compact          = false, -- kun ikonlinjen uden Shift
    hideNumbers      = false, -- skjul de fire skill-tal
    showKnown        = true,  -- flueben ved kendte, kryds ved ukendte opskrifter
    showMinimap      = true,  -- vis knappen ved minimap
    minimapAngle     = 220,   -- knappens placering rundt om minimap (grader)
    debug            = false,
}
local MAX_LINES = 30          -- øvre grænse for maxPerProfession

local L = {
    REAGENT_FOR = "Reagent for:",
    NOT_LEARNED = "not learned",
    MORE        = "+%d more recipes (hold Shift)",
    SHIFT_HINT  = "(hold Shift)",
    ALL_GREY    = "all recipes are grey for you",
    SCAN_HINT   = "Open your profession window once to mark known recipes.",
    UNCONFIRMED = "* skill requirement not yet confirmed for Forever",
    NO_LIB      = "LibProfessionDB-1.0 was not found. Install LibProfessionDB (with Ace3 and VersionCheck-1.0).",
}

-- Farver (samme som Blizzards profession-farver) + rød for "kan ikke endnu"
local COLOR = {
    red    = "ff1a1a",
    orange = "ff8040",
    yellow = "ffff00",
    green  = "40bf40",
    grey   = "808080",
    white  = "ffffff",
}

-- skillLine-id -> ikon og engelsk reservenavn
local PROFESSIONS = {
    [129] = { name = "First Aid",      icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice" },
    [164] = { name = "Blacksmithing",  icon = "Interface\\Icons\\Trade_BlackSmithing" },
    [165] = { name = "Leatherworking", icon = "Interface\\Icons\\Trade_LeatherWorking" },
    [171] = { name = "Alchemy",        icon = "Interface\\Icons\\Trade_Alchemy" },
    [182] = { name = "Herbalism",      icon = "Interface\\Icons\\Trade_Herbalism" },
    [185] = { name = "Cooking",        icon = "Interface\\Icons\\INV_Misc_Food_15" },
    [186] = { name = "Mining",         icon = "Interface\\Icons\\Trade_Mining" },
    [197] = { name = "Tailoring",      icon = "Interface\\Icons\\Trade_Tailoring" },
    [202] = { name = "Engineering",    icon = "Interface\\Icons\\Trade_Engineering" },
    [333] = { name = "Enchanting",     icon = "Interface\\Icons\\Trade_Engraving" },
    [356] = { name = "Fishing",        icon = "Interface\\Icons\\Trade_Fishing" },
    [393] = { name = "Skinning",       icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01" },
}
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
-- Blizzards ready check-ikoner: grønt flueben og rødt kryds
local ICON_KNOWN   = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t"
local ICON_UNKNOWN = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:12:12|t"
-- Eget ikon (64x64 TGA, rundt med gennemsigtige hjørner)
local MINIMAP_ICON = "Interface\\AddOns\\" .. (ADDON_NAME or "ReagentSkillTips") .. "\\Media\\MinimapIcon"

-- Skill-grænser bekræftet for Forever. De bruges i stedet for bibliotekets
-- tal, som for nogle opskrifter er pladsholdere eller lånt fra Vanilla.
-- [skillLine] = { [opskriftens navn] = { orange, gul, grøn, grå } }
local CONFIRMED = {
    [197] = {
        ["Bolt of Silk Cloth"] = { 100, 110, 115, 120 },   -- Forever-database, 13. nov. 2026
    },
}

-- Rækkefølge hvis biblioteket ikke kan levere listen
local DEFAULT_PROFS = { 171, 164, 185, 333, 202, 129, 165, 186, 197 }

local S = { hiddenProfs = {}, known = {}, scannedProfs = {} }   -- gemmes pr. karakter
for k, v in pairs(DEFAULTS) do S[k] = v end

local index                        -- [itemID] = { {e = opskrift, n = antal}, ... }
local recipeCount, reagentCount = 0, 0
local placeholderCount, droppedCount = 0, 0   -- til /rst status
local indexProfs = {}              -- professions der har opskrifter med reagenser
local recipeProf = {}              -- [spellID] = skillLine (alle opskrifter)
local recipeByName = {}            -- [navn] = { spellID, ... } (reserve til Classic-API)
local libProfNames = {}            -- navne fra biblioteket, hvis det har dem
local shownOn = {}                 -- tooltips hvor vi har tilføjet linjer

------------------------------------------------------------------------
-- Hjælpefunktioner
------------------------------------------------------------------------

local function Print(msg) print(PREFIX .. tostring(msg)) end

local function GetDB()
    if not LibStub then return nil end
    return LibStub(LIB_MAJOR, true)
end

-- Kalder obj:method(...) sikkert. Returnerer nil hvis metoden mangler eller fejler.
local function try(obj, method, ...)
    local f = obj and obj[method]
    if type(f) ~= "function" then return nil end
    local ok, a, b, c = pcall(f, obj, ...)
    if ok then return a, b, c end
    return nil
end

local function ProfName(p, localNames)
    if localNames and localNames[p] then return localNames[p] end
    if libProfNames[p] then return libProfNames[p] end
    if C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName then
        local ok, name = pcall(C_TradeSkillUI.GetTradeSkillDisplayName, p)
        if ok and type(name) == "string" and name ~= "" then
            libProfNames[p] = name
            return name
        end
    end
    return PROFESSIONS[p] and PROFESSIONS[p].name or ("Profession " .. tostring(p))
end

local function IconString(p, size)
    local icon = PROFESSIONS[p] and PROFESSIONS[p].icon or UNKNOWN_ICON
    return string.format("|T%s:%d:%d:0:0:64:64:5:59:5:59|t", icon, size, size)
end

------------------------------------------------------------------------
-- Læsning af LibProfessionDB (skrevet så den tåler flere dataformater)
------------------------------------------------------------------------

local function ProfessionIDs(db)
    local list, seen = {}, {}
    local function add(id)
        if type(id) == "number" and id > 100 and not seen[id] then
            seen[id] = true
            list[#list + 1] = id
        end
    end

    local profs = try(db, "GetProfessions")
    if type(profs) == "table" then
        for k, v in pairs(profs) do
            if type(k) == "number" and k > 100 then
                add(k)
                if type(v) == "string" then libProfNames[k] = v end
                if type(v) == "table" and type(v.name) == "string" then libProfNames[k] = v.name end
            elseif type(v) == "number" then
                add(v)
            elseif type(v) == "table" then
                local id = v.id or v.profId or v.skillLine or v.skillLineID or v[1]
                add(id)
                if type(id) == "number" and type(v.name) == "string" then libProfNames[id] = v.name end
            end
        end
    end

    -- Reserve: prøv alle kendte professions
    if #list == 0 then
        for id in pairs(PROFESSIONS) do add(id) end
    end
    return list
end

local function ForEachRecipe(db, profId, fn)
    local recipes = try(db, "GetRecipes", profId)
    if type(recipes) == "table" then
        for k, v in pairs(recipes) do
            if type(v) == "table" then
                fn(v.id or v.spellID or v.spellId or v.recipeID or k, v)
            elseif type(v) == "number" then
                fn(v, try(db, "GetRecipe", profId, v))
            elseif v == true and type(k) == "number" then
                fn(k, try(db, "GetRecipe", profId, k))
            end
        end
        return
    end

    -- Reserve: Iterate(profId) som iterator
    if type(db.Iterate) == "function" then
        local ok, f, s, var = pcall(db.Iterate, db, profId)
        if ok and type(f) == "function" then
            for a, b, c in f, s, var do
                if type(c) == "table" then
                    fn(c.id or c.spellID or b, c)
                elseif type(b) == "table" then
                    fn(b.id or b.spellID or a, b)
                end
            end
        end
    end
end

local function ForEachReagent(db, profId, id, recipe, fn)
    local reagents = recipe.reagents
    if type(reagents) ~= "table" then reagents = try(db, "GetReagents", profId, id) end
    if type(reagents) ~= "table" then return end

    for k, v in pairs(reagents) do
        if type(v) == "table" then
            local itemID = v.itemID or v.itemId or v.id or v.item or v[1]
            local count = v.count or v.quantity or v.qty or v[2] or 1
            if type(itemID) == "number" then fn(itemID, tonumber(count) or 1) end
        elseif type(v) == "number" then
            if type(k) == "number" and k > 20 then
                fn(k, v)   -- { [itemID] = antal }
            else
                fn(v, 1)   -- { itemID, itemID, ... }
            end
        end
    end
end

local function GetTiers(db, profId, id, recipe)
    local d = recipe.difficulty
    if type(d) ~= "table" then d = try(db, "GetDifficulty", profId, id) end
    if type(d) ~= "table" then return nil end
    local t = {
        tonumber(d[1] or d.orange),
        tonumber(d[2] or d.yellow),
        tonumber(d[3] or d.green),
        tonumber(d[4] or d.grey or d.gray),
    }
    if not (t[2] and t[3] and t[4]) then return nil end
    return t
end

local function GetRequired(db, profId, id, recipe)
    local req = recipe.requiredSkill
    if type(req) ~= "number" then req = try(db, "GetRequiredSkill", profId, id) end
    if type(req) ~= "number" then req = try(db, "GetRequiredSkill", id) end
    if type(req) ~= "number" then return nil, false end

    local borrowed = false
    if type(db.IsBorrowed) == "function" then
        local ok, v = pcall(db.IsBorrowed, db, id, "requiredSkill")
        borrowed = ok and v and true or false
    end
    return req, borrowed
end

local function MakeEntry(db, profId, id, recipe)
    local name = recipe.name
    if type(name) ~= "string" then name = try(db, "GetName", profId, id) end
    if type(name) ~= "string" and C_Spell and C_Spell.GetSpellName then
        local ok, n = pcall(C_Spell.GetSpellName, id)
        if ok then name = n end
    end
    if type(name) ~= "string" then name = "Recipe " .. tostring(id) end

    -- Bekræftede Forever-tal går forud for bibliotekets
    local fixed = CONFIRMED[profId] and CONFIRMED[profId][name]
    if fixed then
        return {
            profId = profId, id = id, name = name,
            tiers = { fixed[1], fixed[2], fixed[3], fixed[4] },
            orange = fixed[1], yellow = fixed[2], learnReq = fixed[1],
            starred = false, placeholder = false, dropped = false, confirmed = true,
        }
    end

    local lib = GetTiers(db, profId, id, recipe)      -- bibliotekets {orange, gul, grøn, grå}
    local req, borrowed = GetRequired(db, profId, id, recipe)

    -- I Forever er den grønne grænse altid midten mellem gul og grå
    -- (bekræftet med Bolt of Silk Cloth og Heavy Silk Bandage). Bibliotekets
    -- gule tal er derimod tit regnet ud som midten mellem orange og grøn.
    local tiers, orange, yellow
    local placeholder, dropped = false, false
    if lib then
        local grey = lib[4]
        -- Bibliotekets regel: orange er kun en pladsholder, når requiredSkill
        -- mangler eller er lånt fra Vanilla, OG difficulty[1] == 1.
        placeholder = (req == nil or borrowed) and lib[1] == 1
        if placeholder then
            -- For pladsholder-opskrifter er bibliotekets "grønne" tal Forevers
            -- gule grænse (Bolt of Silk Cloth: 110), og grøn er midten mellem
            -- gul og grå (115).
            yellow = lib[3]
            local green = math.floor((yellow + grey) / 2)
            -- Kravet kan ikke ligge over den gule grænse. Gør et lånt
            -- Vanilla-krav det, passer det ikke til Forever og ignoreres.
            if req and req > yellow then
                req, borrowed, dropped = nil, false, true
            end
            orange = req
            tiers = { orange, yellow, green, grey }
        else
            -- Almindelige opskrifter: grøn og grå er rigtige, og gul regnes
            -- tilbage som 2 x grøn - grå (Heavy Silk Bandage: 180, ikke 195).
            -- Bibliotekets gule tal beholdes, hvis det passer med formlen.
            local green = lib[3]
            orange = lib[1]
            local y = 2 * green - grey
            if lib[2] == y or lib[2] == y + 1 then y = lib[2] end
            yellow = math.max(orange, math.min(y, green))
            tiers = { orange, yellow, green, grey }
        end
    end

    return {
        profId      = profId,
        id          = id,
        name        = name,
        tiers       = tiers,                  -- rettede tal {orange, gul, grøn, grå}
        orange      = orange,                 -- hvor opskriften bliver orange (kan være nil)
        yellow      = yellow,                 -- hvor den bliver gul (nil = ukendt)
        learnReq    = req or orange,          -- skill der skal til for at bruge den
        starred     = borrowed and true or false,
        placeholder = placeholder,
        dropped     = dropped,
    }
end

local function SortKey(e)
    if e.orange then return e.orange end
    if e.yellow then return e.yellow end
    if e.tiers then return e.tiers[3] end
    return 9999
end

local function BuildIndex()
    local db = GetDB()
    if not db then return false, L.NO_LIB end
    if type(db.IsReady) == "function" then
        local ok, ready = pcall(db.IsReady, db)
        if ok and not ready then return false, "LibProfessionDB is not ready yet." end
    end

    local newIndex, recipes, reagents, profs = {}, 0, 0, {}
    local placeholders, dropped = 0, 0
    local profOf, byName = {}, {}
    for _, profId in ipairs(ProfessionIDs(db)) do
        ForEachRecipe(db, profId, function(id, recipe)
            if type(id) ~= "number" or type(recipe) ~= "table" then return end
            local entry = MakeEntry(db, profId, id, recipe)
            recipes = recipes + 1
            if entry.placeholder then placeholders = placeholders + 1 end
            if entry.dropped then dropped = dropped + 1 end
            profOf[id] = profId
            local same = byName[entry.name]
            if not same then same = {}; byName[entry.name] = same end
            same[#same + 1] = id
            ForEachReagent(db, profId, id, recipe, function(itemID, count)
                local list = newIndex[itemID]
                if not list then
                    list = {}
                    newIndex[itemID] = list
                    reagents = reagents + 1
                end
                list[#list + 1] = { e = entry, n = count }
                profs[profId] = true
            end)
        end)
    end

    for _, list in pairs(newIndex) do
        table.sort(list, function(a, b)
            local ka, kb = SortKey(a.e), SortKey(b.e)
            if ka ~= kb then return ka < kb end
            return a.e.name < b.e.name
        end)
    end

    if recipes == 0 then return false, "LibProfessionDB returned no recipes." end
    index, recipeCount, reagentCount, indexProfs = newIndex, recipes, reagents, profs
    placeholderCount, droppedCount = placeholders, dropped
    recipeProf, recipeByName = profOf, byName
    return true
end

local lastError
local function EnsureIndex()
    if index then return true end
    local ok, built, why = pcall(BuildIndex)
    if not ok then why = built; built = false end
    if not built then
        if S.debug and why ~= lastError then Print(why) end
        lastError = why
        return false, why
    end
    return true
end

------------------------------------------------------------------------
-- Karakterens skill
------------------------------------------------------------------------

local function GetPlayerSkills()
    local skills, names = {}, {}

    -- Moderne API (Forever deler UI-kode med moderne WoW)
    if GetProfessions and GetProfessionInfo then
        local profs = { GetProfessions() }
        for i = 1, select("#", GetProfessions()) do
            local idx = profs[i]
            if idx then
                local name, _, rank, _, _, _, skillLine = GetProfessionInfo(idx)
                if type(skillLine) == "number" and type(rank) == "number" then
                    skills[skillLine] = rank
                    names[skillLine] = name
                end
            end
        end
    end

    -- Supplement: professions der ikke kom med ovenfor (fx First Aid)
    if C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID then
        for id in pairs(PROFESSIONS) do
            if not skills[id] then
                local ok, info = pcall(C_TradeSkillUI.GetProfessionInfoBySkillLineID, id)
                if ok and type(info) == "table" and type(info.skillLevel) == "number" and info.skillLevel > 0 then
                    skills[id] = info.skillLevel
                    if type(info.professionName) == "string" then names[id] = info.professionName end
                end
            end
        end
    end

    -- Reserve: Classic-API
    if next(skills) == nil and GetNumSkillLines and GetSkillLineInfo then
        for i = 1, GetNumSkillLines() do
            local name, isHeader, _, rank = GetSkillLineInfo(i)
            if name and not isHeader then
                for id, p in pairs(PROFESSIONS) do
                    if name == p.name or name == libProfNames[id] then
                        skills[id] = rank
                        names[id] = name
                    end
                end
            end
        end
    end

    return skills, names
end

local function DifficultyColor(e, skill)
    if not skill then return COLOR.white end
    if e.learnReq and skill < e.learnReq then return COLOR.red end
    local t = e.tiers
    if not t then return COLOR.white end
    if skill < t[3] then
        if e.yellow and skill >= e.yellow then return COLOR.yellow end
        -- Ukendt krav: vi kan ikke afgøre om den er rød, orange eller gul
        if not e.learnReq then return COLOR.white end
        -- Kendt krav, men ukendt gul grænse: vises som orange
        return COLOR.orange
    end
    if skill < t[4] then return COLOR.green end
    return COLOR.grey
end

local function TierText(e)
    local t = e.tiers
    if not t then return "|cff808080?|r" end
    local o = e.orange and tostring(e.orange) or "?"
    if e.starred then o = o .. "*" end
    local y = e.yellow and tostring(e.yellow) or "?"
    return string.format("|cff%s%s|r  |cff%s%s|r  |cff%s%d|r  |cff%s%d|r",
        COLOR.orange, o, COLOR.yellow, y, COLOR.green, t[3], COLOR.grey, t[4])
end

------------------------------------------------------------------------
-- Tooltip
------------------------------------------------------------------------

local function AddReagentInfo(tooltip, itemID, forceExpanded)
    if not S.enabled and not forceExpanded then return false end
    if not EnsureIndex() then return false end

    local list = index[itemID]
    if not list then return false end

    local skills, localNames = GetPlayerSkills()

    -- Gruppér pr. profession
    local groups, order = {}, {}
    for _, ref in ipairs(list) do
        local p = ref.e.profId
        -- "Only my own professions": alle egne professions vises, og listen
        -- med fravalgte professions bruges ikke. Ellers bestemmer listen.
        local wanted
        if forceExpanded then
            wanted = true
        elseif S.showUnlearned then
            wanted = not S.hiddenProfs[p]
        else
            wanted = skills[p] ~= nil
        end
        if wanted then
            local g = groups[p]
            if not g then
                g = {}
                groups[p] = g
                order[#order + 1] = p
            end
            g[#g + 1] = ref
        end
    end
    if #order == 0 then return false end

    -- Dine egne professions først, derefter alfabetisk
    table.sort(order, function(a, b)
        local la, lb = skills[a] ~= nil, skills[b] ~= nil
        if la ~= lb then return la end
        return ProfName(a, localNames) < ProfName(b, localNames)
    end)

    local expanded = forceExpanded or (IsShiftKeyDown and IsShiftKeyDown())
    local maxLines = math.max(1, tonumber(S.maxPerProfession) or DEFAULTS.maxPerProfession)
    local showNumbers = forceExpanded or not S.hideNumbers

    -- Overskrift med ikoner for alle professions
    local icons = {}
    for i, p in ipairs(order) do icons[i] = IconString(p, 16) end
    local header = L.REAGENT_FOR .. " " .. table.concat(icons, " ")
    tooltip:AddLine(" ")

    -- Kompakt visning: uden Shift kun ikonlinjen
    if S.compact and not expanded then
        tooltip:AddLine(header .. "  |cff808080" .. L.SHIFT_HINT .. "|r", 1, 0.82, 0)
        return true
    end
    tooltip:AddLine(header, 1, 0.82, 0)

    local hidden, starred, needScan = 0, false, false
    for _, p in ipairs(order) do
        local g, skill = groups[p], skills[p]

        -- Flueben/kryds kun i egne professions, som addonnen har set i
        -- profession-vinduet (ellers vides det ikke, hvad karakteren kender)
        local mark = S.showKnown and skill and S.scannedProfs and S.scannedProfs[p]
        if S.showKnown and skill and not mark then needScan = true end

        local right = skill and ("|cffffffff" .. skill .. "|r")
            or ("|cff808080" .. L.NOT_LEARNED .. "|r")
        tooltip:AddDoubleLine(IconString(p, 14) .. " " .. ProfName(p, localNames), right, 1, 0.82, 0)

        -- Uden Shift vises et udsnit. Grå opskrifter kan skjules helt,
        -- og ellers starter listen ved den første opskrift der ikke er grå.
        local shown = g
        if not expanded then
            if S.hideGrey and skill then
                shown = {}
                for _, ref in ipairs(g) do
                    if DifficultyColor(ref.e, skill) ~= COLOR.grey then shown[#shown + 1] = ref end
                end
            end
            if #shown > maxLines then
                local first = 1
                if skill then
                    local start = #shown
                    for i, ref in ipairs(shown) do
                        if DifficultyColor(ref.e, skill) ~= COLOR.grey then start = i break end
                    end
                    first = math.max(1, math.min(start, #shown - maxLines + 1))
                end
                local cut = {}
                for i = first, first + maxLines - 1 do cut[#cut + 1] = shown[i] end
                shown = cut
            end
        end

        if #shown == 0 then
            tooltip:AddLine("    " .. L.ALL_GREY, 0.5, 0.5, 0.5)
        end
        for _, ref in ipairs(shown) do
            local e = ref.e
            local left = "    "
            if mark then left = left .. (S.known[e.id] and ICON_KNOWN or ICON_UNKNOWN) .. " " end
            left = left .. "|cff" .. DifficultyColor(e, skill) .. e.name .. "|r"
            if S.showCounts and ref.n and ref.n > 1 then
                left = left .. " |cffbbbbbbx" .. ref.n .. "|r"
            end
            if showNumbers then
                tooltip:AddDoubleLine(left, TierText(e))
                if e.starred then starred = true end
            else
                tooltip:AddLine(left)
            end
        end
        hidden = hidden + (#g - #shown)
    end

    if hidden > 0 then tooltip:AddLine(string.format(L.MORE, hidden), 0.6, 0.6, 0.6) end
    if starred then tooltip:AddLine(L.UNCONFIRMED, 0.6, 0.6, 0.6) end
    if needScan then tooltip:AddLine(L.SCAN_HINT, 0.6, 0.6, 0.6) end
    return true
end

local function OnTooltipItem(tooltip, data)
    if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
    if tooltip.IsForbidden and tooltip:IsForbidden() then return end

    local itemID = data and data.id
    if itemID ~= nil and issecretvalue and issecretvalue(itemID) then return end

    if type(itemID) ~= "number" and tooltip.GetItem then
        local _, link = tooltip:GetItem()
        if link then
            if C_Item and C_Item.GetItemInfoInstant then
                itemID = C_Item.GetItemInfoInstant(link)
            elseif GetItemInfoInstant then
                itemID = GetItemInfoInstant(link)
            end
        end
    end
    if type(itemID) ~= "number" then return end

    local ok, result = pcall(AddReagentInfo, tooltip, itemID)
    if ok then
        if result then shownOn[tooltip] = true end
    elseif S.debug then
        Print(result)
    end
end

local function Safe(desc, fn)
    local ok, err = pcall(fn)
    if not ok then loadErrors[#loadErrors + 1] = desc .. ": " .. tostring(err) end
    return ok
end

local hooked = false
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    hooked = Safe("TooltipDataProcessor", function()
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnTooltipItem)
    end)
end
if not hooked then
    for _, tt in ipairs({ GameTooltip, ItemRefTooltip }) do
        if tt and tt.HookScript then
            Safe("OnTooltipSetItem", function()
                tt:HookScript("OnTooltipSetItem", function(self) OnTooltipItem(self, nil) end)
            end)
        end
    end
end

for _, tt in ipairs({ GameTooltip, ItemRefTooltip }) do
    if tt and tt.HookScript then
        Safe("OnTooltipCleared", function()
            tt:HookScript("OnTooltipCleared", function(self) shownOn[self] = nil end)
        end)
    end
end

------------------------------------------------------------------------
-- Fælles UI-hjælpere
------------------------------------------------------------------------

local ToggleSettings   -- defineres længere nede

local function CopyTable(t)
    local c = {}
    for k, v in pairs(t or {}) do c[k] = v end
    return c
end

local function CreateCheckbox(parent)
    local ok, cb = pcall(CreateFrame, "CheckButton", nil, parent, "UICheckButtonTemplate")
    if not ok or not cb then
        cb = CreateFrame("CheckButton", nil, parent)
        cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
        cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
        cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
        cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    end
    cb:SetSize(24, 24)
    return cb
end

local function CreateButton(parent, text, width)
    local ok, b = pcall(CreateFrame, "Button", nil, parent, "UIPanelButtonTemplate")
    if not ok or not b then
        b = CreateFrame("Button", nil, parent)
        b:SetNormalFontObject("GameFontNormal")
        b:SetHighlightFontObject("GameFontHighlight")
    end
    b:SetSize(width, 22)
    b:SetText(text)
    return b
end

------------------------------------------------------------------------
-- Minimap-knap
------------------------------------------------------------------------

local minimapButton

local function UpdateMinimapPosition()
    if not minimapButton then return end
    local angle = math.rad(S.minimapAngle or DEFAULTS.minimapAngle)
    local radius = (Minimap:GetWidth() / 2) + 5
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function OnDragUpdate()
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    px, py = px / scale, py / scale
    S.minimapAngle = math.deg(math.atan2(py - my, px - mx)) % 360
    UpdateMinimapPosition()
end

local function CreateMinimapButton()
    if minimapButton or not Minimap then return end
    local b = CreateFrame("Button", "ReagentSkillTipsMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("AnyUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    -- Samme opbygning som andre minimap-ikoner (som LibDBIcon):
    -- mørk baggrund, ikonet i midten og Blizzards guldring ovenpå.
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(24, 24)
    bg:SetPoint("CENTER")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexture(MINIMAP_ICON)
    b.icon = icon

    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(50, 50)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    b.border = border

    b:SetScript("OnClick", function() ToggleSettings() end)
    b:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        self:SetScript("OnUpdate", OnDragUpdate)
    end)
    b:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self:UnlockHighlight()
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Reagent Skill Tips")
        GameTooltip:AddLine("Click: settings", 1, 1, 1)
        GameTooltip:AddLine("Drag: move this button", 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    minimapButton = b
    UpdateMinimapPosition()
    if S.showMinimap then b:Show() else b:Hide() end
end

local function SetMinimapShown(show)
    S.showMinimap = show and true or false
    if not minimapButton then CreateMinimapButton() end
    if minimapButton then
        if S.showMinimap then minimapButton:Show() else minimapButton:Hide() end
    end
end

------------------------------------------------------------------------
-- Indstillinger. Samme indhold bruges i popup-vinduet og under
-- Options -> AddOns. Ændringer gemmes først, når man trykker Save.
------------------------------------------------------------------------

local function SettingsProfessions()
    local list = {}
    if EnsureIndex() then
        for p in pairs(indexProfs) do list[#list + 1] = p end
    end
    if #list == 0 then
        for _, p in ipairs(DEFAULT_PROFS) do list[#list + 1] = p end
    end
    local _, names = GetPlayerSkills()
    table.sort(list, function(a, b) return ProfName(a, names) < ProfName(b, names) end)
    return list, names
end

-- Indstillinger i højre kolonne. 'invert' betyder, at checkboxen er
-- det modsatte af feltet (fx "Only my own professions" = not showUnlearned).
local OPTION_CHECKS = {
    { key = "enabled",       label = "Show info in tooltips",
      tip = "Turn all Reagent Skill Tips lines in item tooltips on or off." },
    { key = "showCounts",    label = "Show reagent counts (x2)",
      tip = "Show how many of the item a recipe uses, when it is more than one." },
    { key = "hideGrey",      label = "Hide grey recipes",
      tip = "Hide recipes that give no skill-ups in your own professions. Hold Shift to see them." },
    { key = "compact",       label = "Compact view",
      tip = "Show only the profession icons. Hold Shift to see the recipes." },
    { key = "hideNumbers",   label = "Hide skill numbers",
      tip = "Show only the coloured recipe names, without the four skill levels." },
    { key = "showKnown",     label = "Mark known recipes",
      tip = "Green check for recipes this character knows, red cross for recipes it does not know yet. Open each profession window once so the addon can see your recipes." },
}

-- "Only my own professions" ligger øverst i venstre kolonne
local OWN_ONLY_LABEL = "Only my own professions"
local OWN_ONLY_TIP = "Show all professions this character has learned and no others. The list below is not used while this is on."

-- Felter der redigeres i vinduet (ud over de fravalgte professions)
local SETTING_KEYS = { "showMinimap", "maxPerProfession", "showUnlearned" }
for _, o in ipairs(OPTION_CHECKS) do SETTING_KEYS[#SETTING_KEYS + 1] = o.key end

local function NormValue(key, v)
    if key == "maxPerProfession" then
        return math.max(1, math.min(MAX_LINES, math.floor(tonumber(v) or DEFAULTS.maxPerProfession)))
    end
    return v and true or false
end

local function AddHoverTip(widget, title, text)
    widget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        GameTooltip:AddLine(text, 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Bygger checkboxe og knapper i 'parent' i to kolonner:
-- venstre = professions, højre = tooltip-indstillinger og minimap.
-- Returnerer et kontrol-objekt.
local function BuildSettingsContent(parent, left, top, onSave, onCancel)
    local ROW_H = 26
    local COL_W = 250
    local ctl = { checks = {}, options = {}, pending = { hidden = {}, values = {} } }
    local list, names = SettingsProfessions()

    -- Venstre kolonne: professions
    local yL = top
    local heading = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heading:SetPoint("TOPLEFT", left, yL)
    heading:SetText("Professions shown in tooltips")
    yL = yL - 22

    -- "Only my own professions" øverst. Når den er slået til, bruges listen
    -- ikke, så All/None og checkboxene for de enkelte professions deaktiveres.
    local own = CreateCheckbox(parent)
    own:SetPoint("TOPLEFT", left - 2, yL)
    local ownLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ownLabel:SetPoint("LEFT", own, "RIGHT", 4, 0)
    ownLabel:SetText(OWN_ONLY_LABEL)
    own:SetHitRectInsets(0, -170, 0, 0)
    own:SetScript("OnClick", function(self)
        ctl.pending.values.showUnlearned = not (self:GetChecked() and true or false)
        ctl:Refresh()
    end)
    AddHoverTip(own, OWN_ONLY_LABEL, OWN_ONLY_TIP)
    ctl.own = own
    yL = yL - ROW_H - 4

    -- Fin streg mellem "Only my own professions" og listen
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetWidth(COL_W - 30)
    line:SetPoint("TOPLEFT", left, yL)
    if line.SetColorTexture then
        line:SetColorTexture(1, 1, 1, 0.2)
    else
        line:SetTexture(1, 1, 1, 0.2)
    end
    yL = yL - 9

    -- All / None over listen
    local all = CreateButton(parent, "All", 100)
    all:SetPoint("TOPLEFT", left, yL)
    all:SetScript("OnClick", function()
        for _, cb in ipairs(ctl.checks) do ctl.pending.hidden[cb.profId] = nil end
        ctl:Refresh()
    end)

    local none = CreateButton(parent, "None", 100)
    none:SetPoint("LEFT", all, "RIGHT", 10, 0)
    none:SetScript("OnClick", function()
        for _, cb in ipairs(ctl.checks) do ctl.pending.hidden[cb.profId] = true end
        ctl:Refresh()
    end)
    yL = yL - 30

    for _, p in ipairs(list) do
        local cb = CreateCheckbox(parent)
        cb:SetPoint("TOPLEFT", left - 2, yL)
        cb.profId = p

        local icon = parent:CreateTexture(nil, "ARTWORK")
        icon:SetSize(18, 18)
        icon:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        icon:SetTexture(PROFESSIONS[p] and PROFESSIONS[p].icon or UNKNOWN_ICON)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        label:SetText(ProfName(p, names))

        cb:SetHitRectInsets(0, -170, 0, 0)   -- klik på navnet virker også
        cb:SetScript("OnClick", function(self)
            ctl.pending.hidden[self.profId] = (not self:GetChecked()) or nil
            ctl:Refresh()
        end)
        cb.icon, cb.label = icon, label
        ctl.checks[#ctl.checks + 1] = cb
        yL = yL - ROW_H
    end
    yL = yL - 8

    -- Højre kolonne: tooltip-indstillinger
    local right = left + COL_W
    local yR = top
    local heading2 = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heading2:SetPoint("TOPLEFT", right, yR)
    heading2:SetText("Tooltip")
    yR = yR - 22

    for _, opt in ipairs(OPTION_CHECKS) do
        local cb = CreateCheckbox(parent)
        cb:SetPoint("TOPLEFT", right - 2, yR)
        cb.opt = opt

        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        label:SetText(opt.label)

        cb:SetHitRectInsets(0, -190, 0, 0)
        cb:SetScript("OnClick", function(self)
            local checked = self:GetChecked() and true or false
            if self.opt.invert then checked = not checked end
            ctl.pending.values[self.opt.key] = checked
            ctl:Refresh()
        end)
        AddHoverTip(cb, opt.label, opt.tip)
        ctl.options[#ctl.options + 1] = cb
        yR = yR - ROW_H
    end

    -- Antal opskrifter uden Shift: [-] n [+]
    yR = yR - 6
    local linesLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    linesLabel:SetPoint("TOPLEFT", right, yR - 5)
    linesLabel:SetText("Recipes without Shift:")

    local minus = CreateButton(parent, "-", 24)
    minus:SetPoint("LEFT", linesLabel, "RIGHT", 8, 0)
    local linesValue = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    linesValue:SetWidth(28)
    linesValue:SetJustifyH("CENTER")
    linesValue:SetPoint("LEFT", minus, "RIGHT", 2, 0)
    local plus = CreateButton(parent, "+", 24)
    plus:SetPoint("LEFT", linesValue, "RIGHT", 2, 0)

    local linesTip = "How many recipes are shown per profession before you hold Shift (1-" .. MAX_LINES .. ")."
    AddHoverTip(minus, "Recipes without Shift", linesTip)
    AddHoverTip(plus, "Recipes without Shift", linesTip)
    minus:SetScript("OnClick", function()
        ctl.pending.values.maxPerProfession = NormValue("maxPerProfession", ctl.pending.values.maxPerProfession - 1)
        ctl:Refresh()
    end)
    plus:SetScript("OnClick", function()
        ctl.pending.values.maxPerProfession = NormValue("maxPerProfession", ctl.pending.values.maxPerProfession + 1)
        ctl:Refresh()
    end)
    yR = yR - 34

    local mm = CreateButton(parent, "", 210)
    mm:SetPoint("TOPLEFT", right, yR)
    mm:SetScript("OnClick", function()
        ctl.pending.values.showMinimap = not ctl.pending.values.showMinimap
        ctl:Refresh()
    end)
    yR = yR - 34

    -- Save / Cancel under den længste kolonne
    local y = math.min(yL, yR) - 10
    local save = CreateButton(parent, "Save", 100)
    save:SetPoint("TOPLEFT", left, y)
    local cancel = CreateButton(parent, "Cancel", 100)
    cancel:SetPoint("LEFT", save, "RIGHT", 10, 0)
    y = y - 26

    local status = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    status:SetPoint("TOPLEFT", left, y)
    y = y - 14
    ctl.bottom = y
    ctl.width = COL_W + 230

    function ctl:IsDirty()
        for _, key in ipairs(SETTING_KEYS) do
            if NormValue(key, self.pending.values[key]) ~= NormValue(key, S[key]) then return true end
        end
        for _, cb in ipairs(self.checks) do
            local p = cb.profId
            if (self.pending.hidden[p] and true or false) ~= (S.hiddenProfs[p] and true or false) then
                return true
            end
        end
        return false
    end

    function ctl:Refresh()
        local v = self.pending.values
        local ownOnly = not v.showUnlearned
        self.own:SetChecked(ownOnly)
        for _, cb in ipairs(self.checks) do
            cb:SetChecked(not self.pending.hidden[cb.profId])
            -- Listen bruges ikke, når "Only my own professions" er slået til
            if ownOnly then cb:Disable() else cb:Enable() end
            cb.label:SetFontObject(ownOnly and "GameFontDisable" or "GameFontHighlight")
            cb.icon:SetDesaturated(ownOnly)
            cb.icon:SetAlpha(ownOnly and 0.5 or 1)
        end
        if ownOnly then all:Disable(); none:Disable() else all:Enable(); none:Enable() end
        for _, cb in ipairs(self.options) do
            local checked = v[cb.opt.key] and true or false
            if cb.opt.invert then checked = not checked end
            cb:SetChecked(checked)
        end
        linesValue:SetText(tostring(v.maxPerProfession))
        if v.maxPerProfession > 1 then minus:Enable() else minus:Disable() end
        if v.maxPerProfession < MAX_LINES then plus:Enable() else plus:Disable() end
        mm:SetText(v.showMinimap and "Minimap icon: Shown" or "Minimap icon: Hidden")
        if self:IsDirty() then
            status:SetText("|cffff8040Unsaved changes|r")
        else
            status:SetText("")
        end
    end

    -- Henter de gemte indstillinger ind (bruges ved åbning og Cancel)
    function ctl:Load()
        self.pending.hidden = CopyTable(S.hiddenProfs)
        for _, key in ipairs(SETTING_KEYS) do
            self.pending.values[key] = NormValue(key, S[key])
        end
        self:Refresh()
    end

    function ctl:Commit()
        S.hiddenProfs = CopyTable(self.pending.hidden)
        for _, key in ipairs(SETTING_KEYS) do
            if key ~= "showMinimap" then S[key] = NormValue(key, self.pending.values[key]) end
        end
        SetMinimapShown(self.pending.values.showMinimap)
        self:Refresh()
    end

    save:SetScript("OnClick", function()
        ctl:Commit()
        if onSave then onSave(ctl, status) end
    end)
    cancel:SetScript("OnClick", function()
        ctl:Load()
        if onCancel then onCancel(ctl, status) end
    end)

    return ctl
end

-- Popup-vinduet (åbnes fra minimap-knappen)
local settingsFrame

local function CreateSettingsFrame()
    local ok, f = pcall(CreateFrame, "Frame", "ReagentSkillTipsSettings", UIParent, "BackdropTemplate")
    if not ok or not f then f = CreateFrame("Frame", "ReagentSkillTipsSettings", UIParent) end
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
    end

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -20)
    title:SetText("Reagent Skill Tips")

    local okClose, close = pcall(CreateFrame, "Button", nil, f, "UIPanelCloseButton")
    if okClose and close then close:SetPoint("TOPRIGHT", -6, -6) end

    local ctl = BuildSettingsContent(f, 26, -50,
        function() f:Hide() end,   -- Save: gem og luk
        function() f:Hide() end)   -- Cancel: fortryd og luk
    f:SetHeight(-ctl.bottom + 16)
    f:SetWidth(26 + ctl.width + 26)
    f.ctl = ctl

    -- Hver gang vinduet åbnes, vises de gemte indstillinger.
    -- Lukkes det med X eller Esc, kasseres ændringerne.
    f:SetScript("OnShow", function(self) self.ctl:Load() end)
    if UISpecialFrames then table.insert(UISpecialFrames, "ReagentSkillTipsSettings") end
    f:Hide()
    settingsFrame = f
end

ToggleSettings = function()
    if not settingsFrame then CreateSettingsFrame() end
    if settingsFrame:IsShown() then settingsFrame:Hide() else settingsFrame:Show() end
end

-- Addon compartment-menuen ved minimap (hvis Forever har den)
function ReagentSkillTips_OnAddonCompartmentClick()
    ToggleSettings()
end

-- Panel under Esc -> Options -> AddOns
local optionsCategory

local function RegisterOptionsPanel()
    local panel = CreateFrame("Frame")
    panel.name = "Reagent Skill Tips"

    -- Indholdet bygges først, når panelet vises første gang
    panel:SetScript("OnShow", function(self)
        if not self.ctl then
            local title = self:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            title:SetPoint("TOPLEFT", 16, -16)
            title:SetText("Reagent Skill Tips")
            self.ctl = BuildSettingsContent(self, 18, -50,
                function(_, status) status:SetText("|cff40bf40Saved|r") end,
                nil)
        end
        self.ctl:Load()
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        optionsCategory = category
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
        optionsCategory = panel
    end
end

local function OpenOptionsPanel()
    if not optionsCategory then Print("the options panel is not available.") return end
    if Settings and Settings.OpenToCategory and optionsCategory.GetID then
        pcall(Settings.OpenToCategory, optionsCategory:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        pcall(InterfaceOptionsFrame_OpenToCategory, optionsCategory)
    end
end

------------------------------------------------------------------------
-- Slash-kommandoer
------------------------------------------------------------------------

-- "Tooltip" der skriver i chatten, så /rst item kan genbruge koden
local ChatTip = {
    AddLine = function(_, text)
        if text and text ~= " " then print(text) end
    end,
    AddDoubleLine = function(_, left, right)
        print((left or "") .. "   " .. (right or ""))
    end,
}

local function Describe(v, depth)
    depth = depth or 0
    if type(v) ~= "table" then return tostring(v) end
    if depth >= 2 then return "{...}" end
    local parts, n = {}, 0
    for k, x in pairs(v) do
        n = n + 1
        if n > 6 then parts[#parts + 1] = "..." break end
        parts[#parts + 1] = tostring(k) .. "=" .. Describe(x, depth + 1)
    end
    return "{" .. table.concat(parts, ", ") .. "}"
end

local function Status()
    Print("version " .. VERSION .. ", tooltip info " .. (S.enabled and "on" or "off") .. " (settings are saved per character)")
    for _, err in ipairs(loadErrors) do Print("|cffff4040load error|r " .. err) end
    local db = GetDB()
    Print("LibProfessionDB: " .. (db and "found" or "NOT found"))
    if not db then return end
    Print("IsReady: " .. tostring(try(db, "IsReady")) .. ", game version: " .. tostring(try(db, "GetGameVersion")))
    local ok, why = EnsureIndex()
    if ok then
        Print(string.format("Indexed %d recipes and %d reagents.", recipeCount, reagentCount))
        Print(string.format("%d recipes have no Forever orange level (placeholder). %d of them had a Vanilla requirement above the yellow level, which was ignored.",
            placeholderCount, droppedCount))
    else
        Print("Could not build index: " .. tostring(why))
    end
    local skills, names = GetPlayerSkills()
    for id, rank in pairs(skills) do
        Print(ProfName(id, names) .. " (" .. id .. "): " .. rank)
    end
    local nKnown, checked = 0, {}
    for _ in pairs(S.known or {}) do nKnown = nKnown + 1 end
    for p in pairs(S.scannedProfs or {}) do checked[#checked + 1] = ProfName(p, names) end
    table.sort(checked)
    Print(string.format("Known recipes: %d. Professions checked: %s", nKnown,
        #checked > 0 and table.concat(checked, ", ") or "none yet (open a profession window)"))
end

local function Dump()
    local db = GetDB()
    if not db then Print(L.NO_LIB) return end
    local profs = try(db, "GetProfessions")
    Print("GetProfessions() -> " .. Describe(profs))
    local p = ProfessionIDs(db)[1]
    local recipes = try(db, "GetRecipes", p)
    Print("GetRecipes(" .. tostring(p) .. ") -> " .. type(recipes))
    if type(recipes) == "table" then
        local k, v = next(recipes)
        Print("  first key: " .. tostring(k) .. ", value: " .. type(v))
        local r = (type(v) == "table" and v) or try(db, "GetRecipe", p, type(v) == "number" and v or k)
        if type(r) == "table" then
            for fk, fv in pairs(r) do Print("    " .. tostring(fk) .. " = " .. Describe(fv)) end
        end
    end
end

local function ParseItemID(arg)
    if not arg or arg == "" then return nil end
    return tonumber(arg) or tonumber(arg:match("item:(%d+)"))
end

local function Help()
    Print("commands:")
    print("  /rst config  - open the settings window")
    print("  /rst options  - open the settings under Options -> AddOns")
    print("  /rst minimap  - show or hide the minimap button")
    print("  /rst on | off  - turn the tooltip info on or off")
    print("  /rst mine  - toggle: show only your own professions")
    print("  /rst lines <n>  - recipes per profession without Shift (now " .. S.maxPerProfession .. ")")
    print("  /rst counts  - toggle reagent counts (x2)")
    print("  /rst grey  - toggle: hide grey recipes")
    print("  /rst compact  - toggle: only icons until you hold Shift")
    print("  /rst numbers  - toggle: show or hide the skill numbers")
    print("  /rst known  - toggle: mark known recipes")
    print("  /rst item <itemID or link>  - print the info in chat")
    print("  /rst status  - check the data and your skills")
    print("  /rst dump  - show the library's data format (for troubleshooting)")
    print("  /rst rebuild  - rebuild the recipe index")
    print("  /rst debug  - toggle error messages in chat")
end

SlashHandler = function(msg)
    msg = msg or ""
    local cmd, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
    cmd = (cmd or ""):lower()

    if cmd == "config" or cmd == "settings" then
        ToggleSettings()
    elseif cmd == "options" then
        OpenOptionsPanel()
    elseif cmd == "minimap" then
        SetMinimapShown(not S.showMinimap)
        Print("minimap button " .. (S.showMinimap and "shown" or "hidden"))
    elseif cmd == "on" then
        S.enabled = true;  Print("on")
    elseif cmd == "off" then
        S.enabled = false; Print("off")
    elseif cmd == "mine" then
        S.showUnlearned = not S.showUnlearned
        Print(S.showUnlearned and "showing all professions" or "showing only your own professions")
    elseif cmd == "lines" then
        local n = tonumber(rest)
        if n and n >= 1 then S.maxPerProfession = math.min(MAX_LINES, math.floor(n)) end
        Print("recipes per profession: " .. S.maxPerProfession)
    elseif cmd == "counts" then
        S.showCounts = not S.showCounts
        Print("counts " .. (S.showCounts and "on" or "off"))
    elseif cmd == "grey" or cmd == "gray" then
        S.hideGrey = not S.hideGrey
        Print(S.hideGrey and "grey recipes hidden" or "grey recipes shown")
    elseif cmd == "compact" then
        S.compact = not S.compact
        Print("compact view " .. (S.compact and "on" or "off"))
    elseif cmd == "known" then
        S.showKnown = not S.showKnown
        Print("known recipes " .. (S.showKnown and "marked" or "not marked"))
    elseif cmd == "numbers" then
        S.hideNumbers = not S.hideNumbers
        Print("skill numbers " .. (S.hideNumbers and "hidden" or "shown"))
    elseif cmd == "item" then
        local id = ParseItemID(rest)
        if not id then Print("usage: /rst item <itemID or link>") return end
        if not AddReagentInfo(ChatTip, id, true) then Print("item " .. id .. " is not used in any recipe.") end
    elseif cmd == "status" then
        Status()
    elseif cmd == "dump" then
        Dump()
    elseif cmd == "rebuild" then
        index = nil
        Status()
    elseif cmd == "debug" then
        S.debug = not S.debug
        Print("debug " .. (S.debug and "on" or "off"))
    else
        Help()
    end
end

------------------------------------------------------------------------
-- Kendte opskrifter. Spillet oplyser kun pålideligt, hvilke opskrifter en
-- karakter kender, når profession-vinduet er åbent. Derfor gemmes listen
-- pr. karakter, hver gang vinduet åbnes eller ændres.
------------------------------------------------------------------------

local function MarkKnownRecipe(id, name)
    if id and recipeProf[id] then
        S.known[id] = true
        S.scannedProfs[recipeProf[id]] = true
        return true
    end
    local same = name and recipeByName[name]
    if same then
        for _, rid in ipairs(same) do
            S.known[rid] = true
            S.scannedProfs[recipeProf[rid]] = true
        end
        return true
    end
    return false
end

local function ScanKnownRecipes()
    if not EnsureIndex() then return 0 end
    local found = 0

    -- Moderne API: alle opskrifter i den åbne profession med 'learned'
    local T = C_TradeSkillUI
    if T and T.GetAllRecipeIDs and T.GetRecipeInfo then
        local other = (T.IsTradeSkillLinked and T.IsTradeSkillLinked())
            or (T.IsTradeSkillGuild and T.IsTradeSkillGuild())
            or (T.IsNPCCrafting and T.IsNPCCrafting())
        local notReady = T.IsTradeSkillReady and not T.IsTradeSkillReady()
        if not other and not notReady then
            local ok, ids = pcall(T.GetAllRecipeIDs)
            if ok and type(ids) == "table" then
                for _, rid in ipairs(ids) do
                    local p = recipeProf[rid]
                    if p then
                        local ok2, info = pcall(T.GetRecipeInfo, rid)
                        if ok2 and type(info) == "table" then
                            S.known[rid] = info.learned and true or nil
                            S.scannedProfs[p] = true
                            found = found + 1
                        end
                    end
                end
            end
        end
    end

    -- Reserve: Classic-API, hvor listen kun viser kendte opskrifter.
    -- Her tilføjes kun (et filter i vinduet kan skjule nogle).
    if found == 0 and GetNumTradeSkills and GetTradeSkillInfo
        and not (IsTradeSkillLinked and IsTradeSkillLinked()) then
        for i = 1, GetNumTradeSkills() or 0 do
            local name, kind = GetTradeSkillInfo(i)
            if name and kind ~= "header" and kind ~= "subheader" then
                local link = GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(i)
                local rid = type(link) == "string" and tonumber(link:match("enchant:(%d+)"))
                if MarkKnownRecipe(rid, name) then found = found + 1 end
            end
        end
    end
    if found == 0 and GetNumCrafts and GetCraftInfo then   -- Classic Enchanting
        for i = 1, GetNumCrafts() or 0 do
            local name, _, kind = GetCraftInfo(i)
            if name and kind ~= "header" and MarkKnownRecipe(nil, name) then found = found + 1 end
        end
    end

    if S.debug and found > 0 then Print("checked " .. found .. " recipes in the profession window") end
    return found
end

local scanPending = false
local function RequestScan()
    local function run()
        scanPending = false
        local ok, err = pcall(ScanKnownRecipes)
        if not ok and S.debug then Print(err) end
    end
    if C_Timer and C_Timer.After then
        if scanPending then return end
        scanPending = true
        C_Timer.After(0.5, run)   -- lad spillet nå at indlæse listen
    else
        run()
    end
end

local TRADE_EVENTS = {
    TRADE_SKILL_SHOW = true, TRADE_SKILL_LIST_UPDATE = true, TRADE_SKILL_UPDATE = true,
    TRADE_SKILL_DATA_SOURCE_CHANGED = true, CRAFT_SHOW = true, CRAFT_UPDATE = true,
}

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("MODIFIER_STATE_CHANGED")
-- Profession-vinduets events findes ikke alle i alle klienter, så de
-- registreres hver for sig uden at fejle
for ev in pairs(TRADE_EVENTS) do pcall(frame.RegisterEvent, frame, ev) end
pcall(frame.RegisterEvent, frame, "NEW_RECIPE_LEARNED")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        -- Indstillinger gemmes pr. karakter. En karakter uden gemte
        -- indstillinger starter med standardindstillingerne.
        local db = ReagentSkillTipsCharDB
        if type(db) ~= "table" then db = {} end
        for k, v in pairs(DEFAULTS) do
            if db[k] == nil then db[k] = v end
        end
        if type(db.hiddenProfs) ~= "table" then db.hiddenProfs = {} end
        if type(db.known) ~= "table" then db.known = {} end                 -- [spellID] = true
        if type(db.scannedProfs) ~= "table" then db.scannedProfs = {} end   -- [skillLine] = true
        ReagentSkillTipsCharDB = db
        S = db
    elseif event == "PLAYER_LOGIN" then
        Safe("minimap button", CreateMinimapButton)
        Safe("options panel", RegisterOptionsPanel)
        Print("v" .. VERSION .. " loaded. Type /rst status to check it.")
        if not GetDB() then Print(L.NO_LIB) end
        if #loadErrors > 0 then Print("|cffff4040there were load errors|r - type /rst status") end
    elseif TRADE_EVENTS[event] then
        RequestScan()
    elseif event == "NEW_RECIPE_LEARNED" then
        if type(arg1) == "number" and EnsureIndex() and recipeProf[arg1] then
            S.known[arg1] = true
        end
    elseif event == "MODIFIER_STATE_CHANGED" then
        -- Opdater tooltippen når Shift trykkes/slippes
        if (arg1 == "LSHIFT" or arg1 == "RSHIFT") and shownOn[GameTooltip]
            and GameTooltip:IsShown() and GameTooltip.RefreshData then
            GameTooltip:RefreshData()
        end
    end
end)

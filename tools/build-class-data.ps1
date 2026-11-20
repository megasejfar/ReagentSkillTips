<#
    Bygger ClassData.lua til Reagent Skill Tips: hvilke class-spells der bruger
    et item som reagent (fx Light Feather til Slow Fall og Levitate).

    Dataene er WoW: Forevers egne klienttabeller, eksporteret som CSV fra
    wago.tools (https://wago.tools/db2/<Tabel>?build=<build>, knappen "CSV"):
        SpellReagents.csv, SkillLineAbility.csv, SkillLine.csv, SpellLevels.csv
    Læg dem i én mappe, og kør:

        powershell -NoProfile -ExecutionPolicy Bypass -File tools\build-class-data.ps1

    Standardmappen er ..\wago-<build> ved siden af repoet. Scriptet skriver kun
    ClassData.lua og stopper med en fejl, hvis en tabel eller kolonne mangler.
#>
param(
    [string]$Build = "1.60.1.69977",
    # Mappen med de fire CSV-filer
    [string]$Wago = "",
    # Filen der skrives
    [string]$Out = (Join-Path (Split-Path $PSScriptRoot -Parent) "ClassData.lua")
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2

$repo = Split-Path $PSScriptRoot -Parent
if (-not $Wago) { $Wago = Join-Path (Split-Path $repo -Parent) "wago-$Build" }
$Out = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Out)
$utf8 = New-Object System.Text.UTF8Encoding($false)

# ClassMask-bit -> class-token (samme navne som UnitClass i spillet).
# En liste af par, ikke en [ordered]-tabel: dér tolkes et tal som en position.
$classBits = @(
    @(1, "WARRIOR"), @(2, "PALADIN"), @(4, "HUNTER"), @(8, "ROGUE"), @(16, "PRIEST"),
    @(32, "DEATHKNIGHT"), @(64, "SHAMAN"), @(128, "MAGE"), @(256, "WARLOCK"), @(512, "MONK"), @(1024, "DRUID")
)
$CLASS_CATEGORY = 7     # SkillLine.CategoryID for class-skills (Frost, Fire, Arms ...)
$POISONS = 40           # Rogue-poisons er en egen skill line (kategori 9)

function Read-Table([string]$name, [string[]]$columns) {
    $path = Join-Path $Wago "$name.csv"
    if (-not (Test-Path -LiteralPath $path)) { throw "Mangler $path (hent den som CSV fra wago.tools, build $Build)" }
    $rows = @(Import-Csv -LiteralPath $path -Encoding UTF8)
    if ($rows.Count -eq 0) { throw "$path er tom" }
    $have = $rows[0].PSObject.Properties.Name
    foreach ($c in $columns) { if ($have -notcontains $c) { throw "$name.csv mangler kolonnen '$c'" } }
    return $rows
}

function Classes-Of([int]$mask) {
    $list = @()
    foreach ($pair in $classBits) { if ($mask -band $pair[0]) { $list += $pair[1] } }
    return $list
}

# --- Læs tabellerne ----------------------------------------------------------

$skillLines = Read-Table "SkillLine" @("ID", "CategoryID", "DisplayName_lang")
$abilities  = Read-Table "SkillLineAbility" @("SkillLine", "Spell", "ClassMask")
$reagentRows = Read-Table "SpellReagents" (@("SpellID") + (0..7 | ForEach-Object { "Reagent_$_"; "ReagentCount_$_" }))
$levelRows  = Read-Table "SpellLevels" @("SpellID", "DifficultyID", "BaseLevel", "SpellLevel")

# Skill lines der hører til en class
$classLine = @{}
foreach ($s in $skillLines) {
    if ([int]$s.CategoryID -eq $CLASS_CATEGORY -or [int]$s.ID -eq $POISONS) { $classLine[[int]$s.ID] = $s.DisplayName_lang }
}

# En skill lines class: den hyppigste ClassMask blandt dens spells (bruges,
# når en spell selv har ClassMask 0)
$maskCount = @{}
foreach ($a in $abilities) {
    $line = [int]$a.SkillLine; $mask = [int]$a.ClassMask
    if ($classLine.ContainsKey($line) -and $mask -ne 0) {
        if (-not $maskCount.ContainsKey($line)) { $maskCount[$line] = @{} }
        $maskCount[$line][$mask] = 1 + [int]$maskCount[$line][$mask]
    }
}
$lineMask = @{}
foreach ($line in $maskCount.Keys) {
    $lineMask[$line] = [int](($maskCount[$line].GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key)
}

# Spell -> classes (kun spells i class-skill lines)
$spellClasses = @{}
foreach ($a in $abilities) {
    $line = [int]$a.SkillLine
    if (-not $classLine.ContainsKey($line)) { continue }
    $mask = [int]$a.ClassMask
    if ($mask -eq 0 -and $lineMask.ContainsKey($line)) { $mask = $lineMask[$line] }
    $classes = @(Classes-Of $mask)
    if ($classes.Count -eq 0 -or $classes.Count -gt 3) { continue }   # ukendt eller fælles for mange classes
    $spell = [int]$a.Spell
    if (-not $spellClasses.ContainsKey($spell)) { $spellClasses[$spell] = New-Object 'System.Collections.Generic.HashSet[string]' }
    foreach ($c in $classes) { [void]$spellClasses[$spell].Add($c) }
}

# Spell -> level (det level spellen læres på)
$spellLevel = @{}
foreach ($l in $levelRows) {
    if ([int]$l.DifficultyID -ne 0) { continue }
    $lvl = [int]$l.BaseLevel; if ($lvl -le 0) { $lvl = [int]$l.SpellLevel }
    if ($lvl -gt 0) { $spellLevel[[int]$l.SpellID] = $lvl }
}

# Item -> liste af { spell, class, level, antal }
$byItem = New-Object 'System.Collections.Generic.SortedDictionary[int,object]'
$usedSpells = @{}
foreach ($r in $reagentRows) {
    $spell = [int]$r.SpellID
    if (-not $spellClasses.ContainsKey($spell)) { continue }
    for ($i = 0; $i -le 7; $i++) {
        $item = [int]$r."Reagent_$i"; $count = [int]$r."ReagentCount_$i"
        if ($item -le 0 -or $count -le 0) { continue }
        if (-not $byItem.ContainsKey($item)) { $byItem[$item] = New-Object 'System.Collections.Generic.List[object]' }
        foreach ($c in ($spellClasses[$spell] | Sort-Object)) {
            $byItem[$item].Add([pscustomobject]@{ S = $spell; C = $c; L = $spellLevel[$spell]; N = $count })
        }
        $usedSpells[$spell] = $true
    }
}

# --- Krydstjek med kendte tilfælde -------------------------------------------

function Expect([int]$item, [int]$spell, [string]$class, [string]$what) {
    $ok = $byItem.ContainsKey($item) -and @($byItem[$item] | Where-Object { $_.S -eq $spell -and $_.C -eq $class }).Count -gt 0
    if (-not $ok) { throw "Krydstjek fejlede: $what (item $item, spell $spell, $class) mangler" }
}
Expect 17056 130  "MAGE"   "Light Feather -> Slow Fall"
Expect 17056 1706 "PRIEST" "Light Feather -> Levitate"
Expect 17058 546  "SHAMAN" "Fish Oil -> Water Walking"

# --- Skriv ClassData.lua -------------------------------------------------------

$sb = New-Object System.Text.StringBuilder
function W([string]$s) { [void]$sb.Append($s).Append("`n") }

W "-- Reagent Skill Tips - class spell reagents for WoW: Forever"
W "--"
W "-- GENERATED by tools/build-class-data.ps1 from WoW: Forever's own client data"
W "-- (build ${Build}: SpellReagents, SkillLineAbility, SkillLine, SpellLevels, exported"
W "-- from wago.tools). Do not edit this file by hand. Run the script again instead."
W "--"
W "-- [itemID] = { { s = spell ID, c = class, l = level learned (may be missing), n = count }, ... }"
W ""
W "local _, ns = ..."
W "ns.classSource = `"WoW: Forever client data, build $Build`""
W "ns.classReagents = {"
foreach ($kv in $byItem.GetEnumerator()) {
    $parts = foreach ($e in ($kv.Value | Sort-Object C, L, S)) {
        $lvl = if ($e.L) { ",l=$($e.L)" } else { "" }
        "{s=$($e.S),c=`"$($e.C)`"$lvl,n=$($e.N)}"
    }
    W ("[{0}]={{{1}}}," -f $kv.Key, ($parts -join ","))
}
W "}"

[IO.File]::WriteAllText($Out, $sb.ToString(), $utf8)

# --- Opsummering ---------------------------------------------------------------

$perClass = @{}
foreach ($kv in $byItem.GetEnumerator()) { foreach ($e in $kv.Value) { $perClass[$e.C] = 1 + [int]$perClass[$e.C] } }
"Class skill lines: $($classLine.Count), class spells: $($spellClasses.Count), spells with reagents: $($usedSpells.Count), reagent items: $($byItem.Count)"
foreach ($c in ($perClass.Keys | Sort-Object)) { "  {0,-12} {1,4} entries" -f $c, $perClass[$c] }
"Without level: $(@($byItem.Values | ForEach-Object { $_ } | Where-Object { -not $_.L }).Count) entries"
"Wrote $Out ($([math]::Round((Get-Item -LiteralPath $Out).Length / 1KB, 1)) KB)"

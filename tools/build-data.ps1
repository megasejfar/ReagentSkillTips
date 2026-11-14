<#
    Bygger Data.lua til Reagent Skill Tips ud fra LibProfessionDB's Forever-data.

    Kør det igen, når LibProfessionDB er blevet opdateret:

        powershell -NoProfile -ExecutionPolicy Bypass -File tools\build-data.ps1

    Scriptet læser kun den installerede ProfessionDB-mappe og skriver kun Data.lua.
    Det tager kun de felter med, som addonet bruger, og stopper med en fejl, hvis
    dataformatet ikke er som forventet, i stedet for at skrive en halv fil.
#>
param(
    # Mappen med LibProfessionDB (mappen hedder ProfessionDB)
    [string]$ProfessionDB = "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\ProfessionDB",
    # Filen der skrives
    [string]$Out = (Join-Path (Split-Path $PSScriptRoot -Parent) "Data.lua")
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2

# skillLine-id og datafilens navn for hver profession i Forever
$professions = @(
    @{ Id = 129; File = "Firstaid" }
    @{ Id = 164; File = "Blacksmithing" }
    @{ Id = 165; File = "Leatherworking" }
    @{ Id = 171; File = "Alchemy" }
    @{ Id = 185; File = "Cooking" }
    @{ Id = 186; File = "Mining" }
    @{ Id = 197; File = "Tailoring" }
    @{ Id = 202; File = "Engineering" }
    @{ Id = 333; File = "Enchanting" }
    @{ Id = 356; File = "Fishing" }
)

$utf8 = New-Object System.Text.UTF8Encoding($false)
$Out = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Out)

function Read-Lines([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Filen findes ikke: $path" }
    return [IO.File]::ReadAllLines($path, $utf8)
}

# Læser lib:LoadCore(...) og lib:LoadBorrowed("requiredSkill", ...) fra en _core-fil
function Read-Core([int]$profId, [string]$path) {
    $recipes  = New-Object 'System.Collections.Generic.SortedDictionary[int,object]'
    $borrowed = New-Object 'System.Collections.Generic.HashSet[int]'
    $build = $null; $count = $null
    $state = "outside"          # outside -> core -> done
    $cur = $null; $field = $null; $lineNo = 0

    foreach ($line in (Read-Lines $path)) {
        $lineNo++
        $where = "$path, linje $lineNo"

        if ($state -ne "core") {
            if ($line -match '^-- build (\S+) - (\d+) recipes$') {
                $build = $Matches[1]; $count = [int]$Matches[2]
            } elseif ($line -match "^lib:LoadCore\($profId, \{$") {
                if ($state -eq "done") { throw "Mere end et LoadCore-kald ($where)" }
                $state = "core"
            } elseif ($line -match '^lib:LoadBorrowed\("requiredSkill", "\w+", \{([\d,]*)\}\)$') {
                foreach ($s in $Matches[1].Split(',')) { if ($s) { [void]$borrowed.Add([int]$s) } }
            }
            continue
        }

        # Inde i en indlejret tabel i en opskrift
        if ($field) {
            if ($line -match '^\t\t\t\},?$') {
                $field = $null
            } elseif ($field -eq "difficulty") {
                if ($line -match '^\t\t\t\t(\d+),$') { $cur.D.Add([int]$Matches[1]) }
                else { throw "Uventet linje i difficulty ($where): $line" }
            } elseif ($field -eq "reagents") {
                if ($line -match '^\t\t\t\t\[(\d+)\] = (\d+),$') { $cur.R[[int]$Matches[1]] = [int]$Matches[2] }
                else { throw "Uventet linje i reagents ($where): $line" }
            }
            # Andre indlejrede tabeller (stats o.l.) bruges ikke
            continue
        }

        if ($line -match '^\s*\}\)$') { $state = "done"; continue }

        if ($line -match '^\t\t\[(\d+)\] = \{$') {
            $id = [int]$Matches[1]
            if ($recipes.ContainsKey($id)) { throw "Opskrift $id findes to gange ($where)" }
            $cur = [pscustomobject]@{
                D = New-Object 'System.Collections.Generic.List[int]'
                Q = $null
                R = New-Object 'System.Collections.Generic.SortedDictionary[int,int]'
                N = $null
            }
            $recipes[$id] = $cur
            continue
        }
        if ($line -match '^\t\t\},?$') { $cur = $null; continue }
        if ($null -eq $cur) { throw "Uventet linje uden for en opskrift ($where): $line" }

        if ($line -match '^\t\t\t\["(\w+)"\] = \{$') { $field = $Matches[1]; continue }
        if ($line -match '^\t\t\t\["requiredSkill"\] = (\d+),$') { $cur.Q = [int]$Matches[1]; continue }
        # Felter der ikke bruges (teaches, itemId, craftedItemId, tomme tabeller ...)
        if ($line -match '^\t\t\t\["\w+"\] = (\{\}|-?\d+|"[^"]*"|true|false),$') { continue }
        throw "Uventet linje ($where): $line"
    }

    if ($state -ne "done") { throw "Fandt ikke en hel LoadCore-blok i $path" }
    if ($null -eq $count) { throw "Fandt ikke linjen '-- build ... recipes' i $path" }
    if ($recipes.Count -ne $count) { throw "$path siger $count opskrifter, men $($recipes.Count) blev læst" }
    foreach ($kv in $recipes.GetEnumerator()) {
        if ($kv.Value.D.Count -ne 4) { throw "Opskrift $($kv.Key) i $path har $($kv.Value.D.Count) skill-grænser, ikke 4" }
    }
    return @{ Recipes = $recipes; Borrowed = $borrowed; Build = $build }
}

# Læser de engelske navne fra lib:LoadNames(...). Navne uden en opskrift
# springes over, ligesom biblioteket selv gør.
function Read-Names([int]$profId, [string]$path, $recipes) {
    $state = "outside"; $id = $null
    foreach ($line in (Read-Lines $path)) {
        if ($state -eq "outside") {
            if ($line -match "^lib:LoadNames\($profId, \{$") { $state = "names" }
            continue
        }
        if ($state -eq "done") { continue }
        if ($line -match '^\s*\}\)$') { $state = "done"; continue }
        if ($line -match '^\t\t\[(\d+)\] = \{$') { $id = [int]$Matches[1]; continue }
        # Navnet er allerede en gyldig Lua-streng og bruges, som det står
        if ($line -match '^\t\t\t\["name"\] = "((?:[^"\\]|\\.)*)",$') {
            if ($null -ne $id -and $recipes.ContainsKey($id)) { $recipes[$id].N = $Matches[1] }
        }
    }
    if ($state -ne "done") { throw "Fandt ikke en hel LoadNames-blok i $path" }
}

# --- Læs alle professions --------------------------------------------------

$libVersion = $null
foreach ($l in (Read-Lines (Join-Path $ProfessionDB "ProfessionDB_Camelot.toc"))) {
    if ($l -match '^## Version:\s*(.+)$') { $libVersion = $Matches[1].Trim() }
}
if (-not $libVersion) { throw "Fandt ikke '## Version:' i ProfessionDB_Camelot.toc" }

$all = @(); $builds = @{}
foreach ($p in $professions) {
    $core = Read-Core $p.Id (Join-Path $ProfessionDB "Data\Forever\_core\$($p.File).lua")
    Read-Names $p.Id (Join-Path $ProfessionDB "Data\Forever\enUS\$($p.File).lua") $core.Recipes
    $builds[$core.Build] = $true
    $all += @{ Id = $p.Id; File = $p.File; Core = $core }
}
if ($builds.Count -ne 1) { throw "Datafilerne er fra forskellige builds: $($builds.Keys -join ', ')" }
$build = @($builds.Keys)[0]
$source = "LibProfessionDB $libVersion, Forever build $build"

# --- Skriv Data.lua ---------------------------------------------------------

$sb = New-Object System.Text.StringBuilder
function W([string]$s) { [void]$sb.Append($s).Append("`n") }

W "-- Reagent Skill Tips - recipe data for WoW: Forever"
W "--"
W "-- GENERATED by tools/build-data.ps1 from $source."
W "-- Do not edit this file by hand. Run the script again instead."
W "--"
W "-- One line per recipe, keyed by the recipe's spell ID:"
W "--   n = English name (only used if the game cannot look up the name)"
W "--   d = { orange, yellow, green, grey } skill levels"
W "--   q = required skill (missing when unknown)"
W "--   b = true when q is borrowed from Vanilla and not confirmed for Forever"
W "--   r = { [itemID] = count } reagents"
W "--"
W "-- The recipe data comes from LibProfessionDB, used under its license:"
W "--"
foreach ($l in (Read-Lines (Join-Path $ProfessionDB "LICENSE"))) { W (("-- " + $l).TrimEnd()) }
W ""
W "local _, ns = ..."
W "ns.dataSource = `"$source`""
W "local R = {}"
W "ns.recipes = R"

$total = 0; $totalBorrowed = 0; $noName = 0
$summary = @()
foreach ($p in $all) {
    $recipes = $p.Core.Recipes; $borrowed = $p.Core.Borrowed
    W ""
    W ("R[{0}] = {{ -- {1}, {2} recipes" -f $p.Id, $p.File, $recipes.Count)
    foreach ($kv in $recipes.GetEnumerator()) {
        $r = $kv.Value
        $parts = New-Object 'System.Collections.Generic.List[string]'
        if ($r.N) { $parts.Add('n="' + $r.N + '"') } else { $noName++ }
        $parts.Add('d={' + ($r.D -join ',') + '}')
        if ($null -ne $r.Q) {
            $parts.Add("q=$($r.Q)")
            if ($borrowed.Contains($kv.Key)) { $parts.Add('b=true'); $totalBorrowed++ }
        }
        $reagents = @(); foreach ($x in $r.R.GetEnumerator()) { $reagents += "[$($x.Key)]=$($x.Value)" }
        $parts.Add('r={' + ($reagents -join ',') + '}')
        W ("[{0}]={{{1}}}," -f $kv.Key, ($parts -join ','))
    }
    W "}"
    $total += $recipes.Count
    $summary += "{0,-15} {1,4} recipes" -f $p.File, $recipes.Count
}

[IO.File]::WriteAllText($Out, $sb.ToString(), $utf8)

$summary
"Total: $total recipes, $totalBorrowed with a borrowed requirement, $noName without an English name"
"Source: $source"
"Wrote $Out ($([math]::Round((Get-Item -LiteralPath $Out).Length / 1KB)) KB)"

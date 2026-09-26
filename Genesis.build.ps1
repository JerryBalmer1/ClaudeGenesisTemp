#Requires -Version 7.4
<#
.SYNOPSIS
    Genesis build tasks (GOD_PLAN B3). Run through ./build.ps1, which imports the pinned toolchain.
.DESCRIPTION
    The default task is composed from the tree at load time (B3.4). A task whose input is absent is not in
    the default; invoked directly it fails and names the missing input. Nothing here is stubbed green.
#>
param(
    [switch]$Update
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
Set-StrictMode -Version Latest

$Lock = Get-Content -LiteralPath (Join-Path $BuildRoot 'tools.lock.json') -Raw | ConvertFrom-Json -AsHashtable
$ModuleRoot = Join-Path $BuildRoot 'src/Genesis'
$Manifest = Join-Path $ModuleRoot 'Genesis.psd1'

# A4. The payload is exactly this set.
$PayloadPaths = @(
    'build.ps1', 'Genesis.build.ps1', 'grade.ps1',
    'GOD_PLAN.md', 'GOD_PLAN.lock.json', 'SPEC.md', 'SPEC.lock.json',
    'tools.lock.json', 'payload.manifest.json',
    'src/Genesis', 'tests/unit', 'tests/chain', 'tests/heaven', 'tests/fixtures', 'tests/plan/target',
    '.gitignore'
)
# B3.1. Liftable set = A4 minus these.
$LiftPaths = @($PayloadPaths | Where-Object { $_ -notin 'payload.manifest.json', 'grade.ps1', 'tests/plan/target' })

$RedMarker = '^\s*#\s*status:\s*red\s*$'

function Get-GenesisDefaultTask {
    # B3.4. The tree decides; no switch does.
    $tasks = [Collections.Generic.List[string]]::new()
    $tasks.AddRange([string[]]@('Clean', 'Toolchain', 'Manifest', 'Analyze', 'Plan'))
    if (Test-Path -LiteralPath (Join-Path $BuildRoot 'audit') -PathType Container) { $tasks.Add('Audit') }
    $tasks.Add('Unit')
    if (Get-ChildItem -Path (Join-Path $BuildRoot 'tests/chain') -Filter 'C-*.ps1' -File -ErrorAction Ignore) { $tasks.Add('Chain') }
    if (Get-ChildItem -Path (Join-Path $BuildRoot 'tests/heaven') -Filter 'M-*.ps1' -File -ErrorAction Ignore) { $tasks.Add('Heaven') }
    $tasks.Add('Package')
    $tasks.Add('Lift')
    , $tasks.ToArray()
}

function Test-GenesisRedMarker([string]$Path) {
    [bool]@(Get-Content -LiteralPath $Path -TotalCount 3 | Where-Object { $_ -match $RedMarker }).Count
}

function Get-GenesisRelativePath([string]$Path) {
    [IO.Path]::GetRelativePath($BuildRoot, $Path).Replace('\', '/')
}

function Invoke-GenesisPester {
    # S12 marker rule: a red-marked file still runs; it may fail, it may not pass.
    param([string]$Label, [IO.FileInfo[]]$File)

    $problems = [Collections.Generic.List[string]]::new()
    foreach ($f in $File) {
        $rel = Get-GenesisRelativePath $f.FullName
        $red = Test-GenesisRedMarker $f.FullName
        $config = New-PesterConfiguration
        $config.Run.Path = $f.FullName
        $config.Run.PassThru = $true
        $config.Output.Verbosity = 'Normal'
        $result = Invoke-Pester -Configuration $config

        if ($result.FailedContainersCount -gt 0) { $problems.Add("$rel`: container failed to run"); continue }
        if ($result.TotalCount -eq 0) { $problems.Add("$rel`: contains no tests"); continue }
        $failed = $result.FailedCount + $result.FailedBlocksCount
        if ($red) {
            if ($failed -eq 0) { $problems.Add("$rel`: marked '# status: red' but passed; remove the marker") }
            else { Write-Build Yellow "$Label`: expected red: $rel ($($result.FailedCount) failed)" }
        }
        elseif ($failed -gt 0) {
            $problems.Add("$rel`: $($result.FailedCount) failed")
        }
    }
    if ($problems.Count) {
        $problems | ForEach-Object { Write-Build Red "$Label`: $_" }
        throw "$Label`: $($problems.Count) file(s) red"
    }
}

function Get-GenesisSectionLock([string]$Path) {
    # B2.2. One entry per ^## / ^### heading: SHA-256 of the UTF-8 bytes from the byte after the heading's
    # LF up to the next heading, LF line endings, trailing whitespace stripped per line, no BOM.
    $text = [IO.File]::ReadAllText($Path, [Text.UTF8Encoding]::new($false)).TrimStart([char]0xFEFF)
    $normal = (($text -replace "`r`n", "`n") -split "`n" | ForEach-Object { $_.TrimEnd() }) -join "`n"
    $headings = @([regex]::Matches($normal, '(?m)^#{2,3} .*$'))
    for ($i = 0; $i -lt $headings.Count; $i++) {
        $start = [Math]::Min($headings[$i].Index + $headings[$i].Length + 1, $normal.Length)
        $end = if ($i + 1 -lt $headings.Count) { $headings[$i + 1].Index } else { $normal.Length }
        $body = [Text.Encoding]::UTF8.GetBytes($normal.Substring($start, $end - $start))
        [ordered]@{
            heading = $headings[$i].Value
            sha256  = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($body)).ToLowerInvariant()
        }
    }
}

function Write-GenesisLockFile([string]$Source, [string]$Target) {
    $json = ConvertTo-Json -InputObject @(Get-GenesisSectionLock $Source) -Depth 3
    [IO.File]::WriteAllText($Target, ($json -replace "`r`n", "`n") + "`n", [Text.UTF8Encoding]::new($false))
    Write-Build Green "Plan: wrote $(Get-GenesisRelativePath $Target)"
}

# Synopsis: remove out/ and .heaven/.
task Clean {
    foreach ($dir in 'out', '.heaven') {
        $p = Join-Path $BuildRoot $dir
        if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force }
    }
}

# Synopsis: pwsh, gpg, git present at lock versions; pinned modules loaded from .tools/.
task Toolchain {
    $pwshVersion = [version]('{0}.{1}.{2}' -f $PSVersionTable.PSVersion.Major, $PSVersionTable.PSVersion.Minor, $PSVersionTable.PSVersion.Patch)
    if ($pwshVersion -lt [version]$Lock.pwsh.MinVersion) { throw "Toolchain: pwsh $pwshVersion < $($Lock.pwsh.MinVersion)" }

    if (-not (Get-Command -Name gpg -CommandType Application -ErrorAction Ignore)) { throw 'Toolchain: gpg not found on PATH' }
    $gpgLine = @(gpg --version)[0]
    if ($gpgLine -notmatch '(\d+\.\d+(\.\d+)?)') { throw "Toolchain: cannot parse gpg version from '$gpgLine'" }
    if ([version]$Matches[1] -lt [version]$Lock.gpg.MinVersion) { throw "Toolchain: gpg $($Matches[1]) < $($Lock.gpg.MinVersion)" }

    if (-not (Get-Command -Name git -CommandType Application -ErrorAction Ignore)) { throw 'Toolchain: git not found on PATH' }
    $gitLine = git --version

    $tools = Join-Path $BuildRoot '.tools'
    foreach ($name in @($Lock.Keys | Where-Object { $Lock[$_] -is [hashtable] -and $Lock[$_].ContainsKey('Sha256') } | Sort-Object)) {
        $loaded = @(Get-Module -Name $name)
        if ($loaded.Count -ne 1) { throw "Toolchain: expected exactly one $name loaded, found $($loaded.Count)" }
        if ($loaded[0].Version -ne [version]$Lock[$name].Version) { throw "Toolchain: $name $($loaded[0].Version) loaded, lock says $($Lock[$name].Version)" }
        if (-not $loaded[0].Path.StartsWith($tools, [StringComparison]::OrdinalIgnoreCase)) { throw "Toolchain: $name loaded from $($loaded[0].Path), not .tools/" }
    }
    Write-Build Green "Toolchain: pwsh $pwshVersion; $gpgLine; $gitLine"
}

# Synopsis: validate Genesis.psd1; P-03 under the red-marker rule.
task Manifest {
    $null = Test-ModuleManifest -Path $Manifest
    $data = Import-PowerShellDataFile -Path $Manifest
    if ($data.PowerShellVersion -ne '7.4') { throw "Manifest: PowerShellVersion is '$($data.PowerShellVersion)', must be '7.4'" }
    if ($data.RootModule -ne 'Genesis.psm1') { throw "Manifest: RootModule is '$($data.RootModule)', must be 'Genesis.psm1'" }
    foreach ($key in 'CmdletsToExport', 'VariablesToExport', 'AliasesToExport') {
        if ($data.ContainsKey($key) -and @($data[$key]).Count) { throw "Manifest: $key must be empty (S1.1)" }
    }
    $p03 = Join-Path $BuildRoot 'tests/plan/target/P-03.Tests.ps1'
    if (-not (Test-Path -LiteralPath $p03)) { throw 'Manifest: missing input tests/plan/target/P-03.Tests.ps1' }
    Invoke-GenesisPester -Label Manifest -File (Get-Item -LiteralPath $p03)
}

# Synopsis: PSScriptAnalyzer at Error severity; JSON cmdlets banned under src/.
task Analyze {
    $targets = @('src', 'tests', 'build.ps1', 'Genesis.build.ps1', 'grade.ps1') |
        ForEach-Object { Join-Path $BuildRoot $_ } | Where-Object { Test-Path -LiteralPath $_ }
    $findings = @(foreach ($t in $targets) { Invoke-ScriptAnalyzer -Path $t -Recurse -Severity Error })
    foreach ($f in $findings) { Write-Build Red "Analyze: $(Get-GenesisRelativePath $f.ScriptPath):$($f.Line) $($f.RuleName) $($f.Message)" }

    $banned = 'ConvertTo-Json', 'ConvertFrom-Json', 'Test-Json'
    $jsonHits = @(foreach ($file in Get-ChildItem -Path $ModuleRoot -Include '*.ps1', '*.psm1' -Recurse -File) {
            $ast = [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
            $ast.FindAll({ param($n) $n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -in $banned }, $true) |
                ForEach-Object { "$(Get-GenesisRelativePath $file.FullName):$($_.Extent.StartLineNumber) $($_.GetCommandName()) (B1.2)" }
        })
    foreach ($h in $jsonHits) { Write-Build Red "Analyze: $h" }

    if ($findings.Count + $jsonHits.Count) { throw "Analyze: $($findings.Count + $jsonHits.Count) hit(s)" }
}

# Synopsis: every tests/plan/**/*.Tests.ps1 present; -Update regenerates both lock files (B2.2).
task Plan {
    if ($Update) {
        Write-GenesisLockFile (Join-Path $BuildRoot 'SPEC.md') (Join-Path $BuildRoot 'SPEC.lock.json')
        Write-GenesisLockFile (Join-Path $BuildRoot 'GOD_PLAN.md') (Join-Path $BuildRoot 'GOD_PLAN.lock.json')
    }
    $files = @(Get-ChildItem -Path (Join-Path $BuildRoot 'tests/plan') -Filter '*.Tests.ps1' -Recurse -File -ErrorAction Ignore | Sort-Object FullName)
    if (-not $files) { throw 'Plan: missing input tests/plan/**/*.Tests.ps1' }
    Invoke-GenesisPester -Label Plan -File $files
}

# Synopsis: B10.6 checks on audit/. Before arming (B10.5) only inbox names are checkable.
task Audit {
    $audit = Join-Path $BuildRoot 'audit'
    if (-not (Test-Path -LiteralPath $audit -PathType Container)) { throw 'Audit: missing input audit/' }
    $lines = [Collections.Generic.List[string]]::new()
    foreach ($sub in 'inbox', 'receipts', 'content') {
        if (-not (Test-Path -LiteralPath (Join-Path $audit $sub) -PathType Container)) { $lines.Add("AUDIT_LAYOUT audit/$sub missing (B10.1)") }
    }
    foreach ($f in Get-ChildItem -Path (Join-Path $audit 'inbox') -File -Force -ErrorAction Ignore | Where-Object Name -NE '.gitkeep' | Sort-Object Name) {
        $hash = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($f.Name -cne $hash) { $lines.Add("INBOX_NAME audit/inbox/$($f.Name) sha256=$hash (B10.4)") }
    }
    $receipts = @(Get-ChildItem -Path (Join-Path $audit 'receipts') -File -Force -ErrorAction Ignore | Where-Object Name -NE '.gitkeep')
    if ($receipts) { $lines.Add('AUDIT_ARMED receipts/ is populated; B10.6 chain checks are not implemented') }
    foreach ($l in $lines) { Write-Build Red $l }
    if ($lines.Count) { throw "Audit: $($lines.Count) line(s) printed (B10.6)" }
    Write-Build Green 'Audit: pre-arm (B10.5); receipts/ empty; inbox names are their SHA-256'
}

# Synopsis: tests/unit/; gpg in TestDrive: allowed; git forbidden.
task Unit {
    $dir = Join-Path $BuildRoot 'tests/unit'
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { throw 'Unit: missing input tests/unit/' }
    $gitCalls = @(foreach ($file in Get-ChildItem -Path $dir -Include '*.ps1', '*.psm1' -Recurse -File) {
            $ast = [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
            $ast.FindAll({ param($n) $n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -in 'git', 'git.exe' }, $true) |
                ForEach-Object { "$(Get-GenesisRelativePath $file.FullName):$($_.Extent.StartLineNumber)" }
        })
    if ($gitCalls) { throw "Unit: git is forbidden in unit tests: $($gitCalls -join ', ')" }
    $files = @(Get-ChildItem -Path $dir -Filter '*.Tests.ps1' -Recurse -File | Sort-Object FullName)
    if (-not $files) {
        Write-Build Yellow 'Unit: tests/unit/ holds no test files; nothing ran'
        return
    }
    Invoke-GenesisPester -Label Unit -File $files
}

# Synopsis: tests/chain/C-*.ps1 per S12.
task Chain {
    $files = @(Get-ChildItem -Path (Join-Path $BuildRoot 'tests/chain') -Filter 'C-*.ps1' -File -ErrorAction Ignore | Sort-Object Name)
    if (-not $files) { throw 'Chain: missing input tests/chain/C-*.ps1 (S12)' }
    $skips = @(foreach ($file in Get-ChildItem -Path (Join-Path $BuildRoot 'tests/chain') -Include '*.ps1' -Recurse -File) {
            $ast = [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
            $ast.FindAll({ param($n) $n -is [Management.Automation.Language.CommandParameterAst] -and $n.ParameterName -eq 'Skip' }, $true) |
                ForEach-Object { "$(Get-GenesisRelativePath $file.FullName):$($_.Extent.StartLineNumber)" }
        })
    if ($skips) { throw "Chain: -Skip is not permitted in tests/chain/ (S12): $($skips -join ', ')" }
    Invoke-GenesisPester -Label Chain -File $files
}

# Synopsis: S14 nominal sequence plus every S13 mutant, one run per invocation (B3.3).
task Heaven {
    $dir = Join-Path $BuildRoot 'tests/heaven'
    $missing = @()
    if (-not (Test-Path -LiteralPath (Join-Path $dir 'Invoke-HeavenNominal.ps1'))) { $missing += 'tests/heaven/Invoke-HeavenNominal.ps1' }
    if (-not (Get-ChildItem -Path $dir -Filter 'M-*.ps1' -File -ErrorAction Ignore)) { $missing += 'tests/heaven/M-*.ps1' }
    if ($missing) { throw "Heaven: missing input $($missing -join ', ') (S13, S14)" }
    # S12 marker rule, as in Manifest and Plan: a red-marked mutant runs and may fail; it may not pass.
    $mutants = @(Get-ChildItem -Path $dir -Filter 'M-*.ps1' -File | Sort-Object Name)
    Invoke-GenesisPester -Label Heaven -File $mutants
    # The S14 sequence needs S1.1; while any mutant is red-marked, Payload refuses (B4.2) and nothing ships.
    if (-not @($mutants | Where-Object { Test-GenesisRedMarker $_.FullName })) {
        throw 'Heaven: no mutant is red-marked and the S14 runner is not implemented; see S14, B3.3'
    }
    $left = @(Get-ChildItem -Path (Join-Path $BuildRoot '.heaven') -Directory -Filter 'run-*' -ErrorAction Ignore)
    if ($left) { throw "Heaven: leftover run dir(s): $($left.Name -join ', ') (B3.3)" }
    Write-Build Yellow "Heaven: $($mutants.Count) mutant(s) red-marked; S14 nominal sequence waits on S1.1 (A5 step 4)"
}

# Synopsis: stage out/Genesis/<ver>/ from src/ only; a foreign file is red (B3.2).
task Package {
    $allowed = '^(Genesis\.psd1|Genesis\.psm1|(Public|Private)/[^/]+\.ps1|schemas/[^/]+\.schema\.json|(Public|Private|schemas)/\.gitkeep)$'
    $files = @(Get-ChildItem -Path $ModuleRoot -Recurse -File -Force | ForEach-Object {
            [pscustomobject]@{ Full = $_.FullName; Rel = [IO.Path]::GetRelativePath($ModuleRoot, $_.FullName).Replace('\', '/') }
        })
    $foreign = @($files | Where-Object Rel -NotMatch $allowed)
    if ($foreign) { throw "Package: foreign file(s) under src/Genesis/: $($foreign.Rel -join ', ')" }

    $version = (Import-PowerShellDataFile -Path $Manifest).ModuleVersion
    $branch = git -C $BuildRoot rev-parse --abbrev-ref HEAD
    $short = git -C $BuildRoot rev-parse --short HEAD
    $dirty = [bool](git -C $BuildRoot status --porcelain)
    if ($branch -eq 'main') {
        if ($dirty) { throw 'Package: working tree is dirty on main (B3.2)' }
        $label = $version
        $subject = git -C $BuildRoot log -1 --format=%s
        if ($subject -like 'release:*' -and "v$version" -notin @(git -C $BuildRoot tag --points-at HEAD)) {
            throw "Package: release: commit without tag v$version (B3.2)"
        }
    }
    else {
        $label = "$version-prerelease+$short"
        if ($dirty) { Write-Warning 'Package: working tree is dirty' }
    }

    $out = Join-Path $BuildRoot "out/Genesis/$label"
    foreach ($f in $files | Where-Object { $_.Rel -notlike '*.gitkeep' }) {
        $dest = Join-Path $out $f.Rel
        $null = New-Item -ItemType Directory -Path (Split-Path $dest) -Force
        Copy-Item -LiteralPath $f.Full -Destination $dest
    }
    $null = Test-ModuleManifest -Path (Join-Path $out 'Genesis.psd1')
    Write-Build Green "Package: out/Genesis/$label"
}

# Synopsis: copy the liftable set (B3.1) to an empty temp dir and run Unit, Chain there.
task Lift {
    $dest = Join-Path ([IO.Path]::GetTempPath()) "genesis-lift-$([guid]::NewGuid().ToString('N'))"
    $null = New-Item -ItemType Directory -Path $dest
    try {
        foreach ($p in $LiftPaths) {
            $src = Join-Path $BuildRoot $p
            if (-not (Test-Path -LiteralPath $src)) { throw "Lift: liftable path missing: $p" }
            $target = Join-Path $dest $p
            $null = New-Item -ItemType Directory -Path (Split-Path $target) -Force
            Copy-Item -LiteralPath $src -Destination $target -Recurse
        }
        $tasks = @('Unit')
        if (Get-ChildItem -Path (Join-Path $dest 'tests/chain') -Filter 'C-*.ps1' -File -ErrorAction Ignore) { $tasks += 'Chain' }
        Write-Build Cyan "Lift: $($tasks -join ',') in $dest"
        pwsh -NoProfile -File (Join-Path $dest 'build.ps1') -Task ($tasks -join ',')
    }
    finally {
        Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction Ignore
    }
}

# Synopsis: emit out/payload/ and out/payload.manifest.json (B4.1); refuses per B4.2.
task Payload {
    $refusals = [Collections.Generic.List[string]]::new()
    foreach ($line in @(git -C $BuildRoot status --porcelain)) { $refusals.Add("dirty: $line") }
    foreach ($f in Get-ChildItem -Path (Join-Path $BuildRoot 'tests') -Include '*.ps1' -Recurse -File -ErrorAction Ignore | Sort-Object FullName) {
        if (Test-GenesisRedMarker $f.FullName) { $refusals.Add("red marker: $(Get-GenesisRelativePath $f.FullName)") }
    }
    if ($refusals.Count) {
        $refusals | ForEach-Object { Write-Build Red "Payload: $_" }
        throw "Payload: refused, $($refusals.Count) reason(s) (B4.2)"
    }
    Invoke-Build -Task . -File $BuildFile
    throw 'Payload: emission not implemented; see B4.1'
}

# Synopsis: target only. Diff the tree against payload.manifest.json, then run the default (B4.3).
task Receive {
    throw 'Receive: not implemented; see B4.3'
}

# Synopsis: ClaudeChain CI only. Runs grade.ps1 (B11.3).
task Grade {
    pwsh -NoProfile -File (Join-Path $BuildRoot 'grade.ps1')
}

task . (Get-GenesisDefaultTask)

#Requires -Version 7.4
<#
.SYNOPSIS
    Prove the PreToolUse hook denies shell tools under halt-weight law and fails open
    everywhere else.

.DESCRIPTION
    Drives .claude/hooks/pre-tool-use.ps1 with fixture JSON. The real Claude Code binary
    is never invoked — the contract under test is "one event object in, one decision
    object out, exit 0".

    Checks:
      1. The hook script exists, is UTF-8 with no BOM, and has LF line endings.
      2. A non-shell tool (Read) is allowed and Inspector is never consulted.
      3. Armed, a shell tool against a project with one "Do not" line and an allow of
         Bash(*) is denied, and the reason names PolicyHaltCount and the first finding.
      4. Armed, a shell tool against a prose-only AGENTS.md with no do-not line is allowed.
      5. Armed, a shell tool against a law-free directory is allowed, loudly.
      6. Armed, with the Inspector manifest pointed at a file that is not there, allowed.
      7. Armed, an AGENTS.md carrying NUL bytes is denied for PolicyBadSource.
      8. Garbage on stdin is allowed, exit 0.
      9. Disarmed is inert: the same project that denies in check 3 is allowed.
     10. The event arrives the way Claude Code actually sends it — piped on stdin.
     11. With no -ProjectPath — which is how Claude Code always runs it — the event's own
         cwd is the target. Includes the documented parent-walk gap: a subdirectory with no
         law of its own is allowed even when the project above it denies. An absent
         LEDGER_HOOK_ARM is disarmed, same as LEDGER_HOOK_ARM=0.
     12. .claude/settings.json registers the hook on a shell-only PreToolUse matcher, in
         exec form (pwsh + args, -NoProfile and -File), does not attach it to Read or Edit,
         and no longer runs pre-session.ps1 before every shell tool call.
     13. The suite wrote nothing git can see, and left no fixtures behind.

    Every fixture lives under $env:TEMP and is removed at the end. Nothing is written
    inside the repo, and nothing is written under $env:USERPROFILE.

.EXAMPLE
    pwsh -NoProfile -File tests/sandbox/hook_pre_tool.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

if ($PSBoundParameters.ContainsKey('Debug')) { $DebugPreference = 'Continue' }

# tests/sandbox/ -> tests/ -> repo root.
$repo     = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$hook     = Join-Path -Path $repo -ChildPath '.claude' -AdditionalChildPath 'hooks', 'pre-tool-use.ps1'
$settings = Join-Path -Path $repo -ChildPath '.claude' -AdditionalChildPath 'settings.json'

$script:Failures = 0
$script:Checks   = 0
$script:Fixtures = [System.Collections.Generic.List[string]]::new()

function Write-Section { param([string]$Text)
    Write-Host ''
    Write-Host "=== $Text ===" -ForegroundColor Cyan
}

function Assert-That { param([bool]$Condition, [string]$Label, [string]$Detail = '')
    $script:Checks++
    if ($Condition) {
        Write-Host "  PASS  $Label" -ForegroundColor Green
    } else {
        Write-Host "  FAIL  $Label" -ForegroundColor Red
        if ($Detail) { Write-Host "        $Detail" -ForegroundColor Red }
        $script:Failures++
    }
}

function New-Fixture {
    # A throwaway directory under $env:TEMP. Tracked so the tail can prove it is gone.
    param([Parameter(Mandatory)] [string]$Name)
    $path = Join-Path -Path $env:TEMP -ChildPath "hook-pre-tool-$PID-$Name"
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    $script:Fixtures.Add($path)
    return $path
}

function New-EventFile {
    # One PreToolUse event as Claude Code would send it: tool_name, tool_input, cwd.
    param(
        [Parameter(Mandatory)] [string]$Dir,
        [Parameter(Mandatory)] [string]$ToolName,
        [Parameter()] [string]$Cwd = ''
    )
    $payload = [ordered]@{
        session_id      = 'hook-suite'
        hook_event_name = 'PreToolUse'
        tool_name       = $ToolName
        tool_input      = [ordered]@{ command = 'git status' }
    }
    if ($Cwd) { $payload['cwd'] = $Cwd }
    $file = Join-Path -Path $Dir -ChildPath "event-$ToolName.json"
    [System.IO.File]::WriteAllText($file, ($payload | ConvertTo-Json -Depth 5 -Compress),
        [System.Text.UTF8Encoding]::new($false))
    return $file
}

function Invoke-Hook {
    <#
    .SYNOPSIS
        Run the hook in a child pwsh and return its decision, both streams and exit code.

    .DESCRIPTION
        stdout and stderr go to separate files so a check can assert on a warning without
        the decision JSON in the way. The child gets its own environment, so an armed run
        cannot leak into the next check.
    #>
    param(
        [Parameter()] [string]$FixtureStdinPath,
        [Parameter()] [string]$ProjectPath,
        [Parameter()] [string]$StdinText,
        [Parameter()] [switch]$Arm,
        [Parameter()] [string]$InspectorOverride,
        # Delete LEDGER_HOOK_ARM from the child rather than setting it to '0'. Absent and
        # '0' are supposed to mean the same thing, and only a child with no such variable
        # at all can prove it.
        [Parameter()] [switch]$NoArmVar
    )

    $work    = Join-Path -Path $env:TEMP -ChildPath "hook-pre-tool-$PID-io"
    if (-not (Test-Path -LiteralPath $work)) {
        New-Item -ItemType Directory -Path $work -Force | Out-Null
        $script:Fixtures.Add($work)
    }
    $outFile = Join-Path -Path $work -ChildPath 'out.txt'
    $errFile = Join-Path -Path $work -ChildPath 'err.txt'

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName               = (Get-Process -Id $PID).Path
    $psi.UseShellExecute        = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.RedirectStandardInput  = $true
    $psi.WorkingDirectory       = $repo

    foreach ($a in @('-NoProfile', '-File', $hook)) { $psi.ArgumentList.Add($a) }
    if ($FixtureStdinPath) { $psi.ArgumentList.Add('-FixtureStdinPath'); $psi.ArgumentList.Add($FixtureStdinPath) }
    if ($ProjectPath)      { $psi.ArgumentList.Add('-ProjectPath');      $psi.ArgumentList.Add($ProjectPath) }

    # The child's environment is explicit: arm only when asked, and never inherit an
    # override from whatever ran the suite.
    if ($NoArmVar) {
        [void]$psi.Environment.Remove('LEDGER_HOOK_ARM')
    } else {
        $psi.Environment['LEDGER_HOOK_ARM'] = if ($Arm) { '1' } else { '0' }
    }
    $psi.Environment['LEDGER_HOOK_INSPECTOR'] = if ($InspectorOverride) { $InspectorOverride } else { '' }

    $proc = [System.Diagnostics.Process]::Start($psi)
    if ($PSBoundParameters.ContainsKey('StdinText')) { $proc.StandardInput.Write($StdinText) }
    $proc.StandardInput.Close()
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    $exit = $proc.ExitCode
    $proc.Dispose()

    [System.IO.File]::WriteAllText($outFile, $stdout, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($errFile, $stderr, [System.Text.UTF8Encoding]::new($false))

    $decision = ''
    $reason   = ''
    $parsed   = $null
    try {
        $parsed = $stdout | ConvertFrom-Json -ErrorAction Stop
        $decision = [string]$parsed.hookSpecificOutput.permissionDecision
        $reason   = [string]$parsed.hookSpecificOutput.permissionDecisionReason
    } catch { }

    Write-Host "    -> exit=$exit decision=$(if($decision){$decision}else{'(unparsed)'})"
    if ($reason) { Write-Host "       reason: $reason" -ForegroundColor DarkGray }
    if ($stderr) { Write-Host "       stderr: $(($stderr -split "`n" | Where-Object { $_ }) -join ' | ')" -ForegroundColor DarkGray }

    return [pscustomobject]@{
        ExitCode = $exit
        Stdout   = $stdout
        Stderr   = $stderr
        Decision = $decision
        Reason   = $reason
        Parsed   = $parsed
    }
}

function Get-GitPorcelain {
    Push-Location -LiteralPath $repo
    try { return (@(git status --porcelain) | Sort-Object) -join "`n" }
    finally { Pop-Location }
}

if (-not (Test-Path -LiteralPath $hook -PathType Leaf)) {
    Write-Host "hook not found at $hook" -ForegroundColor Red
    exit 1
}

$gitBefore = Get-GitPorcelain

# ---------------------------------------------------------------- 1
Write-Section 'CHECK 1  the hook script is UTF-8, no BOM, LF'

$bytes = [System.IO.File]::ReadAllBytes($hook)
$hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
$crCount = @($bytes | Where-Object { $_ -eq 0x0D }).Count
Assert-That (-not $hasBom) 'no UTF-8 BOM' 'a BOM ahead of the decision JSON makes it unparseable'
Assert-That ($crCount -eq 0) 'LF line endings only' "found $crCount CR byte(s)"
$text = [System.IO.File]::ReadAllText($hook, [System.Text.UTF8Encoding]::new($false, $true))
Assert-That ($text -match '#Requires -Version 7\.4') 'declares #Requires -Version 7.4'
Assert-That ($text -match "\`$ErrorActionPreference = 'Stop'") "sets `$ErrorActionPreference = 'Stop'"
Assert-That ($text -match '\$PSNativeCommandUseErrorActionPreference = \$true') 'sets $PSNativeCommandUseErrorActionPreference'

# The import-law checks below are about what the hook *does*, so they read code only.
# The comment-based help names Get-PolicyRules and $env:USERPROFILE precisely to say it
# touches neither, and a grep over the whole file would fail on its own documentation.
$code = [regex]::Replace($text, '(?s)<#.*?#>', '')
$code = ($code -split "`n" | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Assert-That ($code -notmatch 'Get-PolicyRules') 'code never calls Get-PolicyRules directly (Inspector owns the parser)'
Assert-That ($code -notmatch 'Invoke-LedgerForce') 'code never calls Invoke-LedgerForce'
Assert-That ($code -notmatch 'Import-Module.*claude\.build\.policy') 'code never imports claude.build.policy'
Assert-That ($code -notmatch 'USERPROFILE') 'code writes nothing under $env:USERPROFILE'
Assert-That ($code -notmatch '__Code') 'hardcodes no absolute workspace path'
Assert-That ($code -notmatch '\bAdd-Content\b|\bSet-Content\b|\bOut-File\b|WriteAllText') 'code writes no files at all'

# ---------------------------------------------------------------- 2
Write-Section 'CHECK 2  a non-shell tool is allowed and never reaches Inspector'

$d2  = New-Fixture 'nonshell'
# Real law with halts sits right here: if Read were inspected, this would deny.
Set-Content -LiteralPath (Join-Path $d2 'AGENTS.md') -Value "# law`n`n- Do not run anything.`n" -NoNewline
$ev2 = New-EventFile -Dir $d2 -ToolName 'Read' -Cwd $d2
$r2  = Invoke-Hook -FixtureStdinPath $ev2 -ProjectPath $d2 -Arm
Assert-That ($r2.ExitCode -eq 0) 'exit 0' "exit=$($r2.ExitCode)"
Assert-That ($r2.Decision -eq 'allow') 'Read is allowed even with halt-weight law present' "decision=$($r2.Decision)"
Assert-That ($r2.Reason -match 'not a shell tool') 'the reason says shells only' $r2.Reason
Assert-That ([string]::IsNullOrWhiteSpace($r2.Stderr)) 'Inspector was never consulted (no warnings)' $r2.Stderr

# ---------------------------------------------------------------- 3
Write-Section 'CHECK 3  armed shell + do-not line + allow Bash(*) is denied'

$d3 = New-Fixture 'lawful'
Set-Content -LiteralPath (Join-Path $d3 'AGENTS.md') -Value "# fixture law`n`n- Do not import Ledger.`n" -NoNewline
New-Item -ItemType Directory -Path (Join-Path $d3 '.claude') -Force | Out-Null
Set-Content -LiteralPath (Join-Path $d3 '.claude' 'settings.json') `
    -Value '{"permissions":{"allow":["Bash(*)"]}}' -NoNewline
$ev3 = New-EventFile -Dir $d3 -ToolName 'Bash' -Cwd $d3
$r3  = Invoke-Hook -FixtureStdinPath $ev3 -ProjectPath $d3 -Arm
Assert-That ($r3.ExitCode -eq 0) 'exit 0 — deny travels in the JSON, not the exit code' "exit=$($r3.ExitCode)"
Assert-That ($r3.Decision -eq 'deny') 'a shell tool is denied' "decision=$($r3.Decision)"
Assert-That ($r3.Reason -match 'PolicyHaltCount \d+') 'the reason names PolicyHaltCount and a number' $r3.Reason
Assert-That ($r3.Reason -match 'policy halt:') 'the reason quotes the first finding' $r3.Reason
Assert-That ($r3.Reason.Length -le 400) 'the reason is bounded' "len=$($r3.Reason.Length)"
$evPwsh3 = New-EventFile -Dir $d3 -ToolName 'PowerShell' -Cwd $d3
$r3b = Invoke-Hook -FixtureStdinPath $evPwsh3 -ProjectPath $d3 -Arm
Assert-That ($r3b.Decision -eq 'deny') 'PowerShell is in the same shell family as Bash' "decision=$($r3b.Decision)"

# ---------------------------------------------------------------- 4
Write-Section 'CHECK 4  armed shell + prose AGENTS.md, no do-not, is allowed'

$d4 = New-Fixture 'permissive'
Set-Content -LiteralPath (Join-Path $d4 'AGENTS.md') `
    -Value "# a project with law and no prohibitions`n`nThis file is prose. It describes the build and asks for nothing.`n" -NoNewline
$ev4 = New-EventFile -Dir $d4 -ToolName 'Bash' -Cwd $d4
$r4  = Invoke-Hook -FixtureStdinPath $ev4 -ProjectPath $d4 -Arm
Assert-That ($r4.ExitCode -eq 0) 'exit 0' "exit=$($r4.ExitCode)"
Assert-That ($r4.Decision -eq 'allow') 'a permissive project allows shells' "decision=$($r4.Decision)"
Assert-That ($r4.Reason -match 'PolicyHaltCount 0') 'the reason says zero halts, not "no law"' $r4.Reason
Assert-That ($r4.Reason -notmatch 'no law sources') 'a project with law is not reported as lawless' $r4.Reason

# ---------------------------------------------------------------- 5
Write-Section 'CHECK 5  armed shell + no law files at all is allowed, loudly'

$d5  = New-Fixture 'lawless'
$ev5 = New-EventFile -Dir $d5 -ToolName 'Bash' -Cwd $d5
$r5  = Invoke-Hook -FixtureStdinPath $ev5 -ProjectPath $d5 -Arm
Assert-That ($r5.ExitCode -eq 0) 'exit 0' "exit=$($r5.ExitCode)"
Assert-That ($r5.Decision -eq 'allow') 'absent law is allow, not deny' "decision=$($r5.Decision)"
Assert-That ($r5.Stderr -match 'no law sources') 'stderr carries the no-law warning' $r5.Stderr
Assert-That ($r5.Reason -match 'no law sources') 'the reason says so too' $r5.Reason

# Regression: Inspector's own Write-Warning lands on stdout once stdout is redirected,
# which is exactly how Claude Code runs this hook. Left alone it sits in front of the
# decision object and the JSON will not parse — a deny that reads as a silent allow.
# This is the branch where Inspector warns, so it is the branch that proves stdout is clean.
Assert-That ($null -ne $r5.Parsed) 'stdout parsed as JSON' "stdout was: $($r5.Stdout)"
Assert-That (@($r5.Stdout -split "`n" | Where-Object { $_.Trim() }).Count -eq 1) `
    'stdout is the decision object and nothing else' "stdout was: $($r5.Stdout)"
Assert-That ($r5.Stdout -notmatch 'WARNING:') 'no PowerShell warning leaked onto stdout' $r5.Stdout
Assert-That ($r5.Stderr -match 'inspector:') "Inspector's warning was re-emitted on stderr" $r5.Stderr

# ---------------------------------------------------------------- 6
Write-Section 'CHECK 6  armed shell + unreachable Inspector fails open'

$d6      = New-Fixture 'noinspector'
Set-Content -LiteralPath (Join-Path $d6 'AGENTS.md') -Value "# law`n`n- Do not import Ledger.`n" -NoNewline
$ev6     = New-EventFile -Dir $d6 -ToolName 'Bash' -Cwd $d6
$missing = Join-Path -Path $d6 -ChildPath 'no-such-inspector.psd1'
$r6      = Invoke-Hook -FixtureStdinPath $ev6 -ProjectPath $d6 -Arm -InspectorOverride $missing
Assert-That ($r6.ExitCode -eq 0) 'exit 0' "exit=$($r6.ExitCode)"
Assert-That ($r6.Decision -eq 'allow') 'no observer means no opinion' "decision=$($r6.Decision)"
Assert-That ($r6.Stderr -match 'inspector not found') 'stderr says inspector not found' $r6.Stderr
Assert-That ($r6.Reason -match 'fail-open') 'the reason admits it failed open' $r6.Reason

# ---------------------------------------------------------------- 7
Write-Section 'CHECK 7  armed shell + malformed law is denied (PolicyBadSource)'

$d7 = New-Fixture 'badsource'
# A NUL byte is not text. claude.build.policy raises PolicyBadSource and Inspector
# lets it through unwrapped.
[System.IO.File]::WriteAllBytes((Join-Path $d7 'AGENTS.md'),
    [byte[]]@(0x23, 0x20, 0x6C, 0x61, 0x77, 0x00, 0x0A, 0x2D, 0x20, 0x44, 0x6F, 0x20, 0x6E, 0x6F, 0x74, 0x2E, 0x0A))
$ev7 = New-EventFile -Dir $d7 -ToolName 'Bash' -Cwd $d7
$r7  = Invoke-Hook -FixtureStdinPath $ev7 -ProjectPath $d7 -Arm
Assert-That ($r7.ExitCode -eq 0) 'exit 0' "exit=$($r7.ExitCode)"
Assert-That ($r7.Decision -eq 'deny') 'malformed law fails closed' "decision=$($r7.Decision)"
Assert-That ($r7.Reason -match 'PolicyBadSource') 'the reason names PolicyBadSource' $r7.Reason

# ---------------------------------------------------------------- 8
Write-Section 'CHECK 8  garbage stdin is allowed'

$d8 = New-Fixture 'garbage'
$g1 = Join-Path -Path $d8 -ChildPath 'garbage.json'
Set-Content -LiteralPath $g1 -Value 'this is not JSON {{{ "tool_name": ' -NoNewline
$r8 = Invoke-Hook -FixtureStdinPath $g1 -Arm
Assert-That ($r8.ExitCode -eq 0) 'exit 0' "exit=$($r8.ExitCode)"
Assert-That ($r8.Decision -eq 'allow') 'unreadable input is allow, never deny' "decision=$($r8.Decision)"
Assert-That ($r8.Stderr -match 'fail-open') 'stderr says it failed open' $r8.Stderr

$e8 = Join-Path -Path $d8 -ChildPath 'empty.json'
Set-Content -LiteralPath $e8 -Value '' -NoNewline
$r8b = Invoke-Hook -FixtureStdinPath $e8 -Arm
Assert-That ($r8b.Decision -eq 'allow') 'an empty event is allow' "decision=$($r8b.Decision)"

# A JSON array is valid JSON and is not an event object.
$a8 = Join-Path -Path $d8 -ChildPath 'array.json'
Set-Content -LiteralPath $a8 -Value '[1,2,3]' -NoNewline
$r8c = Invoke-Hook -FixtureStdinPath $a8 -Arm
Assert-That ($r8c.Decision -eq 'allow') 'a JSON array is not an event, and is allow' "decision=$($r8c.Decision)"

# ---------------------------------------------------------------- 9
Write-Section 'CHECK 9  disarmed is inert on the very project that denies'

$r9 = Invoke-Hook -FixtureStdinPath $ev3 -ProjectPath $d3
Assert-That ($r9.ExitCode -eq 0) 'exit 0' "exit=$($r9.ExitCode)"
Assert-That ($r9.Decision -eq 'allow') 'the same fixture that denied in check 3 is allowed disarmed' "decision=$($r9.Decision)"
Assert-That ($r9.Reason -match 'disarmed') 'the reason says disarmed' $r9.Reason
Assert-That ([string]::IsNullOrWhiteSpace($r9.Stderr)) 'disarmed never consults Inspector' $r9.Stderr

# ---------------------------------------------------------------- 10
Write-Section 'CHECK 10  the event also arrives on stdin, the way Claude Code sends it'

$json10 = [System.IO.File]::ReadAllText($ev3, [System.Text.UTF8Encoding]::new($false, $true))
$r10 = Invoke-Hook -StdinText $json10 -ProjectPath $d3 -Arm
Assert-That ($r10.ExitCode -eq 0) 'exit 0' "exit=$($r10.ExitCode)"
Assert-That ($r10.Decision -eq 'deny') 'a piped event denies exactly as the fixture does' "decision=$($r10.Decision)"

# No stdin and no fixture: there is no tty, so it must not block and must not crash.
$r10b = Invoke-Hook -StdinText '' -Arm
Assert-That ($r10b.ExitCode -eq 0) 'empty stdin exits 0 rather than blocking' "exit=$($r10b.ExitCode)"
Assert-That ($r10b.Decision -eq 'allow') 'empty stdin is allow' "decision=$($r10b.Decision)"

# ---------------------------------------------------------------- 11
Write-Section "CHECK 11  with no -ProjectPath, the event's own cwd is what gets inspected"

# Every check above hands the hook a -ProjectPath, which is a switch Claude Code never
# passes. In production the target comes from the event's cwd, so that path needs its own
# test: the suite's own plumbing must not be the only reason a deny lands.

# 11a: the halt fixture from check 3, named only by the event's cwd. Same deny.
$r11 = Invoke-Hook -FixtureStdinPath $ev3 -Arm
Assert-That ($r11.ExitCode -eq 0) 'exit 0' "exit=$($r11.ExitCode)"
Assert-That ($r11.Decision -eq 'deny') `
    "the event's cwd alone is enough to deny, with no -ProjectPath" "decision=$($r11.Decision)"
Assert-That ($r11.Reason -match [regex]::Escape($d3)) `
    'and the reason names the directory the event pointed at' $r11.Reason

# 11b: a subdirectory of that same project, with no law files of its own.
#
# This documents what the hook does today, and today it does NOT walk up to the parent.
# Inspector is pointed at the cwd it is given, the subdirectory has no AGENTS.md, and the
# answer is allow + "no law sources" — even though the project directly above it denies.
# A shell tool run from a subdirectory of a halting project is therefore allowed.
#
# That is a real gap and it is left alone deliberately: parent-walking is a change to what
# "the project" means, and it belongs to whoever owns the walk, not to a hook test. Pinning
# the current behaviour here means the day someone implements the walk, this check fails
# and has to be rewritten on purpose rather than drifting.
$sub11 = Join-Path -Path $d3 -ChildPath 'src'
New-Item -ItemType Directory -Path $sub11 -Force | Out-Null
$ev11b = New-EventFile -Dir $d3 -ToolName 'Bash' -Cwd $sub11
$r11b  = Invoke-Hook -FixtureStdinPath $ev11b -Arm
Assert-That ($r11b.ExitCode -eq 0) 'exit 0' "exit=$($r11b.ExitCode)"
Assert-That ($r11b.Decision -eq 'allow') `
    'documented: a subdirectory with no law of its own is allowed, parent law and all' `
    "decision=$($r11b.Decision)"
Assert-That ($r11b.Reason -match 'no law sources') `
    'and the reason is no-law-sources, not a clean bill of health' $r11b.Reason
Assert-That ($r11b.Stderr -match 'no law sources') `
    'the gap is at least loud on stderr' $r11b.Stderr

# 11c: the arm variable absent entirely, not set to '0'. Same fixture that denies in 11a.
$r11c = Invoke-Hook -FixtureStdinPath $ev3 -NoArmVar
Assert-That ($r11c.ExitCode -eq 0) 'exit 0' "exit=$($r11c.ExitCode)"
Assert-That ($r11c.Decision -eq 'allow') `
    'an absent LEDGER_HOOK_ARM is disarmed, exactly as LEDGER_HOOK_ARM=0 is' `
    "decision=$($r11c.Decision)"
Assert-That ($r11c.Reason -match 'disarmed') 'the reason says disarmed' $r11c.Reason
Assert-That ([string]::IsNullOrWhiteSpace($r11c.Stderr)) `
    'and Inspector was never consulted' $r11c.Stderr

# ---------------------------------------------------------------- 12
Write-Section 'CHECK 12  settings.json registers the hook on shells only, in exec form'

$cfgText = [System.IO.File]::ReadAllText($settings, [System.Text.UTF8Encoding]::new($false, $true))
$cfg     = $cfgText | ConvertFrom-Json
$preToolUse = @($cfg.hooks.PreToolUse)

function Get-HookWords {
    # Everything a hook entry would hand the OS: the program, then its arguments. The
    # entry may be exec form (command + args) or the older single shell string, and a
    # script name can live in either, so both are flattened before anything is matched.
    param($HookEntry)
    $words = @([string]$HookEntry.command)
    $argsProp = $HookEntry.PSObject.Properties['args']
    if ($argsProp) { $words += @($argsProp.Value | ForEach-Object { [string]$_ }) }
    return $words
}

function Test-RunsScript {
    param($HookEntry, [string]$Pattern)
    return [bool](@(Get-HookWords $HookEntry | Where-Object { $_ -match $Pattern }).Count)
}

$entries = @($preToolUse | Where-Object {
    @($_.hooks) | Where-Object { Test-RunsScript $_ 'pre-tool-use\.ps1' }
})
Assert-That ($entries.Count -eq 1) 'exactly one PreToolUse matcher runs pre-tool-use.ps1' "found $($entries.Count)"
if ($entries.Count -eq 1) {
    $matcher = [string]$entries[0].matcher
    Write-Host "    matcher: $matcher"
    Assert-That ($matcher -match 'Bash') 'the matcher covers Bash' $matcher
    Assert-That ($matcher -match 'PowerShell') 'the matcher covers PowerShell' $matcher
    Assert-That ($matcher -notmatch 'Read|Edit|Write|Glob|Grep|\*') 'the matcher attaches to no non-shell tool' $matcher

    # Exec form: the program and its arguments are separate fields, so nothing is handed
    # to a shell to re-parse. A single command string goes through a shell first, and a
    # project path with a space or an ampersand in it is then the shell's problem.
    # -NoProfile because a profile writes to stdout, and stdout is the decision object.
    $entry = @($entries[0].hooks | Where-Object { Test-RunsScript $_ 'pre-tool-use\.ps1' })[0]
    $words = Get-HookWords $entry
    Write-Host "    exec: $($words -join ' ')"
    Assert-That ([string]$entry.command -match '^pwsh(\.exe)?$') `
        'the hook entry execs pwsh directly, not a shell string' "command=$($entry.command)"
    Assert-That ($null -ne $entry.PSObject.Properties['args']) `
        'it passes its arguments in args, not welded into command'
    Assert-That ($words -ccontains '-NoProfile') `
        'the parsed settings contain -NoProfile' ($words -join ' ')
    Assert-That ($words -ccontains '-File') `
        'the parsed settings contain -File' ($words -join ' ')
    Assert-That ($null -eq $entry.PSObject.Properties['shell']) `
        'and no "shell" key survives on the entry' 'exec form does not go through one'
    Assert-That ([int]$entry.timeout -eq 15) 'timeout is still 15' "timeout=$($entry.timeout)"
}
foreach ($evt in @('SessionStart', 'UserPromptSubmit')) {
    $bound = @(@($cfg.hooks.$evt) | Where-Object {
        @($_.hooks) | Where-Object { Test-RunsScript $_ 'pre-tool-use\.ps1' }
    })
    Assert-That ($bound.Count -eq 0) "pre-tool-use.ps1 is not wired into $evt" "found $($bound.Count)"
}

# pre-session.ps1 appends to a log under $env:USERPROFILE. On PreToolUse that fired before
# every shell tool call — a write outside the repo, on a hot path, for a hook whose job is a
# session banner. It belongs on the two session events and nowhere else.
$preSessionPre = @($preToolUse | Where-Object {
    @($_.hooks) | Where-Object { Test-RunsScript $_ 'pre-session\.ps1' }
})
Assert-That ($preSessionPre.Count -eq 0) `
    'pre-session.ps1 is NOT on PreToolUse' "found $($preSessionPre.Count)"
foreach ($evt in @('SessionStart', 'UserPromptSubmit')) {
    $kept = @(@($cfg.hooks.$evt) | Where-Object {
        @($_.hooks) | Where-Object { Test-RunsScript $_ 'pre-session\.ps1' }
    })
    Assert-That ($kept.Count -ge 1) "pre-session.ps1 is still registered on $evt" "found $($kept.Count)"
}

# ---------------------------------------------------------------- 13
Write-Section 'CHECK 13  the suite left no trace'

foreach ($f in $script:Fixtures) {
    if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Recurse -Force }
}
$leftovers = @($script:Fixtures | Where-Object { Test-Path -LiteralPath $_ })
Assert-That ($leftovers.Count -eq 0) "cleaned $($script:Fixtures.Count) fixture(s) under `$env:TEMP" ($leftovers -join ', ')

$gitAfter = Get-GitPorcelain
Assert-That ($gitAfter -eq $gitBefore) 'git sees exactly what it saw before the suite ran' `
    "before:`n$gitBefore`nafter:`n$gitAfter"

$homeHook = Join-Path -Path $env:USERPROFILE -ChildPath '.claude' -AdditionalChildPath 'hooks'
$stamp = if (Test-Path -LiteralPath $homeHook) {
    (Get-ChildItem -LiteralPath $homeHook -File | Measure-Object -Property Length -Sum).Sum
} else { 'absent' }
Write-Host "  note: `$env:USERPROFILE\.claude\hooks total bytes = $stamp (pre-session.ps1's log; this hook adds nothing)"

# ---------------------------------------------------------------- tail
Write-Host ''
Write-Host "checks run: $($script:Checks)"
if ($script:Failures -eq 0) {
    Write-Host 'ALL CHECKS PASSED' -ForegroundColor Green
    exit 0
}
Write-Host "$($script:Failures) of $($script:Checks) CHECK(S) FAILED" -ForegroundColor Red
exit 1

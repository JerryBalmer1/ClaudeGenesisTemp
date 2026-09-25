#Requires -Version 7.4
<#
.SYNOPSIS
    PreToolUse hook v0 — deny a shell tool call when this project's own law carries
    halt-weight rules.

.DESCRIPTION
    Run by Claude Code, not by hand:

        pwsh -NoProfile -File .claude/hooks/pre-tool-use.ps1

    Claude Code pipes one PreToolUse event as JSON on stdin. This script prints one
    decision object on stdout and exits 0 — always 0. A non-zero exit is fail-open for
    Claude Code and must never be how this hook denies.

        CLAUDE tool call -> PreToolUse hook -> Invoke-ClaudeInspector -Policy -> allow | deny

    Invoke-LedgerForce -Halt already kills a force. It cannot touch a running agent.
    This closes that gap for shell tools only.

    Frozen v0 behaviour:

      tool is not a shell .................. allow, Inspector never runs
      hook is disarmed ..................... allow, Inspector never runs
      Inspector not reachable .............. allow + stderr warning   (fail-open)
      PolicySourceCount = 0 ................ allow + stderr warning   (absent law is loud, not fatal)
      PolicyHaltCount = 0 .................. allow                    (permissive project)
      PolicyHaltCount > 0 .................. DENY
      PolicyBadSource ...................... DENY                     (malformed law is fail-closed)
      any other Inspector error ............ allow + stderr warning   (fail-open)
      stdin missing or not JSON ............ allow + stderr warning   (fail-open)

    Read, Edit, Write, Glob and Grep are never denied. v0 is shells only.

    This hook writes no receipt, spawns no Python, never calls Invoke-LedgerForce, and
    never calls Get-PolicyRules directly — Inspector owns the parser, exactly as Ledger
    does it. It writes no files anywhere, and in particular nothing under $env:USERPROFILE.

.PARAMETER FixtureStdinPath
    Read the event from this file instead of stdin. For tests/sandbox/hook_pre_tool.ps1 only.

.PARAMETER ProjectPath
    Inspect this directory instead of the one the event names. For the suite only.

.NOTES
    Two environment variables, both for operators and the suite:

      LEDGER_HOOK_ARM        '1' arms the hook. Anything else and every decision is allow
                             before Inspector is ever consulted. This repo self-inspects at
                             22 halts, so an unconditionally armed hook would deny every
                             shell call in its own tree, including the ones that run the
                             suites. Disarmed is the shipped default; the suite arms it.

      LEDGER_HOOK_INSPECTOR  Override the Inspector manifest path. The suite points it at a
                             file that does not exist to prove the fail-open branch.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$FixtureStdinPath,

    [Parameter()]
    [string]$ProjectPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

# Claude Code reads stdout as UTF-8. Emit no BOM: a BOM in front of the JSON makes the
# decision unparseable, and an unparseable decision is a silent fail-open.
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch { }

# The tool names this hook treats as a shell. Same family Inspector already matches.
$script:ShellTools = @('Bash', 'bash', 'PowerShell', 'powershell', 'Shell', 'shell')

# .claude/hooks/ -> .claude/ -> repo root -> the directory the sibling repos live in.
$script:HookRepo = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent

function Get-HookProp {
    <#
    .SYNOPSIS
        StrictMode-safe property read off a ConvertFrom-Json object. A property that is
        not there is the default, not a terminating error.
    #>
    param(
        [Parameter(Mandatory)] [AllowNull()] [object]$InputObject,
        [Parameter(Mandatory)] [string]$Name,
        [Parameter()] [AllowNull()] [object]$Default = $null
    )
    if ($null -eq $InputObject) { return $Default }
    $prop = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $prop -or $null -eq $prop.Value) { return $Default }
    return $prop.Value
}

function Write-HookDecision {
    <#
    .SYNOPSIS
        Print the one decision object and leave. Exit code is 0 for allow and for deny;
        the verdict travels in the JSON, never in the exit status.
    #>
    param(
        [Parameter(Mandatory)] [ValidateSet('allow', 'deny')] [string]$Decision,
        [Parameter(Mandatory)] [string]$Reason
    )

    # Trim to something a permission dialog can show without wrapping off the screen.
    $clean = ($Reason -replace '\s+', ' ').Trim()
    if ($clean.Length -gt 400) { $clean = $clean.Substring(0, 397) + '...' }

    $payload = [pscustomobject]@{
        hookSpecificOutput = [pscustomobject]@{
            hookEventName            = 'PreToolUse'
            permissionDecision       = $Decision
            permissionDecisionReason = $clean
        }
    }
    [Console]::Out.Write(($payload | ConvertTo-Json -Depth 5 -Compress))
    [Console]::Out.Write("`n")
    [Console]::Out.Flush()
    exit 0
}

function Resolve-HookInspector {
    <#
    .SYNOPSIS
        Find the optional claude.build.inspector module. Returns the command, or $null.

    .DESCRIPTION
        The same lazy sibling walk Ledger uses in Resolve-LedgerInspector: an already
        loaded Invoke-ClaudeInspector wins, then the manifest next door. Nothing here
        throws. A missing Inspector is not an error — the caller allows and says so.
    #>
    param()

    $cmd = Get-Command -Name 'Invoke-ClaudeInspector' -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($cmd) { return $cmd }

    $manifest = if ($env:LEDGER_HOOK_INSPECTOR) {
        $env:LEDGER_HOOK_INSPECTOR
    } else {
        [System.IO.Path]::GetFullPath(
            (Join-Path -Path $script:HookRepo -ChildPath '..' `
                -AdditionalChildPath 'claude.build.inspector', 'src', 'claude.build.inspector', 'claude.build.inspector.psd1'))
    }

    if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) { return $null }

    # Silence every stream but errors. Claude Code parses stdout, and with stdout
    # redirected PowerShell routes the warning and verbose streams into it - an import
    # that says anything at all would sit in front of the decision JSON and make it
    # unparseable, which reads as a silent fail-open.
    try { Import-Module -Name $manifest -ErrorAction Stop -Verbose:$false -WarningAction SilentlyContinue }
    catch { return $null }

    return (Get-Command -Name 'Invoke-ClaudeInspector' -ErrorAction SilentlyContinue |
        Select-Object -First 1)
}

# ----------------------------------------------------------------------------------
# Everything below fails open. An unhandled fault in a PreToolUse hook would wedge the
# IDE, so the outer catch allows and explains itself on stderr. Deny is only ever
# reached deliberately, and Write-HookDecision exits before this catch can see it.
# ----------------------------------------------------------------------------------
try {
    # -- read the event ------------------------------------------------------------
    $raw = ''
    if ($FixtureStdinPath) {
        $raw = [System.IO.File]::ReadAllText($FixtureStdinPath, [System.Text.UTF8Encoding]::new($false, $false))
    }
    elseif ([Console]::IsInputRedirected) {
        $raw = [Console]::In.ReadToEnd()
    }
    # No redirected stdin and no fixture: there is no tty to block on. $raw stays empty
    # and falls through to the fail-open below.

    $hookEvent = $null
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
        try { $hookEvent = $raw | ConvertFrom-Json -ErrorAction Stop } catch { $hookEvent = $null }
    }

    if ($null -eq $hookEvent -or $hookEvent -isnot [pscustomobject]) {
        [Console]::Error.WriteLine('hook: hook input was missing or not a JSON object; fail-open')
        Write-HookDecision -Decision 'allow' -Reason 'hook: unreadable hook input; fail-open'
    }

    # -- shells only ---------------------------------------------------------------
    $toolName = [string](Get-HookProp $hookEvent 'tool_name' '')
    if ($toolName -notin $script:ShellTools) {
        $shown = if ($toolName) { $toolName } else { '(unnamed)' }
        Write-HookDecision -Decision 'allow' -Reason "hook: $shown is not a shell tool; v0 inspects shells only"
    }

    # -- armed? --------------------------------------------------------------------
    if ($env:LEDGER_HOOK_ARM -ne '1') {
        Write-HookDecision -Decision 'allow' -Reason 'hook: disarmed; set LEDGER_HOOK_ARM=1 to enforce'
    }

    # -- what to inspect -----------------------------------------------------------
    # The caller's explicit path wins, then the cwd the event names, then the project
    # dir Claude Code exports, then the repo this hook lives in.
    $target = $ProjectPath
    if (-not $target) { $target = [string](Get-HookProp $hookEvent 'cwd' '') }
    if (-not $target) { $target = [string]$env:CLAUDE_PROJECT_DIR }
    if (-not $target) { $target = $script:HookRepo }

    # -- the observer --------------------------------------------------------------
    $inspector = Resolve-HookInspector
    if ($null -eq $inspector) {
        [Console]::Error.WriteLine('hook: inspector not found; fail-open')
        Write-HookDecision -Decision 'allow' -Reason 'hook: inspector not found; fail-open'
    }

    try {
        # Inspector is loud about a law-free project, and rightly so - but its warning
        # stream lands on stdout once stdout is redirected, which is how Claude Code runs
        # this hook. Capture it and re-emit on stderr: stdout carries the decision object
        # and nothing else.
        $invWarn = $null
        $report = @(& $inspector -Path $target -Policy -WarningVariable invWarn -WarningAction SilentlyContinue |
            Where-Object { $_.Scope -eq 'Project' }) | Select-Object -First 1
        foreach ($w in @($invWarn)) {
            if ($w) { [Console]::Error.WriteLine("hook: inspector: $w") }
        }
    }
    catch {
        # Malformed law is the one error worth failing closed on. A project whose AGENTS.md
        # cannot be read has law nobody can evaluate, and silently allowing there is how a
        # broken source becomes a bypass.
        if ($_.FullyQualifiedErrorId -like 'PolicyBadSource*') {
            Write-HookDecision -Decision 'deny' -Reason "hook: PolicyBadSource for $target - $($_.Exception.Message)"
        }
        # Anything else is fail-open. A hook bug must not brick the IDE.
        $id = $_.FullyQualifiedErrorId
        [Console]::Error.WriteLine("hook: inspector error $id; fail-open")
        Write-HookDecision -Decision 'allow' -Reason "hook: inspector error $id; fail-open"
    }

    if ($null -eq $report) {
        [Console]::Error.WriteLine('hook: inspector returned no Project report; fail-open')
        Write-HookDecision -Decision 'allow' -Reason 'hook: inspector returned no Project report; fail-open'
    }

    # Read defensively. Inspector is resolved from disk at call time, so the one next door
    # may predate PolicySourceCount; under StrictMode a direct read of a missing property
    # is terminating, and that would be a fail-open on a version skew.
    $sources = [int](Get-HookProp $report 'PolicySourceCount' 0)
    $halts   = [int](Get-HookProp $report 'PolicyHaltCount' 0)

    # Absent law reports exactly as a lawful, permissive project does: evaluated, zero
    # rules, zero halts. Only the source count tells them apart, so say it out loud
    # rather than record a clean bill of health nobody earned.
    if ($sources -eq 0) {
        [Console]::Error.WriteLine("hook: no law sources under $target; nothing can deny")
        Write-HookDecision -Decision 'allow' -Reason "hook: no law sources under $target; nothing can deny"
    }

    if ($halts -gt 0) {
        $first = ''
        foreach ($finding in @(Get-HookProp $report 'Findings' @())) {
            if ([string]$finding -like 'policy halt:*') { $first = [string]$finding; break }
        }
        if (-not $first) { $first = '(no finding string)' }
        $first = ($first -replace '\s+', ' ').Trim()
        if ($first.Length -gt 200) { $first = $first.Substring(0, 197) + '...' }
        Write-HookDecision -Decision 'deny' -Reason "hook: PolicyHaltCount $halts for $target; first: $first"
    }

    Write-HookDecision -Decision 'allow' -Reason "hook: PolicyHaltCount 0 over $sources law source(s); permissive project"
}
catch {
    [Console]::Error.WriteLine("hook: unhandled $($_.FullyQualifiedErrorId); fail-open")
    try {
        [Console]::Out.Write('{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"hook: unhandled error; fail-open"}}' + "`n")
        [Console]::Out.Flush()
    } catch { }
    exit 0
}

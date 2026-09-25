# .claude/hooks/pre-session.ps1
# SessionStart hook — runs a PowerShell script before Claude does anything.
# Docs: https://code.claude.com/docs/en/hooks#sessionstart
#        https://code.claude.com/docs/en/hooks#windows-powershell-tool
#
# This fires on SessionStart (and optionally UserPromptSubmit). It receives JSON on
# stdin with session_id, cwd, etc. Print to stdout to inject context into Claude.
# Exit non-zero to block the session (rare — usually you just log and continue).

param(
    [string]$HookInput = $null
)

# Read JSON from stdin if not passed as param (Claude Code pipes it)
if (-not $HookInput) {
    $HookInput = [Console]::In.ReadToEnd()
}

try {
    $data = $HookInput | ConvertFrom-Json -ErrorAction Stop
    $sessionId = $data.session_id
    $cwd = $data.cwd
} catch {
    $sessionId = 'unknown'
    $cwd = (Get-Location).Path
}

$logPath = Join-Path $env:USERPROFILE '.claude' 'hooks' 'session-start.log'
$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
"[$timestamp] SessionStart session=$sessionId cwd=$cwd" | Add-Content -Path $logPath -ErrorAction SilentlyContinue

# Optional: inject a reminder into Claude's context
Write-Output "Reminder: PowerShell 7.4+ required. Use `$PSNativeCommandUseErrorActionPreference = `$true."

exit 0

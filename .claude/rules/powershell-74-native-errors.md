# PowerShell 7.4+ Native Command Error Handling

## The Variable That Matters
`$PSNativeCommandUseErrorActionPreference` — set this to `$true`.

Without it, Python (or any native command) returning a non-zero exit code just sets `$LASTEXITCODE` and moves on. With it, PowerShell emits a real error that respects `$ErrorActionPreference`.

## Required Pattern
```powershell
# At the top of every script/module
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

# Call Python
python script.py
# If it fails, this now throws a NativeCommandExitException that can be caught
```

## Capturing and Converting Errors
```powershell
try {
    python -c "import sys; sys.exit(1)"
} catch {
    Write-Error "Python failed: $($_.Exception.Message)"
    # Convert to a proper ErrorRecord if needed
}
```

## Verbose and Debug
- Use `Write-Verbose` for normal operation details.
- Use `Write-Debug` for deep internals.
- Always test with `-Verbose` and `-Debug` to ensure output is visible.
- The user wants to SEE the PowerShell function running and the Python errors being captured on screen.

## Manifest Requirement
In `Ledger.psd1`, set:
```powershell
PowerShellVersion = '7.4'
```

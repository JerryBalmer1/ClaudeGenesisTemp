# clause: B4.3
# P-21: Receive reports every extra, missing, and mismatched file together, ignores .git/ and report/,
# and writes nothing.

BeforeAll {
    $root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $target = Join-Path $TestDrive 'target'
    $null = New-Item -ItemType Directory -Path $target

    function Get-Sha([byte[]]$bytes) { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant() }
    function Set-Text([string]$rel, [string]$text) {
        $path = Join-Path $target $rel
        $null = New-Item -ItemType Directory -Path (Split-Path $path) -Force
        [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))
    }
    function Get-Snapshot {
        Get-ChildItem -LiteralPath $target -Recurse -File -Force | Sort-Object FullName | ForEach-Object {
            "$([IO.Path]::GetRelativePath($target, $_.FullName)) $(Get-Sha ([IO.File]::ReadAllBytes($_.FullName)))"
        }
    }

    Copy-Item -LiteralPath (Join-Path $root 'Genesis.build.ps1') -Destination $target
    Copy-Item -LiteralPath (Join-Path $root 'tools.lock.json') -Destination $target
    Set-Text 'kept.txt' 'kept'
    Set-Text 'changed.txt' 'actual bytes'
    Set-Text 'surplus.txt' 'not in the manifest'
    Set-Text 'report/sentinel-report.md' 'the target grade survives the gut'
    Set-Text '.git/sentinel-git.txt' 'git internals are not payload'

    $files = @(
        foreach ($rel in 'Genesis.build.ps1', 'tools.lock.json', 'kept.txt') {
            [ordered]@{ path = $rel; sha256 = Get-Sha ([IO.File]::ReadAllBytes((Join-Path $target $rel))) }
        }
        [ordered]@{ path = 'changed.txt'; sha256 = Get-Sha ([Text.Encoding]::UTF8.GetBytes('expected bytes')) }
        [ordered]@{ path = 'absent.txt'; sha256 = Get-Sha ([Text.Encoding]::UTF8.GetBytes('never written')) }
        [ordered]@{ path = 'payload.manifest.json'; sha256 = '' }
    ) | Sort-Object { $_.path }
    $manifest = [ordered]@{ genesis_version = '0.1.0'; source_commit = ('0' * 40); files = $files }
    Set-Text 'payload.manifest.json' (ConvertTo-Json -InputObject $manifest -Depth 4)

    # The target runs its own build in its own process; nothing here shares the caller's build state.
    $invokeBuild = Join-Path (Get-Module -Name InvokeBuild).ModuleBase 'InvokeBuild.psd1'
    $command = "`$ErrorActionPreference = 'Stop'; Import-Module -Name '$invokeBuild'; Invoke-Build -Task Receive -File '$(Join-Path $target 'Genesis.build.ps1')'"

    $before = Get-Snapshot
    $PSNativeCommandUseErrorActionPreference = $false
    $output = pwsh -NoProfile -Command $command 2>&1 | Out-String
    $threw = $LASTEXITCODE -ne 0
    $after = Get-Snapshot
}

Describe 'P-21' {
    It 'Receive fails on a defective target' {
        $threw | Should -BeTrue
    }

    It 'reports the extra file' {
        $output | Should -Match '(?im)^.*\bextra\b.*surplus\.txt'
    }

    It 'reports the missing file' {
        $output | Should -Match '(?im)^.*\bmissing\b.*absent\.txt'
    }

    It 'reports the mismatched file' {
        $output | Should -Match '(?im)^.*\bmismatch\w*\b.*changed\.txt'
    }

    It 'does not report .git/ or report/' {
        $output | Should -Not -Match 'sentinel-(git|report)'
    }

    It 'writes nothing' {
        ($after -join "`n") | Should -BeExactly ($before -join "`n")
    }
}

# clause: B2.1
# P-13: every package the bootstrap imports is pinned; every pins entry names an existing file with a
# matching hash; Private/Jcs.ps1 and Private/GpgArgv.ps1, once present, are pinned.

BeforeAll {
    $root = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $lock = Get-Content -LiteralPath (Join-Path $root 'tools.lock.json') -Raw | ConvertFrom-Json -AsHashtable
    $packages = @($lock.Keys | Where-Object { $lock[$_] -is [hashtable] -and $lock[$_].ContainsKey('Sha256') })
}

Describe 'P-13' {
    It 'pins <_> with a version and a sha256' -ForEach @('InvokeBuild', 'Pester', 'PSScriptAnalyzer') {
        $lock[$_].Version | Should -Match '^\d+\.\d+\.\d+$'
        $lock[$_].Sha256 | Should -Match '^[0-9a-f]{64}$'
    }

    It 'declares gpg and pwsh minimums, a heaven timeout, and pins' {
        $lock.gpg.MinVersion | Should -Be '2.4'
        $lock.pwsh.MinVersion | Should -Be '7.4'
        $lock.heaven.TimeoutSeconds | Should -BeGreaterThan 0
        $lock.ContainsKey('pins') | Should -BeTrue
        $lock.pins | Should -BeOfType ([hashtable])
    }

    It 'the bootstrap imports no module by a name outside the lock' {
        $names = foreach ($file in 'build.ps1', 'Genesis.build.ps1') {
            $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $root $file), [ref]$null, [ref]$null)
            $ast.FindAll({ param($n) $n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Import-Module' }, $true) |
                ForEach-Object { $_.CommandElements | Select-Object -Skip 1 } |
                Where-Object { $_ -is [Management.Automation.Language.StringConstantExpressionAst] } |
                ForEach-Object Value
        }
        @($names | Where-Object { $_ -notin $packages }) | Should -BeNullOrEmpty
    }

    It 'every pins entry names an existing file with a matching hash' {
        $bad = foreach ($key in $lock.pins.Keys) {
            $path = Join-Path $root $key
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { "$key missing"; continue }
            $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($hash -ne $lock.pins[$key]) { "$key sha256 $hash" }
        }
        $bad | Should -BeNullOrEmpty
    }

    It '<_>, once present, is pinned' -ForEach @('src/Genesis/Private/Jcs.ps1', 'src/Genesis/Private/GpgArgv.ps1') {
        if (Test-Path -LiteralPath (Join-Path $root $_)) {
            $lock.pins.Keys | Should -Contain $_
        }
    }
}

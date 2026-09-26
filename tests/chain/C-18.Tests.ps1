# status: red
# spec: S4.2, S5.2
# C-18: Private/Jcs.ps1 and Private/GpgArgv.ps1 exist, are pinned in tools.lock.json, and hash to the pin.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Harness.ps1')
    $lock = Get-Content -LiteralPath (Join-Path $HarnessRoot 'tools.lock.json') -Raw | ConvertFrom-Json -AsHashtable
}

Describe 'C-18' {
    It '<_> exists' -ForEach @('src/Genesis/Private/Jcs.ps1', 'src/Genesis/Private/GpgArgv.ps1') {
        Test-Path -LiteralPath (Join-Path $HarnessRoot $_) -PathType Leaf | Should -BeTrue
    }

    It '<_> is pinned' -ForEach @('src/Genesis/Private/Jcs.ps1', 'src/Genesis/Private/GpgArgv.ps1') {
        $lock.pins.Keys | Should -Contain $_
    }

    It '<_> hashes to its pin' -ForEach @('src/Genesis/Private/Jcs.ps1', 'src/Genesis/Private/GpgArgv.ps1') {
        $path = Join-Path $HarnessRoot $_
        $actual = if (Test-Path -LiteralPath $path) { Get-HarnessSha ([IO.File]::ReadAllBytes($path)) }
        $actual | Should -Not -BeNullOrEmpty
        $actual | Should -BeExactly $lock.pins[$_]
    }
}

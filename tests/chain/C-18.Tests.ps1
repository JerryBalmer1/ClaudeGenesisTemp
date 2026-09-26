# status: red
# spec: S4.2, S5.2
# C-18: Jcs.ps1 and GpgArgv.ps1 hashes != tools.lock.json pins -> red.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Helpers.ps1')
    $lock = Get-Content -LiteralPath (Join-Path $ChainRoot 'tools.lock.json') -Raw | ConvertFrom-Json -AsHashtable
}

Describe 'C-18' {
    It '<_> exists' -ForEach @('src/Genesis/Private/Jcs.ps1', 'src/Genesis/Private/GpgArgv.ps1') {
        Test-Path -LiteralPath (Join-Path $ChainRoot $_) -PathType Leaf | Should -BeTrue
    }

    It '<_> is pinned in tools.lock.json' -ForEach @('src/Genesis/Private/Jcs.ps1', 'src/Genesis/Private/GpgArgv.ps1') {
        $lock.pins.Keys | Should -Contain $_
    }

    It '<_> hashes to its pin' -ForEach @('src/Genesis/Private/Jcs.ps1', 'src/Genesis/Private/GpgArgv.ps1') {
        $actual = Get-ChainSha256 ([IO.File]::ReadAllBytes((Join-Path $ChainRoot $_)))
        $actual | Should -BeExactly $lock.pins[$_]
    }
}

# status: red
# spec: S13, S7.8
# C-08: the temptation module (M-01 fixture), loaded by explicit path from tests/fixtures/temptation/,
# verifies a genesis-flipped tree clean. The runner's MUTANTS_SURVIVED line belongs to the Heaven runner (S14),
# which exposes no single-mutant entry point; this file asserts the verdict the runner reports.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Helpers.ps1')
}

Describe 'C-08' {
    BeforeAll {
        $run = $null
        $fixtureDir = Join-Path $ChainRoot 'tests/fixtures/temptation'
        $fixture = @(Get-ChildItem -LiteralPath $fixtureDir -Filter '*.psd1' -File -ErrorAction Ignore)
        $run = New-ChainRun
        $tree = New-ChainTree $run 3
        Invoke-ChainSignatureFlip (Get-ChainReceiptPath $run $tree[0])
        $result = if ($fixture.Count -eq 1) { Invoke-Genesis -Run $run -Command 'Test-GenesisChain' -Module $fixture[0].FullName }
    }
    AfterAll { Remove-ChainRun $run }

    It 'the fixture is exactly one module manifest' {
        $fixture.Count | Should -Be 1
    }

    It 'the fixture is not discoverable on PSModulePath' {
        $paths = @($env:PSModulePath -split [IO.Path]::PathSeparator | Where-Object { $_ } | ForEach-Object { [IO.Path]::GetFullPath($_).TrimEnd('\', '/') })
        $paths | Should -Not -Contain ([IO.Path]::GetFullPath($fixtureDir).TrimEnd('\', '/'))
        $paths | Should -Not -Contain ([IO.Path]::GetFullPath((Split-Path -Parent $fixtureDir)).TrimEnd('\', '/'))
    }

    It 'the temptation verifier passes the genesis-flipped tree: the mutant survives it' {
        Assert-ChainExit $result OK
    }
}

# status: red
# spec: S12, S13, S7.2
# C-08: the temptation module (the M-01 fixture), loaded by explicit path from tests/fixtures/temptation/,
# verifies a genesis-flipped tree clean. That is the survival M-01 exists to show; the runner's
# MUTANTS_SURVIVED line belongs to the S14 runner and is asserted there, not here.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Harness.ps1')
    $temptation = Join-Path $HarnessRoot 'tests/fixtures/temptation/Genesis.psd1'
}

Describe 'C-08' {
    BeforeAll {
        $run = $null
        $run = New-HarnessRun
        $tree = New-HarnessTree $run 3
        Invoke-HarnessSignatureFlip (Get-HarnessReceiptPath $run $tree[0])
        $result = $null
        if (Test-Path -LiteralPath $temptation) {
            $result = Invoke-Genesis $run 'Test-GenesisChain' -Module $temptation
        }
    }
    AfterAll { Remove-HarnessRun $run }

    It 'the temptation module exists at its fixture path' {
        Test-Path -LiteralPath $temptation | Should -BeTrue
    }

    It 'the temptation verifier passes the genesis-flipped tree' {
        $result | Should -Not -BeNullOrEmpty
        Assert-HarnessExit $result OK
    }
}

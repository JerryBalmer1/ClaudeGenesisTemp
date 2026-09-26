# status: red
# spec: S12, S13, S7.2
# C-08b: the shipping Test-GenesisChain on the same genesis-flipped tree C-08 uses -> SIG_FAIL. The
# runner's MUTANTS_KILLED line belongs to the S14 runner and is asserted there, not here.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Harness.ps1')
    $temptation = Join-Path $HarnessRoot 'tests/fixtures/temptation/Genesis.psd1'
}

Describe 'C-08b' {
    BeforeAll {
        $run = $null
        $run = New-HarnessRun
        $tree = New-HarnessTree $run 3
        Invoke-HarnessSignatureFlip (Get-HarnessReceiptPath $run $tree[0])
        $result = Test-HarnessChain $run
    }
    AfterAll { Remove-HarnessRun $run }

    It 'the M-01 fixture is present to be killed' {
        Test-Path -LiteralPath $temptation | Should -BeTrue
    }

    It 'the shipping verifier rejects the flipped genesis' {
        Assert-HarnessExit $result SIG_FAIL
    }
}

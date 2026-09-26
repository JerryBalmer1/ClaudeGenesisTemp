# status: red
# spec: S7.2, S4.2, S4.4
# C-03b: raw byte flip inside the genesis signature value -> SIG_FAIL.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Harness.ps1')
}

Describe 'C-03b' {
    BeforeAll {
        $run = $null
        $run = New-HarnessRun
        $tree = New-HarnessTree $run 3
        $clean = Test-HarnessChain $run
        $target = Get-HarnessReceiptPath $run $tree[0]
        Invoke-HarnessSignatureFlip $target
        $result = Test-HarnessChain $run
    }
    AfterAll { Remove-HarnessRun $run }

    It 'the tree verifies before the flip' {
        Assert-HarnessExit $clean OK
    }

    It 'the flipped genesis signature is SIG_FAIL, filename unchanged' {
        Test-Path -LiteralPath $target | Should -BeTrue
        Assert-HarnessExit $result SIG_FAIL
    }
}

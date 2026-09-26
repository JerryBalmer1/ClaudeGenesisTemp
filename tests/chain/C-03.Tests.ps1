# status: red
# spec: S7.2, S4.2
# C-03: raw byte flip inside the position-1 signature value -> SIG_FAIL.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Harness.ps1')
}

Describe 'C-03' {
    BeforeAll {
        $run = $null
        $run = New-HarnessRun
        $tree = New-HarnessTree $run 3
        $clean = Test-HarnessChain $run
        $target = Get-HarnessReceiptPath $run $tree[1]
        Invoke-HarnessSignatureFlip $target
        $result = Test-HarnessChain $run
    }
    AfterAll { Remove-HarnessRun $run }

    It 'the tree verifies before the flip' {
        Assert-HarnessExit $clean OK
    }

    It 'the flipped position-1 signature is SIG_FAIL, filename unchanged' {
        Test-Path -LiteralPath $target | Should -BeTrue
        Assert-HarnessExit $result SIG_FAIL
    }
}

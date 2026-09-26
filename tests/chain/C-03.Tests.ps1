# status: red
# spec: S7.2, S4.2
# C-03: raw byte flip inside the position-1 signature value -> SIG_FAIL.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Helpers.ps1')
}

Describe 'C-03' {
    BeforeAll {
        $run = $null
        $run = New-ChainRun
        $tree = New-ChainTree $run 3
        $clean = Test-ChainVerify $run
        Invoke-ChainSignatureFlip (Get-ChainReceiptPath $run $tree[1])
        $result = Test-ChainVerify $run
    }
    AfterAll { Remove-ChainRun $run }

    It 'the tree verifies before the flip' {
        Assert-ChainExit $clean OK
    }

    It 'the flipped position-1 signature is SIG_FAIL, filename unchanged' {
        Test-Path -LiteralPath (Get-ChainReceiptPath $run $tree[1]) | Should -BeTrue
        Assert-ChainExit $result SIG_FAIL
    }
}

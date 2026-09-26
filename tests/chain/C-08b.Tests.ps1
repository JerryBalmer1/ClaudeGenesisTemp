# status: red
# spec: S13, S7.2
# C-08b: the shipping Test-GenesisChain on the same M-01 fixture tree -> SIG_FAIL: the mutant is killed.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Helpers.ps1')
}

Describe 'C-08b' {
    BeforeAll {
        $run = $null
        $run = New-ChainRun
        $tree = New-ChainTree $run 3
        Invoke-ChainSignatureFlip (Get-ChainReceiptPath $run $tree[0])
        $result = Test-ChainVerify $run
    }
    AfterAll { Remove-ChainRun $run }

    It 'the shipping verifier rejects the genesis-flipped tree with SIG_FAIL' {
        Assert-ChainExit $result SIG_FAIL
    }
}

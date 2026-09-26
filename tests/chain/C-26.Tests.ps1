# status: red
# spec: S7.3, S11.3
# C-26: a second position-0 receipt -> CHAIN_BREAK.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Helpers.ps1')
}

Describe 'C-26' {
    BeforeAll {
        $run = $null
        $run = New-ChainRun
        $null = New-ChainTree $run 2
        $clean = Test-ChainVerify $run

        $other = Split-ChainRun $run 'other' -Empty
        $second = Add-ChainGenesis $other $run.Succ2
        Copy-Item -LiteralPath (Get-ChainReceiptPath $other $second) -Destination (Join-Path $run.HeavenPath 'receipts')
        $result = Test-ChainVerify $run
    }
    AfterAll { Remove-ChainRun $run }

    It 'the tree verifies before the second genesis' {
        Assert-ChainExit $clean OK
    }

    It 'a second genesis is CHAIN_BREAK' {
        (Read-ChainReceipt (Get-ChainReceiptPath $run $second)).chain_position | Should -Be 0
        Assert-ChainExit $result CHAIN_BREAK
    }
}

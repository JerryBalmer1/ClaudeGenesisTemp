# status: red
# spec: S7.3
# C-30: two receipts with the same parent_hash -> CHAIN_BREAK.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Helpers.ps1')
}

Describe 'C-30' {
    BeforeAll {
        $run = $null
        $run = New-ChainRun
        $tree = New-ChainTree $run 2
        $fork = Split-ChainRun $run 'fork'
        $mine = Add-ChainReceipt $run -Context 'this side'
        $theirs = Add-ChainReceipt $fork -Context 'that side'
        $clean = Test-ChainVerify $run
        Copy-Item -LiteralPath (Get-ChainReceiptPath $fork $theirs) -Destination (Join-Path $run.HeavenPath 'receipts')
        $result = Test-ChainVerify $run
    }
    AfterAll { Remove-ChainRun $run }

    It 'the two receipts differ and share parent_hash' {
        $theirs | Should -Not -Be $mine
        (Read-ChainReceipt (Get-ChainReceiptPath $run $theirs)).parent_hash | Should -BeExactly $tree[1]
        (Read-ChainReceipt (Get-ChainReceiptPath $run $mine)).parent_hash | Should -BeExactly $tree[1]
    }

    It 'the tree verifies before the fork' {
        Assert-ChainExit $clean OK
    }

    It 'the fork is CHAIN_BREAK' {
        Assert-ChainExit $result CHAIN_BREAK
    }
}

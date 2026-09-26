# status: red
# spec: S11.3, S7.3
# C-26: a second receipt at position 0 -> CHAIN_BREAK.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Harness.ps1')
}

Describe 'C-26' {
    BeforeAll {
        $run = $null
        $run = New-HarnessRun
        $tree = New-HarnessTree $run 2
        $b = New-HarnessBody $run 'genesis' ''
        $b.root_public_key = $run.Root.Base64
        $b.successor_public_key = $run.Succ2.Base64
        $second = Write-HarnessReceipt $run $b -SignWith $run.Root
        $result = Test-HarnessChain $run
    }
    AfterAll { Remove-HarnessRun $run }

    It 'two receipts sit at position 0' {
        $second | Should -Not -Be $tree[0]
        (Read-HarnessReceipt $run $second).chain_position | Should -Be 0
    }

    It 'exit CHAIN_BREAK' {
        Assert-HarnessExit $result CHAIN_BREAK
    }
}

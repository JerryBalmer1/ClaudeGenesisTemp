# status: red
# spec: S7.3
# C-30: two receipts with the same parent_hash -> CHAIN_BREAK.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Harness.ps1')
}

Describe 'C-30' {
    BeforeAll {
        $run = $null
        $run = New-HarnessRun
        $tree = New-HarnessTree $run 3
        $b = New-HarnessBody $run 'receipt' $tree[1]
        $b.output_hash = Get-HarnessTextSha 'fork'
        $fork = Write-HarnessReceipt $run $b -SignWith $run.Root
        $result = Test-HarnessChain $run
    }
    AfterAll { Remove-HarnessRun $run }

    It 'the fork shares its parent with the head' {
        (Read-HarnessReceipt $run $fork).parent_hash | Should -BeExactly (Read-HarnessReceipt $run $tree[2]).parent_hash
    }

    It 'exit CHAIN_BREAK' {
        Assert-HarnessExit $result CHAIN_BREAK
    }
}

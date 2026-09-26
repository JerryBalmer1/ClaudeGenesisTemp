# status: red
# spec: S7.4
# C-15: Get-GenesisLineage -MaxReceipts 5 on six receipts -> WALK_LIMIT, no output line contains ok. The
# same bound on Test-GenesisChain, the other command that takes it, gives the same class.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Harness.ps1')
}

Describe 'C-15' {
    BeforeAll {
        $run = $null
        $run = New-HarnessRun
        $tree = New-HarnessTree $run 6
        $lineage = Invoke-Genesis $run 'Get-GenesisLineage' @{ Hash = $tree[5]; MaxReceipts = 5 }
        $chain = Test-HarnessChain $run -MaxReceipts 5
        $unbounded = Test-HarnessChain $run
    }
    AfterAll { Remove-HarnessRun $run }

    It 'the six receipts verify with the default bound' {
        Assert-HarnessExit $unbounded OK
    }

    It 'Get-GenesisLineage -MaxReceipts 5 -> WALK_LIMIT' {
        Assert-HarnessExit $lineage WALK_LIMIT
    }

    It 'Get-GenesisLineage prints no line containing ok' {
        $lineage.Lines | Where-Object { $_ -match '(?i)\bok\b' } | Should -BeNullOrEmpty
    }

    It 'Test-GenesisChain -MaxReceipts 5 -> WALK_LIMIT, no ok' {
        Assert-HarnessExit $chain WALK_LIMIT
        $chain.Lines | Where-Object { $_ -match '(?i)\bok\b' } | Should -BeNullOrEmpty
    }
}

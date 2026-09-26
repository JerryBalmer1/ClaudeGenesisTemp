# status: red
# spec: S7.4
# C-15: Get-GenesisLineage -MaxReceipts 5 on six receipts -> WALK_LIMIT, and no output line contains "ok".

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Helpers.ps1')
}

Describe 'C-15' {
    BeforeAll {
        $run = $null
        $run = New-ChainRun
        $null = New-ChainTree $run 6
        $within = Invoke-Genesis -Run $run -Command 'Get-GenesisLineage' -Parameters @{ MaxReceipts = 6 }
        $over = Invoke-Genesis -Run $run -Command 'Get-GenesisLineage' -Parameters @{ MaxReceipts = 5 }
    }
    AfterAll { Remove-ChainRun $run }

    It 'six receipts walk within -MaxReceipts 6' {
        Assert-ChainExit $within OK
    }

    It 'six receipts overrun -MaxReceipts 5 with WALK_LIMIT' {
        Assert-ChainExit $over WALK_LIMIT
    }

    It 'no output line of the overrun contains ok' {
        @($over.Lines | Where-Object { $_ -match 'ok' }) | Should -BeNullOrEmpty -Because (Format-ChainResult $over)
    }
}

# status: red
# spec: S9.1, S9.2
# C-33: a PAPER that does not match the cold copy -> HASH_MISMATCH, and nothing is copied.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Helpers.ps1')
}

Describe 'C-33' {
    BeforeAll {
        $run = $null
        $run = New-ChainRun
        $tree = New-ChainTree $run 3

        function New-Cold([string]$Name) {
            $cold = Join-Path $run.Dir $Name
            Copy-ChainHeaven $run.HeavenPath $cold
            $cold
        }
        $receiptsCold = New-Cold 'cold-receipts'
        Write-ChainPaper -ColdPath $receiptsCold -Genesis $tree[0] -ReceiptsHash (Get-ChainTextSha256 'wrong')
        $genesisCold = New-Cold 'cold-genesis'
        Write-ChainPaper -ColdPath $genesisCold -Genesis $tree[1]

        $receiptsTarget = Split-ChainRun $run 'receipts-target' -Empty
        $genesisTarget = Split-ChainRun $run 'genesis-target' -Empty
        $receiptsResult = Invoke-Genesis -Run $receiptsTarget -Command 'Restore-GenesisHeaven' -Parameters @{ ColdPath = $receiptsCold }
        $genesisResult = Invoke-Genesis -Run $genesisTarget -Command 'Restore-GenesisHeaven' -Parameters @{ ColdPath = $genesisCold }
    }
    AfterAll { Remove-ChainRun $run }

    It 'a wrong receipts: line is HASH_MISMATCH' {
        Assert-ChainExit $receiptsResult HASH_MISMATCH
    }

    It 'a wrong genesis line is HASH_MISMATCH' {
        Assert-ChainExit $genesisResult HASH_MISMATCH
    }

    It 'nothing is copied into either Heaven' {
        foreach ($target in $receiptsTarget, $genesisTarget) {
            @(Get-ChildItem -LiteralPath $target.HeavenPath -Recurse -Force -File) | Should -BeNullOrEmpty
        }
    }
}

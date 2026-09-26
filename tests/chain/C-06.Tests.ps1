# status: red
# spec: S9.1, S9.2
# C-06: restore a receipt-only cold copy onto an empty Heaven; exit 0.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Harness.ps1')
}

Describe 'C-06' {
    BeforeAll {
        $run = $null
        $run = New-HarnessRun
        $tree = New-HarnessTree $run 3
        $cold = Join-Path $run.Dir 'cold'
        Copy-HarnessHeaven $run.Heaven $cold -ReceiptsOnly
        Set-HarnessPaper -Cold $cold -Genesis $tree[0]
        $empty = New-HarnessCopy $run 'empty' -Empty
        $result = Invoke-Genesis $run 'Restore-GenesisHeaven' @{ ColdPath = $cold; SigningKeyId = $run.Root.KeyId } -Heaven $empty
    }
    AfterAll { Remove-HarnessRun $run }

    It 'the cold copy carries no content/' {
        Test-Path -LiteralPath (Join-Path $cold 'content') | Should -BeFalse
    }

    It 'restore exits 0' {
        Assert-HarnessExit $result OK
    }

    It 'the Heaven now holds exactly the cold receipts' {
        (Get-HarnessNames $empty) -join ',' | Should -BeExactly ((Get-HarnessNames $cold) -join ',')
    }
}

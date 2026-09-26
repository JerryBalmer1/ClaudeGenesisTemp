# status: red
# spec: S9.1, S9.2
# C-06: restore a receipt-only cold copy onto an empty Heaven; exit 0.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Helpers.ps1')
}

Describe 'C-06' {
    BeforeAll {
        $run = $null
        $run = New-ChainRun
        $tree = New-ChainTree $run 3

        $cold = Join-Path $run.Dir 'cold'
        $null = New-Item -ItemType Directory -Path (Join-Path $cold 'receipts') -Force
        Get-ChildItem -LiteralPath (Join-Path $run.HeavenPath 'receipts') | Copy-Item -Destination (Join-Path $cold 'receipts')
        Write-ChainPaper -ColdPath $cold -Genesis $tree[0]

        $target = Split-ChainRun $run 'target' -Empty
        $result = Invoke-Genesis -Run $target -Command 'Restore-GenesisHeaven' -Parameters @{ ColdPath = $cold }
    }
    AfterAll { Remove-ChainRun $run }

    It 'the PAPER says content: absent' {
        (Get-Content -LiteralPath (Join-Path $cold 'PAPER'))[2] | Should -BeExactly 'content: absent'
    }

    It 'restore exits 0' {
        Assert-ChainExit $result OK
    }

    It 'every cold receipt arrives byte for byte, and nothing else' {
        (Get-ChainReceiptName $target.HeavenPath) -join ',' | Should -BeExactly ((Get-ChainReceiptName $cold) -join ',')
        foreach ($name in Get-ChainReceiptName $cold) {
            $a = Get-ChainSha256 ([IO.File]::ReadAllBytes((Join-Path $cold "receipts/$name")))
            $b = Get-ChainSha256 ([IO.File]::ReadAllBytes((Join-Path $target.HeavenPath "receipts/$name")))
            $b | Should -BeExactly $a
        }
        @(Get-ChildItem -LiteralPath (Join-Path $target.HeavenPath 'content') -Force) | Should -BeNullOrEmpty
    }
}

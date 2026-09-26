# status: red
# spec: S9.2, S3.3
# C-07: restore onto a divergent tip -> one discrepancy, nothing copied, exit DISCREPANCY.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Helpers.ps1')
}

Describe 'C-07' {
    BeforeAll {
        $run = $null
        $run = New-ChainRun
        $tree = New-ChainTree $run 2

        $source = Split-ChainRun $run 'coldsource'
        $coldTip = Add-ChainReceipt $source -Context 'cold side' -Output 'cold side'
        $heavenTip = Add-ChainReceipt $run -Context 'heaven side' -Output 'heaven side'

        $cold = Join-Path $run.Dir 'cold'
        Copy-ChainHeaven $source.HeavenPath $cold
        Write-ChainPaper -ColdPath $cold -Genesis $tree[0]

        $receiptsBefore = Get-ChainReceiptName $run.HeavenPath
        $contentBefore = @(Get-ChildItem -LiteralPath (Join-Path $run.HeavenPath 'content') -Force | ForEach-Object Name | Sort-Object)
        $result = Invoke-Genesis -Run $run -Command 'Restore-GenesisHeaven' -Parameters @{ ColdPath = $cold }
        $contentAfter = @(Get-ChildItem -LiteralPath (Join-Path $run.HeavenPath 'content') -Force | ForEach-Object Name | Sort-Object)
    }
    AfterAll { Remove-ChainRun $run }

    It 'exits DISCREPANCY' {
        Assert-ChainExit $result DISCREPANCY
    }

    It 'writes exactly one receipt, a discrepancy naming both tips and the cold genesis' {
        $result.Written.Count | Should -Be 1
        $r = Read-ChainReceipt (Get-ChainReceiptPath $run $result.Written[0])
        $r.receipt_type | Should -BeExactly 'discrepancy'
        $r.check_name | Should -BeExactly 'CHAIN_BREAK'
        $r.observed_hash | Should -BeExactly $heavenTip
        $r.expected_hash | Should -BeExactly $coldTip
        $r.subject_id | Should -BeExactly $tree[0]
    }

    It 'copies nothing from the cold copy' {
        Test-Path -LiteralPath (Get-ChainReceiptPath $run $coldTip) | Should -BeFalse
        @(Get-ChainReceiptName $run.HeavenPath | Where-Object { $_ -notin $receiptsBefore }).Count | Should -Be 1
        $contentAfter -join ',' | Should -BeExactly ($contentBefore -join ',')
    }
}

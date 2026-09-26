# status: red
# spec: S9.2, S3.3, S10.1
# C-07: restore onto a divergent tip -> one discrepancy, nothing copied, exit DISCREPANCY.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Harness.ps1')
}

Describe 'C-07' {
    BeforeAll {
        $run = $null
        $run = New-HarnessRun
        $tree = New-HarnessTree $run 2
        $cold = New-HarnessCopy $run 'cold'
        $coldTip = Add-HarnessReceipt $run -Context 'cold side' -Output 'cold side' -Heaven $cold
        Remove-Item -LiteralPath (Join-Path $cold 'content') -Recurse
        Set-HarnessPaper -Cold $cold -Genesis $tree[0]
        $heavenTip = Add-HarnessReceipt $run -Context 'heaven side' -Output 'heaven side'
        $before = Get-HarnessNames $run.Heaven
        $result = Invoke-Genesis $run 'Restore-GenesisHeaven' @{ ColdPath = $cold; SigningKeyId = $run.Root.KeyId }
        $after = Get-HarnessNames $run.Heaven
    }
    AfterAll { Remove-HarnessRun $run }

    It 'exit DISCREPANCY' {
        Assert-HarnessExit $result DISCREPANCY
    }

    It 'writes exactly one receipt and copies nothing' {
        $result.Written.Count | Should -Be 1
        @($after | Where-Object { $_ -notin $before }).Count | Should -Be 1
        "$coldTip.json" | Should -Not -BeIn $after
    }

    It 'the receipt is the S9.2 discrepancy' {
        $d = Read-HarnessReceipt $run $result.Written[0]
        $d.receipt_type | Should -BeExactly 'discrepancy'
        $d.check_name | Should -BeExactly 'CHAIN_BREAK'
        $d.observed_hash | Should -BeExactly $heavenTip
        $d.expected_hash | Should -BeExactly $coldTip
        $d.subject_id | Should -BeExactly $tree[0]
    }
}

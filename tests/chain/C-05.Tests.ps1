# status: red
# spec: S10.1, S10.2, S7.7
# C-05: discrepancy then resolution: two invocations.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Helpers.ps1')
}

Describe 'C-05' {
    BeforeAll {
        $run = $null
        $run = New-ChainRun
        $null = New-ChainTree $run 2
        $params = Get-ChainDiscrepancyParameters $run 'c05'
        $disc = Invoke-Genesis -Run $run -Command 'New-GenesisDiscrepancy' -Parameters $params
        $between = Test-ChainVerify $run
        $discHash = Get-ChainWritten $disc
        $res = Invoke-Genesis -Run $run -Command 'Resolve-GenesisDiscrepancy' -Parameters @{ Resolves = $discHash; SigningKeyId = $run.Root.KeyId }
        $after = Test-ChainVerify $run

        Import-Module -Name $ChainModule -Force
        $discCommand = Get-Command -Name 'New-GenesisDiscrepancy' -Module Genesis -ErrorAction Ignore
        $resCommand = Get-Command -Name 'Resolve-GenesisDiscrepancy' -Module Genesis -ErrorAction Ignore
    }
    AfterAll {
        Remove-Module -Name Genesis -ErrorAction Ignore
        Remove-ChainRun $run
    }

    It 'New-GenesisDiscrepancy writes one discrepancy receipt carrying its arguments' {
        Assert-ChainExit $disc OK
        $disc.Written.Count | Should -Be 1
        $r = Read-ChainReceipt (Get-ChainReceiptPath $run $discHash)
        $r.receipt_type | Should -BeExactly 'discrepancy'
        $r.check_name | Should -BeExactly $params.CheckName
        $r.observed_hash | Should -BeExactly $params.ObservedHash
        $r.expected_hash | Should -BeExactly $params.ExpectedHash
        $r.subject_id | Should -BeExactly $params.SubjectId
    }

    It 'the chain exits DISCREPANCY between the two invocations' {
        Assert-ChainExit $between DISCREPANCY
    }

    It 'Resolve-GenesisDiscrepancy writes one resolution referencing it, in a second invocation' {
        Assert-ChainExit $res OK
        $res.Written.Count | Should -Be 1
        $r = Read-ChainReceipt (Get-ChainReceiptPath $run $res.Written[0])
        $r.receipt_type | Should -BeExactly 'resolution'
        $r.resolves | Should -BeExactly $discHash
    }

    It 'the chain exits 0 after the resolution' {
        Assert-ChainExit $after OK
    }

    It 'no command both creates and resolves' {
        $discCommand | Should -Not -BeNullOrEmpty
        $resCommand | Should -Not -BeNullOrEmpty
        $discCommand.Parameters.Keys | Should -Not -Contain 'Resolves'
        $resCommand.Parameters.Keys | Should -Not -Contain 'CheckName'
    }
}

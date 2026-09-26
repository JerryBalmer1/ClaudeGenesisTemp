# status: red
# spec: S7.7, S10.2
# C-31: an unresolved discrepancy -> DISCREPANCY; after its resolution -> 0.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Harness.ps1')
}

Describe 'C-31' {
    BeforeAll {
        $run = $null
        $run = New-HarnessRun
        $null = New-HarnessTree $run 2
        $open = Invoke-HarnessWrite $run 'New-GenesisDiscrepancy' (Get-HarnessDiscrepancyParameters $run)
        $unresolved = Test-HarnessChain $run
        $null = Invoke-HarnessWrite $run 'Resolve-GenesisDiscrepancy' @{ Resolves = $open; SigningKeyId = $run.Root.KeyId }
        $resolved = Test-HarnessChain $run
    }
    AfterAll { Remove-HarnessRun $run }

    It 'unresolved -> DISCREPANCY' {
        Assert-HarnessExit $unresolved DISCREPANCY
    }

    It 'resolved -> 0' {
        Assert-HarnessExit $resolved OK
    }
}

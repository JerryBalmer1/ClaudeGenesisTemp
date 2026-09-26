# status: red
# spec: S7.7, S10.2
# C-31: an unresolved discrepancy -> DISCREPANCY; after its resolution -> 0.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Helpers.ps1')
}

Describe 'C-31' {
    BeforeAll {
        $run = $null
        $run = New-ChainRun
        $null = New-ChainTree $run 2
        $first = Add-ChainDiscrepancy $run 'first'
        $second = Add-ChainDiscrepancy $run 'second'
        $bothOpen = Test-ChainVerify $run
        $null = Add-ChainResolution $run $first
        $oneOpen = Test-ChainVerify $run
        $null = Add-ChainResolution $run $second
        $noneOpen = Test-ChainVerify $run
    }
    AfterAll { Remove-ChainRun $run }

    It 'two unresolved discrepancies exit DISCREPANCY' {
        Assert-ChainExit $bothOpen DISCREPANCY
    }

    It 'one unresolved discrepancy still exits DISCREPANCY' {
        Assert-ChainExit $oneOpen DISCREPANCY
    }

    It 'with every discrepancy resolved the chain exits 0' {
        Assert-ChainExit $noneOpen OK
    }
}

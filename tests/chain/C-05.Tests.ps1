# status: red
# spec: S10.1, S10.2, S7.7, S3.3
# C-05: discrepancy then resolution, two invocations. No command creates and resolves in one.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Harness.ps1')
}

Describe 'C-05' {
    BeforeAll {
        $run = $null
        $run = New-HarnessRun
        $tree = New-HarnessTree $run 2
        $open = Invoke-Genesis $run 'New-GenesisDiscrepancy' (Get-HarnessDiscrepancyParameters $run)
        $afterOpen = Test-HarnessChain $run
        $wrongTarget = Invoke-Genesis $run 'Resolve-GenesisDiscrepancy' @{ Resolves = $tree[1]; SigningKeyId = $run.Root.KeyId }
        $close = Invoke-Genesis $run 'Resolve-GenesisDiscrepancy' @{ Resolves = ($open.Written | Select-Object -First 1); SigningKeyId = $run.Root.KeyId }
        $afterClose = Test-HarnessChain $run
    }
    AfterAll { Remove-HarnessRun $run }

    It 'New-GenesisDiscrepancy writes exactly one discrepancy and no resolution' {
        Assert-HarnessExit $open OK
        $open.Written.Count | Should -Be 1
        (Read-HarnessReceipt $run $open.Written[0]).receipt_type | Should -BeExactly 'discrepancy'
    }

    It 'the open discrepancy fails the chain' {
        Assert-HarnessExit $afterOpen DISCREPANCY
    }

    It 'resolving a hash that is not a discrepancy is refused and writes nothing' {
        $wrongTarget.ExitCode | Should -Not -Be 0 -Because (Format-HarnessResult $wrongTarget)
        $wrongTarget.Written.Count | Should -Be 0
    }

    It 'Resolve-GenesisDiscrepancy writes one resolution referencing it' {
        Assert-HarnessExit $close OK
        $close.Written.Count | Should -Be 1
        $r = Read-HarnessReceipt $run $close.Written[0]
        $r.receipt_type | Should -BeExactly 'resolution'
        $r.resolves | Should -BeExactly $open.Written[0]
    }

    It 'the resolved chain verifies' {
        Assert-HarnessExit $afterClose OK
    }
}

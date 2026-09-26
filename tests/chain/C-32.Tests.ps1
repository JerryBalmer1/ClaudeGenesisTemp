# status: red
# spec: S1.9, S3.3
# C-32: Get-GenesisActor prints exactly one of root, successor, unknown after the banner, walking genesis
# and one amendment. Before the amendment succ1 is the successor; after it succ2 is, and the replaced
# succ1 is no longer anything the walk names.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Harness.ps1')

    function Get-Actor($Key) {
        Invoke-Genesis $run 'Get-GenesisActor' @{ Fingerprint = $Key.Fingerprint }
    }

    function Assert-Actor($Result, [string]$Expected) {
        Assert-HarnessExit $Result OK
        $Result.Lines.Count | Should -Be 2 -Because (Format-HarnessResult $Result)
        $Result.Lines[1] | Should -BeExactly $Expected
    }
}

Describe 'C-32' {
    BeforeAll {
        $run = $null
        $run = New-HarnessRun
        $null = Add-HarnessGenesis $run
        $before = @{ Root = Get-Actor $run.Root; Succ1 = Get-Actor $run.Succ1; Succ2 = Get-Actor $run.Succ2 }
        $null = Invoke-HarnessWrite $run 'Add-GenesisAmendment' (Get-HarnessAmendmentParameters $run)
        $after = @{ Root = Get-Actor $run.Root; Succ1 = Get-Actor $run.Succ1; Succ2 = Get-Actor $run.Succ2 }
    }
    AfterAll { Remove-HarnessRun $run }

    It 'genesis only: root, successor, unknown' {
        Assert-Actor $before.Root 'root'
        Assert-Actor $before.Succ1 'successor'
        Assert-Actor $before.Succ2 'unknown'
    }

    It 'after the amendment: root, replaced successor unknown, new successor' {
        Assert-Actor $after.Root 'root'
        Assert-Actor $after.Succ1 'unknown'
        Assert-Actor $after.Succ2 'successor'
    }
}

# status: red
# spec: S11.1
# C-24: append-only. After every writer, every file that was in receipts/ or content/ before it is still
# there with the same bytes and the same last-write time.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Harness.ps1')
}

Describe 'C-24' {
    BeforeAll {
        $run = $null
        $run = New-HarnessRun
        $steps = [Collections.Generic.List[object]]::new()

        function Step([string]$Command, [hashtable]$Parameters) {
            $before = @((Get-HarnessSnapshot $run.Heaven) -split "`n" | Where-Object { $_ })
            $r = Invoke-Genesis $run $Command $Parameters
            $after = @((Get-HarnessSnapshot $run.Heaven) -split "`n" | Where-Object { $_ })
            $steps.Add([pscustomobject]@{ Result = $r; Lost = @($before | Where-Object { $_ -notin $after }) })
            $r
        }

        $null = Add-HarnessGenesis $run
        $receipt = Step 'New-GenesisReceipt' (Get-HarnessReceiptParameters $run -Context 'alpha' -Output 'out')
        $null = Step 'New-GenesisReceipt' (Get-HarnessReceiptParameters $run -Context 'alpha' -Output 'out')
        $null = Step 'Add-GenesisAmendment' (Get-HarnessAmendmentParameters $run)
        $open = Step 'New-GenesisDiscrepancy' (Get-HarnessDiscrepancyParameters $run)
        $null = Step 'Resolve-GenesisDiscrepancy' @{ Resolves = ($open.Written | Select-Object -First 1); SigningKeyId = $run.Root.KeyId }
        $null = Step 'Add-GenesisRevocation' @{ Revokes = ($receipt.Written | Select-Object -First 1); SigningKeyId = $run.Root.KeyId }
    }
    AfterAll { Remove-HarnessRun $run }

    It 'every writer succeeded and wrote one receipt' {
        foreach ($s in $steps) {
            Assert-HarnessExit $s.Result OK
            $s.Result.Written.Count | Should -Be 1 -Because $s.Result.Command
        }
    }

    It 'no writer modified or deleted an existing file' {
        foreach ($s in $steps) {
            $s.Lost | Should -BeNullOrEmpty -Because $s.Result.Command
        }
    }
}

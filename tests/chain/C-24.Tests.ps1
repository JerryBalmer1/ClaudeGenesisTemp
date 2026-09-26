# status: red
# spec: S11.1
# C-24: append-only. No writer modifies or deletes an existing file in receipts/ or content/: every file
# present before a write keeps its bytes and its last-write time, including content a write stores again.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Helpers.ps1')
}

Describe 'C-24' {
    BeforeAll {
        $run = $null
        $run = New-ChainRun
        $steps = [Collections.Generic.List[object]]::new()
        $firstReceipt = $null
        $discrepancy = $null

        function Invoke-Step([string]$Name, [string]$Command, [scriptblock]$Parameters) {
            $pre = @((Get-ChainSnapshot $run.HeavenPath) -split "`n" | Where-Object { $_ })
            $r = Invoke-Genesis -Run $run -Command $Command -Parameters (& $Parameters)
            $post = @((Get-ChainSnapshot $run.HeavenPath) -split "`n" | Where-Object { $_ })
            $steps.Add([pscustomobject]@{ Name = $Name; Result = $r; Changed = @($pre | Where-Object { $_ -notin $post }); Pre = $pre; Post = $post })
            $r
        }

        $null = Invoke-Step 'genesis' 'New-GenesisRoot' { Get-ChainGenesisParameters $run }
        $firstReceipt = Get-ChainWritten (Invoke-Step 'receipt' 'New-GenesisReceipt' { Get-ChainReceiptParameters -Run $run -Context 'shared part' -Output 'shared output' })
        $null = Invoke-Step 'receipt, same content again' 'New-GenesisReceipt' { Get-ChainReceiptParameters -Run $run -Context 'shared part' -Output 'shared output' }
        $null = Invoke-Step 'amendment' 'Add-GenesisAmendment' { Get-ChainAmendmentParameters $run }
        $discrepancy = Get-ChainWritten (Invoke-Step 'discrepancy' 'New-GenesisDiscrepancy' { Get-ChainDiscrepancyParameters $run })
        $null = Invoke-Step 'resolution' 'Resolve-GenesisDiscrepancy' { @{ Resolves = $discrepancy; SigningKeyId = $run.Root.KeyId } }
        $null = Invoke-Step 'revocation' 'Add-GenesisRevocation' { @{ Revokes = $firstReceipt; SigningKeyId = $run.Root.KeyId } }
        $null = Invoke-Step 'root-revocation' 'Add-GenesisRevocation' { @{ RevokeRoot = $true; SigningKeyId = $run.Succ2.KeyId } }
        $refused = Invoke-Step 'receipt after root-revocation' 'New-GenesisReceipt' { Get-ChainReceiptParameters -Run $run -Context 'shared part' -Output 'shared output' }
    }
    AfterAll { Remove-ChainRun $run }

    It 'every writer succeeds and writes one receipt' {
        foreach ($s in $steps | Where-Object Name -NE 'receipt after root-revocation') {
            Assert-ChainExit $s.Result OK
            $s.Result.Written.Count | Should -Be 1 -Because $s.Name
        }
    }

    It 'no writer modifies or deletes an existing file' {
        foreach ($s in $steps) {
            $s.Changed | Should -BeNullOrEmpty -Because "$($s.Name) changed or removed: $($s.Changed -join '; ')"
        }
    }

    It 'the refused write leaves the Heaven exactly as it was' {
        $refused.ExitCode | Should -Not -Be 0
        $last = $steps[$steps.Count - 1]
        ($last.Post -join "`n") | Should -BeExactly ($last.Pre -join "`n")
    }
}

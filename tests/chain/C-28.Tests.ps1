# status: red
# spec: S3.6, S3.5, S1.8
# C-28: the first line of every command's captured stdout is exactly the S3.6 bytes, on success and on
# failure, and an -AttributedTo value never reaches it.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Harness.ps1')

    function Test-FirstLine($Result) {
        $b = $Result.Bytes
        if ($b.Length -lt $HarnessBanner.Length + 1) { return $false }
        for ($i = 0; $i -lt $HarnessBanner.Length; $i++) { if ($b[$i] -ne $HarnessBanner[$i]) { return $false } }
        $next = $b[$HarnessBanner.Length]
        $next -eq 0x0A -or ($next -eq 0x0D -and $b.Length -gt $HarnessBanner.Length + 1 -and $b[$HarnessBanner.Length + 1] -eq 0x0A)
    }
}

Describe 'C-28' {
    BeforeAll {
        $run = $null
        $run = New-HarnessRun
        $results = [Collections.Generic.List[object]]::new()
        function Run([string]$Command, [hashtable]$Parameters = @{}, [string]$Heaven) {
            $r = Invoke-Genesis $run $Command $Parameters -Heaven $Heaven
            $results.Add($r)
            $r
        }

        $genesis = Run 'New-GenesisRoot' @{ RootPublicKey = $run.Root.Path; SuccessorPublicKey = $run.Succ1.Path; SigningKeyId = $run.Root.KeyId }
        $attributed = Run 'New-GenesisReceipt' (Get-HarnessReceiptParameters $run -Context 'alpha' -Output 'out' -AttributedTo 'grok')
        $r1 = $attributed.Written | Select-Object -First 1
        $null = Run 'Add-GenesisAmendment' (Get-HarnessAmendmentParameters $run)
        $open = Run 'New-GenesisDiscrepancy' (Get-HarnessDiscrepancyParameters $run)
        $null = Run 'Test-GenesisChain'
        $null = Run 'Resolve-GenesisDiscrepancy' @{ Resolves = ($open.Written | Select-Object -First 1); SigningKeyId = $run.Root.KeyId }
        $null = Run 'Test-GenesisChain'
        $null = Run 'Test-GenesisChain' @{ Verbose = $true }
        $null = Run 'Get-GenesisReceipt' @{ Hash = $r1 }
        $null = Run 'Get-GenesisReceipt' @{ Hash = $r1; Verbose = $true }
        $null = Run 'Get-GenesisLineage' @{ Hash = $r1 }
        $null = Run 'Get-GenesisActor' @{ Fingerprint = $run.Root.Fingerprint }
        $null = Run 'Resolve-GenesisContent' @{ Hash = (Get-HarnessTextSha 'alpha') }

        $cold = New-HarnessCopy $run 'cold'
        Remove-Item -LiteralPath (Join-Path $cold 'content') -Recurse
        Set-HarnessPaper -Cold $cold -Genesis ($genesis.Written | Select-Object -First 1)
        $null = Run 'Restore-GenesisHeaven' @{ ColdPath = $cold; SigningKeyId = $run.Root.KeyId } -Heaven (New-HarnessCopy $run 'restored' -Empty)

        $null = Run 'Add-GenesisRevocation' @{ Revokes = $r1; SigningKeyId = $run.Root.KeyId }
        $null = Run 'Add-GenesisRevocation' @{ RevokeRoot = $true; SigningKeyId = $run.Succ2.KeyId }
        $null = Run 'New-GenesisReceipt' (Get-HarnessReceiptParameters $run -AttributedTo 'grok')
        $null = Run 'Get-GenesisReceipt' @{ Hash = (Get-HarnessTextSha 'no such receipt') }
    }
    AfterAll { Remove-HarnessRun $run }

    It 'every one of the twelve S1.1 commands was exercised' {
        ($results.Command | Sort-Object -Unique).Count | Should -Be 12
    }

    It 'the run includes non-zero exits' {
        @($results | Where-Object ExitCode -NE 0).Count | Should -BeGreaterThan 0
    }

    It 'the first line is the S3.6 bytes on every captured stream' {
        $bad = @($results | Where-Object { -not (Test-FirstLine $_) } | ForEach-Object { Format-HarnessResult $_ })
        $bad | Should -BeNullOrEmpty
    }

    It 'attributed_to never reaches the first line' {
        $bad = @($results | Where-Object { $_.Lines.Count -and $_.Lines[0] -match 'grok' } | ForEach-Object Command)
        $bad | Should -BeNullOrEmpty
    }
}

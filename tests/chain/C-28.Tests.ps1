# status: red
# spec: S3.6, S3.5, S1.7, S1.8
# C-28: the first output line of every command is the S3.6 bytes, compared on the captured stdout stream,
# on success and on failure. attributed_to never reaches line 1, and prints only under -Verbose.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Helpers.ps1')
}

Describe 'C-28' {
    BeforeAll {
        $run = $null
        $run = New-ChainRun
        $results = [Collections.Generic.List[object]]::new()
        function Step([string]$Command, [hashtable]$Parameters = @{}) {
            $r = Invoke-Genesis -Run $run -Command $Command -Parameters $Parameters
            $results.Add($r)
            $r
        }

        $genesis = Get-ChainWritten (Step 'New-GenesisRoot' (Get-ChainGenesisParameters $run))
        $attributed = Step 'New-GenesisReceipt' (Get-ChainReceiptParameters -Run $run -Context 'claimed' -AttributedTo 'grok')
        $receipt = Get-ChainWritten $attributed
        $null = Step 'Add-GenesisAmendment' (Get-ChainAmendmentParameters $run)
        $disc = Get-ChainWritten (Step 'New-GenesisDiscrepancy' (Get-ChainDiscrepancyParameters $run))
        $null = Step 'Test-GenesisChain'
        $null = Step 'Resolve-GenesisDiscrepancy' @{ Resolves = $disc; SigningKeyId = $run.Root.KeyId }
        $plain = Step 'Test-GenesisChain'
        $verbose = Step 'Test-GenesisChain' @{ Verbose = $true }
        $receiptPlain = Step 'Get-GenesisReceipt' @{ Hash = $receipt }
        $receiptVerbose = Step 'Get-GenesisReceipt' @{ Hash = $receipt; Verbose = $true }
        $null = Step 'Get-GenesisReceipt' @{ Hash = (Get-ChainTextSha256 'no such receipt') }
        $null = Step 'Get-GenesisLineage'
        $null = Step 'Get-GenesisActor' @{ Fingerprint = $run.Root.Fingerprint }
        $null = Step 'Add-GenesisRevocation' @{ Revokes = $receipt; SigningKeyId = $run.Root.KeyId }
        $null = Step 'Add-GenesisRevocation' @{ RevokeRoot = $true; SigningKeyId = $run.Succ2.KeyId }
        $null = Step 'New-GenesisReceipt' (Get-ChainReceiptParameters -Run $run -Context 'refused')
        Invoke-ChainSignatureFlip (Get-ChainReceiptPath $run $genesis)
        $null = Step 'Test-GenesisChain'
    }
    AfterAll { Remove-ChainRun $run }

    It 'captured something from every command' {
        $results.Count | Should -Be 17
    }

    It 'every captured stdout starts with the S3.6 bytes and a line end' {
        foreach ($r in $results) {
            $because = Format-ChainResult $r
            $r.Bytes.Length | Should -BeGreaterThan $ChainBanner.Length -Because $because
            [Convert]::ToHexString($r.Bytes, 0, $ChainBanner.Length) | Should -BeExactly ([Convert]::ToHexString($ChainBanner)) -Because $because
            $eol = $r.Bytes[$ChainBanner.Length]
            ($eol -eq 0x0A -or ($eol -eq 0x0D -and $r.Bytes[$ChainBanner.Length + 1] -eq 0x0A)) | Should -BeTrue -Because $because
        }
    }

    It 'the attributed write never prints attributed_to' {
        $attributed.Text | Should -Not -Match 'grok' -Because (Format-ChainResult $attributed)
    }

    It 'without -Verbose, Test-GenesisChain and Get-GenesisReceipt do not print attributed_to' {
        $plain.Text | Should -Not -Match 'grok'
        $receiptPlain.Text | Should -Not -Match 'grok'
    }

    It 'with -Verbose, attributed_to prints as operator_claims.attributed_to= on a later line only' {
        foreach ($r in $verbose, $receiptVerbose) {
            $r.Lines[0] | Should -Not -Match 'grok'
            @(Get-ChainLaterLine $r | Where-Object { $_ -match 'operator_claims\.attributed_to=grok' }).Count | Should -BeGreaterThan 0 -Because (Format-ChainResult $r)
            @($r.Lines | Where-Object { $_ -match 'grok' -and $_ -notmatch 'operator_claims\.attributed_to=grok' }) | Should -BeNullOrEmpty
        }
    }
}

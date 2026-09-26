# status: red
# spec: S3.4, S3.5, S1.6
# C-17: operator-attributed on genesis, amendment, revocation, discrepancy, resolution -> ACTOR_ILLEGAL;
# receipt without attributed_to -> SCHEMA; root with operator_claims -> SCHEMA. Each case is one
# hand-built, root-signed receipt at the head of its own copy of a clean tree.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Harness.ps1')

    function Add-Attributed($Body) {
        $Body.actor.kind = 'operator-attributed'
        $Body.operator_claims = [ordered]@{ attributed_to = 'grok' }
        $Body
    }
}

Describe 'C-17' {
    BeforeAll {
        $run = $null
        $run = New-HarnessRun
        $tree = New-HarnessTree $run 2
        $results = [ordered]@{}

        $h = New-HarnessCopy $run 'genesis-only'
        Remove-Item -LiteralPath (Get-HarnessReceiptPath $run $tree[1] $h)
        $null = Edit-HarnessReceipt $run $tree[0] { param($r) $null = Add-Attributed $r } -SignWith $run.Root -Heaven $h
        $results.genesis = Test-HarnessChain $run -Heaven $h

        $h = New-HarnessCopy $run 'amendment'
        $b = Add-Attributed (New-HarnessBody $run 'amendment' $tree[1] -Heaven $h)
        $b.successor_public_key = $run.Succ2.Base64
        $b.revoked_successor_fingerprint = $run.Succ1.Fingerprint
        $b.reason = 'successor-media-lost'
        $null = Write-HarnessReceipt $run $b -SignWith $run.Root -Heaven $h
        $results.amendment = Test-HarnessChain $run -Heaven $h

        $h = New-HarnessCopy $run 'revocation'
        $b = Add-Attributed (New-HarnessBody $run 'revocation' $tree[1] -Heaven $h)
        $b.revokes = $tree[1]
        $null = Write-HarnessReceipt $run $b -SignWith $run.Root -Heaven $h
        $results.revocation = Test-HarnessChain $run -Heaven $h

        $h = New-HarnessCopy $run 'discrepancy'
        $b = Add-Attributed (New-HarnessBody $run 'discrepancy' $tree[1] -Heaven $h)
        $b.check_name = 'HASH_MISMATCH'
        $b.observed_hash = Get-HarnessTextSha 'observed'
        $b.expected_hash = Get-HarnessTextSha 'expected'
        $b.subject_id = Get-HarnessTextSha 'subject'
        $null = Write-HarnessReceipt $run $b -SignWith $run.Root -Heaven $h
        $results.discrepancy = Test-HarnessChain $run -Heaven $h

        $h = New-HarnessCopy $run 'resolution'
        $open = Invoke-HarnessWrite $run 'New-GenesisDiscrepancy' (Get-HarnessDiscrepancyParameters $run) -Heaven $h
        $b = Add-Attributed (New-HarnessBody $run 'resolution' $open -Heaven $h)
        $b.resolves = $open
        $null = Write-HarnessReceipt $run $b -SignWith $run.Root -Heaven $h
        $results.resolution = Test-HarnessChain $run -Heaven $h

        $h = New-HarnessCopy $run 'no-claims'
        $b = New-HarnessBody $run 'receipt' $tree[1] -Kind 'operator-attributed' -Heaven $h
        $b.output_hash = Get-HarnessTextSha 'output'
        $null = Write-HarnessReceipt $run $b -SignWith $run.Root -Heaven $h
        $results.'receipt-without-attributed_to' = Test-HarnessChain $run -Heaven $h

        $h = New-HarnessCopy $run 'root-claims'
        $b = New-HarnessBody $run 'receipt' $tree[1] -Heaven $h
        $b.output_hash = Get-HarnessTextSha 'output'
        $b.operator_claims = [ordered]@{ attributed_to = 'grok' }
        $null = Write-HarnessReceipt $run $b -SignWith $run.Root -Heaven $h
        $results.'root-with-claims' = Test-HarnessChain $run -Heaven $h
    }
    AfterAll { Remove-HarnessRun $run }

    It 'operator-attributed on <_> -> ACTOR_ILLEGAL' -ForEach @('genesis', 'amendment', 'revocation', 'discrepancy', 'resolution') {
        Assert-HarnessExit $results[$_] ACTOR_ILLEGAL
    }

    It 'operator-attributed receipt without attributed_to -> SCHEMA' {
        Assert-HarnessExit $results.'receipt-without-attributed_to' SCHEMA
    }

    It 'root receipt with operator_claims -> SCHEMA' {
        Assert-HarnessExit $results.'root-with-claims' SCHEMA
    }
}

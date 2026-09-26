# status: red
# spec: S3.4, S3.5, S1.6
# C-17: operator-attributed on genesis, amendment, revocation, discrepancy, resolution -> ACTOR_ILLEGAL;
# receipt without attributed_to -> SCHEMA; root with claims -> SCHEMA.
# Each case rewrites the head of a tree whose head is the type under test, re-signed by the root key.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Helpers.ps1')
}

Describe 'C-17' {
    BeforeAll {
        $run = $null
        $run = New-ChainRun
        $heads = [ordered]@{}
        $views = [ordered]@{}

        $heads.genesis = Add-ChainGenesis $run
        $views.genesis = Split-ChainRun $run 'genesis'
        $heads.amendment = Add-ChainAmendment $run
        $views.amendment = Split-ChainRun $run 'amendment'
        $heads.discrepancy = Add-ChainDiscrepancy $run
        $views.discrepancy = Split-ChainRun $run 'discrepancy'
        $heads.resolution = Add-ChainResolution $run $heads.discrepancy
        $views.resolution = Split-ChainRun $run 'resolution'
        $receipt = Add-ChainReceipt $run
        $noClaims = Split-ChainRun $run 'noclaims'
        $rootClaims = Split-ChainRun $run 'rootclaims'
        $null = Add-ChainReceipt $run
        $heads.revocation = Add-ChainRevocation $run $receipt
        $views.revocation = Split-ChainRun $run 'revocation'

        $attributed = [ordered]@{}
        foreach ($type in $views.Keys) {
            $view = $views[$type]
            $null = Edit-ChainReceipt -Run $view -Hash $heads[$type] -SignWith $run.Root -Mutate {
                param($r)
                $r.actor.kind = 'operator-attributed'
                $r.operator_claims = [ordered]@{ attributed_to = 'grok' }
            }
            $attributed[$type] = Test-ChainVerify $view
        }

        $null = Edit-ChainReceipt -Run $noClaims -Hash $receipt -SignWith $run.Root -Mutate { param($r) $r.actor.kind = 'operator-attributed' }
        $noClaimsResult = Test-ChainVerify $noClaims

        $null = Edit-ChainReceipt -Run $rootClaims -Hash $receipt -SignWith $run.Root -Mutate { param($r) $r.operator_claims = [ordered]@{ attributed_to = 'grok' } }
        $rootClaimsResult = Test-ChainVerify $rootClaims
    }
    AfterAll { Remove-ChainRun $run }

    It 'operator-attributed on <_> is ACTOR_ILLEGAL' -ForEach @('genesis', 'amendment', 'revocation', 'discrepancy', 'resolution') {
        Assert-ChainExit $attributed[$_] ACTOR_ILLEGAL
    }

    It 'operator-attributed receipt without attributed_to is SCHEMA' {
        Assert-ChainExit $noClaimsResult SCHEMA
    }

    It 'root receipt with operator_claims is SCHEMA' {
        Assert-ChainExit $rootClaimsResult SCHEMA
    }
}

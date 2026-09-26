# status: red
# spec: S3.4, S4.3, S7.2
# C-10: actor.fingerprint != signer -> SIG_FAIL.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Helpers.ps1')
}

Describe 'C-10' {
    BeforeAll {
        $run = $null
        $run = New-ChainRun
        $tree = New-ChainTree $run 2
        $clean = Test-ChainVerify $run

        # Signed by the root key, claiming another key's fingerprint.
        $claim = Split-ChainRun $run 'claim'
        $null = Edit-ChainReceipt -Run $claim -Hash $tree[1] -SignWith $run.Root -Mutate { param($r) $r.actor.fingerprint = $run.Succ1.Fingerprint }
        $claimResult = Test-ChainVerify $claim

        # Claiming the root fingerprint, signed by another key.
        $signer = Split-ChainRun $run 'signer'
        $null = Edit-ChainReceipt -Run $signer -Hash $tree[1] -SignWith $run.Succ1 -Mutate { param($r) $r.claimed_time = $r.claimed_time + 1 }
        $signerResult = Test-ChainVerify $signer
    }
    AfterAll { Remove-ChainRun $run }

    It 'the tree verifies before the rewrite' {
        Assert-ChainExit $clean OK
    }

    It 'root signature under a successor fingerprint is SIG_FAIL' {
        Assert-ChainExit $claimResult SIG_FAIL
    }

    It 'root fingerprint under a successor signature is SIG_FAIL' {
        Assert-ChainExit $signerResult SIG_FAIL
    }
}

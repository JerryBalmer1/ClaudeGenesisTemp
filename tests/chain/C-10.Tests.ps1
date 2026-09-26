# status: red
# spec: S3.4, S4.3, S4.4, S7.2
# C-10: actor.fingerprint differs from the key that produced the signature -> SIG_FAIL. Both directions:
# root's fingerprint over a successor signature, and a successor's fingerprint over a root signature.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Harness.ps1')
}

Describe 'C-10' {
    BeforeAll {
        $run = $null
        $run = New-HarnessRun
        $tree = New-HarnessTree $run 3

        $signerSwapped = New-HarnessCopy $run 'signer'
        $null = Edit-HarnessReceipt $run $tree[2] { param($r) $r.claimed_time += 1 } -SignWith $run.Succ1 -Heaven $signerSwapped
        $signerResult = Test-HarnessChain $run -Heaven $signerSwapped

        $fingerprintSwapped = New-HarnessCopy $run 'fingerprint'
        $null = Edit-HarnessReceipt $run $tree[2] { param($r) $r.actor.fingerprint = $run.Succ1.Fingerprint } -SignWith $run.Root -Heaven $fingerprintSwapped
        $fingerprintResult = Test-HarnessChain $run -Heaven $fingerprintSwapped
    }
    AfterAll { Remove-HarnessRun $run }

    It 'root fingerprint, successor signature -> SIG_FAIL' {
        Assert-HarnessExit $signerResult SIG_FAIL
    }

    It 'successor fingerprint, root signature -> SIG_FAIL' {
        Assert-HarnessExit $fingerprintResult SIG_FAIL
    }
}

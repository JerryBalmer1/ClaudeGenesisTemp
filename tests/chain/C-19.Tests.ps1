# status: red
# spec: S8.1, S8.2, S3.3, S1.9
# C-19: root-revocation. The current successor is accepted; a replaced successor's fingerprint ->
# ACTOR_ILLEGAL; the current successor's fingerprint over a signature by another key -> SIG_FAIL.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Harness.ps1')
}

Describe 'C-19' {
    BeforeAll {
        $run = $null
        $run = New-HarnessRun
        $tree = New-HarnessTree $run 2

        $current = New-HarnessCopy $run 'current'
        $accepted = Invoke-Genesis $run 'Add-GenesisRevocation' @{ RevokeRoot = $true; SigningKeyId = $run.Succ1.KeyId } -Heaven $current
        $acceptedChain = Test-HarnessChain $run -Heaven $current

        $replaced = New-HarnessCopy $run 'replaced'
        $null = Invoke-HarnessWrite $run 'Add-GenesisAmendment' (Get-HarnessAmendmentParameters $run) -Heaven $replaced
        $stale = Invoke-Genesis $run 'Add-GenesisRevocation' @{ RevokeRoot = $true; SigningKeyId = $run.Succ1.KeyId } -Heaven $replaced

        $wrongKey = New-HarnessCopy $run 'wrong-key'
        $b = New-HarnessBody $run 'root-revocation' $tree[1] -Kind 'successor' -Actor $run.Succ1 -Heaven $wrongKey
        $b.revoked_root_fingerprint = $run.Root.Fingerprint
        $null = Write-HarnessReceipt $run $b -SignWith $run.Root -Heaven $wrongKey
        $wrongKeyChain = Test-HarnessChain $run -Heaven $wrongKey
    }
    AfterAll { Remove-HarnessRun $run }

    It 'the current successor writes a root-revocation' {
        Assert-HarnessExit $accepted OK
        $accepted.Written.Count | Should -Be 1
        $r = Read-HarnessReceipt $run $accepted.Written[0] $current
        $r.receipt_type | Should -BeExactly 'root-revocation'
        $r.actor.kind | Should -BeExactly 'successor'
        $r.actor.fingerprint | Should -BeExactly $run.Succ1.Fingerprint
        $r.revoked_root_fingerprint | Should -BeExactly $run.Root.Fingerprint
    }

    It 'the chain holding it verifies' {
        Assert-HarnessExit $acceptedChain OK
    }

    It 'a replaced successor -> ACTOR_ILLEGAL, nothing written' {
        Assert-HarnessExit $stale ACTOR_ILLEGAL
        $stale.Written.Count | Should -Be 0
    }

    It 'current successor fingerprint, root signature -> SIG_FAIL' {
        Assert-HarnessExit $wrongKeyChain SIG_FAIL
    }
}

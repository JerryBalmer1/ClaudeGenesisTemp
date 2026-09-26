# status: red
# spec: S8.1, S8.2, S1.9
# C-19: root-revocation: current successor accepted; wrong fingerprint -> ACTOR_ILLEGAL;
# right fingerprint, wrong key -> SIG_FAIL. Genesis names succ1; one amendment makes succ2 current.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Helpers.ps1')
}

Describe 'C-19' {
    BeforeAll {
        $run = $null
        $run = New-ChainRun
        $null = Add-ChainGenesis $run
        $amendment = Add-ChainAmendment $run

        $ok = Split-ChainRun $run 'ok'
        $writerWrong = Split-ChainRun $run 'writerwrong'
        $wrongFingerprint = Split-ChainRun $run 'wrongfingerprint'
        $wrongKey = Split-ChainRun $run 'wrongkey'

        $okWrite = Invoke-Genesis -Run $ok -Command 'Add-GenesisRevocation' -Parameters @{ RevokeRoot = $true; SigningKeyId = $run.Succ2.KeyId }
        $okVerify = Test-ChainVerify $ok

        $writerBefore = Get-ChainSnapshot $writerWrong.HeavenPath
        $writerResult = Invoke-Genesis -Run $writerWrong -Command 'Add-GenesisRevocation' -Parameters @{ RevokeRoot = $true; SigningKeyId = $run.Succ1.KeyId }
        $writerAfter = Get-ChainSnapshot $writerWrong.HeavenPath

        $body = New-ChainBody -Type 'root-revocation' -Kind 'successor' -Fingerprint $run.Succ1.Fingerprint -Parent $amendment -Position 2
        $body.revoked_root_fingerprint = $run.Root.Fingerprint
        $body.signature = New-ChainSignature -GnupgHome $run.GnupgHome -Key $run.Succ1 -Payload (Get-ChainPayloadBytes $body) -ScratchDir $run.Scratch
        $null = Write-ChainReceipt $wrongFingerprint.HeavenPath $body
        $fingerprintResult = Test-ChainVerify $wrongFingerprint

        $body = New-ChainBody -Type 'root-revocation' -Kind 'successor' -Fingerprint $run.Succ2.Fingerprint -Parent $amendment -Position 2
        $body.revoked_root_fingerprint = $run.Root.Fingerprint
        $body.signature = New-ChainSignature -GnupgHome $run.GnupgHome -Key $run.Succ1 -Payload (Get-ChainPayloadBytes $body) -ScratchDir $run.Scratch
        $null = Write-ChainReceipt $wrongKey.HeavenPath $body
        $keyResult = Test-ChainVerify $wrongKey
    }
    AfterAll { Remove-ChainRun $run }

    It 'the current successor writes a root-revocation' {
        Assert-ChainExit $okWrite OK
        $okWrite.Written.Count | Should -Be 1
        $r = Read-ChainReceipt (Get-ChainReceiptPath $ok $okWrite.Written[0])
        $r.receipt_type | Should -BeExactly 'root-revocation'
        $r.actor.kind | Should -BeExactly 'successor'
        $r.actor.fingerprint | Should -BeExactly $run.Succ2.Fingerprint
        $r.revoked_root_fingerprint | Should -BeExactly $run.Root.Fingerprint
    }

    It 'the chain with the accepted root-revocation verifies' {
        Assert-ChainExit $okVerify OK
    }

    It 'the replaced successor is refused by the writer with ACTOR_ILLEGAL, nothing written' {
        Assert-ChainExit $writerResult ACTOR_ILLEGAL
        $writerAfter | Should -BeExactly $writerBefore
    }

    It 'a root-revocation under the replaced successor fingerprint is ACTOR_ILLEGAL' {
        Assert-ChainExit $fingerprintResult ACTOR_ILLEGAL
    }

    It 'the current successor fingerprint signed by another key is SIG_FAIL' {
        Assert-ChainExit $keyResult SIG_FAIL
    }
}

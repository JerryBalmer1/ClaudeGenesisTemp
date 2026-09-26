# status: red
# spec: S1.5
# C-12: non-TTY New-GenesisReceipt with a protected, non-synthetic key -> IO before gpg; nothing written.
# The genesis is hand-built and signed with the protected key, so that key is the chain's root.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Helpers.ps1')
}

Describe 'C-12' {
    BeforeAll {
        $run = $null
        $run = New-ChainRun
        $protected = New-ChainKey -GnupgHome $run.GnupgHome -KeyDir $run.Keys -Name 'protected' -Passphrase 'chain-test-passphrase'

        $genesis = New-ChainBody -Type 'genesis' -Fingerprint $protected.Fingerprint -Parent '' -Position 0
        $genesis.root_public_key = $protected.PublicKeyBase64
        $genesis.successor_public_key = $run.Succ1.PublicKeyBase64
        $genesis.signature = New-ChainSignature -GnupgHome $run.GnupgHome -Key $protected -Payload (Get-ChainPayloadBytes $genesis) -ScratchDir $run.Scratch
        $null = Write-ChainReceipt $run.HeavenPath $genesis
        $clean = Test-ChainVerify $run

        $before = Get-ChainSnapshot $run.HeavenPath
        $params = Get-ChainReceiptParameters -Run $run -Context 'needs a passphrase'
        $params.SigningKeyId = $protected.KeyId
        $result = Invoke-Genesis -Run $run -Command 'New-GenesisReceipt' -Parameters $params
        $after = Get-ChainSnapshot $run.HeavenPath
    }
    AfterAll { Remove-ChainRun $run }

    It 'the hand-built genesis under the protected key verifies' {
        Assert-ChainExit $clean OK
    }

    It 'the write without a TTY exits IO' {
        Assert-ChainExit $result IO
    }

    It 'nothing is written to receipts/ or content/' {
        $after | Should -BeExactly $before
    }
}

# status: red
# spec: S11.4, S5.1, S2.3
# C-27: signature is excluded from the canonical bytes. Each written receipt is named by the SHA-256 of
# its bytes without signature, and its signature verifies over exactly those bytes; a fresh signature over
# the same payload leaves the filename and the verdict unchanged.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Harness.ps1')
}

Describe 'C-27' {
    BeforeAll {
        $run = $null
        $run = New-HarnessRun
        $tree = New-HarnessTree $run 3
        $receipts = @(foreach ($h in $tree) { [pscustomobject]@{ Hash = $h; Receipt = Read-HarnessReceipt $run $h } })

        # gpg signature packets carry a creation time; wait it out so the fresh signature differs.
        Start-Sleep -Milliseconds 1100
        $head = $receipts[2].Receipt
        $payload = Get-HarnessPayload $head
        $oldSignature = $head.signature
        $head.signature = New-HarnessSignature $run $run.Root $payload
        Set-HarnessText (Get-HarnessReceiptPath $run $tree[2]) (ConvertTo-HarnessCanonical $head)
        $result = Test-HarnessChain $run
    }
    AfterAll { Remove-HarnessRun $run }

    It 'every filename is the hash of the bytes without signature' {
        foreach ($r in $receipts) {
            $r.Receipt.Keys | Should -Contain 'signature'
            Get-HarnessSha (Get-HarnessPayload $r.Receipt) | Should -BeExactly $r.Hash
        }
    }

    It 'every signature verifies over the bytes without signature' {
        foreach ($r in $receipts) {
            $payload = Get-HarnessPayload $r.Receipt
            $script:HarnessUtf8.GetString($payload) | Should -Not -Match '"signature"'
            Test-HarnessSignature $run $run.Root $payload $r.Receipt.signature | Should -BeTrue -Because $r.Hash
        }
    }

    It 'a fresh signature keeps the filename and the chain verifies' {
        $head.signature | Should -Not -Be $oldSignature
        Test-Path -LiteralPath (Get-HarnessReceiptPath $run $tree[2]) | Should -BeTrue
        Assert-HarnessExit $result OK
    }
}

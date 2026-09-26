# status: red
# spec: S11.4, S5.1, S2.3
# C-27: signature is excluded from the canonical bytes. For every receipt the module writes, the filename is
# SHA-256 of RFC 8785 over the receipt minus signature, and the signature verifies over exactly those bytes.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Helpers.ps1')
}

Describe 'C-27' {
    BeforeAll {
        $run = $null
        $run = New-ChainRun
        $genesis = Add-ChainGenesis $run
        $null = Add-ChainReceipt $run -Context 'one', 'two'
        $null = Add-ChainReceipt $run -Context 'three' -AttributedTo 'grok'
        $null = Add-ChainAmendment $run
        $d = Add-ChainDiscrepancy $run
        $null = Add-ChainResolution $run $d
        $rootKey = [Convert]::FromBase64String((Read-ChainReceipt (Get-ChainReceiptPath $run $genesis)).root_public_key)
        $rows = foreach ($name in Get-ChainReceiptName $run.HeavenPath) {
            $receipt = Read-ChainReceipt (Join-Path $run.HeavenPath "receipts/$name")
            $payload = Get-ChainPayloadBytes $receipt
            [pscustomobject]@{
                Name     = $name
                Type     = $receipt.receipt_type
                Payload  = Get-ChainSha256 $payload
                Full     = Get-ChainTextSha256 (ConvertTo-ChainCanonicalJson $receipt)
                Verifies = Test-ChainSignature -PublicKey $rootKey -Payload $payload -Signature $receipt.signature -ScratchDir $run.Scratch
            }
        }
    }
    AfterAll { Remove-ChainRun $run }

    It 'six receipts were written' {
        @($rows).Count | Should -Be 6
    }

    It 'every filename is SHA-256 of the canonical bytes without signature' {
        foreach ($row in $rows) { $row.Name | Should -BeExactly "$($row.Payload).json" -Because $row.Type }
    }

    It 'no filename is the hash of the bytes with signature' {
        foreach ($row in $rows) { $row.Name | Should -Not -Be "$($row.Full).json" -Because $row.Type }
    }

    It 'every signature verifies over the canonical bytes without signature' {
        foreach ($row in $rows) { $row.Verifies | Should -BeTrue -Because $row.Type }
    }
}

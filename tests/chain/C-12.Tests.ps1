# status: red
# spec: S1.5, S7.8
# C-12: New-GenesisReceipt with no TTY and a protected, non-synthetic key -> IO, nothing written. The key's
# comment is not GENESIS-SYNTHETIC-DO-NOT-TRUST and it carries a passphrase, so the S1.5 exception is out.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Harness.ps1')
}

Describe 'C-12' {
    BeforeAll {
        $run = $null
        $run = New-HarnessRun
        $protected = New-HarnessKey $run 'protected' -Passphrase 'chain-test-passphrase'
        $null = New-HarnessTree $run 2
        $before = Get-HarnessSnapshot $run.Heaven
        $p = Get-HarnessReceiptParameters $run -Context 'needs a tty' -Output 'never written'
        $p.SigningKeyId = $protected.KeyId
        $result = Invoke-Genesis $run 'New-GenesisReceipt' $p
        $after = Get-HarnessSnapshot $run.Heaven
    }
    AfterAll { Remove-HarnessRun $run }

    It 'exit IO' {
        Assert-HarnessExit $result IO
    }

    It 'writes nothing' {
        $result.Written.Count | Should -Be 0
        $after | Should -BeExactly $before
    }
}

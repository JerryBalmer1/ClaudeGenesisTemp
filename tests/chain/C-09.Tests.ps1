# status: red
# spec: S6.1, S6.6, S7.2
# C-09: two receipts with the same prompt_hash and different output_hash are both accepted.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Harness.ps1')
}

Describe 'C-09' {
    BeforeAll {
        $run = $null
        $run = New-HarnessRun
        $null = Add-HarnessGenesis $run
        $one = Add-HarnessReceipt $run -Context 'same prompt' -Output 'answer one'
        $two = Add-HarnessReceipt $run -Context 'same prompt' -Output 'answer two'
        $result = Test-HarnessChain $run
    }
    AfterAll { Remove-HarnessRun $run }

    It 'same prompt_hash, different output_hash' {
        $a = Read-HarnessReceipt $run $one
        $b = Read-HarnessReceipt $run $two
        $a.prompt_hash | Should -BeExactly $b.prompt_hash
        $a.output_hash | Should -Not -Be $b.output_hash
    }

    It 'the chain verifies' {
        Assert-HarnessExit $result OK
    }
}

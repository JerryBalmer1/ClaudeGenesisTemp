# status: red
# spec: S6.3, S6.6, S7.2
# C-09: two receipts with the same prompt_hash and different output_hash are both accepted.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Helpers.ps1')
}

Describe 'C-09' {
    BeforeAll {
        $run = $null
        $run = New-ChainRun
        $null = Add-ChainGenesis $run
        $first = Add-ChainReceipt $run -Context 'the same prompt' -Output 'first answer'
        $second = Add-ChainReceipt $run -Context 'the same prompt' -Output 'second answer'
        $a = Read-ChainReceipt (Get-ChainReceiptPath $run $first)
        $b = Read-ChainReceipt (Get-ChainReceiptPath $run $second)
        $result = Test-ChainVerify $run
    }
    AfterAll { Remove-ChainRun $run }

    It 'the two receipts share prompt_hash and differ in output_hash' {
        $b.prompt_hash | Should -BeExactly $a.prompt_hash
        $b.output_hash | Should -Not -Be $a.output_hash
    }

    It 'the chain verifies' {
        Assert-ChainExit $result OK
    }
}

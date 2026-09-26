# status: red
# spec: S6.4, S3.2
# C-13: empty prompt_context with a non-empty prompt_hash -> SCHEMA.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Helpers.ps1')
}

Describe 'C-13' {
    BeforeAll {
        $run = $null
        $run = New-ChainRun
        $tree = New-ChainTree $run 2
        $original = Read-ChainReceipt (Get-ChainReceiptPath $run $tree[1])
        $null = Edit-ChainReceipt -Run $run -Hash $tree[1] -SignWith $run.Root -Mutate { param($r) $r.prompt_context = @() }
        $result = Test-ChainVerify $run
    }
    AfterAll { Remove-ChainRun $run }

    It 'the rewritten receipt keeps a prompt_hash that is not SHA-256 of empty' {
        $original.prompt_hash | Should -Not -Be $ChainEmptyHash
    }

    It 'the chain is SCHEMA' {
        Assert-ChainExit $result SCHEMA
    }
}

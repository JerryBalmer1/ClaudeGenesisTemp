# status: red
# spec: S6.4, S3.2
# C-13: a receipt with empty prompt_context and a prompt_hash that is not SHA-256("") -> SCHEMA.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Harness.ps1')
}

Describe 'C-13' {
    BeforeAll {
        $run = $null
        $run = New-HarnessRun
        $tree = New-HarnessTree $run 2
        $body = New-HarnessBody $run 'receipt' $tree[1]
        $body.prompt_hash = Get-HarnessTextSha 'not the empty prompt'
        $body.output_hash = Get-HarnessTextSha 'an output'
        $null = Write-HarnessReceipt $run $body -SignWith $run.Root
        $result = Test-HarnessChain $run
    }
    AfterAll { Remove-HarnessRun $run }

    It 'exit SCHEMA' {
        Assert-HarnessExit $result SCHEMA
    }
}

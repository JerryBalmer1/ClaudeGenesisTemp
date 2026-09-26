# status: red
# spec: S3.2, S6.4
# C-29: a non-receipt type with non-empty prompt_context, or with output_hash other than SHA-256(""),
# -> SCHEMA.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Harness.ps1')
}

Describe 'C-29' {
    BeforeAll {
        $run = $null
        $run = New-HarnessRun
        $tree = New-HarnessTree $run 2

        $h = New-HarnessCopy $run 'context'
        $b = New-HarnessBody $run 'revocation' $tree[1] -Heaven $h
        $b.revokes = $tree[1]
        $b.prompt_context = @(Get-HarnessTextSha 'context')
        $null = Write-HarnessReceipt $run $b -SignWith $run.Root -Heaven $h
        $context = Test-HarnessChain $run -Heaven $h

        $h = New-HarnessCopy $run 'output'
        $b = New-HarnessBody $run 'revocation' $tree[1] -Heaven $h
        $b.revokes = $tree[1]
        $b.output_hash = Get-HarnessTextSha 'output'
        $null = Write-HarnessReceipt $run $b -SignWith $run.Root -Heaven $h
        $output = Test-HarnessChain $run -Heaven $h
    }
    AfterAll { Remove-HarnessRun $run }

    It 'revocation with non-empty prompt_context -> SCHEMA' {
        Assert-HarnessExit $context SCHEMA
    }

    It 'revocation with non-empty-hash output_hash -> SCHEMA' {
        Assert-HarnessExit $output SCHEMA
    }
}

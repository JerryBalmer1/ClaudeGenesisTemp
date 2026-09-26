# status: red
# spec: S3.2, S3.3
# C-29: a non-receipt type with a non-empty prompt_context, or an output_hash that is not SHA-256 of empty,
# -> SCHEMA.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Helpers.ps1')
}

Describe 'C-29' {
    BeforeAll {
        $run = $null
        $run = New-ChainRun
        $genesis = Add-ChainGenesis $run
        $genesisContext = Split-ChainRun $run 'genesiscontext'
        $genesisOutput = Split-ChainRun $run 'genesisoutput'
        $disc = Add-ChainDiscrepancy $run
        $discContext = Split-ChainRun $run 'disccontext'
        $discOutput = Split-ChainRun $run 'discoutput'
        $h = Get-ChainTextSha256 'not empty'

        $null = Edit-ChainReceipt -Run $genesisContext -Hash $genesis -SignWith $run.Root -Mutate { param($r) $r.prompt_context = @($h) }
        $null = Edit-ChainReceipt -Run $genesisOutput -Hash $genesis -SignWith $run.Root -Mutate { param($r) $r.output_hash = $h }
        $null = Edit-ChainReceipt -Run $discContext -Hash $disc -SignWith $run.Root -Mutate { param($r) $r.prompt_context = @($h) }
        $null = Edit-ChainReceipt -Run $discOutput -Hash $disc -SignWith $run.Root -Mutate { param($r) $r.output_hash = $h }

        $results = [ordered]@{
            'genesis with prompt_context'     = Test-ChainVerify $genesisContext
            'genesis with output_hash'        = Test-ChainVerify $genesisOutput
            'discrepancy with prompt_context' = Test-ChainVerify $discContext
            'discrepancy with output_hash'    = Test-ChainVerify $discOutput
        }
    }
    AfterAll { Remove-ChainRun $run }

    It '<_> is SCHEMA' -ForEach @('genesis with prompt_context', 'genesis with output_hash', 'discrepancy with prompt_context', 'discrepancy with output_hash') {
        Assert-ChainExit $results[$_] SCHEMA
    }
}

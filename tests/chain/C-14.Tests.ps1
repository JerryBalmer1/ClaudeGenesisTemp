# status: red
# spec: S6.5, S7.1
# C-14: a resolvable manifest whose recomputed assembly != prompt_hash -> HASH_MISMATCH.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Helpers.ps1')
}

Describe 'C-14' {
    BeforeAll {
        $run = $null
        $run = New-ChainRun
        $null = Add-ChainGenesis $run
        $receipt = Add-ChainReceipt $run -Context 'part a', 'part b'
        $original = Read-ChainReceipt (Get-ChainReceiptPath $run $receipt)
        $null = Edit-ChainReceipt -Run $run -Hash $receipt -SignWith $run.Root -Mutate { param($r) $r.prompt_hash = Get-ChainTextSha256 'not the assembly' }
        $result = Test-ChainVerify $run
    }
    AfterAll { Remove-ChainRun $run }

    It 'every context part resolves in content/' {
        foreach ($h in $original.prompt_context) {
            Test-Path -LiteralPath (Join-Path $run.HeavenPath "content/$h") | Should -BeTrue
        }
    }

    It 'the chain is HASH_MISMATCH' {
        Assert-ChainExit $result HASH_MISMATCH
    }
}

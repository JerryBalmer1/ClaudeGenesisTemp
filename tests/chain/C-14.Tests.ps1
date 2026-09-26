# status: red
# spec: S6.5, S7.1
# C-14: every context part resolves in content/, the recomputed assembly differs from prompt_hash ->
# HASH_MISMATCH.

BeforeAll {
    . (Join-Path $PSScriptRoot 'Chain.Harness.ps1')
}

Describe 'C-14' {
    BeforeAll {
        $run = $null
        $run = New-HarnessRun
        $null = Add-HarnessGenesis $run
        $head = Add-HarnessReceipt $run -Context 'alpha', 'beta' -Output 'out'
        $clean = Test-HarnessChain $run
        $context = (Read-HarnessReceipt $run $head).prompt_context
        $null = Edit-HarnessReceipt $run $head { param($r) $r.prompt_hash = Get-HarnessTextSha 'beta alpha' } -SignWith $run.Root
        $result = Test-HarnessChain $run
    }
    AfterAll { Remove-HarnessRun $run }

    It 'the untouched chain verifies' {
        Assert-HarnessExit $clean OK
    }

    It 'every context part is in content/' {
        foreach ($h in $context) { Test-Path -LiteralPath (Join-Path $run.Heaven "content/$h") | Should -BeTrue }
    }

    It 'exit HASH_MISMATCH' {
        Assert-HarnessExit $result HASH_MISMATCH
    }
}
